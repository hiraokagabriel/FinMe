import 'package:hive/hive.dart';
import '../domain/goal_entity.dart';
import '../domain/goal_type.dart';

/// Repositório Hive para metas (Economia e Teto de Gastos).
class GoalsRepository {
  GoalsRepository(this._box);

  final Box _box;
  static const _boxName = 'goals';
  static String get boxName => _boxName;

  List<GoalEntity> getAll() {
    return _box.values.whereType<Map>().map(_fromMap).toList();
  }

  List<GoalEntity> getByType(GoalType type) {
    return getAll().where((g) => g.type == type).toList();
  }

  Future<void> save(GoalEntity goal) async {
    await _box.put(goal.id, _toMap(goal));
  }

  Future<void> remove(String id) async {
    await _box.delete(id);
  }

  static Map<String, dynamic> _toMap(GoalEntity g) => {
        'id': g.id,
        'type': g.type.index,
        'title': g.title,
        'targetAmount': g.targetAmount,
        'currentAmount': g.currentAmount,
        'categoryId': g.categoryId,
        'limitAmount': g.limitAmount,
        'month': g.month?.millisecondsSinceEpoch,
      };

  static GoalEntity _fromMap(Map m) {
    final typeIndex = (m['type'] as int?) ?? 1; // default: spendingCeiling (retrocompat)
    final type = GoalType.values[typeIndex.clamp(0, GoalType.values.length - 1)];
    return GoalEntity(
      id: m['id'] as String,
      type: type,
      title: (m['title'] as String?) ?? '',
      targetAmount: (m['targetAmount'] as num?)?.toDouble(),
      currentAmount: (m['currentAmount'] as num?)?.toDouble(),
      categoryId: m['categoryId'] as String?,
      limitAmount: (m['limitAmount'] as num?)?.toDouble(),
      month: m['month'] != null
          ? DateTime.fromMillisecondsSinceEpoch(m['month'] as int)
          : null,
    );
  }
}
