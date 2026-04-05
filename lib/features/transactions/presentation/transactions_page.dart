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

class TransactionsPage extends StatefulWidget {
  const TransactionsPage({super.key});

  @override
  State<TransactionsPage> createState() => _TransactionsPageState();
}

class _TransactionsPageState extends State<TransactionsPage> {
  late final TransactionsRepository _transactionsRepository;
  List<TransactionEntity> _transactions = const [];
  Map<String, CategoryEntity> _categoriesById = const {};
  Map<String, CardEntity> _cardsById = const {};
  bool _isLoading = true;
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

    double expenses = 0;
    double income = 0;
    for (final tx in transactions) {
      if (tx.type == TransactionType.expense) {
        expenses += tx.amount.amount;
      } else {
        income += tx.amount.amount;
      }
    }

    setState(() {
      _transactions = transactions;
      _categoriesById = categoriesById;
      _cardsById = cardsById;
      _totalExpenses = expenses;
      _totalIncome = income;
      _isLoading = false;
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

  Widget _buildExpensesByCardChart() {
    final cardsWithExpenses = _cardsById.values
        .map((c) {
          double total = 0;
          for (final tx in _transactions) {
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
                          padding: const EdgeInsets.only(left: 16, bottom: 4),
                          child: Text(
                            'R\$ ${cardsWithExpenses[i].total.toStringAsFixed(2)}',
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.grey[600],
                            ),
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
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 12),
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
                    if (isUltra) _buildExpensesByCardChart(),
                    const Divider(height: 1),
                    Expanded(
                      child: ListView.separated(
                        padding: const EdgeInsets.only(bottom: 80),
                        itemCount: _transactions.length,
                        separatorBuilder: (_, __) =>
                            const Divider(height: 1),
                        itemBuilder: (context, index) {
                          final tx = _transactions[index];
                          final category = _categoriesById[tx.categoryId];
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
                            final catPart =
                                category?.name ?? 'Sem categoria';
                            final cardPart =
                                card != null ? card.name : 'Sem cartao';
                            subtitleText =
                                '$catPart \u2022 $cardPart \u2022 $dateText';
                          }

                          return Dismissible(
                            key: ValueKey(tx.id),
                            direction: DismissDirection.endToStart,
                            confirmDismiss: (_) => _confirmDelete(tx),
                            onDismissed: (_) async {
                              await _transactionsRepository.remove(tx.id);
                              await _loadData();
                              if (!mounted) return;
                              ScaffoldMessenger.of(context).showSnackBar(
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
          style: TextStyle(
            fontSize: 11,
            color: Colors.grey[600],
          ),
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
