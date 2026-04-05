import 'package:hive/hive.dart';

import 'category_model.dart';
import '../domain/category_entity.dart';
import 'categories_repository.dart';

class HiveCategoriesRepository implements CategoriesRepository {
  HiveCategoriesRepository(this._box);

  final Box<CategoryModel> _box;

  @override
  Future<List<CategoryEntity>> getAll() async {
    return _box.values.map((m) => m.toEntity()).toList(growable: false);
  }

  @override
  Future<void> add(CategoryEntity entity) async {
    final model = CategoryModel.fromEntity(entity);
    await _box.put(entity.id, model);
  }

  @override
  Future<void> update(CategoryEntity entity) async {
    final model = CategoryModel.fromEntity(entity);
    await _box.put(entity.id, model);
  }

  @override
  Future<void> remove(String id) async {
    await _box.delete(id);
  }
}
