import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';

import '../data/transactions_repository.dart';
import '../domain/transaction_entity.dart';
import '../domain/transaction_type.dart';
import '../../categories/domain/category_entity.dart';
import '../../cards/domain/card_entity.dart';
import '../../../core/models/app_mode.dart';
import '../../../core/services/app_mode_controller.dart';
import '../../../core/services/repository_locator.dart';
import '../../../core/theme/app_theme.dart';
import 'new_transaction_page.dart';

enum _PeriodFilter { thisMonth, lastMonth, thisWeek, all }

String _periodLabel(_PeriodFilter f) {
  switch (f) {
    case _PeriodFilter.thisMonth:  return 'Este mês';
    case _PeriodFilter.lastMonth:  return 'Mês anterior';
    case _PeriodFilter.thisWeek:   return 'Esta semana';
    case _PeriodFilter.all:        return 'Tudo';
  }
}

(DateTime, DateTime) _periodRange(_PeriodFilter f) {
  final now = DateTime.now();
  switch (f) {
    case _PeriodFilter.thisMonth:
      return (
        DateTime(now.year, now.month, 1),
        DateTime(now.year, now.month + 1, 0, 23, 59, 59),
      );
    case _PeriodFilter.lastMonth:
      return (
        DateTime(now.year, now.month - 1, 1),
        DateTime(now.year, now.month, 0, 23, 59, 59),
      );
    case _PeriodFilter.thisWeek:
      final start = now.subtract(Duration(days: now.weekday - 1));
      return (
        DateTime(start.year, start.month, start.day),
        DateTime(now.year, now.month, now.day, 23, 59, 59),
      );
    case _PeriodFilter.all:
      return (DateTime(2000), DateTime(2100));
  }
}

class TransactionsPage extends StatefulWidget {
  const TransactionsPage({super.key});

  @override
  State<TransactionsPage> createState() => _TransactionsPageState();
}

class _TransactionsPageState extends State<TransactionsPage> {
  late final TransactionsRepository _transactionsRepository;
  List<TransactionEntity> _allTransactions = const [];
  List<TransactionEntity> _filtered       = const [];
  List<TransactionEntity> _provisioned    = const [];
  Map<String, CategoryEntity> _categoriesById = const {};
  Map<String, CardEntity>     _cardsById      = const {};
  bool _isLoading = true;

  _PeriodFilter _period = _PeriodFilter.thisMonth;
  String? _filterCategoryId;

  double _totalExpenses = 0;
  double _totalIncome   = 0;

  @override
  void initState() {
    super.initState();
    _transactionsRepository = RepositoryLocator.instance.transactions;
    _loadData();
  }

  Future<void> _loadData() async {
    final locator = RepositoryLocator.instance;
    final transactions   = await _transactionsRepository.getAll();
    final categoriesList = await locator.categories.getAll();
    final cardsList      = await locator.cards.getAll();

    setState(() {
      _allTransactions = transactions;
      _categoriesById  = {for (final c in categoriesList) c.id: c};
      _cardsById       = {for (final c in cardsList) c.id: c};
      _isLoading       = false;
    });
    _applyFilters();
  }

  void _applyFilters() {
    final (start, end) = _periodRange(_period);

    final provisioned = _allTransactions
        .where((tx) => tx.isProvisioned)
        .toList()
      ..sort((a, b) {
        final da = a.provisionedDueDate ?? a.date;
        final db = b.provisionedDueDate ?? b.date;
        return da.compareTo(db);
      });

    final result = _allTransactions.where((tx) {
      if (tx.isProvisioned) return false;
      return !tx.date.isBefore(start) &&
          !tx.date.isAfter(end) &&
          (_filterCategoryId == null || tx.categoryId == _filterCategoryId);
    }).toList()
      ..sort((a, b) => b.date.compareTo(a.date));

    double expenses = 0, income = 0;
    for (final tx in result) {
      if (tx.type == TransactionType.expense) {
        expenses += tx.amount.amount;
      } else {
        income += tx.amount.amount;
      }
    }

    setState(() {
      _filtered       = result;
      _provisioned    = provisioned;
      _totalExpenses  = expenses;
      _totalIncome    = income;
    });
  }

  Future<void> _openForm({TransactionEntity? initial}) async {
    final ok = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (context) => NewTransactionPage(initialTransaction: initial),
      ),
    );
    if (ok == true) await _loadData();
  }

  Future<bool?> _confirmDelete(TransactionEntity tx) {
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Excluir transação'),
        content: Text('Deseja excluir "${tx.description ?? 'Sem descrição'}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text('Excluir',
                style: TextStyle(color: AppColors.danger)),
          ),
        ],
      ),
    );
  }

  // ── Filtros ──────────────────────────────────────────────────────────────

  Widget _buildSimpleFiltersRow() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md, vertical: AppSpacing.sm),
      child: Row(
        children: _PeriodFilter.values.map((f) {
          final selected = f == _period;
          return Padding(
            padding: const EdgeInsets.only(right: AppSpacing.xs + 2),
            child: FilterChip(
              label: Text(_periodLabel(f)),
              selected: selected,
              selectedColor: AppColors.primarySubtle,
              checkmarkColor: AppColors.primary,
              labelStyle: TextStyle(
                color: selected
                    ? AppColors.primary
                    : AppColors.textSecondary,
                fontSize: 13,
              ),
              onSelected: (_) {
                setState(() => _period = f);
                _applyFilters();
              },
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildUltraFiltersRow() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md, vertical: AppSpacing.sm),
      child: Row(
        children: [
          ..._PeriodFilter.values.map((f) {
            final selected = f == _period;
            return Padding(
              padding: const EdgeInsets.only(right: AppSpacing.xs + 2),
              child: FilterChip(
                label: Text(_periodLabel(f)),
                selected: selected,
                selectedColor: AppColors.primarySubtle,
                checkmarkColor: AppColors.primary,
                labelStyle: TextStyle(
                  color: selected
                      ? AppColors.primary
                      : AppColors.textSecondary,
                  fontSize: 13,
                ),
                onSelected: (_) {
                  setState(() => _period = f);
                  _applyFilters();
                },
              ),
            );
          }),
          Container(
            width: 1,
            height: 24,
            color: AppColors.divider,
            margin: const EdgeInsets.symmetric(horizontal: AppSpacing.xs + 2),
          ),
          Padding(
            padding: const EdgeInsets.only(right: AppSpacing.xs + 2),
            child: FilterChip(
              label: const Text('Todas'),
              selected: _filterCategoryId == null,
              selectedColor: AppColors.primarySubtle,
              checkmarkColor: AppColors.primary,
              labelStyle: TextStyle(
                color: _filterCategoryId == null
                    ? AppColors.primary
                    : AppColors.textSecondary,
                fontSize: 13,
              ),
              onSelected: (_) {
                setState(() => _filterCategoryId = null);
                _applyFilters();
              },
            ),
          ),
          ..._categoriesById.values.map((cat) {
            final selected = _filterCategoryId == cat.id;
            final color = cat.colorValue != null
                ? Color(cat.colorValue!)
                : AppColors.textSecondary;
            return Padding(
              padding: const EdgeInsets.only(right: AppSpacing.xs + 2),
              child: FilterChip(
                avatar: CircleAvatar(
                  backgroundColor: color.withOpacity(0.22),
                  child: Text(
                    cat.name[0].toUpperCase(),
                    style: TextStyle(fontSize: 10, color: color),
                  ),
                ),
                label: Text(cat.name),
                selected: selected,
                selectedColor: AppColors.primarySubtle,
                checkmarkColor: AppColors.primary,
                labelStyle: TextStyle(
                  color: selected
                      ? AppColors.primary
                      : AppColors.textSecondary,
                  fontSize: 13,
                ),
                onSelected: (_) {
                  setState(() =>
                      _filterCategoryId = selected ? null : cat.id);
                  _applyFilters();
                },
              ),
            );
          }),
        ],
      ),
    );
  }

  // ── Resumo ───────────────────────────────────────────────────────────────

  Widget _buildSimpleSummary() {
    return Padding(
      padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg, vertical: AppSpacing.sm + 2),
      child: _SummaryChip(
        label: 'Despesas no período',
        value: '- R\$ ${_totalExpenses.toStringAsFixed(2)}',
        color: AppColors.danger,
      ),
    );
  }

  Widget _buildUltraSummary() {
    final balance = _totalIncome - _totalExpenses;
    return Padding(
      padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg, vertical: AppSpacing.sm + 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _SummaryChip(
            label: 'Despesas',
            value: '- R\$ ${_totalExpenses.toStringAsFixed(2)}',
            color: AppColors.danger,
          ),
          _SummaryChip(
            label: 'Receitas',
            value: '+ R\$ ${_totalIncome.toStringAsFixed(2)}',
            color: AppColors.limitLow,
          ),
          _SummaryChip(
            label: 'Saldo',
            value: 'R\$ ${balance.toStringAsFixed(2)}',
            color: balance >= 0 ? AppColors.primary : AppColors.danger,
          ),
        ],
      ),
    );
  }

  // ── Gráficos ─────────────────────────────────────────────────────────────

  static const List<Color> _chartColors = [
    AppColors.primary,
    Color(0xFF7E57C2),
    Color(0xFF26A69A),
    AppColors.warning,
    Color(0xFFEC407A),
    Color(0xFF5C6BC0),
    AppColors.danger,
    AppColors.limitLow,
  ];

  Widget _buildPieCard({
    required String title,
    required List<MapEntry<String, double>> entries,
    required String Function(String key) labelOf,
  }) {
    if (entries.isEmpty) return const SizedBox.shrink();
    return Card(
      margin: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg, vertical: AppSpacing.sm),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: AppText.sectionLabel),
            const SizedBox(height: AppSpacing.md),
            SizedBox(
              height: 160,
              child: Row(
                children: [
                  Expanded(
                    child: PieChart(
                      PieChartData(
                        sectionsSpace: 2,
                        centerSpaceRadius: 38,
                        sections: [
                          for (int i = 0; i < entries.length; i++)
                            PieChartSectionData(
                              value: entries[i].value,
                              color: _chartColors[i % _chartColors.length],
                              title: '',
                              radius: 24,
                            ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      for (int i = 0; i < entries.length; i++) ...[
                        Row(
                          children: [
                            Container(
                              width: 10,
                              height: 10,
                              decoration: BoxDecoration(
                                color: _chartColors[i % _chartColors.length],
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: AppSpacing.xs + 2),
                            Text(labelOf(entries[i].key),
                                style: AppText.secondary),
                          ],
                        ),
                        Padding(
                          padding: const EdgeInsets.only(
                              left: AppSpacing.lg, bottom: AppSpacing.xs),
                          child: Text(
                            'R\$ ${entries[i].value.toStringAsFixed(2)}',
                            style: AppText.secondary,
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildExpensesByCategoryChart() {
    final Map<String, double> byCategory = {};
    for (final tx in _filtered) {
      if (tx.type == TransactionType.expense) {
        final catId = tx.categoryId ?? '';
        byCategory[catId] = (byCategory[catId] ?? 0) + tx.amount.amount;
      }
    }
    final entries = byCategory.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return _buildPieCard(
      title: 'Gastos por categoria',
      entries: entries,
      labelOf: (key) => _categoriesById[key]?.name ?? key,
    );
  }

  Widget _buildExpensesByCardChart() {
    final entries = _cardsById.values
        .map((c) {
          double total = 0;
          for (final tx in _filtered) {
            if (tx.type == TransactionType.expense && tx.cardId == c.id) {
              total += tx.amount.amount;
            }
          }
          return MapEntry(c.id, total);
        })
        .where((e) => e.value > 0)
        .toList();

    return _buildPieCard(
      title: 'Gastos por cartão',
      entries: entries,
      labelOf: (key) => _cardsById[key]?.name ?? key,
    );
  }

  // ── Seção A vencer ───────────────────────────────────────────────────────

  Widget _buildProvisionedSection() {
    if (_provisioned.isEmpty) return const SizedBox.shrink();

    final today = DateTime.now();
    final todayDay = DateTime(today.year, today.month, today.day);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg, AppSpacing.md, AppSpacing.lg, AppSpacing.xs),
          child: Row(
            children: [
              Icon(Icons.schedule_outlined,
                  size: 14, color: AppColors.warning),
              const SizedBox(width: AppSpacing.xs + 2),
              Text(
                'A VENCER',
                style: AppText.badge.copyWith(
                  color: AppColors.warning,
                  letterSpacing: 1,
                ),
              ),
            ],
          ),
        ),
        ..._provisioned.map((tx) {
          final dueDate = tx.provisionedDueDate ?? tx.date;
          final dueDay =
              DateTime(dueDate.year, dueDate.month, dueDate.day);
          final daysLeft = dueDay.difference(todayDay).inDays;
          final isOverdue  = daysLeft < 0;
          final isDueToday = daysLeft == 0;

          final dueDateText =
              '${dueDate.day.toString().padLeft(2, '0')}'
              '/${dueDate.month.toString().padLeft(2, '0')}'
              '/${dueDate.year}';

          final String daysLabel;
          if (isOverdue) {
            daysLabel =
                'Vencido há ${-daysLeft} dia${(-daysLeft) != 1 ? 's' : ''}';
          } else if (isDueToday) {
            daysLabel = 'Vence hoje';
          } else {
            daysLabel =
                'Vence em $daysLeft dia${daysLeft != 1 ? 's' : ''}';
          }

          final badgeColor = isOverdue
              ? AppColors.danger
              : (isDueToday ? AppColors.warning : AppColors.primary);

          final category = _categoriesById[tx.categoryId];
          final card =
              tx.cardId != null ? _cardsById[tx.cardId!] : null;
          final installmentText = tx.installmentCount != null
              ? ' (${tx.installmentCount}x)'
              : '';

          return Dismissible(
            key: ValueKey('prov_${tx.id}'),
            direction: DismissDirection.endToStart,
            confirmDismiss: (_) => _confirmDelete(tx),
            onDismissed: (_) async {
              await _transactionsRepository.remove(tx.id);
              await _loadData();
              if (!mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Transação excluída')),
              );
            },
            background: Container(
              color: AppColors.danger,
              alignment: Alignment.centerRight,
              padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.lg),
              child: const Icon(Icons.delete_outline,
                  color: Colors.white),
            ),
            child: ListTile(
              onTap: () => _openForm(initial: tx),
              leading: _CategoryDot(category: category),
              title: Text(
                  '${tx.description ?? 'Sem descrição'}$installmentText'),
              subtitle: Text(
                '${category?.name ?? 'Sem cat.'}'
                '${card != null ? ' · ${card.name}' : ''}'
                ' · $dueDateText',
              ),
              trailing: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '- R\$ ${tx.amount.amount.toStringAsFixed(2)}',
                    style: AppText.body.copyWith(
                      color: AppColors.danger,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.xs + 2,
                        vertical: AppSpacing.xs - 2),
                    decoration: BoxDecoration(
                      color: badgeColor.withOpacity(0.12),
                      borderRadius:
                          BorderRadius.circular(AppRadius.chip),
                    ),
                    child: Text(
                      daysLabel,
                      style: AppText.badge.copyWith(
                          color: badgeColor,
                          fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
            ),
          );
        }),
        const Divider(height: 1),
      ],
    );
  }

  // ── Lista ─────────────────────────────────────────────────────────────────

  Widget _buildTransactionList(bool isSimple) {
    if (_filtered.isEmpty) {
      return SliverFillRemaining(
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.receipt_long_outlined,
                  size: 48, color: AppColors.textSecondary),
              const SizedBox(height: AppSpacing.md),
              Text('Nenhuma transação neste período.',
                  style: AppText.secondary),
            ],
          ),
        ),
      );
    }

    return SliverList(
      delegate: SliverChildBuilderDelegate(
        (context, index) {
          final tx       = _filtered[index];
          final category = _categoriesById[tx.categoryId];
          final card =
              tx.cardId != null ? _cardsById[tx.cardId!] : null;

          final isExpense = tx.type == TransactionType.expense;
          final amountText =
              '${isExpense ? '-' : '+'} R\$ ${tx.amount.amount.toStringAsFixed(2)}';

          final dateText =
              '${tx.date.day.toString().padLeft(2, '0')}'
              '/${tx.date.month.toString().padLeft(2, '0')}'
              '/${tx.date.year}';

          final subtitleText = isSimple
              ? dateText
              : '${category?.name ?? 'Sem categoria'}'
                ' · ${card != null ? card.name : 'Sem cartão'}'
                ' · $dateText'
                '${tx.installmentCount != null ? ' · ${tx.installmentCount}x' : ''}';

          return Column(
            children: [
              Dismissible(
                key: ValueKey(tx.id),
                direction: DismissDirection.endToStart,
                confirmDismiss: (_) => _confirmDelete(tx),
                onDismissed: (_) async {
                  await _transactionsRepository.remove(tx.id);
                  await _loadData();
                  if (!mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                        content: Text('Transação excluída')),
                  );
                },
                background: Container(
                  color: AppColors.danger,
                  alignment: Alignment.centerRight,
                  padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.lg),
                  child: const Icon(Icons.delete_outline,
                      color: Colors.white),
                ),
                child: ListTile(
                  onTap: () => _openForm(initial: tx),
                  leading: _CategoryDot(category: category),
                  title: Text(tx.description ?? 'Sem descrição'),
                  subtitle: Text(subtitleText),
                  trailing: Text(
                    amountText,
                    style: AppText.body.copyWith(
                      color: isExpense
                          ? AppColors.danger
                          : AppColors.limitLow,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
              const Divider(height: 1),
            ],
          );
        },
        childCount: _filtered.length,
      ),
    );
  }

  // ── Build principal ───────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: AppModeController.instance,
      builder: (context, _) {
        final mode     = AppModeController.instance.mode;
        final isSimple = mode == AppMode.simple;
        final isUltra  = mode == AppMode.ultra;

        return Scaffold(
          appBar: AppBar(title: const Text('Transações')),
          floatingActionButton: FloatingActionButton.extended(
            onPressed: () => _openForm(),
            icon: const Icon(Icons.add),
            label: const Text('Nova transação'),
          ),
          body: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : CustomScrollView(
                  slivers: [
                    SliverToBoxAdapter(
                      child: isSimple
                          ? _buildSimpleFiltersRow()
                          : _buildUltraFiltersRow(),
                    ),
                    const SliverToBoxAdapter(child: Divider(height: 1)),
                    SliverToBoxAdapter(
                      child: isSimple
                          ? _buildSimpleSummary()
                          : _buildUltraSummary(),
                    ),
                    if (isUltra) ...[
                      SliverToBoxAdapter(
                          child: _buildExpensesByCategoryChart()),
                      SliverToBoxAdapter(
                          child: _buildExpensesByCardChart()),
                      SliverToBoxAdapter(
                          child: _buildProvisionedSection()),
                    ],
                    const SliverToBoxAdapter(child: Divider(height: 1)),
                    SliverPadding(
                      padding:
                          const EdgeInsets.only(bottom: 80),
                      sliver: _buildTransactionList(isSimple),
                    ),
                  ],
                ),
        );
      },
    );
  }
}

// ── Widgets auxiliares ──────────────────────────────────────────────────────

class _CategoryDot extends StatelessWidget {
  const _CategoryDot({this.category});
  final CategoryEntity? category;

  @override
  Widget build(BuildContext context) {
    final color = category?.colorValue != null
        ? Color(category!.colorValue!)
        : AppColors.textSecondary;
    final letter = category != null && category!.name.isNotEmpty
        ? category!.name[0].toUpperCase()
        : '?';
    return CircleAvatar(
      radius: 18,
      backgroundColor: color.withOpacity(0.18),
      child: Text(
        letter,
        style: TextStyle(
            color: color,
            fontWeight: FontWeight.bold,
            fontSize: 13),
      ),
    );
  }
}

class _SummaryChip extends StatelessWidget {
  const _SummaryChip({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: AppText.secondary),
        const SizedBox(height: 2),
        Text(
          value,
          style:
              AppText.body.copyWith(fontWeight: FontWeight.w700, color: color),
        ),
      ],
    );
  }
}
