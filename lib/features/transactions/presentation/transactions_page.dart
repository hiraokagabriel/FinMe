import 'package:flutter/material.dart';

import '../data/transactions_repository.dart';
import '../domain/transaction_entity.dart';
import '../domain/transaction_type.dart';
import '../../categories/domain/category_entity.dart';
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
    final categoriesById = {for (final c in categoriesList) c.id: c};

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
      _totalExpenses = expenses;
      _totalIncome = income;
      _isLoading = false;
    });
  }

  Future<void> _openNewTransactionForm() async {
    final created = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (context) => const NewTransactionPage()),
    );
    if (created == true) {
      await _loadData();
    }
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
            onPressed: _openNewTransactionForm,
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

                          final isExpense = tx.type == TransactionType.expense;
                          final sign = isExpense ? '-' : '+';
                          final amountText =
                              '$sign R\$ ${tx.amount.amount.toStringAsFixed(2)}';

                          final dateText =
                              '${tx.date.day.toString().padLeft(2, '0')}/${tx.date.month.toString().padLeft(2, '0')}/${tx.date.year}';

                          final subtitleText = isSimple
                              ? dateText
                              : [
                                  category?.name ?? 'Sem categoria',
                                  dateText,
                                ].join(' • ');

                          return ListTile(
                            title: Text(tx.description ?? 'Sem descricao'),
                            subtitle: Text(subtitleText),
                            trailing: Text(
                              amountText,
                              style: TextStyle(
                                color: isExpense ? Colors.red : Colors.green,
                                fontWeight: FontWeight.bold,
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
