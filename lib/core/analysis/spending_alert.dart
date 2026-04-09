/// Alerta de desvio de gastos em relação à média histórica.
class SpendingAlert {
  const SpendingAlert({
    required this.categoryId,
    required this.categoryName,
    required this.historicalAvg,
    required this.currentSpend,
    required this.deviationPct,
    required this.severity,
  });

  final String categoryId;
  final String categoryName;

  /// Média dos 3 meses anteriores (R$).
  final double historicalAvg;

  /// Gasto no mês atual (R$).
  final double currentSpend;

  /// Desvio percentual: (current - avg) / avg * 100.
  final double deviationPct;

  /// 'warning' (> 30%) ou 'critical' (> 80%).
  final String severity;

  bool get isCritical => severity == 'critical';
}
