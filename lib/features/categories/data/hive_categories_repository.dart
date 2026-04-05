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
}
