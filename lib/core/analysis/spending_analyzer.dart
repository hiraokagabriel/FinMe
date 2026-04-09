import '../../features/transactions/domain/transaction_entity.dart';
import '../../features/transactions/domain/transaction_type.dart';
import 'spending_alert.dart';

/// Analisa padrões de gasto e retorna uma lista de [SpendingAlert].
/// Função pura — sem side-effects, sem acesso a Hive.
///
/// Alertas gerados:
/// 1. [SpendingAlertType.categoryDominant] — categoria > 40% do total do período
/// 2. [SpendingAlertType.monthlySpike]     — mês atual > média histórica + 25%
/// 3. [SpendingAlertType.categorySpike]    — categoria cresceu > 50% vs mês anterior
List<SpendingAlert> analyzeSpending(List<TransactionEntity> transactions) {
  final expenses = transactions
      .where((tx) =>
          tx.type == TransactionType.expense &&
          !tx.isProvisioned &&
          tx.categoryId != null)
      .toList();

  if (expenses.isEmpty) return const [];

  final alerts = <SpendingAlert>[];

  alerts.addAll(_checkCategoryDominant(expenses));
  alerts.addAll(_checkMonthlySpike(expenses));
  alerts.addAll(_checkCategorySpike(expenses));

  // Ordena: crítico → atenção → info, depois por tipo
  alerts.sort((a, b) => b.severity.compareTo(a.severity));
  return alerts;
}

// ── 1. Categoria dominante ─────────────────────────────────────────────────

List<SpendingAlert> _checkCategoryDominant(
    List<TransactionEntity> expenses) {
  const threshold = 0.40;

  final now = DateTime.now();
  final currentMonth = expenses
      .where((tx) => tx.date.year == now.year && tx.date.month == now.month)
      .toList();

  if (currentMonth.isEmpty) return const [];

  final total =
      currentMonth.fold<double>(0, (s, tx) => s + tx.amount.amount);
  if (total == 0) return const [];

  final byCategory = <String, double>{};
  for (final tx in currentMonth) {
    byCategory[tx.categoryId!] =
        (byCategory[tx.categoryId!] ?? 0) + tx.amount.amount;
  }

  return byCategory.entries
      .where((e) => e.value / total > threshold)
      .map((e) {
        final pct = (e.value / total * 100).toStringAsFixed(0);
        return SpendingAlert(
          type: SpendingAlertType.categoryDominant,
          categoryId: e.key,
          title: 'Categoria concentrada',
          description:
              'Esta categoria representa $pct% das suas despesas este mês.',
          severity: e.value / total > 0.60 ? 3 : 2,
        );
      })
      .toList();
}

// ── 2. Spike mensal geral ──────────────────────────────────────────────────

List<SpendingAlert> _checkMonthlySpike(
    List<TransactionEntity> expenses) {
  const growthThreshold = 0.25;

  final now = DateTime.now();

  final byMonth = <String, double>{};
  for (final tx in expenses) {
    final key = '${tx.date.year}-${tx.date.month.toString().padLeft(2, '0')}';
    byMonth[key] = (byMonth[key] ?? 0) + tx.amount.amount;
  }

  final currentKey =
      '${now.year}-${now.month.toString().padLeft(2, '0')}';
  final currentTotal = byMonth[currentKey] ?? 0;
  if (currentTotal == 0) return const [];

  // Média dos meses anteriores (excluindo o atual)
  final pastValues =
      byMonth.entries.where((e) => e.key != currentKey).map((e) => e.value).toList();
  if (pastValues.isEmpty) return const [];

  final avg = pastValues.reduce((a, b) => a + b) / pastValues.length;
  if (avg == 0) return const [];

  final growth = (currentTotal - avg) / avg;
  if (growth <= growthThreshold) return const [];

  final pct = (growth * 100).toStringAsFixed(0);
  return [
    SpendingAlert(
      type: SpendingAlertType.monthlySpike,
      title: 'Gastos acima da média',
      description:
          'Seus gastos este mês estão $pct% acima da sua média histórica.',
      severity: growth > 0.50 ? 3 : 2,
    ),
  ];
}

// ── 3. Spike por categoria (vs mês anterior) ───────────────────────────────

List<SpendingAlert> _checkCategorySpike(
    List<TransactionEntity> expenses) {
  const growthThreshold = 0.50;

  final now = DateTime.now();
  final prevMonth = DateTime(now.year, now.month - 1);

  bool isCurrentMonth(TransactionEntity tx) =>
      tx.date.year == now.year && tx.date.month == now.month;
  bool isPrevMonth(TransactionEntity tx) =>
      tx.date.year == prevMonth.year && tx.date.month == prevMonth.month;

  final current = <String, double>{};
  final previous = <String, double>{};

  for (final tx in expenses) {
    if (isCurrentMonth(tx)) {
      current[tx.categoryId!] =
          (current[tx.categoryId!] ?? 0) + tx.amount.amount;
    } else if (isPrevMonth(tx)) {
      previous[tx.categoryId!] =
          (previous[tx.categoryId!] ?? 0) + tx.amount.amount;
    }
  }

  final alerts = <SpendingAlert>[];
  for (final entry in current.entries) {
    final prev = previous[entry.key] ?? 0;
    if (prev == 0) continue;
    final growth = (entry.value - prev) / prev;
    if (growth <= growthThreshold) continue;
    final pct = (growth * 100).toStringAsFixed(0);
    alerts.add(SpendingAlert(
      type: SpendingAlertType.categorySpike,
      categoryId: entry.key,
      title: 'Categoria em alta',
      description:
          'Gasto $pct% maior que o mês anterior nesta categoria.',
      severity: growth > 1.0 ? 3 : 2,
    ));
  }
  return alerts;
}
