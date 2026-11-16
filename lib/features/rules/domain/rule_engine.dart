import '../../../core/utils/text_normalize.dart';
import '../../categories/domain/transaction_category.dart';
import '../../transactions/domain/tags.dart';
import '../../transactions/domain/transaction.dart';
import 'transaction_rule.dart';

/// Assunto da regra: a descrição do arquivo, para que renomear não apague o que casa.
String ruleSubject(Transaction t) => t.importedDescription ?? t.description;

/// Padrão vazio nunca é válido; regex precisa compilar.
bool isValidRulePattern(String pattern, RuleMatchType type) {
  if (pattern.trim().isEmpty) {
    return false;
  }
  if (type != RuleMatchType.regex) {
    return true;
  }
  try {
    RegExp(pattern, caseSensitive: false);
    return true;
  } on FormatException {
    return false;
  }
}

/// Regra pronta para casar. Regex inválida compila para `null` e nunca casa.
class CompiledRule {
  CompiledRule(this.rule)
    : _needle = foldText(rule.pattern),
      _regex =
          rule.matchType == RuleMatchType.regex &&
              isValidRulePattern(rule.pattern, rule.matchType)
          ? RegExp(rule.pattern, caseSensitive: false)
          : null;

  final TransactionRule rule;
  final String _needle;
  final RegExp? _regex;

  /// Não checa `active`: "testar padrão" usa regras inativas.
  bool matches(String description) => switch (rule.matchType) {
    RuleMatchType.regex => _regex?.hasMatch(description) ?? false,
    RuleMatchType.contains =>
      _needle.isNotEmpty && foldText(description).contains(_needle),
    RuleMatchType.startsWith =>
      _needle.isNotEmpty && foldText(description).startsWith(_needle),
  };
}

/// Só regras ativas, por `priority` asc e empate por `id` asc.
List<CompiledRule> compileRules(Iterable<TransactionRule> rules) {
  final active = rules.where((r) => r.active).toList()
    ..sort(
      (a, b) => a.priority != b.priority
          ? a.priority.compareTo(b.priority)
          : a.id.compareTo(b.id),
    );
  return [for (final r in active) CompiledRule(r)];
}

/// Prioridade passa a ser o índice na lista (0..n-1).
List<TransactionRule> reorderRules(List<TransactionRule> ordered) => [
  for (final (i, r) in ordered.indexed) r.copyWith(priority: i),
];

bool _isRuleTarget(Transaction t) =>
    t.type == TransactionType.expense || t.type == TransactionType.income;

/// Transações de despesa/receita cujo assunto casa com [rule], na ordem de entrada.
List<Transaction> matchingTransactions(
  TransactionRule rule,
  Iterable<Transaction> txs,
) {
  final compiled = CompiledRule(rule);
  return [
    for (final t in txs)
      if (_isRuleTarget(t) && compiled.matches(ruleSubject(t))) t,
  ];
}

/// Aplica as regras e devolve só as transações alteradas (cópias).
/// Categoria: 1ª regra que casa com categoria existente de kind compatível.
/// Renomeia: 1ª regra que casa com `renameTo` não vazio; guarda a descrição original em `importedDescription`.
/// Tags: acrescenta as tags de todas as regras que casam (nunca remove).
List<Transaction> reapplyRules(
  List<CompiledRule> compiled,
  Iterable<Transaction> txs, {
  required Map<String, TransactionCategory> categoriesById,
  bool overwriteCategory = false,
}) {
  final changed = <Transaction>[];
  for (final t in txs) {
    if (!_isRuleTarget(t)) {
      continue;
    }
    final subject = ruleSubject(t);
    final kind = t.type == TransactionType.expense
        ? CategoryKind.expense
        : CategoryKind.income;
    String? categoryId;
    String? renameTo;
    final ruleTags = <String>[];
    for (final c in compiled) {
      if (!c.matches(subject)) {
        continue;
      }
      final catId = c.rule.categoryId;
      final cat = catId == null ? null : categoriesById[catId];
      categoryId ??= cat != null && cat.kind == kind ? catId : null;
      final name = c.rule.renameTo;
      if (renameTo == null && name != null && name.trim().isNotEmpty) {
        renameTo = name;
      }
      ruleTags.addAll(c.rule.tags);
    }
    var out = t;
    if (categoryId != null &&
        (t.categoryId == null || overwriteCategory) &&
        categoryId != t.categoryId) {
      out = out.copyWith(categoryId: categoryId);
    }
    if (renameTo != null && t.description != renameTo) {
      out = out.copyWith(
        description: renameTo,
        importedDescription: t.importedDescription ?? t.description,
      );
    }
    if (ruleTags.isNotEmpty) {
      final merged = normalizeTags([...t.tags, ...ruleTags]);
      if (merged.length > t.tags.length) {
        out = out.copyWith(tags: merged);
      }
    }
    if (out != t) {
      changed.add(out);
    }
  }
  return changed;
}
