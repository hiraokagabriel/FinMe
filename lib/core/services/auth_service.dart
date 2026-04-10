import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:hive/hive.dart';

import '../../features/auth/data/login_model.dart';
import '../../features/auth/data/profile_model.dart';
import 'hive_init.dart';

class AuthService extends ChangeNotifier {
  AuthService._();
  static final AuthService instance = AuthService._();

  static const int maxProfilesPerLogin = 5;
  static const _kActiveLogin   = 'activeLogin';
  static const _kActiveProfile = 'activeProfile';

  String? _activeLoginId;
  String? _activeProfileId;

  String? get activeLoginId   => _activeLoginId;
  String? get activeProfileId => _activeProfileId;
  bool    get isAuthenticated => _activeLoginId != null;

  Box<LoginModel>   get _loginsBox   => Hive.box<LoginModel>(HiveInit.loginsBoxName);
  Box<ProfileModel> get _profilesBox => Hive.box<ProfileModel>(HiveInit.profilesBoxName);

  // ---------------------------------------------------------------------------
  // Boot
  // ---------------------------------------------------------------------------

  Future<void> loadFromStorage() async {
    final settings     = Hive.box<String>(HiveInit.settingsBoxName);
    final storedLogin  = settings.get(_kActiveLogin);
    final storedProfile = settings.get(_kActiveProfile);

    if (storedLogin != null && _loginsBox.containsKey(storedLogin)) {
      _activeLoginId   = storedLogin;
      _activeProfileId = storedProfile;
    }
  }

  // ---------------------------------------------------------------------------
  // Auth
  // ---------------------------------------------------------------------------

  Future<bool> register(String username, String password) async {
    final exists = _loginsBox.values.any(
      (l) => l.username.toLowerCase() == username.toLowerCase(),
    );
    if (exists) return false;

    final id = _newId();
    await _loginsBox.put(
      id,
      LoginModel(
        id:           id,
        username:     username,
        passwordHash: _hash(password),
        createdAt:    DateTime.now(),
      ),
    );
    await _createProfileInternal(loginId: id, name: 'Principal', avatarEmoji: '\uD83D\uDC64');
    return true;
  }

  Future<bool> login(String username, String password) async {
    final login = _loginsBox.values.where(
      (l) => l.username.toLowerCase() == username.toLowerCase(),
    ).firstOrNull;
    if (login == null) return false;

    final valid = login.passwordHash.isEmpty || login.passwordHash == _hash(password);
    if (!valid) return false;

    _activeLoginId = login.id;
    final profiles = profilesForLogin(login.id);
    _activeProfileId = profiles.isNotEmpty ? profiles.first.id : null;

    final settings = Hive.box<String>(HiveInit.settingsBoxName);
    await settings.put(_kActiveLogin, login.id);
    if (_activeProfileId != null) {
      await settings.put(_kActiveProfile, _activeProfileId!);
    }
    notifyListeners();
    return true;
  }

  Future<void> logout() async {
    _activeLoginId   = null;
    _activeProfileId = null;
    final settings = Hive.box<String>(HiveInit.settingsBoxName);
    await settings.delete(_kActiveLogin);
    await settings.delete(_kActiveProfile);
    notifyListeners();
  }

  // ---------------------------------------------------------------------------
  // Perfis
  // ---------------------------------------------------------------------------

  List<ProfileModel> profilesForLogin(String loginId) =>
      _profilesBox.values.where((p) => p.loginId == loginId).toList()
        ..sort((a, b) => a.createdAt.compareTo(b.createdAt));

  List<ProfileModel> get profilesForActiveLogin =>
      isAuthenticated ? profilesForLogin(_activeLoginId!) : [];

  Future<ProfileModel?> createProfile(String name, String avatarEmoji) async {
    if (!isAuthenticated) return null;
    if (profilesForActiveLogin.length >= maxProfilesPerLogin) return null;
    return _createProfileInternal(
      loginId:     _activeLoginId!,
      name:        name,
      avatarEmoji: avatarEmoji,
    );
  }

  Future<void> switchProfile(String profileId) async {
    if (_activeProfileId == profileId) return;
    _activeProfileId = profileId;
    final settings = Hive.box<String>(HiveInit.settingsBoxName);
    await settings.put(_kActiveProfile, profileId);
    notifyListeners();
  }

  Future<bool> deleteProfile(String profileId) async {
    if (!isAuthenticated) return false;
    final profiles = profilesForActiveLogin;
    if (profiles.length <= 1) return false;

    final key = _profilesBox.keys.firstWhere(
      (k) => _profilesBox.get(k)?.id == profileId,
      orElse: () => null,
    );
    if (key == null) return false;
    await _profilesBox.delete(key);

    if (_activeProfileId == profileId) {
      final remaining = profilesForActiveLogin;
      await switchProfile(remaining.first.id);
    }
    notifyListeners();
    return true;
  }

  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------

  static int _counter = 0;
  static String _newId() {
    final ts = DateTime.now().microsecondsSinceEpoch;
    _counter++;
    return '${ts}_$_counter';
  }

  static String _hash(String input) =>
      sha256.convert(utf8.encode(input)).toString();

  Future<ProfileModel> _createProfileInternal({
    required String loginId,
    required String name,
    required String avatarEmoji,
  }) async {
    final id = _newId();
    final model = ProfileModel(
      id:          id,
      loginId:     loginId,
      name:        name,
      avatarEmoji: avatarEmoji,
      createdAt:   DateTime.now(),
    );
    await _profilesBox.put('${loginId}_$id', model);
    return model;
  }
}
