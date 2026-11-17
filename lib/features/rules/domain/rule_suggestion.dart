// Padrão de regra sugerido a partir da seleção (Dart puro). Contrato: docs/SPEC.md §5.19.

import '../../../core/utils/text_normalize.dart';

final RegExp _digitRe = RegExp(r'\d');
final RegExp _alnumRe = RegExp('[A-Z0-9]');
final RegExp _alnumEndRe = RegExp(r'[A-Z0-9]+$');
final RegExp _nonAlnumEndRe = RegExp(r'[^A-Z0-9]+$');
const Set<String> _cutTokens = {'PARC', 'PARCELA', 'PARCELADO'};

/// Padrão `contains` comum a todos os [subjects] (`ruleSubject` das transações selecionadas).
/// Vazio quando não há prefixo útil em comum.
String suggestRulePattern(Iterable<String> subjects) {
  final keys = [for (final s in subjects) _keyOf(s)];
  if (keys.isEmpty) {
    return '';
  }
  var prefix = keys.first;
  for (final k in keys.skip(1)) {
    prefix = _commonPrefix(prefix, k);
  }
  // Corte no meio de palavra (ex.: 'PADARIA PAO' x 'PADARIA PAOLO') descarta a última palavra.
  final cutsWord =
      prefix.isNotEmpty &&
      _alnumRe.hasMatch(prefix[prefix.length - 1]) &&
      keys.any(
        (k) => k.length > prefix.length && _alnumRe.hasMatch(k[prefix.length]),
      );
  if (cutsWord) {
    prefix = prefix.replaceFirst(_alnumEndRe, '');
  }
  return prefix.replaceFirst(_nonAlnumEndRe, '');
}

/// Tokens até o primeiro com dígito ou marcador de parcela; sem tokens úteis, a descrição inteira.
String _keyOf(String subject) {
  final folded = foldText(subject);
  final kept = <String>[];
  for (final token in folded.split(' ')) {
    if (_digitRe.hasMatch(token) || _cutTokens.contains(token)) {
      break;
    }
    kept.add(token);
  }
  return kept.isEmpty ? folded : kept.join(' ');
}

String _commonPrefix(String a, String b) {
  var i = 0;
  while (i < a.length && i < b.length && a[i] == b[i]) {
    i++;
  }
  return a.substring(0, i);
}
