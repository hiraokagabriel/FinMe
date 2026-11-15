import '../../../core/utils/enum_utils.dart';

enum CategoryKind { expense, income }

/// Categoria de despesa ou receita. `monthlyBudgetCents` null = sem orçamento.
class TransactionCategory {
  const TransactionCategory({
    required this.id,
    required this.name,
    required this.kind,
    required this.iconCodePoint,
    required this.colorValue,
    this.monthlyBudgetCents,
  });

  factory TransactionCategory.fromMap(Map<String, dynamic> map) =>
      TransactionCategory(
        id: map['id'] as String,
        name: map['name'] as String,
        kind: enumByName(CategoryKind.values, map['kind']),
        iconCodePoint: (map['iconCodePoint'] as num).toInt(),
        colorValue: (map['colorValue'] as num).toInt(),
        monthlyBudgetCents: (map['monthlyBudgetCents'] as num?)?.toInt(),
      );

  final String id;
  final String name;
  final CategoryKind kind;
  final int iconCodePoint;
  final int colorValue;
  final int? monthlyBudgetCents;

  TransactionCategory copyWith({
    String? name,
    CategoryKind? kind,
    int? iconCodePoint,
    int? colorValue,
    int? monthlyBudgetCents,
  }) => TransactionCategory(
    id: id,
    name: name ?? this.name,
    kind: kind ?? this.kind,
    iconCodePoint: iconCodePoint ?? this.iconCodePoint,
    colorValue: colorValue ?? this.colorValue,
    monthlyBudgetCents: monthlyBudgetCents ?? this.monthlyBudgetCents,
  );

  Map<String, dynamic> toMap() => {
    'id': id,
    'name': name,
    'kind': kind.name,
    'iconCodePoint': iconCodePoint,
    'colorValue': colorValue,
    'monthlyBudgetCents': monthlyBudgetCents,
  };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TransactionCategory &&
          other.id == id &&
          other.name == name &&
          other.kind == kind &&
          other.iconCodePoint == iconCodePoint &&
          other.colorValue == colorValue &&
          other.monthlyBudgetCents == monthlyBudgetCents;

  @override
  int get hashCode => Object.hash(
    id,
    name,
    kind,
    iconCodePoint,
    colorValue,
    monthlyBudgetCents,
  );
}
