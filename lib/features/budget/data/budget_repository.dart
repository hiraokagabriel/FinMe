import 'package:hive/hive.dart';
import '../domain/budget_entity.dart';
import '../domain/budget_period.dart';

/// Persiste orçamentos como Map dinâmico — sem adapter Hive gerado.
class BudgetRepository {
  BudgetRepository(this._box);

  final Box _box;
  static const boxName = 'budgets';

  List<BudgetEntity> getAll() {
    return _box.values.whereType<Map>().map(_fromMap).toList();
  }

  List<BudgetEntity> getByMonth(DateTime month) {
    return getAll()
        .where((b) => b.appliesToMonth(month))
        .toList();
  }

  Future<void> save(BudgetEntity budget) async {
    await _box.put(budget.id, _toMap(budget));
  }

  Future<void> remove(String id) async {
    await _box.delete(id);
  }

  static Map<String, dynamic> _toMap(BudgetEntity b) => {
        'id': b.id,
        'categoryId': b.categoryId,
        'limitAmount': b.limitAmount,
        'month': b.month.millisecondsSinceEpoch,
        'period': b.period.index,
      };

  static BudgetEntity _fromMap(Map m) {
    return BudgetEntity(
      id: m['id'] as String,
      categoryId: m['categoryId'] as String,
      limitAmount: (m['limitAmount'] as num).toDouble(),
      month: DateTime.fromMillisecondsSinceEpoch(m['month'] as int),
      period: BudgetPeriod
          .values[(m['period'] as int? ?? 0)
              .clamp(0, BudgetPeriod.values.length - 1)],
    );
  }
}
