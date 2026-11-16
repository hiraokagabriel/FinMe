import 'package:flutter/widgets.dart';

import '../core/services/collection_repository.dart';
import '../core/services/settings_controller.dart';
import '../features/accounts/domain/account.dart';
import '../features/cards/domain/payment_card.dart';
import '../features/categories/domain/transaction_category.dart';
import '../features/goals/domain/goal.dart';
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
    required this.ledger,
    this.clock = DateTime.now,
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
  final Ledger ledger;
  final DateTime Function() clock;
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
