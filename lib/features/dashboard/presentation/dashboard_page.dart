import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';

import '../../../app/router.dart';
import '../../../core/models/app_mode.dart';
import '../../../core/services/app_mode_controller.dart';
import '../../../core/services/repository_locator.dart';
import '../../../core/theme/app_theme.dart';
import '../../transactions/domain/transaction_entity.dart';
import '../../transactions/domain/transaction_type.dart';

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  List<TransactionEntity> _transactions = const [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final txs = await RepositoryLocator.instance.transactions.getAll();
    if (!mounted) return;
    setState(() {
      _transactions = txs;
      _isLoading = false;
    });
  }

  List<_MonthSummary> _buildMonthlySummary({int months = 6}) {
    final now = DateTime.now();
    return List.generate(months, (i) {
      final month = DateTime(now.year, now.month - (months - 1 - i), 1);
      double income = 0;
      double expense = 0;
      for (final tx in _transactions) {
        if (tx.isProvisioned) continue;
        if (tx.date.year == month.year && tx.date.month == month.month) {
          if (tx.type == TransactionType.income) {
            income += tx.amount.amount;
          } else {
            expense += tx.amount.amount;
          }
        }
      }
      return _MonthSummary(month: month, income: income, expense: expense);
    });
  }

  (double, double) get _currentMonthTotals {
    final now = DateTime.now();
    double income = 0;
    double expense = 0;
    for (final tx in _transactions) {
      if (tx.isProvisioned) continue;
      if (tx.date.year == now.year && tx.date.month == now.month) {
        if (tx.type == TransactionType.income) {
          income += tx.amount.amount;
        } else {
          expense += tx.amount.amount;
        }
      }
    }
    return (income, expense);
  }

  double get _totalProvisioned {
    final now = DateTime.now();
    double total = 0;
    for (final tx in _transactions) {
      if (!tx.isProvisioned) continue;
      final due = tx.provisionedDueDate ?? tx.date;
      if (!due.isBefore(DateTime(now.year, now.month, now.day))) {
        total += tx.amount.amount;
      }
    }
    return total;
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: AppModeController.instance,
      builder: (context, _) {
        final isUltra =
            AppModeController.instance.mode == AppMode.ultra;

        return Scaffold(
          appBar: AppBar(
            title: const Text('FinMe'),
            actions: [
              IconButton(
                tooltip: 'Configurações',
                icon: const Icon(Icons.settings_outlined),
                onPressed: () =>
                    Navigator.of(context).pushNamed(AppRouter.settings),
              ),
            ],
          ),
          body: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView(
                    padding: const EdgeInsets.all(AppSpacing.lg),
                    children: [
                      _buildModeBadge(isUltra),
                      const SizedBox(height: AppSpacing.lg),
                      _buildSummaryCards(isUltra),
                      const SizedBox(height: AppSpacing.lg),
                      _buildLineChartCard(),
                      const SizedBox(height: AppSpacing.lg),
                      _buildQuickActions(context, isUltra),
                      const SizedBox(height: AppSpacing.lg),
                    ],
                  ),
                ),
        );
      },
    );
  }

  Widget _buildModeBadge(bool isUltra) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md, vertical: AppSpacing.xs),
          decoration: BoxDecoration(
            color:
                isUltra ? AppColors.primarySubtle : AppColors.sidebar,
            borderRadius: BorderRadius.circular(AppRadius.full),
          ),
          child: Text(
            isUltra ? 'Modo Ultra' : 'Modo Simples',
            style: AppText.badge.copyWith(
              color: isUltra
                  ? AppColors.primary
                  : AppColors.textSecondary,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSummaryCards(bool isUltra) {
    final (income, expense) = _currentMonthTotals;
    final balance = income - expense;

    final cards = [
      _SummaryCardData(
        label: 'Receitas',
        value: income,
        icon: Icons.arrow_upward_rounded,
        color: AppColors.limitLow,
        prefix: '+ R\$',
      ),
      _SummaryCardData(
        label: 'Despesas',
        value: expense,
        icon: Icons.arrow_downward_rounded,
        color: AppColors.danger,
        prefix: '- R\$',
      ),
      _SummaryCardData(
        label: 'Saldo',
        value: balance,
        icon: Icons.account_balance_wallet_outlined,
        color: balance >= 0 ? AppColors.primary : AppColors.danger,
        prefix: 'R\$',
      ),
    ];

    final all = isUltra
        ? [
            ...cards,
            _SummaryCardData(
              label: 'A vencer',
              value: _totalProvisioned,
              icon: Icons.schedule_outlined,
              color: AppColors.warning,
              prefix: 'R\$',
            ),
          ]
        : cards;

    return Row(
      children: all
          .asMap()
          .entries
          .map((e) => Expanded(
                child: Padding(
                  padding: EdgeInsets.only(
                      right: e.key < all.length - 1
                          ? AppSpacing.sm
                          : 0),
                  child: _SummaryCard(data: e.value),
                ),
              ))
          .toList(),
    );
  }

  Widget _buildLineChartCard() {
    final summary = _buildMonthlySummary(months: 6);
    final hasData = summary.any((m) => m.income > 0 || m.expense > 0);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text('Evolução mensal', style: AppText.sectionLabel),
                const Spacer(),
                _LegendDot(
                    color: AppColors.limitLow, label: 'Receitas'),
                const SizedBox(width: AppSpacing.md),
                _LegendDot(
                    color: AppColors.danger, label: 'Despesas'),
              ],
            ),
            const SizedBox(height: AppSpacing.lg),
            if (!hasData)
              SizedBox(
                height: 160,
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.show_chart_outlined,
                          size: 36,
                          color: AppColors.textSecondary),
                      const SizedBox(height: AppSpacing.sm),
                      Text('Sem dados nos últimos 6 meses',
                          style: AppText.secondary),
                    ],
                  ),
                ),
              )
            else
              SizedBox(
                height: 180,
                child: _MonthlyLineChart(summary: summary),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickActions(BuildContext context, bool isUltra) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Acesso rápido', style: AppText.sectionLabel),
        const SizedBox(height: AppSpacing.md),
        Wrap(
          spacing: AppSpacing.md,
          runSpacing: AppSpacing.md,
          children: [
            OutlinedButton.icon(
              onPressed: () => Navigator.of(context)
                  .pushNamed(AppRouter.transactions),
              icon: const Icon(Icons.receipt_long_outlined),
              label: const Text('Transações'),
            ),
            OutlinedButton.icon(
              onPressed: () =>
                  Navigator.of(context).pushNamed(AppRouter.goals),
              icon: const Icon(Icons.flag_outlined),
              label: const Text('Metas'),
            ),
            if (isUltra)
              OutlinedButton.icon(
                onPressed: () =>
                    Navigator.of(context).pushNamed(AppRouter.cards),
                icon: const Icon(Icons.credit_card_outlined),
                label: const Text('Cartões'),
              ),
          ],
        ),
      ],
    );
  }
}

// ── Gráfico ───────────────────────────────────────────────────────────────

class _MonthlyLineChart extends StatelessWidget {
  const _MonthlyLineChart({required this.summary});
  final List<_MonthSummary> summary;

  static const _monthAbbr = [
    '', 'Jan', 'Fev', 'Mar', 'Abr', 'Mai', 'Jun',
    'Jul', 'Ago', 'Set', 'Out', 'Nov', 'Dez',
  ];

  @override
  Widget build(BuildContext context) {
    final maxY = summary
        .expand((m) => [m.income, m.expense])
        .fold<double>(0, (a, b) => a > b ? a : b);
    final topY = maxY <= 0 ? 1000.0 : (maxY * 1.2);

    FlSpot toSpot(int i, double v) => FlSpot(i.toDouble(), v);

    final incomeSpots = [
      for (int i = 0; i < summary.length; i++)
        toSpot(i, summary[i].income)
    ];
    final expenseSpots = [
      for (int i = 0; i < summary.length; i++)
        toSpot(i, summary[i].expense)
    ];

    return LineChart(
      LineChartData(
        minY: 0,
        maxY: topY,
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          getDrawingHorizontalLine: (_) =>
              FlLine(color: AppColors.divider, strokeWidth: 1),
        ),
        borderData: FlBorderData(show: false),
        titlesData: FlTitlesData(
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 48,
              getTitlesWidget: (value, _) {
                if (value == 0) return const SizedBox.shrink();
                final label = value >= 1000
                    ? 'R\$${(value / 1000).toStringAsFixed(0)}k'
                    : 'R\$${value.toStringAsFixed(0)}';
                return Text(label,
                    style: AppText.secondary
                        .copyWith(fontSize: 10));
              },
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 24,
              getTitlesWidget: (value, _) {
                final i = value.toInt();
                if (i < 0 || i >= summary.length) {
                  return const SizedBox.shrink();
                }
                return Text(
                  _monthAbbr[summary[i].month.month],
                  style:
                      AppText.secondary.copyWith(fontSize: 10),
                );
              },
            ),
          ),
          topTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false)),
          rightTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false)),
        ),
        lineBarsData: [
          LineChartBarData(
            spots: incomeSpots,
            isCurved: true,
            color: AppColors.limitLow,
            barWidth: 2.5,
            dotData: FlDotData(
              show: true,
              getDotPainter: (_, __, ___, ____) =>
                  FlDotCirclePainter(
                radius: 3.5,
                color: AppColors.limitLow,
                strokeWidth: 0,
              ),
            ),
            belowBarData: BarAreaData(
              show: true,
              color: AppColors.limitLow.withOpacity(0.08),
            ),
          ),
          LineChartBarData(
            spots: expenseSpots,
            isCurved: true,
            color: AppColors.danger,
            barWidth: 2.5,
            dotData: FlDotData(
              show: true,
              getDotPainter: (_, __, ___, ____) =>
                  FlDotCirclePainter(
                radius: 3.5,
                color: AppColors.danger,
                strokeWidth: 0,
              ),
            ),
            belowBarData: BarAreaData(
              show: true,
              color: AppColors.danger.withOpacity(0.06),
            ),
          ),
        ],
        lineTouchData: LineTouchData(
          touchTooltipData: LineTouchTooltipData(
            getTooltipColor: (_) => AppColors.surface,
            tooltipBorder: BorderSide(color: AppColors.divider),
            getTooltipItems: (spots) {
              return spots.map((s) {
                final isIncome = s.barIndex == 0;
                return LineTooltipItem(
                  'R\$ ${s.y.toStringAsFixed(2)}',
                  AppText.secondary.copyWith(
                    color: isIncome
                        ? AppColors.limitLow
                        : AppColors.danger,
                    fontWeight: FontWeight.w600,
                  ),
                );
              }).toList();
            },
          ),
        ),
      ),
    );
  }
}

// ── Widgets auxiliares ─────────────────────────────────────────────────────

class _MonthSummary {
  const _MonthSummary(
      {required this.month,
      required this.income,
      required this.expense});
  final DateTime month;
  final double income;
  final double expense;
}

class _SummaryCardData {
  const _SummaryCardData({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
    required this.prefix,
  });
  final String label;
  final double value;
  final IconData icon;
  final Color color;
  final String prefix;
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({required this.data});
  final _SummaryCardData data;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(data.icon, size: 14, color: data.color),
                const SizedBox(width: AppSpacing.xs),
                Flexible(
                  child: Text(data.label,
                      style: AppText.secondary,
                      overflow: TextOverflow.ellipsis),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              '${data.prefix} ${data.value.toStringAsFixed(2)}',
              style: AppText.amount
                  .copyWith(color: data.color, fontSize: 13),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}

class _LegendDot extends StatelessWidget {
  const _LegendDot({required this.color, required this.label});
  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration:
              BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: AppSpacing.xs),
        Text(label, style: AppText.secondary),
      ],
    );
  }
}
