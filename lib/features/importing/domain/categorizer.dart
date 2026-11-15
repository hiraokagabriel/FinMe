// Categorização em cascata de lançamentos importados. Contrato: docs/SPEC.md §5.13.

import '../../../core/utils/text_normalize.dart';
import '../../categories/domain/transaction_category.dart';
import '../../rules/domain/rule_engine.dart';
import '../../rules/domain/transaction_rule.dart';
import 'category_history.dart';
import 'merchant_dictionary.dart';

/// Passo da cascata que deu a sugestão.
enum SuggestionSource { rule, bank, history, dictionary }

/// Sugestão de categoria. Sem categoria: `categoryId` e `source` null, `confidence` 0;
/// `renamedDescription` pode vir mesmo assim (regra que só renomeia).
class CategorizationResult {
  const CategorizationResult({
    this.categoryId,
    this.source,
    this.confidence = 0,
    this.ruleId,
    this.renamedDescription,
  });

  final String? categoryId;
  final SuggestionSource? source;

  /// 0..1.
  final double confidence;

  /// Regra que deu a categoria.
  final String? ruleId;

  /// `renameTo` da 1ª regra ativa que casa com `renameTo` não vazio.
  final String? renamedDescription;

  static const none = CategorizationResult();
}

/// Rótulo de confiança: >= 0.8 'alta', >= 0.5 'média', senão 'baixa'.
String confidenceLabel(double c) {
  if (c >= 0.8) {
    return 'alta';
  }
  if (c >= 0.5) {
    return 'média';
  }
  return 'baixa';
}

String? _nonBlank(String? s) => s == null || s.trim().isEmpty ? null : s;

/// Entrada do dicionário com categoria resolvida; `pattern` já em foldText.
class _DictRule {
  const _DictRule(this.pattern, this.categoryId, this.kind);

  final String pattern;
  final String categoryId;
  final CategoryKind kind;
}

/// Entradas com categoria resolvida, pattern mais longo primeiro; empate: ordem da lista.
List<_DictRule> _resolveDictionary(
  Iterable<DictionaryEntry> entries,
  List<TransactionCategory> categories,
  Map<String, CategoryKind> kindById,
) {
  final resolved = <(int, _DictRule)>[];
  for (final (i, e) in entries.indexed) {
    final id = resolveCategoryByName(e.categoryName, categories);
    final kind = id == null ? null : kindById[id];
    if (id != null && kind != null) {
      resolved.add((i, _DictRule(foldText(e.pattern), id, kind)));
    }
  }
  resolved.sort((a, b) {
    final byLength = b.$2.pattern.length.compareTo(a.$2.pattern.length);
    return byLength != 0 ? byLength : a.$1.compareTo(b.$1);
  });
  return [for (final r in resolved) r.$2];
}

/// Cascata: regras, banco, histórico, dicionário. Só sugere categoria do tipo do lançamento.
class Categorizer {
  factory Categorizer({
    required Iterable<TransactionRule> rules,
    required Iterable<TransactionCategory> categories,
    required CategoryHistory history,
    required Iterable<DictionaryEntry> dictionary,
  }) {
    final cats = List<TransactionCategory>.of(categories);
    final kindById = {for (final c in cats) c.id: c.kind};
    return Categorizer._(
      compileRules(rules),
      cats,
      kindById,
      history,
      _resolveDictionary(dictionary, cats, kindById),
    );
  }

  Categorizer._(
    this._rules,
    this._categories,
    this._kindById,
    this._history,
    this._dictionary,
  );

  final List<CompiledRule> _rules;
  final List<TransactionCategory> _categories;
  final Map<String, CategoryKind> _kindById;
  final CategoryHistory _history;
  final List<_DictRule> _dictionary;

  CategorizationResult categorize(
    String description, {
    required bool isIncome,
    String? bankCategory,
    Map<String, String> bankCategoryMap = const {},
  }) {
    final kind = isIncome ? CategoryKind.income : CategoryKind.expense;
    // Categoria permitida: existe e é do mesmo tipo do lançamento.
    String? permitted(String? id) =>
        id != null && _kindById[id] == kind ? id : null;

    // 1. Regras: categoria da 1ª permitida; renomeio da 1ª com renameTo (independe da categoria).
    String? renamed;
    String? ruleCat;
    String? ruleId;
    for (final c in _rules) {
      if (!c.matches(description)) {
        continue;
      }
      renamed ??= _nonBlank(c.rule.renameTo);
      if (ruleCat == null) {
        final id = permitted(c.rule.categoryId);
        if (id != null) {
          ruleCat = id;
          ruleId = c.rule.id;
        }
      }
      if (ruleCat != null && renamed != null) {
        break;
      }
    }

    CategorizationResult hit(
      String id,
      SuggestionSource source,
      double confidence, {
      String? byRule,
    }) => CategorizationResult(
      categoryId: id,
      source: source,
      confidence: confidence,
      ruleId: byRule,
      renamedDescription: renamed,
    );

    if (ruleCat != null) {
      return hit(ruleCat, SuggestionSource.rule, 1.0, byRule: ruleId);
    }

    // 2. Banco: mapa da coluna de categoria, senão nome igual/fallback.
    if (bankCategory != null) {
      final mapped = permitted(bankCategoryMap[foldText(bankCategory)]);
      if (mapped != null) {
        return hit(mapped, SuggestionSource.bank, 0.9);
      }
      final byName = permitted(
        resolveCategoryByName(bankCategory, _categories),
      );
      if (byName != null) {
        return hit(byName, SuggestionSource.bank, 0.7);
      }
    }

    // 3. Histórico: exato; se não há chave exata, a parecida. Sugestão não permitida é ignorada.
    final key = normalizeDescription(description);
    if (key.isNotEmpty) {
      final exact = _history.exact(key);
      if (exact != null) {
        final id = permitted(exact.categoryId);
        if (id != null) {
          return hit(id, SuggestionSource.history, 0.5 + 0.4 * exact.share);
        }
      } else {
        final similar = _history.similar(key);
        final id = permitted(similar?.categoryId);
        if (similar != null && id != null) {
          return hit(id, SuggestionSource.history, 0.6 * similar.score);
        }
      }
    }

    // 4. Dicionário: o padrão mais longo que casa e tem categoria permitida.
    final folded = foldText(description);
    for (final d in _dictionary) {
      if (d.kind == kind && dictionaryPatternMatches(d.pattern, folded)) {
        return hit(d.categoryId, SuggestionSource.dictionary, 0.5);
      }
    }

    // 5. Nada.
    return CategorizationResult(renamedDescription: renamed);
  }
}
