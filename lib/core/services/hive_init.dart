import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../../features/transactions/data/transaction_model.dart';
import '../../features/categories/data/category_model.dart';
import '../../features/cards/data/card_model.dart';
import '../../features/accounts/data/account_model.dart';
import '../../features/auth/data/login_model.dart';
import '../../features/auth/data/profile_model.dart';

class HiveInit {
  static const String transactionsBoxName = 'transactions';
  static const String categoriesBoxName   = 'categories';
  static const String cardsBoxName        = 'cards';
  static const String goalsBoxName        = 'goals';
  static const String settingsBoxName     = 'settings';
  static const String accountsBoxName     = 'accounts';
  static const String preferencesBoxName  = 'preferences';
  static const String budgetsBoxName      = 'budgets';
  static const String loginsBoxName       = 'logins';
  static const String profilesBoxName     = 'profiles';

  static const String _onboardingDoneKey      = 'onboardingDone';
  static const String _profileMigratedKey     = 'profileMigrationDone';
  static const String _loginMigratedKey       = 'loginMigrationDone';
  static const String _billPaymentCleanedKey  = 'billPaymentOrphansCleaned';

  static const String defaultLoginId = 'local_default';

  static bool isOnboardingDone() {
    final box = Hive.box<String>(settingsBoxName);
    return box.get(_onboardingDoneKey) == 'true';
  }

  static Future<void> markOnboardingDone() async {
    final box = Hive.box<String>(settingsBoxName);
    await box.put(_onboardingDoneKey, 'true');
  }

  static Future<void> init() async {
    await Hive.initFlutter();

    if (!Hive.isAdapterRegistered(0)) Hive.registerAdapter(TransactionModelAdapter());
    if (!Hive.isAdapterRegistered(2)) Hive.registerAdapter(CategoryModelAdapter());
    if (!Hive.isAdapterRegistered(3)) Hive.registerAdapter(CardModelAdapter());
    if (!Hive.isAdapterRegistered(4)) Hive.registerAdapter(AccountModelAdapter());
    if (!Hive.isAdapterRegistered(7)) Hive.registerAdapter(LoginModelAdapter());
    if (!Hive.isAdapterRegistered(8)) Hive.registerAdapter(ProfileModelAdapter());

    await Hive.openBox<String>(settingsBoxName);
    await Hive.openBox<String>(preferencesBoxName);
    await Hive.openBox<LoginModel>(loginsBoxName);
    await Hive.openBox<ProfileModel>(profilesBoxName);

    await _migrateProfilesIfNeeded();
    await _migrateLoginNamespaceIfNeeded();
  }

  /// Deve ser chamado após os boxes de transações do perfil ativo serem abertos.
  /// Remove transações órfãs criadas pela versão antiga de markAsPaid (cardBill).
  static Future<void> cleanBillPaymentOrphans(String txBoxName) async {
    final settings = Hive.box<String>(settingsBoxName);
    if (settings.get(_billPaymentCleanedKey) == 'true') return;

    if (!Hive.isBoxOpen(txBoxName)) return;
    final box = Hive.box<TransactionModel>(txBoxName);

    final orphanKeys = box.keys.where((k) {
      final tx = box.get(k);
      if (tx == null) return false;
      // Padrão antigo: expense, cardId não nulo, sem recurrenceSourceId,
      // descrição começa com 'Fatura ', isBillPayment == false (campo antigo ausente).
      return tx.cardId != null &&
          tx.recurrenceSourceId == null &&
          !tx.isBillPayment &&
          (tx.description?.startsWith('Fatura ') ?? false);
    }).toList();

    for (final k in orphanKeys) {
      await box.delete(k);
    }

    await settings.put(_billPaymentCleanedKey, 'true');
  }

  static Future<void> _migrateProfilesIfNeeded() async {
    final settings = Hive.box<String>(settingsBoxName);
    if (settings.get(_profileMigratedKey) == 'true') return;

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
        if (!Hive.isBoxOpen(name)) await Hive.openBox(name);
        await Hive.box(name).deleteFromDisk();
      } catch (_) {}
    }

    await settings.put(_profileMigratedKey, 'true');
  }

  static Future<void> _migrateLoginNamespaceIfNeeded() async {
    final settings = Hive.box<String>(settingsBoxName);
    if (settings.get(_loginMigratedKey) == 'true') return;

    final loginsBox   = Hive.box<LoginModel>(loginsBoxName);
    final profilesBox = Hive.box<ProfileModel>(profilesBoxName);

    if (!loginsBox.containsKey(defaultLoginId)) {
      loginsBox.put(
        defaultLoginId,
        LoginModel(
          id:           defaultLoginId,
          username:     'local_default',
          passwordHash: '',
          createdAt:    DateTime.now(),
        ),
      );
    }

    const legacyProfiles = ['default', 'demo'];
    final dataBoxBases = [
      transactionsBoxName,
      categoriesBoxName,
      cardsBoxName,
      goalsBoxName,
      accountsBoxName,
      budgetsBoxName,
    ];

    for (final oldProfileId in legacyProfiles) {
      bool hasData = false;
      for (final base in dataBoxBases) {
        final oldName = '${base}_$oldProfileId';
        try {
          if (!Hive.isBoxOpen(oldName)) await Hive.openBox(oldName);
          if (Hive.box(oldName).isNotEmpty) { hasData = true; }
        } catch (_) {}
      }
      if (!hasData && oldProfileId != 'default') continue;

      final newProfileId = oldProfileId;

      final existingProfile = profilesBox.values
          .where((p) => p.loginId == defaultLoginId && p.id == newProfileId)
          .isEmpty;
      if (existingProfile) {
        profilesBox.put(
          '${defaultLoginId}_$newProfileId',
          ProfileModel(
            id:          newProfileId,
            loginId:     defaultLoginId,
            name:        oldProfileId == 'default' ? 'Principal' : 'Demo',
            avatarEmoji: oldProfileId == 'default' ? '👤' : '🧪',
            createdAt:   DateTime.now(),
          ),
        );
      }

      for (final base in dataBoxBases) {
        final oldName = '${base}_$oldProfileId';
        final newName = '${base}_${defaultLoginId}_$newProfileId';
        try {
          if (!Hive.isBoxOpen(oldName)) await Hive.openBox(oldName);
          final oldBox = Hive.box(oldName);
          if (oldBox.isEmpty) continue;

          if (!Hive.isBoxOpen(newName)) await Hive.openBox(newName);
          final newBox = Hive.box(newName);

          for (final key in oldBox.keys) {
            await newBox.put(key, oldBox.get(key));
          }
          await oldBox.deleteFromDisk();
        } catch (_) {}
      }
    }

    await settings.put(_loginMigratedKey, 'true');
  }
}
