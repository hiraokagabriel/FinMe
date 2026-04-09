import 'budget_period.dart';

class BudgetEntity {
  final String id;
  final String categoryId;
  final double limitAmount;

  /// Ano e mês de referência (dia sempre 1).
  final DateTime month;
  final BudgetPeriod period;

  const BudgetEntity({
    required this.id,
    required this.categoryId,
    required this.limitAmount,
    required this.month,
    this.period = BudgetPeriod.monthly,
  });

  bool appliesToMonth(DateTime date) =>
      month.year == date.year && month.month == date.month;

  BudgetEntity copyWith({
    String? id,
    String? categoryId,
    double? limitAmount,
    DateTime? month,
    BudgetPeriod? period,
  }) {
    return BudgetEntity(
      id: id ?? this.id,
      categoryId: categoryId ?? this.categoryId,
      limitAmount: limitAmount ?? this.limitAmount,
      month: month ?? this.month,
      period: period ?? this.period,
    );
  }
}
