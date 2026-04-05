import '../domain/category_entity.dart';
import '../domain/category_kind.dart';

abstract class CategoriesRepository {
  Future<List<CategoryEntity>> getAll();
}

class InMemoryCategoriesRepository implements CategoriesRepository {
  InMemoryCategoriesRepository();

  final List<CategoryEntity> _categories = const [
    CategoryEntity(
      id: 'cat_food',
      name: 'Alimentação',
      kind: CategoryKind.expense,
    ),
    CategoryEntity(
      id: 'cat_transport',
      name: 'Transporte',
      kind: CategoryKind.expense,
    ),
    CategoryEntity(
      id: 'cat_subscriptions',
      name: 'Assinaturas',
      kind: CategoryKind.expense,
    ),
    CategoryEntity(
      id: 'cat_salary',
      name: 'Salário',
      kind: CategoryKind.income,
    ),
  ];

  @override
  Future<List<CategoryEntity>> getAll() async {
    return _categories;
  }
}
