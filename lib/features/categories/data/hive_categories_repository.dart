import 'package:hive/hive.dart';

import 'category_model.dart';
import '../domain/category_entity.dart';
import 'categories_repository.dart';

class HiveCategoriesRepository implements CategoriesRepository {
  HiveCategoriesRepository(this._box) {
    _migrateLegacyKeys();
  }

  final Box<CategoryModel> _box;

  // Records seeded with addAll() were stored under auto-numeric keys (0,1,2...).
  // This migration copies each such record to its entity.id key and removes the
  // old numeric key, so that update() and remove() (which use entity.id) work
  // correctly on both new and existing installations.
  void _migrateLegacyKeys() {
    final toMigrate = _box.keys
        .where((k) => k is! String)
        .toList(growable: false);

    for (final key in toMigrate) {
      final model = _box.get(key);
      if (model == null) continue;
      // Only migrate if there is no record already stored under the string id
      if (!_box.containsKey(model.id)) {
        _box.put(model.id, model);
      }
      _box.delete(key);
    }
  }

  @override
  Future<List<CategoryEntity>> getAll() async {
    return _box.values.map((m) => m.toEntity()).toList(growable: false);
  }

  @override
  Future<void> add(CategoryEntity entity) async {
    await _box.put(entity.id, CategoryModel.fromEntity(entity));
  }

  @override
  Future<void> update(CategoryEntity entity) async {
    await _box.put(entity.id, CategoryModel.fromEntity(entity));
  }

  @override
  Future<void> remove(String id) async {
    await _box.delete(id);
  }
}
