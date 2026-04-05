import '../domain/category_entity.dart';

abstract class CategoriesRepository {
  Future<List<CategoryEntity>> getAll();
  Future<void> add(CategoryEntity entity);
  Future<void> update(CategoryEntity entity);
  Future<void> remove(String id);
}
