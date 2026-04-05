import 'category_kind.dart';

class CategoryEntity {
  final String id;
  final String name;
  final CategoryKind kind;
  final int? colorValue; // opcional, para uso futuro na UI

  const CategoryEntity({
    required this.id,
    required this.name,
    required this.kind,
    this.colorValue,
  });
}
