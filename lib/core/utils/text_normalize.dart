// Normalização de descrições bancárias (Dart puro). Contrato: docs/SPEC.md §3.7.

const Map<String, String> _accentMap = {
  'Á': 'A',
  'À': 'A',
  'Â': 'A',
  'Ã': 'A',
  'Ä': 'A',
  'É': 'E',
  'È': 'E',
  'Ê': 'E',
  'Ë': 'E',
  'Í': 'I',
  'Ì': 'I',
  'Î': 'I',
  'Ï': 'I',
  'Ó': 'O',
  'Ò': 'O',
  'Ô': 'O',
  'Õ': 'O',
  'Ö': 'O',
  'Ú': 'U',
  'Ù': 'U',
  'Û': 'U',
  'Ü': 'U',
  'Ç': 'C',
  'Ñ': 'N',
};
final RegExp _accentRe = RegExp('[${_accentMap.keys.join()}]');
final RegExp _spacesRe = RegExp('[\\s ]+');
final RegExp _dateRe = RegExp(r'\b\d{1,2}[/.-]\d{1,2}([/.-]\d{2,4})?\b');
final RegExp _ofRe = RegExp(r'\b\d{1,2}\s+DE\s+\d{1,2}\b');
final RegExp _nonKeyRe = RegExp(r'[^A-Z0-9 ]');
final RegExp _digitRe = RegExp(r'\d');

const Set<String> _parcelaTokens = {'PARC', 'PARCELA', 'PARCELADO'};

const Set<String> kStopTokens = {
  'PARC',
  'PARCELA',
  'PARCELADO',
  'COMPRA',
  'PAG',
  'PAGTO',
  'PGTO',
  'PAGAMENTO',
  'DEBITO',
  'CREDITO',
  'CARTAO',
  'LTDA',
  'EIRELI',
  'ME',
  'SA',
  'DE',
  'DA',
  'DO',
  'DOS',
  'DAS',
  'COM',
  'EM',
  'BR',
};

const Set<String> kUfTokens = {
  'AC',
  'AL',
  'AP',
  'AM',
  'BA',
  'CE',
  'DF',
  'ES',
  'GO',
  'MA',
  'MT',
  'MS',
  'MG',
  'PA',
  'PB',
  'PR',
  'PE',
  'PI',
  'RJ',
  'RN',
  'RS',
  'RO',
  'RR',
  'SC',
  'SP',
  'SE',
  'TO',
  'BR',
  'BRA',
  'BRASIL',
};

const List<String> kCitySuffixes = [
  'SAO PAULO',
  'RIO DE JANEIRO',
  'BELO HORIZONTE',
  'BRASILIA',
  'SALVADOR',
  'FORTALEZA',
  'CURITIBA',
  'RECIFE',
  'PORTO ALEGRE',
  'MANAUS',
  'BELEM',
  'GOIANIA',
  'CAMPINAS',
  'FLORIANOPOLIS',
  'VITORIA',
  'NATAL',
  'JOAO PESSOA',
  'OSASCO',
  'SANTOS',
  'GUARULHOS',
];

final List<List<String>> _citySuffixWords = [
  for (final c in kCitySuffixes) c.split(' '),
];

/// Maiúsculas, sem acento, espaços colapsados e trim. Pontuação é mantida.
String foldText(String s) => s
    .toUpperCase()
    .replaceAllMapped(_accentRe, (m) => _accentMap[m[0]]!)
    .replaceAll(_spacesRe, ' ')
    .trim();

/// Chave de histórico/dedupe: remove datas, códigos e cidade/UF finais.
String normalizeDescription(String s) {
  final cleaned = foldText(
    s,
  ).replaceAll(_dateRe, ' ').replaceAll(_ofRe, ' ').replaceAll(_nonKeyRe, ' ');
  final words = [
    for (final w in cleaned.split(' '))
      if (w.isNotEmpty && !_digitRe.hasMatch(w) && !_parcelaTokens.contains(w))
        w,
  ];
  // shortcut: sufixo de cidade é lista fixa de 20 capitais/cidades, sem casamento fuzzy.
  for (var pass = 0; pass < 3; pass++) {
    while (words.length > 1 && kUfTokens.contains(words.last)) {
      words.removeLast();
    }
    for (final suffix in _citySuffixWords) {
      if (words.length > suffix.length && _endsWithWords(words, suffix)) {
        words.removeRange(words.length - suffix.length, words.length);
        break;
      }
    }
  }
  return words.join(' ');
}

bool _endsWithWords(List<String> words, List<String> suffix) {
  final start = words.length - suffix.length;
  for (var i = 0; i < suffix.length; i++) {
    if (words[start + i] != suffix[i]) {
      return false;
    }
  }
  return true;
}

/// Tokens de comparação: sem tokens de 1 caractere nem stop tokens.
Set<String> descriptionTokens(String normalized) => {
  for (final w in normalized.split(' '))
    if (w.length >= 2 && !kStopTokens.contains(w)) w,
};

/// Índice de Jaccard |a∩b| / |a∪b|; conjuntos vazios dão 0.0.
double jaccard(Set<String> a, Set<String> b) {
  final union = a.union(b).length;
  if (union == 0) {
    return 0.0;
  }
  return a.intersection(b).length / union;
}

/// Duas descrições são a mesma compra? Igualdade de chave, contenção de tokens inteiros (menor com ≥ 4 chars)
/// ou Jaccard ≥ 0.5 (≥ 0.67 quando a união tem 4+ tokens: evita "PIX FULANO" × "PIX CICLANO").
bool similarDescriptions(String a, String b) {
  final ka = normalizeDescription(a);
  final kb = normalizeDescription(b);
  if (ka.isNotEmpty && ka == kb) {
    return true;
  }
  final (short, long) = ka.length <= kb.length ? (ka, kb) : (kb, ka);
  if (short.length >= 4 && ' $long '.contains(' $short ')) {
    return true;
  }
  final ta = descriptionTokens(ka);
  final tb = descriptionTokens(kb);
  final minJaccard = ta.union(tb).length >= 4 ? 0.67 : 0.5;
  return jaccard(ta, tb) >= minJaccard;
}
