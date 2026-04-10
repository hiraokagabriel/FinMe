import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../../features/transactions/data/transaction_model.dart';
import '../../features/categories/data/category_model.dart';
import '../../features/cards/data/card_model.dart';
import '../../features/accounts/data/account_model.dart';
import 'hive_init.dart';
import 'repository_locator.dart';
import 'auth_service.dart';

class ProfileService extends ChangeNotifier {
  ProfileService._();
  static final ProfileService instance = ProfileService._();

  static const String profileDefault = 'default';
  static const String profileDemo    = 'demo';

  String _activeProfileId = profileDefault;
  String get activeProfileId => _activeProfileId;
  bool get isDemoActive => _activeProfileId == profileDemo;

  /// Monta o nome do box com namespace loginId + profileId.
  static String boxName(String base, String loginId, String profileId) =>
      '${base}_${loginId}_$profileId';

  /// Carregado após AuthService. Abre os boxes do perfil ativo e inicializa repositórios.
  Future<void> loadFromStorage() async {
    final loginId = AuthService.instance.activeLoginId!
        // fallback para usuários migrados sem login real
        ;
    final storedProfileId = AuthService.instance.activeProfileId ?? profileDefault;
    _activeProfileId = storedProfileId;
    await _openBoxesForProfile(loginId, storedProfileId);
    RepositoryLocator.instance.reinit(loginId, storedProfileId);
  }

  Future<void> switchTo(String loginId, String targetProfileId) async {
    if (_activeProfileId == targetProfileId) return;

    await _closeProfileBoxes(loginId, _activeProfileId);
    _activeProfileId = targetProfileId;
    await _openBoxesForProfile(loginId, targetProfileId);
    RepositoryLocator.instance.reinit(loginId, targetProfileId);
    notifyListeners();
  }

  Future<void> _openBoxesForProfile(String loginId, String profileId) async {
    final tx = boxName(HiveInit.transactionsBoxName, loginId, profileId);
    final ca = boxName(HiveInit.categoriesBoxName,   loginId, profileId);
    final cd = boxName(HiveInit.cardsBoxName,        loginId, profileId);
    final go = boxName(HiveInit.goalsBoxName,        loginId, profileId);
    final ac = boxName(HiveInit.accountsBoxName,     loginId, profileId);
    final bu = boxName(HiveInit.budgetsBoxName,      loginId, profileId);

    if (!Hive.isBoxOpen(tx)) await Hive.openBox<TransactionModel>(tx);
    if (!Hive.isBoxOpen(ca)) await Hive.openBox<CategoryModel>(ca);
    if (!Hive.isBoxOpen(cd)) await Hive.openBox<CardModel>(cd);
    if (!Hive.isBoxOpen(go)) await Hive.openBox(go);
    if (!Hive.isBoxOpen(ac)) await Hive.openBox<AccountModel>(ac);
    if (!Hive.isBoxOpen(bu)) await Hive.openBox(bu);
  }

  Future<void> _closeProfileBoxes(String loginId, String profileId) async {
    final tx = boxName(HiveInit.transactionsBoxName, loginId, profileId);
    final ca = boxName(HiveInit.categoriesBoxName,   loginId, profileId);
    final cd = boxName(HiveInit.cardsBoxName,        loginId, profileId);
    final go = boxName(HiveInit.goalsBoxName,        loginId, profileId);
    final ac = boxName(HiveInit.accountsBoxName,     loginId, profileId);
    final bu = boxName(HiveInit.budgetsBoxName,      loginId, profileId);

    if (Hive.isBoxOpen(tx)) await Hive.box<TransactionModel>(tx).close();
    if (Hive.isBoxOpen(ca)) await Hive.box<CategoryModel>(ca).close();
    if (Hive.isBoxOpen(cd)) await Hive.box<CardModel>(cd).close();
    if (Hive.isBoxOpen(go)) await Hive.box(go).close();
    if (Hive.isBoxOpen(ac)) await Hive.box<AccountModel>(ac).close();
    if (Hive.isBoxOpen(bu)) await Hive.box(bu).close();
  }
}
