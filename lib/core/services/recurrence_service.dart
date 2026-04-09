import '../../features/transactions/data/transaction_model.dart';
import '../../features/transactions/domain/recurrence_rule.dart';
import '../../features/transactions/domain/transaction_entity.dart';
import 'repository_locator.dart';

/// Gera automaticamente as transações recorrentes pendentes.
/// Deve ser chamado após ProfileService.loadFromStorage() e DefaultSeedService.
class RecurrenceService {
  static Future<void> generatePending() async {
    final repo  = RepositoryLocator.instance.transactions;
    final all   = await repo.getAll();
    final now   = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    final existingIds = all.map((t) => t.id).toSet();
    final toAdd = <TransactionEntity>[];

    for (final tx in all) {
      final rule = tx.recurrenceRule;
      if (rule == RecurrenceRule.none) continue;
      if (tx.recurrenceSourceId != null) continue;

      DateTime cursor = rule.next(
        DateTime(tx.date.year, tx.date.month, tx.date.day),
      );

      int safety = 0;
      while (!cursor.isAfter(today) && safety < 730) {
        safety++;
        final occurrenceId = '${tx.id}_rec_${cursor.millisecondsSinceEpoch}';

        if (!existingIds.contains(occurrenceId)) {
          toAdd.add(TransactionModel(
            id: occurrenceId,
            amount: tx.amount.amount,
            currency: tx.amount.currency,
            date: cursor,
            typeIndex: tx.type.index,
            paymentMethodIndex: tx.paymentMethod.index,
            description: tx.description,
            categoryId: tx.categoryId ?? '',
            cardId: tx.cardId,
            isBoleto: tx.isBoleto,
            isProvisioned: false,
            recurrenceRuleIndex: 0,
            recurrenceSourceId: tx.id,
          ).toEntity());
          existingIds.add(occurrenceId);
        }
        cursor = rule.next(cursor);
      }
    }

    for (final entity in toAdd) {
      await repo.add(entity);
    }
  }
}
