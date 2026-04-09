import '../../features/categories/domain/category_entity.dart';
import '../../features/transactions/domain/transaction_entity.dart';
import '../../features/transactions/domain/transaction_type.dart';
import 'spending_alert.dart';

/// Analisa desvios de gastos por categoria comparando mês atual
/// com média dos 3 meses anteriores.
/// Função pura — sem side-effects, sem acesso a Hive.
class SpendingAnalyzer {
  static List<SpendingAlert> analyze({
    required List<TransactionEntity> transactions,
    required List<CategoryEntity> categories,
    required DateTime currentMonth,
  }) {
    final catMap = {for (final c in categories) c.id: c};

    double _spentInMonth(String categoryId, DateTime month) {
      return transactions
          .where((tx) =>
              !tx.isProvisioned &&
              tx.type == TransactionType.expense &&
              tx.categoryId == categoryId &&
              tx.date.year == month.year &&
              tx.date.month == month.month)
          .fold(0.0, (s, tx) => s + tx.amount.amount);
    }

    // Coleta categorias únicas com gastos no período relevante
    final allCategoryIds = transactions
        .where((tx) =>
            !tx.isProvisioned &&
            tx.type == TransactionType.expense &&
            tx.categoryId != null)
        .map((tx) => tx.categoryId!)
        .toSet();

    final alerts = <SpendingAlert>[];

    for (final catId in allCategoryIds) {
      // Calcula média dos 3 meses anteriores
      final historicalMonths = List.generate(
        3,
        (i) => DateTime(currentMonth.year, currentMonth.month - (i + 1)),
      );

      final historicalSpends = historicalMonths
          .map((m) => _spentInMonth(catId, m))
          .where((v) => v > 0)
          .toList();

      // Ignora categorias com menos de 2 meses históricos
      if (historicalSpends.length < 2) continue;

      final historicalAvg =
          historicalSpends.fold(0.0, (s, v) => s + v) /
              historicalSpends.length;

      final currentSpend = _spentInMonth(catId, currentMonth);

      // Ignora gastos baixos (< R$ 20) no mês atual
      if (currentSpend < 20) continue;

      // Ignora desvio negativo (gastou menos)
      if (currentSpend <= historicalAvg) continue;

      final deviationPct =
          (currentSpend - historicalAvg) / historicalAvg * 100;

      // Só alerta se desvio > 30%
      if (deviationPct <= 30) continue;

      final severity = deviationPct > 80 ? 'critical' : 'warning';
      final cat = catMap[catId];

      alerts.add(SpendingAlert(
        categoryId: catId,
        categoryName: cat?.name ?? catId,
        historicalAvg: historicalAvg,
        currentSpend: currentSpend,
        deviationPct: deviationPct,
        severity: severity,
      ));
    }

    alerts.sort(
        (a, b) => b.deviationPct.compareTo(a.deviationPct));
    return alerts;
  }
}
