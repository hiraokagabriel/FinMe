import 'dart:io';

import 'package:hive_flutter/hive_flutter.dart';
import 'package:path_provider/path_provider.dart';

import '../core/services/backup_service.dart';
import '../core/services/collection_repository.dart';
import '../core/services/record_store.dart';
import '../core/services/recovery_journal.dart';
import '../core/services/settings_controller.dart';
import '../core/utils/date_utils.dart';
import '../features/accounts/domain/account.dart';
import '../features/cards/domain/payment_card.dart';
import '../features/categories/domain/transaction_category.dart';
import '../features/debts/domain/debt.dart';
import '../features/debts/presentation/debt_transaction_sync.dart';
import '../features/goals/domain/goal.dart';
import '../features/net_worth/domain/asset.dart';
import '../features/profiles/domain/profile.dart';
import '../features/importing/domain/import_batch.dart';
import '../features/importing/domain/import_profile.dart';
import '../features/importing/domain/merchant_dictionary.dart';
import '../features/recurring/domain/recurrence.dart';
import '../features/recurring/domain/recurring_rule.dart';
import '../features/rules/domain/transaction_rule.dart';
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
  'fm_rules',
  'fm_import_profiles',
  'fm_dictionary',
  'fm_goals',
  'fm_assets',
  'fm_debts',
  'fm_import_batches',
  'fm_ui_state',
];

/// SPEC §10.3: o perfil `default` mantém os nomes de antes dos perfis; os outros ganham prefixo.
String boxNameFor(String profileId, String box) =>
    profileId == defaultProfileId ? box : 'p${profileId}_$box';

List<String> boxNamesFor(String profileId) => [
  for (final box in _boxes) boxNameFor(profileId, box),
];

Future<File> _journalFile(String profileId) async {
  final support = await getApplicationSupportDirectory();
  final suffix = profileId == defaultProfileId ? '' : '_$profileId';
  return File('${support.path}/finme_import_journal$suffix.json');
}

/// Apaga do disco os boxes e o retrato do perfil. Nunca chamar para o perfil aberto.
Future<void> deleteProfileData(String profileId) async {
  for (final name in boxNamesFor(profileId)) {
    await Hive.deleteBoxFromDisk(name);
  }
  final journal = await _journalFile(profileId);
  if (await journal.exists()) {
    await journal.delete();
  }
}

/// Monta os serviços do perfil [profileId]. Sem [storeFactory] usa Hive; testes passam `MemoryRecordStore`.
/// [storeFactory] recebe o nome do box já com o prefixo do perfil.
/// Sem [journal]: arquivo de retrato no Hive, memória com [storeFactory].
Future<AppServices> bootstrap({
  String profileId = defaultProfileId,
  RecordStore Function(String box)? storeFactory,
  DateTime Function()? clock,
  RecoveryJournal? journal,
}) async {
  RecoveryJournal? recovery = journal;
  if (storeFactory == null) {
    await Hive.initFlutter('finme');
    recovery ??= FileRecoveryJournal(await _journalFile(profileId));
  }
  final stores = <String, RecordStore>{};
  for (final box in _boxes) {
    final name = boxNameFor(profileId, box);
    stores[box] = storeFactory != null
        ? storeFactory(name)
        : await HiveRecordStore.open(name);
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
  final rules = CollectionRepository<TransactionRule>(
    store: stores['fm_rules']!,
    fromMap: TransactionRule.fromMap,
    toMap: (r) => r.toMap(),
    idOf: (r) => r.id,
  );
  final importProfiles = CollectionRepository<ImportProfile>(
    store: stores['fm_import_profiles']!,
    fromMap: ImportProfile.fromMap,
    toMap: (p) => p.toMap(),
    idOf: (p) => p.id,
  );
  final dictionary = CollectionRepository<DictionaryEntry>(
    store: stores['fm_dictionary']!,
    fromMap: DictionaryEntry.fromMap,
    toMap: (e) => e.toMap(),
    idOf: (e) => e.id,
  );

  final goals = CollectionRepository<Goal>(
    store: stores['fm_goals']!,
    fromMap: Goal.fromMap,
    toMap: (g) => g.toMap(),
    idOf: (g) => g.id,
  );
  final assets = CollectionRepository<Asset>(
    store: stores['fm_assets']!,
    fromMap: Asset.fromMap,
    toMap: (a) => a.toMap(),
    idOf: (a) => a.id,
  );
  final debts = CollectionRepository<Debt>(
    store: stores['fm_debts']!,
    fromMap: Debt.fromMap,
    toMap: (d) => d.toMap(),
    idOf: (d) => d.id,
  );
  final importBatches = CollectionRepository<ImportBatch>(
    store: stores['fm_import_batches']!,
    fromMap: ImportBatch.fromMap,
    toMap: (b) => b.toMap(),
    idOf: (b) => b.id,
  );
  final debtSync = DebtTransactionSync(
    transactions: transactions,
    debts: debts,
  );
  recovery ??= MemoryRecoveryJournal();

  if (categories.isEmpty) {
    await categories.upsertAll(defaultCategories());
  }
  if (dictionary.isEmpty) {
    await dictionary.upsertAll(defaultDictionary());
  }

  late final AppServices services;
  final ledger = Ledger(
    accounts: accounts,
    cards: cards,
    categories: categories,
    transactions: transactions,
    recurring: recurring,
    settings: settings,
    rules: rules,
    dictionary: dictionary,
    goals: goals,
    assets: assets,
    debts: debts,
    clock: now,
    onDayChanged: () => materializeRecurring(services),
  );
  services = AppServices(
    accounts: accounts,
    cards: cards,
    categories: categories,
    transactions: transactions,
    recurring: recurring,
    settings: settings,
    rules: rules,
    importProfiles: importProfiles,
    dictionary: dictionary,
    goals: goals,
    assets: assets,
    debts: debts,
    importBatches: importBatches,
    uiState: stores['fm_ui_state']!,
    journal: recovery,
    debtSync: debtSync,
    ledger: ledger,
    clock: now,
    stores: stores.values.toList(),
  );
  // Antes de materializar: o retrato restaurado é o estado a que as recorrências se aplicam.
  if (await BackupService.recoverPendingImport(services)) {
    services.restoredFromJournal = true;
  }
  await materializeRecurring(services);
  return services;
}

/// SPEC §5.4: grava as ocorrências de recorrência de `materializedUntil + 1` até ontem
/// e avança `materializedUntil = ontem`. Idempotente; a ocorrência de hoje e as futuras
/// não são gravadas: entram na previsão via projeção.
Future<void> materializeRecurring(AppServices s) async {
  final today = dateOnly(s.clock());
  final yesterday = DateTime(today.year, today.month, today.day - 1);
  final existing = {for (final t in s.transactions.all) t.id};
  final created = <Transaction>[];
  final updated = <RecurringRule>[];
  for (final r in s.recurring.all) {
    final from = _firstPendingDay(r);
    if (from.isAfter(yesterday)) {
      continue;
    }
    // `to = hoje` só para a regra de status (tudo < hoje fica paid, exceto boleto);
    // o filtro tira a ocorrência de hoje, que não é gravada.
    created.addAll(
      occurrenceTransactions(
        r,
        from,
        today,
        existing,
        forProjection: false,
      ).where((t) => t.date.isBefore(today)),
    );
    updated.add(r.copyWith(materializedUntil: yesterday));
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
