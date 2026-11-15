import '../../../core/utils/enum_utils.dart';

/// Sentinela de `copyWith`: parâmetro omitido mantém o campo; `null` limpa; valor troca.
const Object _keep = Object();

enum ImportFormat { csv, ofx }

/// dd/mm/aaaa, mm/dd/aaaa, aaaa-mm-dd (qualquer separador / . -).
enum DateOrder { dmy, mdy, ymd }

enum DecimalMark { comma, dot }

/// Data da linha de parcela: lançamento na fatura (posting) ou compra original (purchase).
enum InstallmentDateMode { posting, purchase }

/// Perfil salvo de importação (mapeamento CSV ou destino OFX), reaplicável com 1 clique.
class ImportProfile {
  const ImportProfile({
    required this.id,
    required this.name,
    this.format = ImportFormat.csv,
    this.accountId,
    this.cardId,
    this.delimiter = ';',
    this.skipRows = 1,
    this.dateColumn = 0,
    this.descriptionColumn = 1,
    this.amountColumn = 2,
    this.debitColumn,
    this.creditColumn,
    this.categoryColumn,
    this.dateOrder = DateOrder.dmy,
    this.decimalMark = DecimalMark.comma,
    this.invertSign = false,
    this.installmentDateMode = InstallmentDateMode.posting,
    this.categoryMap = const {},
  });

  /// Campos na ordem do `toMap`; `fromMap` tolera ausência de qualquer um.
  factory ImportProfile.fromMap(Map<String, dynamic> map) => ImportProfile(
    id: map['id'] as String,
    name: map['name'] as String,
    format: enumByName(ImportFormat.values, map['format']),
    accountId: map['accountId'] as String?,
    cardId: map['cardId'] as String?,
    delimiter: (map['delimiter'] as String?) ?? ';',
    skipRows: _intOr(map['skipRows'], 1),
    dateColumn: _intOr(map['dateColumn'], 0),
    descriptionColumn: _intOr(map['descriptionColumn'], 1),
    // Coluna nula é válida (modo débito/crédito): só a ausência usa o padrão.
    amountColumn: map.containsKey('amountColumn')
        ? _intOrNull(map['amountColumn'])
        : 2,
    debitColumn: _intOrNull(map['debitColumn']),
    creditColumn: _intOrNull(map['creditColumn']),
    categoryColumn: _intOrNull(map['categoryColumn']),
    dateOrder: enumByName(DateOrder.values, map['dateOrder']),
    decimalMark: enumByName(DecimalMark.values, map['decimalMark']),
    invertSign: map['invertSign'] == true,
    installmentDateMode: enumByName(
      InstallmentDateMode.values,
      map['installmentDateMode'],
    ),
    categoryMap: map['categoryMap'] is Map
        ? {
            for (final e in (map['categoryMap'] as Map).entries)
              e.key as String: e.value as String,
          }
        : const {},
  );

  static int _intOr(Object? v, int fallback) =>
      v == null ? fallback : (v as num).toInt();

  static int? _intOrNull(Object? v) => v == null ? null : (v as num).toInt();

  final String id;
  final String name;
  final ImportFormat format;

  /// Destino: exatamente um dos dois.
  final String? accountId;
  final String? cardId;

  /// 1 caractere: ';' ',' '\t' '|'.
  final String delimiter;

  /// Linhas antes dos dados (inclui o cabeçalho).
  final int skipRows;

  /// 0-based.
  final int dateColumn;
  final int descriptionColumn;

  /// Valor único com sinal, ou débito/crédito separados.
  final int? amountColumn;
  final int? debitColumn;
  final int? creditColumn;

  /// Opcional.
  final int? categoryColumn;

  final DateOrder dateOrder;
  final DecimalMark decimalMark;

  /// Fatura de cartão com compras positivas.
  final bool invertSign;
  final InstallmentDateMode installmentDateMode;

  /// foldText(categoria do banco) → categoryId (de-para).
  final Map<String, String> categoryMap;

  /// null = válido.
  String? get mappingError {
    if ((accountId != null) == (cardId != null)) {
      return 'Escolha a conta ou o cartão';
    }
    if (format == ImportFormat.ofx) {
      return null;
    }
    if ((amountColumn != null) ==
        (debitColumn != null || creditColumn != null)) {
      return 'Use valor único ou débito/crédito';
    }
    final columns = [
      dateColumn,
      descriptionColumn,
      amountColumn,
      debitColumn,
      creditColumn,
      categoryColumn,
    ].whereType<int>().toList();
    if (columns.any((c) => c < 0) || columns.toSet().length != columns.length) {
      return 'Colunas repetidas ou inválidas';
    }
    if (delimiter.length != 1) {
      return 'Separador inválido';
    }
    if (skipRows < 0) {
      return 'Linhas a pular inválidas';
    }
    return null;
  }

  /// Acrescenta só as chaves novas; mapeamentos já salvos prevalecem.
  ImportProfile learnBankCategories(Map<String, String> learned) =>
      copyWith(categoryMap: {...learned, ...categoryMap});

  ImportProfile copyWith({
    String? name,
    ImportFormat? format,
    Object? accountId = _keep,
    Object? cardId = _keep,
    String? delimiter,
    int? skipRows,
    int? dateColumn,
    int? descriptionColumn,
    Object? amountColumn = _keep,
    Object? debitColumn = _keep,
    Object? creditColumn = _keep,
    Object? categoryColumn = _keep,
    DateOrder? dateOrder,
    DecimalMark? decimalMark,
    bool? invertSign,
    InstallmentDateMode? installmentDateMode,
    Map<String, String>? categoryMap,
  }) => ImportProfile(
    id: id,
    name: name ?? this.name,
    format: format ?? this.format,
    accountId: identical(accountId, _keep)
        ? this.accountId
        : accountId as String?,
    cardId: identical(cardId, _keep) ? this.cardId : cardId as String?,
    delimiter: delimiter ?? this.delimiter,
    skipRows: skipRows ?? this.skipRows,
    dateColumn: dateColumn ?? this.dateColumn,
    descriptionColumn: descriptionColumn ?? this.descriptionColumn,
    amountColumn: identical(amountColumn, _keep)
        ? this.amountColumn
        : amountColumn as int?,
    debitColumn: identical(debitColumn, _keep)
        ? this.debitColumn
        : debitColumn as int?,
    creditColumn: identical(creditColumn, _keep)
        ? this.creditColumn
        : creditColumn as int?,
    categoryColumn: identical(categoryColumn, _keep)
        ? this.categoryColumn
        : categoryColumn as int?,
    dateOrder: dateOrder ?? this.dateOrder,
    decimalMark: decimalMark ?? this.decimalMark,
    invertSign: invertSign ?? this.invertSign,
    installmentDateMode: installmentDateMode ?? this.installmentDateMode,
    categoryMap: categoryMap ?? this.categoryMap,
  );

  Map<String, dynamic> toMap() => {
    'id': id,
    'name': name,
    'format': format.name,
    'accountId': accountId,
    'cardId': cardId,
    'delimiter': delimiter,
    'skipRows': skipRows,
    'dateColumn': dateColumn,
    'descriptionColumn': descriptionColumn,
    'amountColumn': amountColumn,
    'debitColumn': debitColumn,
    'creditColumn': creditColumn,
    'categoryColumn': categoryColumn,
    'dateOrder': dateOrder.name,
    'decimalMark': decimalMark.name,
    'invertSign': invertSign,
    'installmentDateMode': installmentDateMode.name,
    'categoryMap': categoryMap,
  };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ImportProfile &&
          other.id == id &&
          other.name == name &&
          other.format == format &&
          other.accountId == accountId &&
          other.cardId == cardId &&
          other.delimiter == delimiter &&
          other.skipRows == skipRows &&
          other.dateColumn == dateColumn &&
          other.descriptionColumn == descriptionColumn &&
          other.amountColumn == amountColumn &&
          other.debitColumn == debitColumn &&
          other.creditColumn == creditColumn &&
          other.categoryColumn == categoryColumn &&
          other.dateOrder == dateOrder &&
          other.decimalMark == decimalMark &&
          other.invertSign == invertSign &&
          other.installmentDateMode == installmentDateMode &&
          _sameMap(other.categoryMap, categoryMap);

  @override
  int get hashCode => Object.hash(
    id,
    name,
    format,
    accountId,
    cardId,
    delimiter,
    skipRows,
    dateColumn,
    descriptionColumn,
    amountColumn,
    debitColumn,
    creditColumn,
    categoryColumn,
    dateOrder,
    decimalMark,
    invertSign,
    installmentDateMode,
  );

  static bool _sameMap(Map<String, String> a, Map<String, String> b) =>
      a.length == b.length && a.entries.every((e) => b[e.key] == e.value);
}
