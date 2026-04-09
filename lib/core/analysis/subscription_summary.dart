/// Resumo de uma assinatura detectada automaticamente.
/// Value object — imutável, sem dependências de framework.
class SubscriptionSummary {
  final String description;
  final String? categoryId;
  final double avgAmount;
  final String frequency; // 'monthly' | 'yearly'
  final DateTime lastDate;
  final int occurrences;
  final bool isManual; // recurrenceRule != none

  const SubscriptionSummary({
    required this.description,
    this.categoryId,
    required this.avgAmount,
    required this.frequency,
    required this.lastDate,
    required this.occurrences,
    this.isManual = false,
  });

  /// Custo mensal projetado (anual dividido por 12 para yearly).
  double get monthlyAmount =>
      frequency == 'yearly' ? avgAmount / 12 : avgAmount;

  /// Custo anual projetado.
  double get annualAmount =>
      frequency == 'yearly' ? avgAmount : avgAmount * 12;
}
