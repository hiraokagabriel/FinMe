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
import 'new_transaction_page.dart';

// ---------------------------------------------------------------------------
// Filtro de periodo
// ---------------------------------------------------------------------------
enum _PeriodFilter { thisMonth, lastMonth, thisWeek, all }

String _periodLabel(_PeriodFilter f) {
  switch (f) {
    case _PeriodFilter.thisMonth:
      return 'Este mes';
    case _PeriodFilter.lastMonth:
      return 'Mes anterior';
    case _PeriodFilter.thisWeek:
      return 'Esta semana';
    case _PeriodFilter.all:
      return 'Tudo';
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
      final first = DateTime(now.year, now.month - 1, 1);
      final last = DateTime(now.year, now.month, 0, 23, 59, 59);
      return (first, last);
    case _PeriodFilter.thisWeek:
      final weekday = now.weekday; // 1=Mon
      final start = now.subtract(Duration(days: weekday - 1));
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
  List<TransactionEntity> _filtered = const [];
  Map<String, CategoryEntity> _categoriesById = const {};
  Map<String, CardEntity> _cardsById = const {};
  bool _isLoading = true;

  _PeriodFilter _period = _PeriodFilter.thisMonth;
  String? _filterCategoryId; // null = todas

  // totals do periodo filtrado
  double _totalExpenses = 0;
  double _totalIncome = 0;

  @override
  void initState() {
    super.initState();
    _transactionsRepository = RepositoryLocator.instance.transactions;
    _loadData();
  }

  Future<void> _loadData() async {
    final locator = RepositoryLocator.instance;
    final transactions = await _transactionsRepository.getAll();
    final categoriesList = await locator.categories.getAll();
    final cardsList = await locator.cards.getAll();

    final categoriesById = {for (final c in categoriesList) c.id: c};
    final cardsById = {for (final c in cardsList) c.id: c};

    setState(() {
      _allTransactions = transactions;
      _categoriesById = categoriesById;
      _cardsById = cardsById;
      _isLoading = false;
    });
    _applyFilters();
  }

  void _applyFilters() {
    final range = _periodRange(_period);
    final start = range.$1;
    final end = range.$2;

    var result = _allTransactions.where((tx) {
      final inPeriod = !tx.date.isBefore(start) && !tx.date.isAfter(end);
      final inCategory =
          _filterCategoryId == null || tx.categoryId == _filterCategoryId;
      return inPeriod && inCategory;
    }).toList();

    // ordem: mais recente primeiro
    result.sort((a, b) => b.date.compareTo(a.date));

    double expenses = 0;
    double income = 0;
    for (final tx in result) {
      if (tx.type == TransactionType.expense) {
        expenses += tx.amount.amount;
      } else {
        income += tx.amount.amount;
      }
    }

    setState(() {
      _filtered = result;
      _totalExpenses = expenses;
      _totalIncome = income;
    });
  }

  Future<void> _openForm({TransactionEntity? initial}) async {
    final ok = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (context) =>
            NewTransactionPage(initialTransaction: initial),
      ),
    );
    if (ok == true) await _loadData();
  }

  Future<bool?> _confirmDelete(TransactionEntity tx) async {
    return showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Excluir transacao'),
          content: Text(
            'Deseja excluir a transacao "${tx.description ?? 'Sem descricao'}"?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancelar'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Excluir'),
            ),
          ],
        );
      },
    );
  }

  Widget _buildFiltersRow() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        children: [
          // --- Periodo ---
          ..._PeriodFilter.values.map((f) {
            final selected = f == _period;
            return Padding(
              padding: const EdgeInsets.only(right: 6),
              child: FilterChip(
                label: Text(_periodLabel(f)),
                selected: selected,
                onSelected: (_) {
                  setState(() => _period = f);
                  _applyFilters();
                },
              ),
            );
          }),
          // --- Separador ---
          Container(
            width: 1,
            height: 24,
            color: Colors.grey[300],
            margin: const EdgeInsets.symmetric(horizontal: 6),
          ),
          // --- Categorias ---
          Padding(
            padding: const EdgeInsets.only(right: 6),
            child: FilterChip(
              label: const Text('Todas'),
              selected: _filterCategoryId == null,
              onSelected: (_) {
                setState(() => _filterCategoryId = null);
                _applyFilters();
              },
            ),
          ),
          ..._categoriesById.values.map((cat) {
            final selected = _filterCategoryId == cat.id;
            final color = cat.colorValue != null ? Color(cat.colorValue!) : Colors.blueGrey;
            return Padding(
              padding: const EdgeInsets.only(right: 6),
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
                onSelected: (_) {
                  setState(() => _filterCategoryId = selected ? null : cat.id);
                  _applyFilters();
                },
              ),
            );
          }),
        ],
      ),
    );
  }

  // Grafico de gastos por categoria (modo ultra)
  Widget _buildExpensesByCategoryChart() {
    final Map<String, double> byCategory = {};
    for (final tx in _filtered) {
      if (tx.type == TransactionType.expense) {
        byCategory[tx.categoryId] =
            (byCategory[tx.categoryId] ?? 0) + tx.amount.amount;
      }
    }
    if (byCategory.isEmpty) return const SizedBox.shrink();

    final entries = byCategory.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    final colors = [
      Colors.blue,
      Colors.deepPurple,
      Colors.teal,
      Colors.orange,
      Colors.pink,
      Colors.indigo,
      Colors.red,
      Colors.green,
    ];

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Gastos por categoria',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
            ),
            const SizedBox(height: 12),
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
                              color: colors[i % colors.length],
                              title: '',
                              radius: 24,
                            ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
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
                                color: colors[i % colors.length],
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              _categoriesById[entries[i].key]?.name ??
                                  entries[i].key,
                              style: const TextStyle(fontSize: 12),
                            ),
                          ],
                        ),
                        Padding(
                          padding:
                              const EdgeInsets.only(left: 16, bottom: 4),
                          child: Text(
                            'R\$ ${entries[i].value.toStringAsFixed(2)}',
                            style: TextStyle(
                                fontSize: 11, color: Colors.grey[600]),
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

  // Grafico de gastos por cartao (modo ultra)
  Widget _buildExpensesByCardChart() {
    final cardsWithExpenses = _cardsById.values
        .map((c) {
          double total = 0;
          for (final tx in _filtered) {
            if (tx.type == TransactionType.expense && tx.cardId == c.id) {
              total += tx.amount.amount;
            }
          }
          return (card: c, total: total);
        })
        .where((e) => e.total > 0)
        .toList();

    if (cardsWithExpenses.isEmpty) return const SizedBox.shrink();

    final colors = [
      Colors.blue,
      Colors.deepPurple,
      Colors.teal,
      Colors.orange,
      Colors.pink,
    ];

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Gastos por cartao',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
            ),
            const SizedBox(height: 12),
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
                          for (int i = 0;
                              i < cardsWithExpenses.length;
                              i++)
                            PieChartSectionData(
                              value: cardsWithExpenses[i].total,
                              color: colors[i % colors.length],
                              title: '',
                              radius: 24,
                            ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      for (int i = 0;
                          i < cardsWithExpenses.length;
                          i++) ...[
                        Row(
                          children: [
                            Container(
                              width: 10,
                              height: 10,
                              decoration: BoxDecoration(
                                color: colors[i % colors.length],
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              cardsWithExpenses[i].card.name,
                              style: const TextStyle(fontSize: 12),
                            ),
                          ],
                        ),
                        Padding(
                          padding:
                              const EdgeInsets.only(left: 16, bottom: 4),
                          child: Text(
                            'R\$ ${cardsWithExpenses[i].total.toStringAsFixed(2)}',
                            style: TextStyle(
                                fontSize: 11, color: Colors.grey[600]),
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

  @override
  Widget build(BuildContext context) {
    final modeController = AppModeController.instance;
    return AnimatedBuilder(
      animation: modeController,
      builder: (context, _) {
        final mode = modeController.mode;
        final isSimple = mode == AppMode.simple;
        final isUltra = mode == AppMode.ultra;

        return Scaffold(
          appBar: AppBar(
            title: const Text('Transacoes'),
          ),
          floatingActionButton: FloatingActionButton.extended(
            onPressed: () => _openForm(),
            icon: const Icon(Icons.add),
            label: const Text('Nova transacao'),
          ),
          body: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Filtros de periodo e categoria
                    _buildFiltersRow(),
                    const Divider(height: 1),
                    // Resumo do periodo
                    Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 10),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          _SummaryChip(
                            label: 'Despesas',
                            value:
                                '- R\$ ${_totalExpenses.toStringAsFixed(2)}',
                            color: Colors.red,
                          ),
                          _SummaryChip(
                            label: 'Receitas',
                            value:
                                '+ R\$ ${_totalIncome.toStringAsFixed(2)}',
                            color: Colors.green,
                          ),
                          _SummaryChip(
                            label: 'Saldo',
                            value:
                                'R\$ ${(_totalIncome - _totalExpenses).toStringAsFixed(2)}',
                            color: (_totalIncome - _totalExpenses) >= 0
                                ? Colors.blue
                                : Colors.red,
                          ),
                        ],
                      ),
                    ),
                    // Graficos (modo ultra)
                    if (isUltra) _buildExpensesByCategoryChart(),
                    if (isUltra) _buildExpensesByCardChart(),
                    const Divider(height: 1),
                    // Lista
                    Expanded(
                      child: _filtered.isEmpty
                          ? Center(
                              child: Text(
                                'Nenhuma transacao neste periodo.',
                                style: TextStyle(color: Colors.grey[500]),
                              ),
                            )
                          : ListView.separated(
                              padding:
                                  const EdgeInsets.only(bottom: 80),
                              itemCount: _filtered.length,
                              separatorBuilder: (_, __) =>
                                  const Divider(height: 1),
                              itemBuilder: (context, index) {
                                final tx = _filtered[index];
                                final category =
                                    _categoriesById[tx.categoryId];
                                final card = tx.cardId != null
                                    ? _cardsById[tx.cardId!]
                                    : null;

                                final isExpense =
                                    tx.type == TransactionType.expense;
                                final sign = isExpense ? '-' : '+';
                                final amountText =
                                    '$sign R\$ ${tx.amount.amount.toStringAsFixed(2)}';

                                final dateText =
                                    '${tx.date.day.toString().padLeft(2, '0')}/${tx.date.month.toString().padLeft(2, '0')}/${tx.date.year}';

                                String subtitleText;
                                if (isSimple) {
                                  subtitleText = dateText;
                                } else {
                                  final catName =
                                      category?.name ?? 'Sem categoria';
                                  final cardPart = card != null
                                      ? card.name
                                      : 'Sem cartao';
                                  subtitleText =
                                      '$catName \u2022 $cardPart \u2022 $dateText';
                                }

                                return Dismissible(
                                  key: ValueKey(tx.id),
                                  direction:
                                      DismissDirection.endToStart,
                                  confirmDismiss: (_) =>
                                      _confirmDelete(tx),
                                  onDismissed: (_) async {
                                    await _transactionsRepository
                                        .remove(tx.id);
                                    await _loadData();
                                    if (!mounted) return;
                                    ScaffoldMessenger.of(context)
                                        .showSnackBar(
                                      const SnackBar(
                                        content: Text(
                                            'Transacao excluida com sucesso'),
                                      ),
                                    );
                                  },
                                  background: Container(
                                    color: Colors.red,
                                    alignment: Alignment.centerRight,
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 16),
                                    child: const Icon(
                                      Icons.delete,
                                      color: Colors.white,
                                    ),
                                  ),
                                  child: ListTile(
                                    onTap: () => _openForm(initial: tx),
                                    leading: _CategoryDot(
                                      category: category,
                                    ),
                                    title: Text(
                                        tx.description ?? 'Sem descricao'),
                                    subtitle: Text(subtitleText),
                                    trailing: Text(
                                      amountText,
                                      style: TextStyle(
                                        color: isExpense
                                            ? Colors.red
                                            : Colors.green,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                );
                              },
                            ),
                    ),
                  ],
                ),
        );
      },
    );
  }
}

class _CategoryDot extends StatelessWidget {
  const _CategoryDot({this.category});
  final CategoryEntity? category;

  @override
  Widget build(BuildContext context) {
    final color = category?.colorValue != null
        ? Color(category!.colorValue!)
        : Colors.blueGrey;
    final letter =
        category != null && category!.name.isNotEmpty
            ? category!.name[0].toUpperCase()
            : '?';
    return CircleAvatar(
      radius: 18,
      backgroundColor: color.withOpacity(0.18),
      child: Text(
        letter,
        style: TextStyle(
            color: color, fontWeight: FontWeight.bold, fontSize: 13),
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
        Text(
          label,
          style: TextStyle(fontSize: 11, color: Colors.grey[600]),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      ],
    );
  }
}
