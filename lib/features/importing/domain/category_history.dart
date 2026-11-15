// Histórico de categorias por descrição normalizada. Contrato: docs/SPEC.md §5.13.

import '../../../core/utils/text_normalize.dart';
import '../../transactions/domain/transaction.dart';

/// Tokens presentes em mais chaves que isso não geram candidatos (ruído: "LOJA", "COMPRA").
const int _maxTokenKeys = 500;

/// Teto de candidatos avaliados por `similar`, tokens mais raros primeiro (custo limitado).
const int _maxCandidates = 300;

class _KeyStats {
  final Map<String, int> counts = {};
  final Map<String, DateTime> latest = {};
  int total = 0;

  void add(String categoryId, DateTime date) {
    counts[categoryId] = (counts[categoryId] ?? 0) + 1;
    final prev = latest[categoryId];
    if (prev == null || date.isAfter(prev)) {
      latest[categoryId] = date;
    }
    total++;
  }
}

/// Qual categoria de uma chave vence: mais frequente, depois a mais recente, depois id asc.
bool _beats(_KeyStats s, String a, String b) {
  final ca = s.counts[a]!;
  final cb = s.counts[b]!;
  if (ca != cb) {
    return ca > cb;
  }
  final da = s.latest[a]!;
  final db = s.latest[b]!;
  if (da != db) {
    return da.isAfter(db);
  }
  return a.compareTo(b) < 0;
}

/// Índice de categorias passadas por descrição. Chaves já vêm de `normalizeDescription`.
class CategoryHistory {
  const CategoryHistory._(this._stats, this._index, this._tokens);

  /// Só despesas/receitas com categoria; assunto = `importedDescription ?? description`.
  factory CategoryHistory.build(Iterable<Transaction> transactions) {
    final stats = <String, _KeyStats>{};
    for (final t in transactions) {
      final categoryId = t.categoryId;
      final isCategorizable =
          t.type == TransactionType.expense || t.type == TransactionType.income;
      if (categoryId == null || !isCategorizable) {
        continue;
      }
      final key = normalizeDescription(t.importedDescription ?? t.description);
      if (key.isEmpty) {
        continue;
      }
      stats.putIfAbsent(key, _KeyStats.new).add(categoryId, t.date);
    }
    final index = <String, List<String>>{};
    final tokens = <String, Set<String>>{};
    for (final key in stats.keys) {
      final keyTokens = descriptionTokens(key);
      tokens[key] = keyTokens;
      for (final token in keyTokens) {
        (index[token] ??= []).add(key);
      }
    }
    return CategoryHistory._(stats, index, tokens);
  }

  final Map<String, _KeyStats> _stats;
  final Map<String, List<String>> _index;
  final Map<String, Set<String>> _tokens;

  static const CategoryHistory empty = CategoryHistory._({}, {}, {});

  /// Categoria mais frequente da chave e sua fatia (`share`); chave ausente → null.
  ({String categoryId, double share})? exact(String key) {
    final s = _stats[key];
    if (s == null) {
      return null;
    }
    String? best;
    for (final id in s.counts.keys) {
      if (best == null || _beats(s, id, best)) {
        best = id;
      }
    }
    return (categoryId: best!, share: s.counts[best]! / s.total);
  }

  /// Melhor chave parecida (Jaccard de tokens >= `threshold`) e a categoria dela; sem candidato → null.
  ({String categoryId, double score})? similar(
    String key, {
    double threshold = 0.5,
  }) {
    final queryTokens = descriptionTokens(key);
    // Tokens usados como gatilho: os que existem no histórico e não são ruído; raros primeiro.
    final triggers =
        <String>[
          for (final token in queryTokens)
            if (_index[token] case final keys?
                when keys.length <= _maxTokenKeys)
              token,
        ]..sort((a, b) {
          final byRarity = _index[a]!.length.compareTo(_index[b]!.length);
          return byRarity != 0 ? byRarity : a.compareTo(b);
        });

    final candidates = <String>{};
    for (final token in triggers) {
      for (final candidate in _index[token]!) {
        if (candidates.length >= _maxCandidates) {
          break;
        }
        candidates.add(candidate);
      }
      if (candidates.length >= _maxCandidates) {
        break;
      }
    }

    String? bestKey;
    var bestScore = 0.0;
    for (final candidate in candidates) {
      final score = jaccard(queryTokens, _tokens[candidate]!);
      if (score < threshold) {
        continue;
      }
      if (bestKey == null ||
          _beatsMatch(candidate, score, bestKey, bestScore)) {
        bestKey = candidate;
        bestScore = score;
      }
    }
    if (bestKey == null) {
      return null;
    }
    return (categoryId: exact(bestKey)!.categoryId, score: bestScore);
  }

  /// Melhor score vence; empate → mais ocorrências totais; depois texto da chave menor.
  bool _beatsMatch(String a, double scoreA, String b, double scoreB) {
    if (scoreA != scoreB) {
      return scoreA > scoreB;
    }
    final ta = _stats[a]!.total;
    final tb = _stats[b]!.total;
    if (ta != tb) {
      return ta > tb;
    }
    return a.compareTo(b) < 0;
  }
}
