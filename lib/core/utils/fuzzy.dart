// Busca aproximada sobre textos dobrados (Dart puro). Contrato: docs/SPEC.md §3.8.

import 'text_normalize.dart';

final RegExp _nonWordRe = RegExp(r'[^A-Z0-9]+');

/// Palavras de um texto JÁ dobrado por [foldText], sem vazios.
List<String> foldedWords(String folded) =>
    folded.split(_nonWordRe).where((w) => w.isNotEmpty).toList();

/// Score de um token contra um texto dobrado. Primeira regra que vale: prefixo do texto (4),
/// prefixo de palavra (3), contém (2), subsequência com 3+ caracteres (1); senão null.
int? fuzzyTokenScore(String token, String folded, List<String> words) {
  if (folded.startsWith(token)) {
    return 4;
  }
  for (final word in words) {
    if (word.startsWith(token)) {
      return 3;
    }
  }
  if (folded.contains(token)) {
    return 2;
  }
  if (token.length >= 3 && _isSubsequence(token, folded)) {
    return 1;
  }
  return null;
}

/// Soma dos scores dos tokens da query; qualquer token sem casamento anula o score (null).
/// Query sem tokens vale 0.
int? fuzzyScore(String query, String text) {
  final tokens = foldText(query).split(' ').where((t) => t.isNotEmpty).toList();
  if (tokens.isEmpty) {
    return 0;
  }
  final folded = foldText(text);
  final words = foldedWords(folded);
  var total = 0;
  for (final token in tokens) {
    final score = fuzzyTokenScore(token, folded, words);
    if (score == null) {
      return null;
    }
    total += score;
  }
  return total;
}

/// Ordena por score desc (empate mantém a ordem de entrada) e descarta itens sem casamento.
/// Score do item = maior [fuzzyScore] entre seus textos; item sem textos sai.
List<T> fuzzyRank<T>(
  Iterable<T> items,
  String query,
  Iterable<String> Function(T item) texts, {
  int? limit,
}) {
  final scored = <({int score, int index, T item})>[];
  var index = 0;
  for (final item in items) {
    int? best;
    for (final text in texts(item)) {
      final score = fuzzyScore(query, text);
      if (score != null && (best == null || score > best)) {
        best = score;
      }
    }
    if (best != null) {
      scored.add((score: best, index: index, item: item));
    }
    index++;
  }
  // shortcut: List.sort não garante estabilidade; o índice de entrada desempata.
  scored.sort(
    (a, b) => a.score != b.score
        ? b.score.compareTo(a.score)
        : a.index.compareTo(b.index),
  );
  final ranked = [for (final entry in scored) entry.item];
  return limit == null ? ranked : ranked.take(limit).toList();
}

bool _isSubsequence(String token, String text) {
  var i = 0;
  for (var c = 0; c < text.length && i < token.length; c++) {
    if (text.codeUnitAt(c) == token.codeUnitAt(i)) {
      i++;
    }
  }
  return i == token.length;
}
