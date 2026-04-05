import 'package:hive/hive.dart';
import '../domain/goal_entity.dart';

/// Repositório em memória (Hive-box) para metas.
/// Usa HiveBox<Map> com chave = goal.id.
class GoalsRepository {
  GoalsRepository(this._box);

  final Box _box;
  static const _boxName = 'goals';
  static String get boxName => _boxName;

  List<GoalEntity> getAll() {
    return _box.values
        .whereType<Map>()
        .map(_fromMap)
        .toList();
  }

  Future<void> save(GoalEntity goal) async {
    await _box.put(goal.id, _toMap(goal));
  }

  Future<void> remove(String id) async {
    await _box.delete(id);
  }

  static Map<String, dynamic> _toMap(GoalEntity g) => {
        'id': g.id,
        'categoryId': g.categoryId,
        'limitAmount': g.limitAmount,
        'month': g.month?.millisecondsSinceEpoch,
      };

  static GoalEntity _fromMap(Map m) => GoalEntity(
        id: m['id'] as String,
        categoryId: m['categoryId'] as String,
        limitAmount: (m['limitAmount'] as num).toDouble(),
        month: m['month'] != null
            ? DateTime.fromMillisecondsSinceEpoch(m['month'] as int)
            : null,
      );
}
