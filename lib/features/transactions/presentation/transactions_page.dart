import 'package:flutter/material.dart';

import '../data/transactions_repository.dart';
import '../domain/transaction_entity.dart';
import '../domain/transaction_type.dart';
import '../../categories/data/categories_repository.dart';
import '../../categories/domain/category_entity.dart';

class TransactionsPage extends StatefulWidget {
  const TransactionsPage({super.key});

  @override
  State<TransactionsPage> createState() => _TransactionsPageState();
}

class _TransactionsPageState extends State<TransactionsPage> {
  late final TransactionsRepository _transactionsRepository;
  late final CategoriesRepository _categoriesRepository;

  List<TransactionEntity> _transactions = const [];
  Map<String, CategoryEntity> _categoriesById = const {};
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _transactionsRepository = InMemoryTransactionsRepository();
    _categoriesRepository = InMemoryCategoriesRepository();
    _loadData();
  }

  Future<void> _loadData() async {
    final transactions = await _transactionsRepository.getAll();
    final categoriesList = await _categoriesRepository.getAll();
    final categoriesById = {
      for (final c in categoriesList) c.id: c,
    };

    setState(() {
      _transactions = transactions;
      _categoriesById = categoriesById;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Transações'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView.separated(
              itemCount: _transactions.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final tx = _transactions[index];
                final category = _categoriesById[tx.categoryId];

                final isExpense = tx.type == TransactionType.expense;
                final sign = isExpense ? '-' : '+';
                final amountText = '$sign R\$ ${tx.amount.amount.toStringAsFixed(2)}';

                return ListTile(
                  title: Text(tx.description ?? 'Sem descrição'),
                  subtitle: Text(
                    [
                      category?.name ?? 'Sem categoria',
                      '${tx.date.day.toString().padLeft(2, '0')}/${tx.date.month.toString().padLeft(2, '0')}/${tx.date.year}',
                    ].join(' • '),
                  ),
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
    );
  }
}
