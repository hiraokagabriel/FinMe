import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/layout.dart';
import '../../../core/widgets/money.dart';
import '../../../core/widgets/sortable_header.dart';
import '../domain/monthly_flow.dart';

const _barChartHeight = 220.0;
const _lineChartHeight = 160.0;
const _barWidth = 8.0;
const _monthColWidth = 96.0;
const _moneyColWidth = 128.0;
const _averageColWidth = 152.0;
const _cellPadding = EdgeInsets.symmetric(
  horizontal: AppSpace.sm,
  vertical: AppSpace.sm,
);

/// Tooltip de um mês (SPEC §7.3 Fase 12). Linhas separadas por '\n'; [hideValues] mascara os valores.
String trendTooltipText(TrendPoint p, {required bool hideValues}) {
  String money(int cents) => formatMoney(cents, hidden: hideValues);
  return [
    formatMonthLong(p.month),
    'Receitas: ${money(p.incomeCents)}',
    'Despesas: ${money(p.expenseCents)}',
    'Saldo do mês: ${money(p.balanceCents)}',
  ].join('\n');
}

/// Colunas da tabela. `month` ordena por data; as demais por valor.
enum _TrendColumn {
  month,
  income,
  expense,
  balance,
  expenseAverage,
  balanceAverage,
}

/// Totais do rodapé e flags de escala. Calculados uma vez por lista de pontos, nunca no build.
class _Totals {
  _Totals(List<TrendPoint> points)
    : income = points.fold(0, (s, p) => s + p.incomeCents),
      expense = points.fold(0, (s, p) => s + p.expenseCents),
      noFlow = points.every((p) => p.incomeCents == 0 && p.expenseCents == 0),
      hasNegativeBalance = points.any((p) => p.balanceCents < 0);

  final int income;
  final int expense;
  final bool noFlow;
  final bool hasNegativeBalance;

  int get balance => income - expense;
}

/// Tendência mensal: barras de receita e despesa, linha de saldo (Ultra) e tabela.
/// x = índice em [points]; y = reais (só para os gráficos). A média móvel vem pronta do domínio.
class TrendView extends StatefulWidget {
  const TrendView({
    super.key,
    required this.points,
    required this.expenseAverage,
    required this.balanceAverage,
    required this.ultra,
    required this.hideValues,
  });

  final List<TrendPoint> points;
  final List<int?> expenseAverage;
  final List<int?> balanceAverage;
  final bool ultra;
  final bool hideValues;

  @override
  State<TrendView> createState() => _TrendViewState();
}

class _TrendViewState extends State<TrendView> {
  bool _showAverage = false;
  _TrendColumn _column = _TrendColumn.month;
  bool _ascending = true;
  late _Totals _totals = _Totals(widget.points);

  @override
  void didUpdateWidget(TrendView old) {
    super.didUpdateWidget(old);
    if (!identical(old.points, widget.points)) {
      _totals = _Totals(widget.points);
    }
  }

  /// Valor da célula de [col] no mês [i]; `null` = sem média. Também é a chave de ordenação.
  int? _valueAt(_TrendColumn col, int i) {
    final p = widget.points[i];
    return switch (col) {
      _TrendColumn.month => i,
      _TrendColumn.income => p.incomeCents,
      _TrendColumn.expense => p.expenseCents,
      _TrendColumn.balance => p.balanceCents,
      _TrendColumn.expenseAverage => widget.expenseAverage[i],
      _TrendColumn.balanceAverage => widget.balanceAverage[i],
    };
  }

  /// Ordem das linhas (presentação). Nulos sempre no fim; empate pela ordem cronológica.
  List<int> _order() {
    final order = [for (var i = 0; i < widget.points.length; i++) i];
    order.sort((a, b) {
      final ka = _valueAt(_column, a);
      final kb = _valueAt(_column, b);
      if (ka == null || kb == null) {
        return (ka == null ? 1 : 0) - (kb == null ? 1 : 0);
      }
      final cmp = _ascending ? ka.compareTo(kb) : kb.compareTo(ka);
      return cmp != 0 ? cmp : a.compareTo(b);
    });
    return order;
  }

  /// Coluna nova: texto (mês) asc, valor desc. Coluna ativa: inverte.
  void _sortBy(_TrendColumn col) {
    setState(() {
      if (col == _column) {
        _ascending = !_ascending;
      } else {
        _column = col;
        _ascending = col == _TrendColumn.month;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final t = _totals;
    if (t.noFlow) {
      return const EmptyState(
        icon: Icons.bar_chart,
        message: 'Sem lançamentos no período com estes filtros.',
      );
    }
    final c = context.colors;
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            height: _barChartHeight,
            child: _TrendBarChart(
              points: widget.points,
              hideValues: widget.hideValues,
            ),
          ),
          const SizedBox(height: AppSpace.sm),
          _Legend(items: [(c.success, 'Receitas'), (c.chartBar, 'Despesas')]),
          if (widget.ultra) ...[
            const SizedBox(height: AppSpace.xl),
            Align(
              alignment: Alignment.centerLeft,
              child: FilterChip(
                key: const Key('trend-average'),
                label: const Text('Média móvel 3 meses'),
                selected: _showAverage,
                onSelected: (v) => setState(() => _showAverage = v),
              ),
            ),
            const SizedBox(height: AppSpace.sm),
            SizedBox(
              height: _lineChartHeight,
              child: _BalanceLineChart(
                points: widget.points,
                showAverage: _showAverage,
                balanceAverage: widget.balanceAverage,
                expenseAverage: widget.expenseAverage,
                hasNegative: t.hasNegativeBalance,
                hideValues: widget.hideValues,
              ),
            ),
            const SizedBox(height: AppSpace.sm),
            _Legend(
              items: [
                (c.primary, 'Saldo do mês'),
                if (_showAverage) ...[
                  (c.primary, 'Média 3m saldo'),
                  (c.textSecondary, 'Média 3m despesas'),
                ],
              ],
            ),
          ],
          const SizedBox(height: AppSpace.xl),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: _table(context, _order(), t),
          ),
        ],
      ),
    );
  }

  Widget _table(BuildContext context, List<int> order, _Totals t) {
    final c = context.colors;
    final body = Theme.of(context).textTheme.bodyMedium;
    final bold = body?.copyWith(fontWeight: FontWeight.w600);
    final cols = [
      (_TrendColumn.month, 'Mês', _monthColWidth),
      (_TrendColumn.income, 'Receitas', _moneyColWidth),
      (_TrendColumn.expense, 'Despesas', _moneyColWidth),
      (_TrendColumn.balance, 'Saldo do mês', _moneyColWidth),
      if (widget.ultra) ...[
        (_TrendColumn.expenseAverage, 'Média 3m despesas', _averageColWidth),
        (_TrendColumn.balanceAverage, 'Média 3m saldo', _averageColWidth),
      ],
    ];
    return Table(
      defaultVerticalAlignment: TableCellVerticalAlignment.middle,
      columnWidths: {
        for (var i = 0; i < cols.length; i++) i: FixedColumnWidth(cols[i].$3),
      },
      children: [
        TableRow(
          decoration: BoxDecoration(
            border: Border(bottom: BorderSide(color: c.border)),
          ),
          children: [
            for (final (col, label, _) in cols)
              Padding(
                padding: _cellPadding,
                child: SortableHeaderLabel(
                  label: label,
                  active: _column == col,
                  ascending: _ascending,
                  alignEnd: col != _TrendColumn.month,
                  onTap: () => _sortBy(col),
                ),
              ),
          ],
        ),
        for (final i in order)
          TableRow(
            children: [
              for (final (col, _, _) in cols)
                Padding(padding: _cellPadding, child: _cell(col, i, body, c)),
            ],
          ),
        TableRow(
          decoration: BoxDecoration(
            border: Border(top: BorderSide(color: c.border)),
          ),
          children: [
            Padding(
              padding: _cellPadding,
              child: Text('Total', style: bold),
            ),
            _alignEnd(MoneyText(t.income, style: bold)),
            _alignEnd(MoneyText(t.expense, style: bold)),
            _alignEnd(MoneyText(t.balance, style: bold, colorBySign: true)),
            if (widget.ultra) ...const [SizedBox.shrink(), SizedBox.shrink()],
          ],
        ),
      ],
    );
  }

  Widget _cell(_TrendColumn col, int i, TextStyle? body, AppColors c) {
    if (col == _TrendColumn.month) {
      return Text(formatMonth(widget.points[i].month), style: body);
    }
    final cents = _valueAt(col, i);
    if (cents == null) {
      return _alignEnd(
        Text('–', style: body?.copyWith(color: c.textSecondary)),
      );
    }
    final colorBySign =
        col == _TrendColumn.balance || col == _TrendColumn.balanceAverage;
    return _alignEnd(MoneyText(cents, style: body, colorBySign: colorBySign));
  }

  Widget _alignEnd(Widget child) =>
      Align(alignment: Alignment.centerRight, child: child);
}

FlTitlesData _trendTitles(
  BuildContext context,
  List<TrendPoint> points,
  bool hideValues,
) {
  final style = Theme.of(
    context,
  ).textTheme.bodySmall?.copyWith(color: context.colors.textSecondary);
  final last = points.length - 1;
  // Até 12 meses, rótulo em todos; acima disso, 1 a cada 3.
  final every = points.length > 12 ? 3.0 : 1.0;
  return FlTitlesData(
    topTitles: const AxisTitles(),
    rightTitles: const AxisTitles(),
    leftTitles: AxisTitles(
      sideTitles: SideTitles(
        showTitles: !hideValues,
        reservedSize: 88,
        getTitlesWidget: (v, meta) =>
            Text(formatMoney((v * 100).round()), style: style),
      ),
    ),
    bottomTitles: AxisTitles(
      sideTitles: SideTitles(
        showTitles: true,
        reservedSize: 24,
        interval: every,
        getTitlesWidget: (v, meta) => Text(
          formatMonth(points[v.round().clamp(0, last)].month),
          style: style,
        ),
      ),
    ),
  );
}

FlGridData _grid(AppColors c) => FlGridData(
  drawVerticalLine: false,
  getDrawingHorizontalLine: (_) => FlLine(color: c.border, strokeWidth: 1),
);

/// Receita e despesa por mês. Tooltip rico com [trendTooltipText].
class _TrendBarChart extends StatelessWidget {
  const _TrendBarChart({required this.points, required this.hideValues});

  final List<TrendPoint> points;
  final bool hideValues;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return BarChart(
      BarChartData(
        barGroups: [
          for (var i = 0; i < points.length; i++)
            BarChartGroupData(
              x: i,
              barRods: [
                BarChartRodData(
                  toY: points[i].incomeCents / 100,
                  color: c.success,
                  width: _barWidth,
                ),
                BarChartRodData(
                  toY: points[i].expenseCents / 100,
                  color: c.chartBar,
                  width: _barWidth,
                ),
              ],
            ),
        ],
        barTouchData: BarTouchData(
          touchTooltipData: BarTouchTooltipData(
            getTooltipColor: (_) => c.surface,
            tooltipBorder: BorderSide(color: c.border),
            getTooltipItem: (group, _, rod, rodIndex) => BarTooltipItem(
              trendTooltipText(points[group.x], hideValues: hideValues),
              TextStyle(color: c.textPrimary, fontSize: 12),
            ),
          ),
        ),
        titlesData: _trendTitles(context, points, hideValues),
        gridData: _grid(c),
        borderData: FlBorderData(show: false),
      ),
    );
  }
}

List<FlSpot> _spots(List<int?> values) => [
  for (var i = 0; i < values.length; i++)
    values[i] == null
        ? FlSpot.nullSpot
        : FlSpot(i.toDouble(), values[i]! / 100),
];

LineChartBarData _line(
  List<FlSpot> spots,
  Color color, {
  bool dashed = false,
}) => LineChartBarData(
  spots: spots,
  color: color,
  barWidth: dashed ? 1.5 : 2,
  dashArray: dashed ? const [6, 4] : null,
  dotData: const FlDotData(show: false),
);

/// Saldo do mês (Ultra). Com [showAverage], soma média do saldo e média das despesas (tracejadas).
class _BalanceLineChart extends StatelessWidget {
  const _BalanceLineChart({
    required this.points,
    required this.showAverage,
    required this.balanceAverage,
    required this.expenseAverage,
    required this.hasNegative,
    required this.hideValues,
  });

  final List<TrendPoint> points;
  final bool showAverage;
  final List<int?> balanceAverage;
  final List<int?> expenseAverage;
  final bool hasNegative;
  final bool hideValues;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return LineChart(
      LineChartData(
        minX: 0,
        maxX: (points.length - 1).toDouble(),
        lineBarsData: [
          _line(_spots([for (final p in points) p.balanceCents]), c.primary),
          if (showAverage) ...[
            _line(_spots(balanceAverage), c.primary, dashed: true),
            _line(_spots(expenseAverage), c.textSecondary, dashed: true),
          ],
        ],
        extraLinesData: ExtraLinesData(
          horizontalLines: [
            if (hasNegative)
              HorizontalLine(
                y: 0,
                color: c.danger.withValues(alpha: 0.4),
                strokeWidth: 1,
                dashArray: const [6, 4],
              ),
          ],
        ),
        lineTouchData: const LineTouchData(enabled: false),
        titlesData: _trendTitles(context, points, hideValues),
        gridData: _grid(c),
        borderData: FlBorderData(show: false),
      ),
    );
  }
}

/// Legenda compacta: quadradinho na cor da série + rótulo.
class _Legend extends StatelessWidget {
  const _Legend({required this.items});

  final List<(Color, String)> items;

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(
      context,
    ).textTheme.bodySmall?.copyWith(color: context.colors.textSecondary);
    return Wrap(
      spacing: AppSpace.lg,
      runSpacing: AppSpace.xs,
      children: [
        for (final (color, label) in items)
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              DecoratedBox(
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: AppRadius.chipBorder,
                ),
                child: const SizedBox(width: 10, height: 10),
              ),
              const SizedBox(width: AppSpace.xs),
              Text(label, style: style),
            ],
          ),
      ],
    );
  }
}
