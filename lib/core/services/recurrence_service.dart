import 'package:hive/hive.dart';

import '../../features/transactions/data/transaction_model.dart';
import '../../features/transactions/domain/recurrence_rule.dart';

/// Gera automaticamente as transações recorrentes pendentes.
///
/// Deve ser chamado uma vez no startup, após o Hive estar inicializado.
/// Para cada transação com [RecurrenceRule] != none, verifica se a próxima
/// ocorrência já existe e, caso não exista, a cria.
class RecurrenceService {
  static const String _boxName = 'transactions';

  /// Ponto de entrada — chame em main() após HiveInit.init().
  static Future<void> generatePending() async {
    final box = await Hive.openBox<TransactionModel>(_boxName);
    final all = box.values.toList();
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    // Monta set de IDs existentes para evitar duplicatas
    final existingIds = box.keys.toSet();

    final toAdd = <String, TransactionModel>{};

    for (final model in all) {
      final rule = model.recurrenceRuleIndex < RecurrenceRule.values.length
          ? RecurrenceRule.values[model.recurrenceRuleIndex]
          : RecurrenceRule.none;

      if (rule == RecurrenceRule.none) continue;
      // Só processa as transações-origem (não as geradas automaticamente)
      if (model.recurrenceSourceId != null) continue;

      // Avança a partir da data da transação-origem até cobrir hoje
      DateTime cursor = rule.next(
        DateTime(model.date.year, model.date.month, model.date.day),
      );

      int safety = 0; // limite de segurança: máx 730 iterações (~2 anos)
      while (!cursor.isAfter(today) && safety < 730) {
        safety++;
        // ID determinístico: sourceId + timestamp da ocorrência
        final occurrenceId =
            '${model.id}_rec_${cursor.millisecondsSinceEpoch}';

        if (!existingIds.contains(occurrenceId) &&
            !toAdd.containsKey(occurrenceId)) {
          toAdd[occurrenceId] = TransactionModel(
            id: occurrenceId,
            amount: model.amount,
            currency: model.currency,
            date: cursor,
            typeIndex: model.typeIndex,
            paymentMethodIndex: model.paymentMethodIndex,
            description: model.description,
            categoryId: model.categoryId,
            cardId: model.cardId,
            isBoleto: model.isBoleto,
            isProvisioned: false,
            installmentCount: null,
            provisionedDueDate: null,
            recurrenceRuleIndex: 0, // gerada = sem regra própria
            recurrenceSourceId: model.id,
          );
          existingIds.add(occurrenceId);
        }
        cursor = rule.next(cursor);
      }
    }

    if (toAdd.isNotEmpty) {
      await box.putAll(toAdd);
    }
  }
}
