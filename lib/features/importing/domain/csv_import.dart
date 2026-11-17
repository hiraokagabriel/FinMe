import 'dart:convert';
import 'dart:math';

import 'package:csv/csv.dart';

import 'import_profile.dart';
import 'imported_line.dart';

final RegExp _intDigits = RegExp(r'^\d+$');
final RegExp _fracDigits = RegExp(r'^\d*$');
final RegExp _spaces = RegExp('[\\s ]');

/// UTF-8 com BOM ou sem; bytes inválidos em UTF-8 viram Latin-1 (extratos de bancos antigos).
String decodeText(List<int> bytes) {
  final body =
      bytes.length >= 3 &&
          bytes[0] == 0xEF &&
          bytes[1] == 0xBB &&
          bytes[2] == 0xBF
      ? bytes.sublist(3)
      : bytes;
  try {
    return utf8.decode(body, allowMalformed: false);
  } on FormatException {
    return latin1.decode(body);
  }
}

/// Delimitador pelas 5 primeiras linhas não vazias, ignorando o que está entre aspas.
/// Empate ou nenhum candidato → ';'.
String guessDelimiter(String text) {
  const candidates = [';', ',', '\t', '|'];
  final counts = {for (final c in candidates) c: 0};
  final lines = text.split('\n').where((l) => l.trim().isNotEmpty).take(5);
  for (final line in lines) {
    var quoted = false;
    for (final ch in line.split('')) {
      if (ch == '"') {
        quoted = !quoted;
      } else if (!quoted && counts.containsKey(ch)) {
        counts[ch] = counts[ch]! + 1;
      }
    }
  }
  final best = counts.values.fold(0, max);
  if (best == 0) {
    return ';';
  }
  final top = candidates.where((c) => counts[c] == best).toList();
  return top.length == 1 ? top.single : ';';
}

/// Linhas como células já com trim; linhas vazias do fim são removidas.
List<List<String>> readCsv(String text, {required String delimiter}) {
  final normalized = text.replaceAll('\r\n', '\n').replaceAll('\r', '\n');
  final raw = CsvToListConverter(
    fieldDelimiter: delimiter,
    eol: '\n',
    shouldParseNumbers: false,
  ).convert(normalized);
  final rows = [
    for (final row in raw) [for (final cell in row) '${cell ?? ''}'.trim()],
  ];
  while (rows.isNotEmpty && rows.last.every((c) => c.isEmpty)) {
    rows.removeLast();
  }
  return rows;
}

/// Centavos com sinal. Sem `double`: a fração é tratada como texto.
int? parseAmountCell(String raw, DecimalMark mark) {
  var s = raw.toUpperCase().replaceAll('R\$', '').replaceAll(_spaces, '');
  var negative = false;
  if (s.endsWith('D')) {
    negative = true;
    s = s.substring(0, s.length - 1);
  } else if (s.endsWith('C')) {
    s = s.substring(0, s.length - 1);
  }
  if (s.startsWith('(') && s.endsWith(')')) {
    negative = true;
    s = s.substring(1, s.length - 1);
  }
  if (s.startsWith('-')) {
    negative = true;
    s = s.substring(1);
  }
  if (s.endsWith('-')) {
    negative = true;
    s = s.substring(0, s.length - 1);
  }
  final unit = mark == DecimalMark.comma
      ? s.replaceAll('.', '').replaceAll(',', '.')
      : s.replaceAll(',', '');
  final parts = unit.split('.');
  // Fração com mais de 2 dígitos é inválida (não arredonda: "12,345" → null).
  if (parts.length > 2 ||
      !_intDigits.hasMatch(parts[0]) ||
      parts[0].length > 12 ||
      (parts.length == 2 &&
          (!_fracDigits.hasMatch(parts[1]) || parts[1].length > 2))) {
    return null;
  }
  final frac = parts.length == 2 ? parts[1].padRight(2, '0') : '00';
  final cents = int.parse(parts[0]) * 100 + int.parse(frac);
  return negative ? -cents : cents;
}

/// 1º token (antes de espaço ou `T`); ano com 2 dígitos → 2000+aa. Data inexistente → null.
DateTime? parseDateCell(String raw, DateOrder order) {
  final token = raw.trim().split(RegExp(r'[\sT]')).first;
  final parts = token.split(RegExp(r'[/.\-]'));
  if (parts.length != 3 ||
      parts.any((p) => p.length > 4 || !_intDigits.hasMatch(p))) {
    return null;
  }
  final (y, m, d) = switch (order) {
    DateOrder.dmy => (parts[2], parts[1], parts[0]),
    DateOrder.mdy => (parts[2], parts[0], parts[1]),
    DateOrder.ymd => (parts[0], parts[1], parts[2]),
  };
  if (y.length != 2 && y.length != 4) {
    return null;
  }
  final year = int.parse(y) + (y.length == 2 ? 2000 : 0);
  final month = int.parse(m);
  final day = int.parse(d);
  final date = DateTime(year, month, day);
  return date.year == year && date.month == month && date.day == day
      ? date
      : null;
}

/// Pula `skipRows` linhas; erro de uma linha não interrompe as outras.
ImportParseResult parseCsvLines(
  List<List<String>> rows,
  ImportProfile profile,
) {
  final lines = <ImportedLine>[];
  final errors = <ImportLineError>[];
  for (var i = max(profile.skipRows, 0); i < rows.length; i++) {
    final row = i + 1;
    final (line, error) = _csvLine(row, rows[i], profile);
    if (line != null) {
      lines.add(line);
    } else {
      errors.add(ImportLineError(row, error!));
    }
  }
  return ImportParseResult(lines, errors);
}

(ImportedLine?, String?) _csvLine(
  int row,
  List<String> cells,
  ImportProfile p,
) {
  final used = [
    p.dateColumn,
    p.descriptionColumn,
    p.amountColumn,
    p.debitColumn,
    p.creditColumn,
    p.categoryColumn,
  ].whereType<int>();
  if (used.any((c) => c >= cells.length)) {
    return (null, 'Coluna ausente');
  }
  final date = parseDateCell(cells[p.dateColumn], p.dateOrder);
  if (date == null) {
    return (null, 'Data inválida');
  }
  final description = cells[p.descriptionColumn].trim();
  if (description.isEmpty) {
    return (null, 'Descrição vazia');
  }
  final amount = _amountOf(cells, p);
  if (amount == null) {
    return (null, 'Valor inválido');
  }
  final signed = p.invertSign ? -amount : amount;
  if (signed == 0) {
    return (null, 'Valor zero');
  }
  final categoryColumn = p.categoryColumn;
  final category = categoryColumn == null ? null : cells[categoryColumn].trim();
  return (
    ImportedLine(
      row: row,
      date: date,
      description: description,
      amountCents: signed,
      bankCategory: category == null || category.isEmpty ? null : category,
    ),
    null,
  );
}

/// Valor único com sinal, ou débito (−) e crédito (+) separados. Ambos preenchidos → crédito − débito.
int? _amountOf(List<String> cells, ImportProfile p) {
  final amountColumn = p.amountColumn;
  if (amountColumn != null) {
    return parseAmountCell(cells[amountColumn], p.decimalMark);
  }
  final debitColumn = p.debitColumn;
  final creditColumn = p.creditColumn;
  final debit = debitColumn == null
      ? null
      : parseAmountCell(cells[debitColumn], p.decimalMark)?.abs();
  final credit = creditColumn == null
      ? null
      : parseAmountCell(cells[creditColumn], p.decimalMark)?.abs();
  if (debit == null && credit == null) {
    return null;
  }
  return (credit ?? 0) - (debit ?? 0);
}
