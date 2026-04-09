import '../transactions/domain/transaction_entity.dart';
import '../transactions/domain/transaction_type.dart';
import '../transactions/domain/recurrence_rule.dart';
import 'subscription_summary.dart';

/// Detecta assinaturas recorrentes a partir de uma lista de transações.
/// Função pura — sem side-effects, sem acesso a Hive.
///
/// Estratégia:
/// 1. Transações com [RecurrenceRule] != none → assinaturas manuais (sempre incluídas)
/// 2. Despesas com descrição repetida em intervalo 25–35 dias e variação de valor ≤ 10%
///    → assinaturas automáticas
/// Resultado ordenado por [avgAmount] decrescente.
List<SubscriptionSummary> detectSubscriptions(
  List<TransactionEntity> transactions,
) {
  final manual = _detectManual(transactions);
  final auto = _detectAuto(transactions);

  final manualKeys = manual.map((s) => _key(s.description, s.categoryId)).toSet();
  final autoFiltered =
      auto.where((s) => !manualKeys.contains(_key(s.description, s.categoryId))).toList();

  return [...manual, ...autoFiltered]
    ..sort((a, b) => b.avgAmount.compareTo(a.avgAmount));
}

String _key(String desc, String? catId) =>
    '${desc.toLowerCase().trim()}_${catId ?? ''}';

// ── Assinaturas manuais (recurrenceRule != none) ───────────────────────────

List<SubscriptionSummary> _detectManual(List<TransactionEntity> txs) {
  final recurring = txs
      .where((tx) =>
          tx.recurrenceRule != RecurrenceRule.none &&
          tx.type != TransactionType.transfer)
      .toList();

  final Map<String, List<TransactionEntity>> groups = {};
  for (final tx in recurring) {
    final k = _key(tx.description ?? '', tx.categoryId);
    groups.putIfAbsent(k, () => []).add(tx);
  }

  return groups.entries
      .where((e) => e.value.length >= 2)
      .map((e) {
        final list = e.value;
        final avg = list.map((t) => t.amount.amount).reduce((a, b) => a + b) /
            list.length;
        final lastDate =
            list.map((t) => t.date).reduce((a, b) => a.isAfter(b) ? a : b);
        final freq = list.any((t) => t.recurrenceRule == RecurrenceRule.yearly)
            ? 'yearly'
            : 'monthly';
        return SubscriptionSummary(
          description: list.first.description ?? 'Sem descrição',
          categoryId: list.first.categoryId,
          avgAmount: avg,
          frequency: freq,
          lastDate: lastDate,
          occurrences: list.length,
          isManual: true,
        );
      })
      .toList();
}

// ── Assinaturas automáticas (padrão de repetição) ─────────────────────────

List<SubscriptionSummary> _detectAuto(List<TransactionEntity> txs) {
  // Apenas despesas efetivadas
  final expenses = txs
      .where((tx) =>
          tx.type == TransactionType.expense &&
          !tx.isProvisioned &&
          tx.recurrenceRule == RecurrenceRule.none)
      .toList();

  final Map<String, List<TransactionEntity>> groups = {};
  for (final tx in expenses) {
    final normalized = _normalize(tx.description ?? '');
    if (normalized.isEmpty) continue;
    final k = _key(normalized, tx.categoryId);
    groups.putIfAbsent(k, () => []).add(tx);
  }

  return groups.entries
      .where((e) {
        final list = e.value;
        if (list.length < 2) return false;

        list.sort((a, b) => a.date.compareTo(b.date));

        // Verifica padrão mensal: ao menos um par com 25–35 dias de intervalo
        bool hasPattern = false;
        for (int i = 1; i < list.length; i++) {
          final diff = list[i].date.difference(list[i - 1].date).inDays;
          if (diff >= 25 && diff <= 35) {
            hasPattern = true;
            break;
          }
        }
        if (!hasPattern) return false;

        // Variação de valor ≤ 10%
        final amounts = list.map((t) => t.amount.amount).toList();
        final avg = amounts.reduce((a, b) => a + b) / amounts.length;
        if (avg == 0) return false;
        final maxDev =
            amounts.map((v) => (v - avg).abs() / avg).reduce((a, b) => a > b ? a : b);
        return maxDev <= 0.10;
      })
      .map((e) {
        final list = e.value;
        final avg = list.map((t) => t.amount.amount).reduce((a, b) => a + b) /
            list.length;
        final lastDate =
            list.map((t) => t.date).reduce((a, b) => a.isAfter(b) ? a : b);
        return SubscriptionSummary(
          description: list.first.description ?? 'Sem descrição',
          categoryId: list.first.categoryId,
          avgAmount: avg,
          frequency: 'monthly',
          lastDate: lastDate,
          occurrences: list.length,
          isManual: false,
        );
      })
      .toList();
}

/// Normaliza descrição para agrupamento:
/// lowercase + trim + remove números/pontuação no final.
String _normalize(String s) {
  return s
      .toLowerCase()
      .trim()
      .replaceAll(RegExp(r'[\d.,/\\\-]+\s*$'), '')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
}
