/// Entidade de meta mensal por categoria.
/// Uma meta define um teto de gastos para uma categoria num determinado mês.
class GoalEntity {
  final String id;
  final String categoryId;

  /// Limite máximo de gasto (em reais) para o mês.
  final double limitAmount;

  /// Mês-referência da meta (apenas ano e mês são relevantes).
  /// Se null, a meta vale para todos os meses (recorrente).
  final DateTime? month;

  const GoalEntity({
    required this.id,
    required this.categoryId,
    required this.limitAmount,
    this.month,
  });

  /// Verifica se esta meta se aplica ao mês-ano informado.
  bool appliesTo(DateTime date) {
    if (month == null) return true;
    return month!.year == date.year && month!.month == date.month;
  }

  GoalEntity copyWith({
    String? id,
    String? categoryId,
    double? limitAmount,
    DateTime? month,
  }) {
    return GoalEntity(
      id: id ?? this.id,
      categoryId: categoryId ?? this.categoryId,
      limitAmount: limitAmount ?? this.limitAmount,
      month: month ?? this.month,
    );
  }
}
