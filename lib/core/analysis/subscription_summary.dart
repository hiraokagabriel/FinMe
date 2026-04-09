/// Resumo de uma assinatura detectada automaticamente.
class SubscriptionSummary {
  const SubscriptionSummary({
    required this.description,
    required this.categoryId,
    required this.avgAmount,
    required this.frequency,
    required this.lastDate,
    required this.occurrences,
  });

  final String description;
  final String? categoryId;

  /// Valor médio das ocorrências (R$).
  final double avgAmount;

  /// 'monthly' ou 'yearly'.
  final String frequency;

  final DateTime lastDate;
  final int occurrences;

  double get monthlyProjected =>
      frequency == 'yearly' ? avgAmount / 12 : avgAmount;

  double get yearlyProjected =>
      frequency == 'yearly' ? avgAmount : avgAmount * 12;
}
