import 'package:flutter/foundation.dart';
import 'package:hive/hive.dart';

/// Controlador global do tema (claro vs escuro).
/// Persiste a escolha no Hive (box 'settings', chave 'app_theme').
class ThemeController extends ChangeNotifier {
  ThemeController._();

  static final ThemeController instance = ThemeController._();

  static const String _boxName  = 'settings';
  static const String _themeKey = 'app_theme';
  static const String _dark     = 'dark';
  static const String _light    = 'light';

  bool _isDark = false;

  bool get isDark => _isDark;

  /// Chama uma vez em main() após HiveInit.init().
  Future<void> loadFromStorage() async {
    final box = await Hive.openBox<String>(_boxName);
    _isDark = box.get(_themeKey) == _dark;
    notifyListeners();
  }

  void setDark(bool value) {
    if (value == _isDark) return;
    _isDark = value;
    _persist();
    notifyListeners();
  }

  void toggle() => setDark(!_isDark);

  Future<void> _persist() async {
    final box = await Hive.openBox<String>(_boxName);
    await box.put(_themeKey, _isDark ? _dark : _light);
  }
}
