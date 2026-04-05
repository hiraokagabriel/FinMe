import 'package:flutter/material.dart';

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
    final locator = RepositoryLocator.instance;
    _transactionsRepository = locator.transactions;
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

  Future<void> _openNewTransactionForm({TransactionEntity? initial}) async {
    final createdOrUpdated = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (context) => NewTransactionPage(
          initialTransaction: initial,
        ),
      ),
    );
    if (createdOrUpdated == true) {
      await _loadData();
    }
  }

  Future<bool?> _confirmDelete(TransactionEntity tx) async {
    return showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Excluir transacao'),
          content: Text(
            'Tem certeza que deseja excluir esta transacao?\n\n${tx.description ?? 'Sem descricao'}',
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

  @override
  Widget build(BuildContext context) {
    final modeController = AppModeController.instance;
    return AnimatedBuilder(
      animation: modeController,
      builder: (context, _) {
        final mode = modeController.mode;
        final isSimple = mode == AppMode.simple;

        return Scaffold(
          appBar: AppBar(
            title: const Text('Transacoes'),
          ),
          floatingActionButton: FloatingActionButton.extended(
            onPressed: () => _openNewTransactionForm(),
            icon: const Icon(Icons.add),
            label: const Text('Nova transacao'),
          ),
          body: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Despesas',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.red,
                                ),
                              ),
                              Text(
                                '- R\$ ${_totalExpenses.toStringAsFixed(2)}',
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.red,
                                ),
                              ),
                            ],
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              const Text(
                                'Receitas',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.green,
                                ),
                              ),
                              Text(
                                '+ R\$ ${_totalIncome.toStringAsFixed(2)}',
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.green,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const Divider(height: 1),
                    Expanded(
                      child: ListView.separated(
                        itemCount: _transactions.length,
                        separatorBuilder: (_, __) => const Divider(height: 1),
                        itemBuilder: (context, index) {
                          final tx = _transactions[index];
                          final category = _categoriesById[tx.categoryId];
                          final card =
                              tx.cardId != null ? _cardsById[tx.cardId!] : null;

                          final isExpense = tx.type == TransactionType.expense;
                          final sign = isExpense ? '-' : '+';
                          final amountText =
                              '$sign R\$ ${tx.amount.amount.toStringAsFixed(2)}';

                          final dateText =
                              '${tx.date.day.toString().padLeft(2, '0')}/${tx.date.month.toString().padLeft(2, '0')}/${tx.date.year}';

                          String subtitleText;
                          if (isSimple) {
                            subtitleText = dateText;
                          } else {
                            final categoryPart =
                                category?.name ?? 'Sem categoria';
                            final cardPart =
                                card != null ? card.name : 'Sem cartao';
                            subtitleText =
                                '$categoryPart • $cardPart • $dateText';
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
                                  content:
                                      Text('Transacao excluida com sucesso'),
                                ),
                              );
                            },
                            background: Container(
                              color: Colors.red,
                              alignment: Alignment.centerRight,
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 16),
                              child: const Icon(
                                Icons.delete,
                                color: Colors.white,
                              ),
                            ),
                            child: ListTile(
                              onTap: () =>
                                  _openNewTransactionForm(initial: tx),
                              title:
                                  Text(tx.description ?? 'Sem descricao'),
                              subtitle: Text(subtitleText),
                              trailing: Text(
                                amountText,
                                style: TextStyle(
                                  color:
                                      isExpense ? Colors.red : Colors.green,
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
