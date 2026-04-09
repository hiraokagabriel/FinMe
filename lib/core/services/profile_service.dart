import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../../features/transactions/data/transaction_model.dart';
import '../../features/categories/data/category_model.dart';
import '../../features/cards/data/card_model.dart';
import '../../features/accounts/data/account_model.dart';
import 'hive_init.dart';
import 'repository_locator.dart';

class ProfileService extends ChangeNotifier {
  ProfileService._();
  static final ProfileService instance = ProfileService._();

  static const _kActiveProfile = 'activeProfile';
  static const String profileDefault = 'default';
  static const String profileDemo    = 'demo';

  String _activeProfileId = profileDefault;
  String get activeProfileId => _activeProfileId;
  bool get isDemoActive => _activeProfileId == profileDemo;

  Future<void> loadFromStorage() async {
    final box = Hive.box<String>(HiveInit.settingsBoxName);
    _activeProfileId = box.get(_kActiveProfile) ?? profileDefault;
    await _openBoxesForProfile(_activeProfileId);
    RepositoryLocator.instance.reinit(_activeProfileId);
  }

  Future<void> switchTo(String targetProfileId) async {
    if (_activeProfileId == targetProfileId) return;

    final box = Hive.box<String>(HiveInit.settingsBoxName);
    await box.put(_kActiveProfile, targetProfileId);

    await _closeProfileBoxes(_activeProfileId);

    _activeProfileId = targetProfileId;

    await _openBoxesForProfile(targetProfileId);
    RepositoryLocator.instance.reinit(targetProfileId);

    notifyListeners();
  }

  static String boxName(String base, String profileId) => '${base}_$profileId';

  Future<void> _openBoxesForProfile(String profileId) async {
    final tx = boxName(HiveInit.transactionsBoxName, profileId);
    final ca = boxName(HiveInit.categoriesBoxName,   profileId);
    final cd = boxName(HiveInit.cardsBoxName,        profileId);
    final go = boxName(HiveInit.goalsBoxName,        profileId);
    final ac = boxName(HiveInit.accountsBoxName,     profileId);
    final bu = boxName(HiveInit.budgetsBoxName,      profileId);

    if (!Hive.isBoxOpen(tx)) await Hive.openBox<TransactionModel>(tx);
    if (!Hive.isBoxOpen(ca)) await Hive.openBox<CategoryModel>(ca);
    if (!Hive.isBoxOpen(cd)) await Hive.openBox<CardModel>(cd);
    if (!Hive.isBoxOpen(go)) await Hive.openBox(go);
    if (!Hive.isBoxOpen(ac)) await Hive.openBox<AccountModel>(ac);
    if (!Hive.isBoxOpen(bu)) await Hive.openBox(bu);
  }

  Future<void> _closeProfileBoxes(String profileId) async {
    // Fecha cada box usando o mesmo tipo genérico com que foi aberto.
    // Hive rejeita acesso sem tipo a boxes tipados.
    final tx = boxName(HiveInit.transactionsBoxName, profileId);
    final ca = boxName(HiveInit.categoriesBoxName,   profileId);
    final cd = boxName(HiveInit.cardsBoxName,        profileId);
    final go = boxName(HiveInit.goalsBoxName,        profileId);
    final ac = boxName(HiveInit.accountsBoxName,     profileId);
    final bu = boxName(HiveInit.budgetsBoxName,      profileId);

    if (Hive.isBoxOpen(tx)) await Hive.box<TransactionModel>(tx).close();
    if (Hive.isBoxOpen(ca)) await Hive.box<CategoryModel>(ca).close();
    if (Hive.isBoxOpen(cd)) await Hive.box<CardModel>(cd).close();
    if (Hive.isBoxOpen(go)) await Hive.box(go).close();
    if (Hive.isBoxOpen(ac)) await Hive.box<AccountModel>(ac).close();
    if (Hive.isBoxOpen(bu)) await Hive.box(bu).close();
  }
}
