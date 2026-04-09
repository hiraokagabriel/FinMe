/// Tipos de alerta gerados pelo [SpendingAnalyzer].
enum SpendingAlertType {
  /// Uma categoria ultrapassou [thresholdPct]% do total de despesas no período.
  categoryDominant,

  /// Gasto total do mês atual excedeu a média dos meses anteriores em [thresholdPct]%.
  monthlySpike,

  /// Uma categoria cresceu mais de [thresholdPct]% em relação ao mês anterior.
  categorySpike,
}

/// Resultado imutável de um alerta de gasto.
class SpendingAlert {
  const SpendingAlert({
    required this.type,
    required this.title,
    required this.description,
    this.categoryId,
    required this.severity, // 1 = info, 2 = warning, 3 = critical
  });

  final SpendingAlertType type;
  final String title;
  final String description;
  final String? categoryId;

  /// 1 = informativo · 2 = atenção · 3 = crítico
  final int severity;
}
