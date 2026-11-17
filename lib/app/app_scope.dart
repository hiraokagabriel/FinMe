import 'package:flutter/widgets.dart';

import '../core/services/collection_repository.dart';
import '../core/services/record_store.dart';
import '../core/services/recovery_journal.dart';
import '../core/services/settings_controller.dart';
import '../features/accounts/domain/account.dart';
import '../features/cards/domain/payment_card.dart';
import '../features/categories/domain/transaction_category.dart';
import '../features/debts/domain/debt.dart';
import '../features/debts/presentation/debt_transaction_sync.dart';
import '../features/goals/domain/goal.dart';
import '../features/net_worth/domain/asset.dart';
import '../features/importing/domain/import_batch.dart';
import '../features/importing/domain/import_profile.dart';
import '../features/importing/domain/merchant_dictionary.dart';
import '../features/recurring/domain/recurring_rule.dart';
import '../features/rules/domain/transaction_rule.dart';
import '../features/transactions/domain/transaction.dart';
import 'ledger.dart';

/// Dependências globais do app. `clock` é injetável para testes.
class AppServices {
  AppServices({
    required this.accounts,
    required this.cards,
    required this.categories,
    required this.transactions,
    required this.recurring,
    required this.settings,
    required this.rules,
    required this.importProfiles,
    required this.dictionary,
    required this.goals,
    required this.assets,
    required this.debts,
    required this.importBatches,
    required this.uiState,
    required this.journal,
    required this.debtSync,
    required this.ledger,
    this.clock = DateTime.now,
    this.stores = const [],
  });

  final CollectionRepository<Account> accounts;
  final CollectionRepository<PaymentCard> cards;
  final CollectionRepository<TransactionCategory> categories;
  final CollectionRepository<Transaction> transactions;
  final CollectionRepository<RecurringRule> recurring;
  final SettingsController settings;
  final CollectionRepository<TransactionRule> rules;
  final CollectionRepository<ImportProfile> importProfiles;
  final CollectionRepository<DictionaryEntry> dictionary;
  final CollectionRepository<Goal> goals;
  final CollectionRepository<Asset> assets;
  final CollectionRepository<Debt> debts;
  final CollectionRepository<ImportBatch> importBatches;

  /// Estado de tela: fora do backup e do "Apagar todos os dados".
  final RecordStore uiState;
  final RecoveryJournal journal;
  final DebtTransactionSync debtSync;
  final Ledger ledger;
  final DateTime Function() clock;

  /// Stores abertos pelo bootstrap; fechados em [close] ao trocar de perfil.
  final List<RecordStore> stores;

  /// Encerra o perfil: para o `Ledger` e fecha os boxes Hive. Os serviços não podem ser usados depois.
  Future<void> close() async {
    ledger.dispose();
    for (final store in stores) {
      if (store is HiveRecordStore) {
        await store.close();
      }
    }
  }

  /// true quando o boot restaurou um import de backup interrompido (SnackBar única).
  bool restoredFromJournal = false;
}

/// Expõe [AppServices] à árvore. Os serviços são estáveis: não notifica dependentes.
class AppScope extends InheritedWidget {
  const AppScope({super.key, required this.services, required super.child});

  final AppServices services;

  static AppServices of(BuildContext context) {
    final scope = context.getInheritedWidgetOfExactType<AppScope>();
    if (scope == null) {
      throw StateError('AppScope ausente acima deste widget');
    }
    return scope.services;
  }

  @override
  bool updateShouldNotify(AppScope oldWidget) => false;
}
