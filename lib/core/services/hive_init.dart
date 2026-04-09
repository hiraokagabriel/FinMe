import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../../features/transactions/data/transaction_model.dart';
import '../../features/categories/data/category_model.dart';
import '../../features/cards/data/card_model.dart';
import '../../features/accounts/data/account_model.dart';

class HiveInit {
  static const String transactionsBoxName = 'transactions';
  static const String categoriesBoxName   = 'categories';
  static const String cardsBoxName        = 'cards';
  static const String goalsBoxName        = 'goals';
  static const String settingsBoxName     = 'settings';
  static const String accountsBoxName     = 'accounts';
  static const String preferencesBoxName  = 'preferences';
  static const String budgetsBoxName      = 'budgets';

  static const String _onboardingDoneKey  = 'onboardingDone';

  static bool isOnboardingDone() {
    final box = Hive.box<String>(settingsBoxName);
    return box.get(_onboardingDoneKey) == 'true';
  }

  static Future<void> markOnboardingDone() async {
    final box = Hive.box<String>(settingsBoxName);
    await box.put(_onboardingDoneKey, 'true');
  }

  /// Registra adapters e abre apenas os boxes globais (settings, preferences).
  /// Os boxes de dados são abertos por ProfileService com sufixo de perfil.
  static Future<void> init() async {
    await Hive.initFlutter();

    if (!Hive.isAdapterRegistered(0)) Hive.registerAdapter(TransactionModelAdapter());
    if (!Hive.isAdapterRegistered(2)) Hive.registerAdapter(CategoryModelAdapter());
    if (!Hive.isAdapterRegistered(3)) Hive.registerAdapter(CardModelAdapter());
    if (!Hive.isAdapterRegistered(4)) Hive.registerAdapter(AccountModelAdapter());

    await Hive.openBox<String>(settingsBoxName);
    await Hive.openBox<String>(preferencesBoxName);

    // Seed padrão removido — feito pelo ProfileService no primeiro boot do perfil 'default'
  }
}
