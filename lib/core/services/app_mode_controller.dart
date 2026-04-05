import 'package:flutter/foundation.dart';
import 'package:hive/hive.dart';

import '../models/app_mode.dart';

/// Controlador global do modo do app (simples vs ultra).
/// Persiste a escolha no Hive (box 'settings', chave 'app_mode').
class AppModeController extends ChangeNotifier {
  AppModeController._();

  static final AppModeController instance = AppModeController._();

  static const String _boxName = 'settings';
  static const String _modeKey = 'app_mode';

  AppMode _mode = AppMode.simple;

  AppMode get mode => _mode;

  /// Chama uma vez em main() apos HiveInit.init().
  Future<void> loadFromStorage() async {
    final box = await Hive.openBox<String>(_boxName);
    final stored = box.get(_modeKey);
    if (stored == AppMode.ultra.name) {
      _mode = AppMode.ultra;
    } else {
      _mode = AppMode.simple;
    }
    notifyListeners();
  }

  void setMode(AppMode newMode) {
    if (newMode == _mode) return;
    _mode = newMode;
    _persist();
    notifyListeners();
  }

  void toggle() {
    setMode(_mode == AppMode.simple ? AppMode.ultra : AppMode.simple);
  }

  Future<void> _persist() async {
    final box = await Hive.openBox<String>(_boxName);
    await box.put(_modeKey, _mode.name);
  }
}
