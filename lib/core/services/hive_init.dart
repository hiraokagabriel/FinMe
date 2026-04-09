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
  static const String _profileMigratedKey = 'profileMigrationDone';

  static bool isOnboardingDone() {
    final box = Hive.box<String>(settingsBoxName);
    return box.get(_onboardingDoneKey) == 'true';
  }

  static Future<void> markOnboardingDone() async {
    final box = Hive.box<String>(settingsBoxName);
    await box.put(_onboardingDoneKey, 'true');
  }

  /// Registra adapters e abre apenas os boxes globais (settings, preferences).
  /// Na primeira execução após a migração para o sistema de perfis,
  /// deleta os boxes antigos sem sufixo para evitar conflitos de tipo no Hive.
  static Future<void> init() async {
    await Hive.initFlutter();

    if (!Hive.isAdapterRegistered(0)) Hive.registerAdapter(TransactionModelAdapter());
    if (!Hive.isAdapterRegistered(2)) Hive.registerAdapter(CategoryModelAdapter());
    if (!Hive.isAdapterRegistered(3)) Hive.registerAdapter(CardModelAdapter());
    if (!Hive.isAdapterRegistered(4)) Hive.registerAdapter(AccountModelAdapter());

    await Hive.openBox<String>(settingsBoxName);
    await Hive.openBox<String>(preferencesBoxName);

    await _migrateIfNeeded();
  }

  /// Executa uma única vez: deleta boxes legados (sem sufixo de perfil) do disco.
  /// Isso evita que o Hive tente reabrri-los com tipo errado e cause
  /// `HiveError: Box not found` ou conflitos de adapter.
  static Future<void> _migrateIfNeeded() async {
    final settings = Hive.box<String>(settingsBoxName);
    if (settings.get(_profileMigratedKey) == 'true') return;

    // Boxes legados sem sufixo — existiam antes do sistema de perfis.
    // Se estiverem abertos, fecha e deleta do disco.
    final legacyBoxes = [
      transactionsBoxName,
      categoriesBoxName,
      cardsBoxName,
      goalsBoxName,
      accountsBoxName,
      budgetsBoxName,
    ];

    for (final name in legacyBoxes) {
      try {
        // Abre sem tipo para garantir acesso mesmo se estava fechado
        if (!Hive.isBoxOpen(name)) {
          await Hive.openBox(name);
        }
        await Hive.box(name).deleteFromDisk();
      } catch (_) {
        // Box não existia — tudo bem
      }
    }

    await settings.put(_profileMigratedKey, 'true');
  }
}
