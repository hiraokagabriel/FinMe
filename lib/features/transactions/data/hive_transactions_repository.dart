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
}
