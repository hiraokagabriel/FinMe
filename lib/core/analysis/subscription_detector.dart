import '../../features/transactions/domain/transaction_entity.dart';
import '../../features/transactions/domain/transaction_type.dart';
import '../../features/transactions/domain/recurrence_rule.dart';
import 'subscription_summary.dart';

/// Detecta assinaturas recorrentes a partir de uma lista de transações.
/// Função pura — sem side-effects, sem acesso a Hive.
class SubscriptionDetector {
  static List<SubscriptionSummary> detect(
      List<TransactionEntity> transactions) {
    // Apenas despesas não provisionadas dos últimos 12 meses
    final cutoff = DateTime.now().subtract(const Duration(days: 365));
    final expenses = transactions
        .where((tx) =>
            tx.type == TransactionType.expense &&
            !tx.isProvisioned &&
            tx.date.isAfter(cutoff))
        .toList();

    final results = <SubscriptionSummary>[];
    final seen = <String>{};

    // 1. Candidatas diretas: recurrenceRule != none
    for (final tx in expenses) {
      if (tx.recurrenceRule == RecurrenceRule.none) continue;
      final key = _normalize(tx.description ?? tx.id);
      if (seen.contains(key)) continue;
      seen.add(key);

      final group = expenses
          .where((t) =>
              _normalize(t.description ?? t.id) == key ||
              t.recurrenceSourceId == tx.id ||
              t.id == tx.recurrenceSourceId)
          .toList()
        ..sort((a, b) => a.date.compareTo(b.date));

      final avg = group.fold(0.0, (s, t) => s + t.amount.amount) /
          group.length;
      final freq = (tx.recurrenceRule == RecurrenceRule.yearly)
          ? 'yearly'
          : 'monthly';

      results.add(SubscriptionSummary(
        description: tx.description ?? key,
        categoryId: tx.categoryId,
        avgAmount: avg,
        frequency: freq,
        lastDate: group.last.date,
        occurrences: group.length,
      ));
    }

    // 2. Detecção por padrão: agrupamento por description normalizada
    final groups = <String, List<TransactionEntity>>{};
    for (final tx in expenses) {
      if (tx.recurrenceRule != RecurrenceRule.none) continue;
      final key = _normalize(tx.description ?? '');
      if (key.isEmpty) continue;
      groups.putIfAbsent(key, () => []).add(tx);
    }

    for (final entry in groups.entries) {
      final key = entry.key;
      if (seen.contains(key)) continue;

      final group = entry.value
        ..sort((a, b) => a.date.compareTo(b.date));

      if (group.length < 2) continue;

      // Verifica intervalo entre ocorrências consecutivas
      final intervals = <int>[];
      for (int i = 1; i < group.length; i++) {
        intervals.add(
            group[i].date.difference(group[i - 1].date).inDays);
      }

      final avgInterval =
          intervals.fold(0, (s, v) => s + v) / intervals.length;

      String? freq;
      if (avgInterval >= 25 && avgInterval <= 35) {
        freq = 'monthly';
      } else if (avgInterval >= 350 && avgInterval <= 380) {
        freq = 'yearly';
      }
      if (freq == null) continue;

      // Verifica variação de valor ≤ 10%
      final amounts = group.map((t) => t.amount.amount).toList();
      final avg = amounts.fold(0.0, (s, v) => s + v) / amounts.length;
      final maxDev = amounts
          .map((v) => (v - avg).abs() / avg)
          .fold(0.0, (a, b) => a > b ? a : b);
      if (maxDev > 0.10) continue;

      seen.add(key);
      results.add(SubscriptionSummary(
        description: group.last.description ?? key,
        categoryId: group.last.categoryId,
        avgAmount: avg,
        frequency: freq,
        lastDate: group.last.date,
        occurrences: group.length,
      ));
    }

    results.sort((a, b) => b.avgAmount.compareTo(a.avgAmount));
    return results;
  }

  /// Normaliza texto: lowercase, remove números e pontuação.
  static String _normalize(String input) {
    return input
        .toLowerCase()
        .trim()
        .replaceAll(RegExp(r'[0-9]'), '')
        .replaceAll(RegExp(r'[^\w\s]'), '')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }
}
