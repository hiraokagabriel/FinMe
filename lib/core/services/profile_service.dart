import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../../features/transactions/data/transaction_model.dart';
import '../../features/categories/data/category_model.dart';
import '../../features/cards/data/card_model.dart';
import '../../features/accounts/data/account_model.dart';
import 'hive_init.dart';
import 'repository_locator.dart';

/// Gerencia perfis de dados isolados.
/// Cada perfil usa boxes Hive com sufixo: 'transactions_default', 'transactions_demo', etc.
/// Extensível: novos perfis apenas precisam de um id string único.
class ProfileService extends ChangeNotifier {
  ProfileService._();
  static final ProfileService instance = ProfileService._();

  static const _kActiveProfile = 'activeProfile';
  static const String profileDefault = 'default';
  static const String profileDemo    = 'demo';

  String _activeProfileId = profileDefault;
  String get activeProfileId => _activeProfileId;
  bool get isDemoActive => _activeProfileId == profileDemo;

  /// Lê o perfil ativo persistido e abre os boxes correspondentes.
  /// Chamado uma vez no boot, após HiveInit.init().
  Future<void> loadFromStorage() async {
    final box = Hive.box<String>(HiveInit.settingsBoxName);
    _activeProfileId = box.get(_kActiveProfile) ?? profileDefault;
    await _openBoxesForProfile(_activeProfileId);
    RepositoryLocator.instance.reinit(_activeProfileId);
  }

  /// Troca para [targetProfileId]. Fecha boxes do perfil atual, abre os novos,
  /// reinicializa o RepositoryLocator e notifica listeners.
  Future<void> switchTo(String targetProfileId) async {
    if (_activeProfileId == targetProfileId) return;

    // Persiste escolha
    final box = Hive.box<String>(HiveInit.settingsBoxName);
    await box.put(_kActiveProfile, targetProfileId);

    // Fecha boxes do perfil atual (exceto settings e preferences)
    await _closeProfileBoxes(_activeProfileId);

    _activeProfileId = targetProfileId;

    // Abre boxes do novo perfil
    await _openBoxesForProfile(targetProfileId);

    // Reinicializa repositórios apontando para os novos boxes
    RepositoryLocator.instance.reinit(targetProfileId);

    notifyListeners();
  }

  // ── Helpers ────────────────────────────────────────────────────────────────

  static String boxName(String base, String profileId) => '${base}_$profileId';

  Future<void> _openBoxesForProfile(String profileId) async {
    final tx = boxName(HiveInit.transactionsBoxName, profileId);
    final ca = boxName(HiveInit.categoriesBoxName, profileId);
    final cd = boxName(HiveInit.cardsBoxName, profileId);
    final go = boxName(HiveInit.goalsBoxName, profileId);
    final ac = boxName(HiveInit.accountsBoxName, profileId);
    final bu = boxName(HiveInit.budgetsBoxName, profileId);

    if (!Hive.isBoxOpen(tx)) await Hive.openBox<TransactionModel>(tx);
    if (!Hive.isBoxOpen(ca)) await Hive.openBox<CategoryModel>(ca);
    if (!Hive.isBoxOpen(cd)) await Hive.openBox<CardModel>(cd);
    if (!Hive.isBoxOpen(go)) await Hive.openBox(go);
    if (!Hive.isBoxOpen(ac)) await Hive.openBox<AccountModel>(ac);
    if (!Hive.isBoxOpen(bu)) await Hive.openBox(bu);
  }

  Future<void> _closeProfileBoxes(String profileId) async {
    final names = [
      boxName(HiveInit.transactionsBoxName, profileId),
      boxName(HiveInit.categoriesBoxName, profileId),
      boxName(HiveInit.cardsBoxName, profileId),
      boxName(HiveInit.goalsBoxName, profileId),
      boxName(HiveInit.accountsBoxName, profileId),
      boxName(HiveInit.budgetsBoxName, profileId),
    ];
    for (final name in names) {
      if (Hive.isBoxOpen(name)) await Hive.box(name).close();
    }
  }
}
