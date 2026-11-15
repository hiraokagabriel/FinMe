import 'package:hive_flutter/hive_flutter.dart';

import '../core/services/collection_repository.dart';
import '../core/services/record_store.dart';
import '../core/services/settings_controller.dart';
import '../core/utils/date_utils.dart';
import '../features/accounts/domain/account.dart';
import '../features/cards/domain/payment_card.dart';
import '../features/categories/domain/transaction_category.dart';
import '../features/recurring/domain/recurrence.dart';
import '../features/recurring/domain/recurring_rule.dart';
import '../features/transactions/domain/transaction.dart';
import 'app_scope.dart';
import 'ledger.dart';
import 'seed.dart';

const _boxes = [
  'fm_accounts',
  'fm_cards',
  'fm_categories',
  'fm_transactions',
  'fm_recurring',
  'fm_settings',
];

/// Monta os serviços do app. Sem [storeFactory] usa Hive; testes passam `MemoryRecordStore`.
Future<AppServices> bootstrap({
  RecordStore Function(String box)? storeFactory,
  DateTime Function()? clock,
}) async {
  if (storeFactory == null) {
    await Hive.initFlutter('finme');
  }
  final stores = <String, RecordStore>{};
  for (final box in _boxes) {
    stores[box] = storeFactory != null
        ? storeFactory(box)
        : await HiveRecordStore.open(box);
  }
  final now = clock ?? DateTime.now;

  final accounts = CollectionRepository<Account>(
    store: stores['fm_accounts']!,
    fromMap: Account.fromMap,
    toMap: (a) => a.toMap(),
    idOf: (a) => a.id,
  );
  final cards = CollectionRepository<PaymentCard>(
    store: stores['fm_cards']!,
    fromMap: PaymentCard.fromMap,
    toMap: (c) => c.toMap(),
    idOf: (c) => c.id,
  );
  final categories = CollectionRepository<TransactionCategory>(
    store: stores['fm_categories']!,
    fromMap: TransactionCategory.fromMap,
    toMap: (c) => c.toMap(),
    idOf: (c) => c.id,
  );
  final transactions = CollectionRepository<Transaction>(
    store: stores['fm_transactions']!,
    fromMap: Transaction.fromMap,
    toMap: (t) => t.toMap(),
    idOf: (t) => t.id,
  );
  final recurring = CollectionRepository<RecurringRule>(
    store: stores['fm_recurring']!,
    fromMap: RecurringRule.fromMap,
    toMap: (r) => r.toMap(),
    idOf: (r) => r.id,
  );
  final settings = SettingsController(stores['fm_settings']!);

  if (categories.isEmpty) {
    await categories.upsertAll(defaultCategories());
  }

  final ledger = Ledger(
    accounts: accounts,
    cards: cards,
    categories: categories,
    transactions: transactions,
    recurring: recurring,
    settings: settings,
    clock: now,
  );
  final services = AppServices(
    accounts: accounts,
    cards: cards,
    categories: categories,
    transactions: transactions,
    recurring: recurring,
    settings: settings,
    ledger: ledger,
    clock: now,
  );
  await materializeRecurring(services);
  return services;
}

/// SPEC §5.4: grava as ocorrências de recorrência de `materializedUntil + 1` até hoje
/// e avança `materializedUntil`. Idempotente; ocorrências futuras não são gravadas.
Future<void> materializeRecurring(AppServices s) async {
  final today = dateOnly(s.clock());
  final existing = {for (final t in s.transactions.all) t.id};
  final created = <Transaction>[];
  final updated = <RecurringRule>[];
  for (final r in s.recurring.all) {
    final from = _firstPendingDay(r);
    if (from.isAfter(today)) {
      continue;
    }
    created.addAll(
      occurrenceTransactions(r, from, today, existing, forProjection: false),
    );
    updated.add(r.copyWith(materializedUntil: today));
  }
  // Transações antes das regras: se falhar no meio, a próxima execução não duplica (ids existentes são pulados).
  await s.transactions.upsertAll(created);
  await s.recurring.upsertAll(updated);
}

DateTime _firstPendingDay(RecurringRule r) {
  final until = r.materializedUntil;
  if (until == null) {
    return r.startDate;
  }
  final next = DateTime(until.year, until.month, until.day + 1);
  return next.isAfter(r.startDate) ? next : r.startDate;
}
