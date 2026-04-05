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
      final weekday = now.weekday;
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
  // Provisionados pendentes (a vencer)
  List<TransactionEntity> _provisioned = const [];
  Map<String, CategoryEntity> _categoriesById = const {};
  Map<String, CardEntity> _cardsById = const {};
  bool _isLoading = true;

  _PeriodFilter _period = _PeriodFilter.thisMonth;
  String? _filterCategoryId;

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

    // Separa provisionados (aparecem na secao A vencer, nao na lista principal)
    final provisioned = _allTransactions
        .where((tx) => tx.isProvisioned)
        .toList()
      ..sort((a, b) {
        final da = a.provisionedDueDate ?? a.date;
        final db = b.provisionedDueDate ?? b.date;
        return da.compareTo(db);
      });

    var result = _allTransactions.where((tx) {
      if (tx.isProvisioned) return false; // provisionados ficam na secao propria
      final inPeriod = !tx.date.isBefore(start) && !tx.date.isAfter(end);
      final inCategory =
          _filterCategoryId == null || tx.categoryId == _filterCategoryId;
      return inPeriod && inCategory;
    }).toList();

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
      _provisioned = provisioned;
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
            'Deseja excluir "${tx.description ?? 'Sem descricao'}"?',
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

  // ---------------------------------------------------------------------------
  // Filtros
  // ---------------------------------------------------------------------------

  /// Filtros simplificados para o Modo Simples: apenas periodo, sem categoria.
  Widget _buildSimpleFiltersRow() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        children: _PeriodFilter.values.map((f) {
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
        }).toList(),
      ),
    );
  }

  /// Filtros completos para o Modo Ultra: periodo + categorias.
  Widget _buildUltraFiltersRow() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        children: [
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
          Container(
            width: 1,
            height: 24,
            color: Colors.grey[300],
            margin: const EdgeInsets.symmetric(horizontal: 6),
          ),
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
            final color = cat.colorValue != null
                ? Color(cat.colorValue!)
                : Colors.blueGrey;
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

  // ---------------------------------------------------------------------------
  // Resumo
  // ---------------------------------------------------------------------------

  /// Resumo enxuto para o Modo Simples: so despesas.
  Widget _buildSimpleSummary() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          _SummaryChip(
            label: 'Despesas no periodo',
            value: '- R\$ ${_totalExpenses.toStringAsFixed(2)}',
            color: Colors.red,
          ),
        ],
      ),
    );
  }

  /// Resumo completo para o Modo Ultra: despesas, receitas e saldo.
  Widget _buildUltraSummary() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _SummaryChip(
            label: 'Despesas',
            value: '- R\$ ${_totalExpenses.toStringAsFixed(2)}',
            color: Colors.red,
          ),
          _SummaryChip(
            label: 'Receitas',
            value: '+ R\$ ${_totalIncome.toStringAsFixed(2)}',
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
    );
  }

  // ---------------------------------------------------------------------------
  // Graficos (Ultra only)
  // ---------------------------------------------------------------------------

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
              style:
                  TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
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
              style:
                  TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
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

  // ---------------------------------------------------------------------------
  // Secao "A vencer" - provisionados (Ultra only)
  // ---------------------------------------------------------------------------

  Widget _buildProvisionedSection() {
    if (_provisioned.isEmpty) return const SizedBox.shrink();

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.fromLTRB(16, 12, 16, 6),
          child: Row(
            children: [
              Icon(Icons.schedule_outlined, size: 15, color: Colors.orange),
              SizedBox(width: 6),
              Text(
                'A VENCER',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: Colors.orange,
                  letterSpacing: 1,
                ),
              ),
            ],
          ),
        ),
        ..._provisioned.map((tx) {
          final dueDate = tx.provisionedDueDate ?? tx.date;
          final dueDay = DateTime(dueDate.year, dueDate.month, dueDate.day);
          final daysLeft = dueDay.difference(today).inDays;
          final isOverdue = daysLeft < 0;
          final isDueToday = daysLeft == 0;

          final dueDateText = '${dueDate.day.toString().padLeft(2, '0')}'
              '/${dueDate.month.toString().padLeft(2, '0')}'
              '/${dueDate.year}';

          final String daysLabel;
          if (isOverdue) {
            daysLabel = 'Vencido ha ${-daysLeft} dia${(-daysLeft) != 1 ? 's' : ''}';
          } else if (isDueToday) {
            daysLabel = 'Vence hoje';
          } else {
            daysLabel = 'Vence em $daysLeft dia${daysLeft != 1 ? 's' : ''}';
          }

          final badgeColor =
              isOverdue ? Colors.red : (isDueToday ? Colors.orange : Colors.blue);

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
                const SnackBar(content: Text('Transacao excluida')),
              );
            },
            background: Container(
              color: Colors.red,
              alignment: Alignment.centerRight,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: const Icon(Icons.delete, color: Colors.white),
            ),
            child: ListTile(
              onTap: () => _openForm(initial: tx),
              leading: _CategoryDot(category: category),
              title: Text(
                '${tx.description ?? 'Sem descricao'}$installmentText',
              ),
              subtitle: Text(
                '${category?.name ?? 'Sem cat.'}'  
                '${card != null ? ' \u2022 ${card.name}' : ''}'
                ' \u2022 $dueDateText',
              ),
              trailing: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '- R\$ ${tx.amount.amount.toStringAsFixed(2)}',
                    style: const TextStyle(
                      color: Colors.red,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: badgeColor.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      daysLabel,
                      style: TextStyle(
                          fontSize: 10,
                          color: badgeColor,
                          fontWeight: FontWeight.bold),
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

  // ---------------------------------------------------------------------------
  // Lista de transacoes
  // ---------------------------------------------------------------------------

  Widget _buildTransactionList(bool isSimple) {
    if (_filtered.isEmpty) {
      return SliverFillRemaining(
        child: Center(
          child: Text(
            'Nenhuma transacao neste periodo.',
            style: TextStyle(color: Colors.grey[500]),
          ),
        ),
      );
    }

    return SliverList(
      delegate: SliverChildBuilderDelegate(
        (context, index) {
          final tx = _filtered[index];
          final category = _categoriesById[tx.categoryId];
          final card =
              tx.cardId != null ? _cardsById[tx.cardId!] : null;

          final isExpense = tx.type == TransactionType.expense;
          final sign = isExpense ? '-' : '+';
          final amountText =
              '$sign R\$ ${tx.amount.amount.toStringAsFixed(2)}';

          final dateText =
              '${tx.date.day.toString().padLeft(2, '0')}/${tx.date.month.toString().padLeft(2, '0')}/${tx.date.year}';

          final String subtitleText;
          if (isSimple) {
            subtitleText = dateText;
          } else {
            final catName = category?.name ?? 'Sem categoria';
            final cardPart = card != null ? card.name : 'Sem cartao';
            final installText = tx.installmentCount != null
                ? ' \u2022 ${tx.installmentCount}x'
                : '';
            subtitleText = '$catName \u2022 $cardPart \u2022 $dateText$installText';
          }

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
                        content: Text('Transacao excluida com sucesso')),
                  );
                },
                background: Container(
                  color: Colors.red,
                  alignment: Alignment.centerRight,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: const Icon(Icons.delete, color: Colors.white),
                ),
                child: ListTile(
                  onTap: () => _openForm(initial: tx),
                  leading: _CategoryDot(category: category),
                  title: Text(tx.description ?? 'Sem descricao'),
                  subtitle: Text(subtitleText),
                  trailing: Text(
                    amountText,
                    style: TextStyle(
                      color: isExpense ? Colors.red : Colors.green,
                      fontWeight: FontWeight.bold,
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

  // ---------------------------------------------------------------------------
  // Build principal
  // ---------------------------------------------------------------------------

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
              : CustomScrollView(
                  slivers: [
                    // --- Filtros ---
                    SliverToBoxAdapter(
                      child: isSimple
                          ? _buildSimpleFiltersRow()
                          : _buildUltraFiltersRow(),
                    ),
                    SliverToBoxAdapter(
                      child: const Divider(height: 1),
                    ),

                    // --- Resumo ---
                    SliverToBoxAdapter(
                      child: isSimple
                          ? _buildSimpleSummary()
                          : _buildUltraSummary(),
                    ),

                    // --- Graficos (Ultra only) ---
                    if (isUltra) ...[
                      SliverToBoxAdapter(
                          child: _buildExpensesByCategoryChart()),
                      SliverToBoxAdapter(
                          child: _buildExpensesByCardChart()),
                    ],

                    // --- Secao A vencer (Ultra only) ---
                    if (isUltra)
                      SliverToBoxAdapter(
                          child: _buildProvisionedSection()),

                    SliverToBoxAdapter(
                      child: const Divider(height: 1),
                    ),

                    // --- Lista ---
                    SliverPadding(
                      padding: const EdgeInsets.only(bottom: 80),
                      sliver: _buildTransactionList(isSimple),
                    ),
                  ],
                ),
        );
      },
    );
  }
}

// ---------------------------------------------------------------------------
// Widgets auxiliares
// ---------------------------------------------------------------------------

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
