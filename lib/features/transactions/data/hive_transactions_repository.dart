import 'package:hive/hive.dart';

import '../../../core/models/date_range.dart';
import 'transaction_model.dart';
import '../domain/transaction_entity.dart';
import 'transactions_repository.dart';

class HiveTransactionsRepository implements TransactionsRepository {
  HiveTransactionsRepository(this._box);

  final Box<TransactionModel> _box;

  @override
  Future<List<TransactionEntity>> getAll() async {
    return _box.values.map((m) => m.toEntity()).toList(growable: false);
  }

  @override
  Future<List<TransactionEntity>> getByRange(DateRange range) async {
    return _box.values
        .where((m) => range.contains(m.date))
        .map((m) => m.toEntity())
        .toList(growable: false);
  }

  @override
  Future<void> add(TransactionEntity transaction) async {
    final model = TransactionModel.fromEntity(transaction);
    await _box.add(model);
  }

  @override
  Future<void> update(TransactionEntity transaction) async {
    final model = TransactionModel.fromEntity(transaction);
    final key = _findKeyById(transaction.id);
    if (key == null) return;
    await _box.put(key, model);
  }

  @override
  Future<void> remove(String id) async {
    final key = _findKeyById(id);
    if (key == null) return;
    await _box.delete(key);
  }

  dynamic _findKeyById(String id) {
    for (final key in _box.keys) {
      final value = _box.get(key);
      if (value != null && value.id == id) {
        return key;
      }
    }
    return null;
  }
}
