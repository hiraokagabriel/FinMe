/// Linha lida de um extrato (CSV ou OFX), ainda sem conta/cartão atribuído.
class ImportedLine {
  const ImportedLine({
    required this.row,
    required this.date,
    required this.description,
    required this.amountCents,
    this.fitid,
    this.bankCategory,
  });

  /// 1-based: linha do arquivo (CSV) ou ordem do STMTTRN (OFX).
  final int row;

  /// dateOnly.
  final DateTime date;

  /// Trim, nunca vazia (vazia vira erro da linha).
  final String description;

  /// Com sinal: + entrada, − saída. Nunca 0.
  final int amountCents;

  /// OFX FITID.
  final String? fitid;

  /// Coluna de categoria do CSV (trim; vazia → null).
  final String? bankCategory;
}

class ImportLineError {
  const ImportLineError(this.row, this.message);

  final int row;
  final String message;
}

class ImportParseResult {
  const ImportParseResult(this.lines, this.errors);

  final List<ImportedLine> lines;
  final List<ImportLineError> errors;
}
