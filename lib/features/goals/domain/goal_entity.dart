import 'goal_type.dart';

/// Entidade unificada para Metas de Economia e Tetos de Gasto.
class GoalEntity {
  final String id;

  /// Tipo da meta: economia ou teto de gastos.
  final GoalType type;

  /// Título livre da meta (ex: "Viagem para Europa", "Limite Alimentação").
  final String title;

  // ── Campos de Meta de Economia ─────────────────────────────────────────

  /// Valor alvo que se deseja acumular. Usado em [GoalType.savingsGoal].
  final double? targetAmount;

  /// Valor já acumulado/guardado até o momento. Atualizado manualmente.
  /// Usado em [GoalType.savingsGoal].
  final double? currentAmount;

  // ── Campos de Teto de Gastos ──────────────────────────────────────────

  /// ID da categoria monitorada. Usado em [GoalType.spendingCeiling].
  final String? categoryId;

  /// Valor máximo permitido de gasto. Usado em [GoalType.spendingCeiling].
  final double? limitAmount;

  /// Mês-referência do teto. Se null, vale para todos os meses (recorrente).
  /// Usado em [GoalType.spendingCeiling].
  final DateTime? month;

  const GoalEntity({
    required this.id,
    required this.type,
    required this.title,
    this.targetAmount,
    this.currentAmount,
    this.categoryId,
    this.limitAmount,
    this.month,
  });

  /// Verifica se este teto se aplica ao mês-ano informado.
  bool appliesTo(DateTime date) {
    if (type != GoalType.spendingCeiling) return false;
    if (month == null) return true;
    return month!.year == date.year && month!.month == date.month;
  }

  GoalEntity copyWith({
    String? id,
    GoalType? type,
    String? title,
    double? targetAmount,
    double? currentAmount,
    String? categoryId,
    double? limitAmount,
    DateTime? month,
  }) {
    return GoalEntity(
      id: id ?? this.id,
      type: type ?? this.type,
      title: title ?? this.title,
      targetAmount: targetAmount ?? this.targetAmount,
      currentAmount: currentAmount ?? this.currentAmount,
      categoryId: categoryId ?? this.categoryId,
      limitAmount: limitAmount ?? this.limitAmount,
      month: month ?? this.month,
    );
  }
}
