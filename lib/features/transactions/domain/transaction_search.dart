// Busca de transações (Dart puro). Contrato: docs/SPEC.md §5.17. Usa fuzzy.dart e parseMoney.

import '../../../core/utils/formatters.dart';
import '../../../core/utils/fuzzy.dart';
import '../../../core/utils/text_normalize.dart';
import 'transaction.dart';

final RegExp _digitStartRe = RegExp(r'^\d');

typedef _Folded = ({String text, List<String> words});

_Folded _fold(String raw) {
  final text = foldText(raw);
  return (text: text, words: foldedWords(text));
}

/// Índice de busca: dobra as descrições uma vez no construtor; [search] só compara.
class TransactionSearchIndex {
  /// [matchAmounts] false (valores ocultos) desliga o casamento por valor exato.
  TransactionSearchIndex(
    Iterable<Transaction> transactions, {
    this.matchAmounts = true,
  }) : _entries = [for (final t in transactions) _Indexed(t)];

  final bool matchAmounts;
  final List<_Indexed> _entries;

  /// Transações que casam com todos os tokens da query, do maior score ao menor.
  List<Transaction> search(String query, {int limit = 20}) {
    final q = foldText(query);
    if (q.length < 2) {
      return const [];
    }
    final tokens = q.split(' ').where((t) => t.isNotEmpty).toList();
    final cents = [
      for (final token in tokens) matchAmounts ? _valueCents(token) : null,
    ];
    final hits = <({Transaction transaction, int score})>[];
    for (final entry in _entries) {
      final score = entry.scoreOf(tokens, cents);
      if (score != null) {
        hits.add((transaction: entry.transaction, score: score));
      }
    }
    hits.sort((a, b) {
      if (a.score != b.score) {
        return b.score.compareTo(a.score);
      }
      final byDate = b.transaction.date.compareTo(a.transaction.date);
      if (byDate != 0) {
        return byDate;
      }
      return a.transaction.id.compareTo(b.transaction.id);
    });
    return [for (final hit in hits.take(limit)) hit.transaction];
  }
}

/// Token de valor ("23,15", "2315"): começa com dígito e é dinheiro válido. Devolve centavos absolutos.
int? _valueCents(String token) {
  if (!_digitStartRe.hasMatch(token)) {
    return null;
  }
  return parseMoney(token)?.abs();
}

class _Indexed {
  _Indexed(this.transaction)
    : texts = [
        _fold(transaction.description),
        if (transaction.importedDescription != null)
          _fold(transaction.importedDescription!),
      ];

  final Transaction transaction;
  final List<_Folded> texts;

  /// Soma dos scores dos tokens; null se algum token não casa.
  int? scoreOf(List<String> tokens, List<int?> cents) {
    var total = 0;
    for (var i = 0; i < tokens.length; i++) {
      final score = _tokenScore(tokens[i], cents[i]);
      if (score == null) {
        return null;
      }
      total += score;
    }
    return total;
  }

  /// Melhor score entre descrição, descrição importada e valor exato (4).
  int? _tokenScore(String token, int? tokenCents) {
    int? best;
    if (tokenCents != null && tokenCents == transaction.amountCents) {
      best = 4;
    }
    for (final text in texts) {
      final score = fuzzyTokenScore(token, text.text, text.words);
      if (score != null && (best == null || score > best)) {
        best = score;
      }
    }
    return best;
  }
}
