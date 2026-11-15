// Parser OFX (SGML 1.x sem tags de fechamento e XML 2.x). Contrato: docs/SPEC.md §5.11.
import '../../../core/utils/text_normalize.dart';
import 'imported_line.dart';

class OfxStatement {
  const OfxStatement({
    required this.isCreditCard,
    this.accountId,
    required this.result,
  });

  /// Existe `<CCSTMTRS>` (fatura de cartão).
  final bool isCreditCard;
  final String? accountId;
  final ImportParseResult result;
}

final RegExp _ofxRootRe = RegExp('<OFX>', caseSensitive: false);
final RegExp _ccRe = RegExp('<CCSTMTRS>', caseSensitive: false);
final RegExp _stmtRe = RegExp('<STMTTRN>', caseSensitive: false);
final RegExp _blockEndRe = RegExp(
  '</STMTTRN>|</BANKTRANLIST>',
  caseSensitive: false,
);
final RegExp _tagRe = RegExp('<([A-Za-z0-9]+)>([^<]*)');
final RegExp _entityRe = RegExp('&(amp|lt|gt|quot|apos);');
final RegExp _dateRe = RegExp(r'^(\d{4})(\d{2})(\d{2})');
final RegExp _wholeRe = RegExp(r'^\d+$');
final RegExp _groupedRe = RegExp(r'^\d{1,3}([.,]\d{3})+$');
final RegExp _fractionRe = RegExp(r'^\d{1,2}$');
final RegExp _separatorRe = RegExp(r'[.,]');

const Map<String, String> _entities = {
  'amp': '&',
  'lt': '<',
  'gt': '>',
  'quot': '"',
  'apos': "'",
};

/// Lança [FormatException] se não houver `<OFX>`. Erros de linha vão para `result.errors`.
OfxStatement parseOfx(String text) {
  if (!_ofxRootRe.hasMatch(text)) {
    throw const FormatException('Arquivo OFX inválido');
  }
  final starts = _stmtRe.allMatches(text).toList();
  final lines = <ImportedLine>[];
  final errors = <ImportLineError>[];
  for (var i = 0; i < starts.length; i++) {
    final row = i + 1;
    final from = starts[i].end;
    final to = i + 1 < starts.length ? starts[i + 1].start : text.length;
    final chunk = text.substring(from, to);
    final stop = _blockEndRe.firstMatch(chunk);
    final tags = _tags(stop == null ? chunk : chunk.substring(0, stop.start));

    final date = _parseDate(tags['DTPOSTED']);
    if (date == null) {
      errors.add(ImportLineError(row, 'Data inválida'));
      continue;
    }
    final amount = _parseAmount(tags['TRNAMT']);
    if (amount == null) {
      errors.add(ImportLineError(row, 'Valor inválido'));
      continue;
    }
    if (amount == 0) {
      errors.add(ImportLineError(row, 'Valor zero'));
      continue;
    }
    final description = _description(tags['NAME'], tags['MEMO']);
    if (description == null) {
      errors.add(ImportLineError(row, 'Descrição vazia'));
      continue;
    }
    lines.add(
      ImportedLine(
        row: row,
        date: date,
        description: description,
        amountCents: amount,
        fitid: tags['FITID'],
      ),
    );
  }
  return OfxStatement(
    isCreditCard: _ccRe.hasMatch(text),
    accountId: _tags(text)['ACCTID'],
    result: ImportParseResult(lines, errors),
  );
}

/// Primeira ocorrência de cada tag, em maiúsculas; valor vazio some (= ausente).
Map<String, String> _tags(String s) {
  final tags = <String, String>{};
  for (final m in _tagRe.allMatches(s)) {
    final value = _decode(m[2]!.trim());
    if (value.isNotEmpty) {
      tags.putIfAbsent(m[1]!.toUpperCase(), () => value);
    }
  }
  return tags;
}

String _decode(String s) =>
    s.replaceAllMapped(_entityRe, (m) => _entities[m[1]]!);

/// Primeiros 8 dígitos `yyyyMMdd`; hora e fuso são ignorados.
DateTime? _parseDate(String? raw) {
  final m = raw == null ? null : _dateRe.firstMatch(raw);
  if (m == null) {
    return null;
  }
  final year = int.parse(m[1]!);
  final month = int.parse(m[2]!);
  final day = int.parse(m[3]!);
  final date = DateTime(year, month, day);
  // DateTime rola datas inválidas (30/02 → 02/03); a checagem rejeita esses casos.
  return date.month == month && date.day == day ? date : null;
}

/// Centavos com sinal. O último `.`/`,` é o decimal; sem ele, só dígitos.
int? _parseAmount(String? raw) {
  if (raw == null) {
    return null;
  }
  final negative = raw.startsWith('-');
  final body = negative || raw.startsWith('+') ? raw.substring(1) : raw;
  final lastDot = body.lastIndexOf('.');
  final lastComma = body.lastIndexOf(',');
  final String intPart;
  var fraction = '';
  if (lastDot < 0 && lastComma < 0) {
    intPart = body;
  } else {
    final at = lastDot > lastComma ? lastDot : lastComma;
    intPart = body.substring(0, at);
    fraction = body.substring(at + 1);
    if (!_fractionRe.hasMatch(fraction)) {
      return null;
    }
  }
  if (!_wholeRe.hasMatch(intPart) && !_groupedRe.hasMatch(intPart)) {
    return null;
  }
  final whole = int.parse(intPart.replaceAll(_separatorRe, ''));
  final cents = int.parse(fraction.padRight(2, '0'));
  final total = whole * 100 + cents;
  return negative ? -total : total;
}

/// NAME e MEMO não vazios: se um contém o outro (após foldText), vale o mais longo; senão "NAME MEMO".
String? _description(String? name, String? memo) {
  if (name == null) {
    return memo;
  }
  if (memo == null) {
    return name;
  }
  final foldedName = foldText(name);
  final foldedMemo = foldText(memo);
  if (foldedName.contains(foldedMemo)) {
    return name;
  }
  if (foldedMemo.contains(foldedName)) {
    return memo;
  }
  return '$name $memo';
}
