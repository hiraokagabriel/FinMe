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

  static const String _onboardingDoneKey    = 'onboardingDone';
  static const String _profileMigratedKey   = 'profileMigrationDone';
  static const String _loginMigratedKey     = 'loginMigrationDone';

  // Login padrão criado na migração para usuários sem senha
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

  // Migração 1 (existente): deleta boxes legados sem sufixo de perfil.
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

  // Migração 2: promove boxes {base}_{profileId} → {base}_{loginId}_{profileId}.
  // Cria o login padrão (sem senha) e os ProfileModel correspondentes
  // para usuários que tinham dados antes da feature de auth.
  static Future<void> _migrateLoginNamespaceIfNeeded() async {
    final settings = Hive.box<String>(settingsBoxName);
    if (settings.get(_loginMigratedKey) == 'true') return;

    final loginsBox   = Hive.box<LoginModel>(loginsBoxName);
    final profilesBox = Hive.box<ProfileModel>(profilesBoxName);

    // Garante que o login padrão exista
    if (!loginsBox.containsKey(defaultLoginId)) {
      loginsBox.put(
        defaultLoginId,
        LoginModel(
          id:           defaultLoginId,
          username:     'local_default',
          passwordHash: '', // sem senha
          createdAt:    DateTime.now(),
        ),
      );
    }

    // Perfis que existiam no sistema antigo
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
      final oldNamespace = '${dataBoxBases[0]}_$oldProfileId';

      // Verifica se algum box antigo existe antes de migrar
      bool hasData = false;
      for (final base in dataBoxBases) {
        final oldName = '${base}_$oldProfileId';
        try {
          if (!Hive.isBoxOpen(oldName)) await Hive.openBox(oldName);
          if (Hive.box(oldName).isNotEmpty) { hasData = true; }
        } catch (_) {}
      }
      // Ignora perfil vazio (ex: demo nunca usado)
      if (!hasData && oldProfileId != 'default') continue;

      final newProfileId = oldProfileId;
      final newNamespace = '${defaultLoginId}_$newProfileId';

      // Cria ProfileModel se ainda não existir
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

      // Copia dados de {base}_{oldProfileId} → {base}_{newNamespace}
      for (final base in dataBoxBases) {
        final oldName = '${base}_$oldProfileId';
        final newName = '${base}_$newNamespace';
        try {
          if (!Hive.isBoxOpen(oldName)) await Hive.openBox(oldName);
          final oldBox = Hive.box(oldName);
          if (oldBox.isEmpty) continue;

          if (!Hive.isBoxOpen(newName)) await Hive.openBox(newName);
          final newBox = Hive.box(newName);

          // Copia chave a chave para preservar tipos
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
