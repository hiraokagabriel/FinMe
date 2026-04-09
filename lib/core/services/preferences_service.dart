import 'package:hive/hive.dart';

/// Singleton que persiste preferências do usuário no box Hive 'preferences'.
/// Usa apenas tipos primitivos — sem adapter customizado.
///
/// Camada 1 — Configurações do usuário:
///   currency, dateFormat, language (reservado)
///
/// Camada 2 — Preferências de UI/filtros:
///   transactionsPeriod, transactionsCategoryId,
///   reportsPeriod
class PreferencesService {
  PreferencesService._();
  static final PreferencesService instance = PreferencesService._();

  static const String _boxName = 'preferences';

  // ─── Chaves ───────────────────────────────────────────────────────
  static const _kCurrency             = 'currency';
  static const _kDateFormat           = 'dateFormat';
  static const _kLanguage             = 'language';
  static const _kTransactionsPeriod   = 'txPeriod';
  static const _kTransactionsCatId    = 'txCategoryId';
  static const _kReportsPeriod        = 'reportsPeriod';

  Box<String> get _box => Hive.box<String>(_boxName);

  // ─── Camada 1 — Configurações ─────────────────────────────────────

  String get currency => _box.get(_kCurrency, defaultValue: 'BRL')!;
  Future<void> setCurrency(String value) => _box.put(_kCurrency, value);

  String get dateFormat => _box.get(_kDateFormat, defaultValue: 'dd/MM/yyyy')!;
  Future<void> setDateFormat(String value) => _box.put(_kDateFormat, value);

  /// Reservado para M4/M5 — salva mas não aplica ainda.
  String get language => _box.get(_kLanguage, defaultValue: 'pt')!;
  Future<void> setLanguage(String value) => _box.put(_kLanguage, value);

  // ─── Camada 2 — Preferências de UI ───────────────────────────────

  String get transactionsPeriod =>
      _box.get(_kTransactionsPeriod, defaultValue: 'thisMonth')!;
  Future<void> setTransactionsPeriod(String value) =>
      _box.put(_kTransactionsPeriod, value);

  /// Retorna null quando nenhuma categoria está selecionada.
  String? get transactionsCategoryId =>
      _box.get(_kTransactionsCatId);
  Future<void> setTransactionsCategoryId(String? value) async {
    if (value == null) {
      await _box.delete(_kTransactionsCatId);
    } else {
      await _box.put(_kTransactionsCatId, value);
    }
  }

  String get reportsPeriod =>
      _box.get(_kReportsPeriod, defaultValue: 'thisMonth')!;
  Future<void> setReportsPeriod(String value) =>
      _box.put(_kReportsPeriod, value);
}
