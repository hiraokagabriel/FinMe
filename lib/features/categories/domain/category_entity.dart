import 'category_kind.dart';

class CategoryEntity {
  final String id;
  final String name;
  final CategoryKind kind;
  final int? colorValue;

  /// Código do MaterialIcons (codePoint). null = usa inicial do nome.
  final int? iconCodePoint;

  const CategoryEntity({
    required this.id,
    required this.name,
    required this.kind,
    this.colorValue,
    this.iconCodePoint,
  });
}
