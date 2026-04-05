import '../../../core/models/date_range.dart';
import '../domain/transaction_entity.dart';

abstract class TransactionsRepository {
  Future<List<TransactionEntity>> getAll();
  Future<List<TransactionEntity>> getByRange(DateRange range);

  Future<void> add(TransactionEntity transaction);
  Future<void> update(TransactionEntity transaction);
  Future<void> remove(String id);
}

class InMemoryTransactionsRepository implements TransactionsRepository {
  InMemoryTransactionsRepository();

  final List<TransactionEntity> _transactions = [];

  @override
  Future<List<TransactionEntity>> getAll() async {
    return List.unmodifiable(_transactions);
  }

  @override
  Future<List<TransactionEntity>> getByRange(DateRange range) async {
    return _transactions
        .where((tx) => range.contains(tx.date))
        .toList(growable: false);
  }

  @override
  Future<void> add(TransactionEntity transaction) async {
    _transactions.add(transaction);
  }

  @override
  Future<void> update(TransactionEntity transaction) async {
    final index =
        _transactions.indexWhere((element) => element.id == transaction.id);
    if (index == -1) return;
    _transactions[index] = transaction;
  }

  @override
  Future<void> remove(String id) async {
    _transactions.removeWhere((element) => element.id == id);
  }
}
