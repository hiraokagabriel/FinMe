import '../../../core/utils/text_normalize.dart';
import 'transaction.dart';

/// Tag livre normalizada. Remove `,` e `;`, `#` iniciais e espaços repetidos.
/// Mantém a grafia digitada. Vazio → null.
String? normalizeTag(String raw) {
  final s = raw
      .replaceAll(RegExp('[,;]'), '')
      .trim()
      .replaceFirst(RegExp('^#+'), '')
      .replaceAll(RegExp(r'[\s ]+'), ' ')
      .trim();
  return s.isEmpty ? null : s;
}

/// Chave de comparação: ignora caixa e acento (`'Viagem'` e `'VIÁGEM'` → `'VIAGEM'`).
String tagKey(String tag) => foldText(tag);

/// Normaliza, descarta vazias e remove duplicatas por [tagKey] (fica a 1ª grafia).
List<String> normalizeTags(Iterable<String> raw) {
  final seen = <String>{};
  final out = <String>[];
  for (final r in raw) {
    final t = normalizeTag(r);
    if (t != null && seen.add(tagKey(t))) {
      out.add(t);
    }
  }
  return out;
}

/// Entrada de campo de tags: separada por `,` ou `;`.
List<String> parseTagInput(String input) =>
    normalizeTags(input.split(RegExp('[,;]')));

/// Chaves de [t] já dobradas. Memoizado por instância: `Transaction` é imutável.
final _tagKeysCache = Expando<Set<String>>();

/// Conjunto imutável de [tagKey] das tags de [t]; sem tags → vazio.
Set<String> tagKeysOf(Transaction t) {
  if (t.tags.isEmpty) {
    return const {};
  }
  return _tagKeysCache[t] ??= Set.unmodifiable({
    for (final tag in t.tags) tagKey(tag),
  });
}

/// Alguma tag de [t] tem uma das [keys] (já em [tagKey]). [keys] vazio → true.
bool hasAnyTag(Transaction t, Set<String> keys) {
  if (keys.isEmpty) {
    return true;
  }
  return tagKeysOf(t).any(keys.contains);
}

/// Adiciona [tags] só nas transações que ganham alguma tag nova.
List<Transaction> bulkAddTags(
  Iterable<Transaction> selected,
  List<String> tags,
) {
  final out = <Transaction>[];
  for (final t in selected) {
    final merged = normalizeTags([...t.tags, ...tags]);
    if (merged.length > t.tags.length) {
      out.add(t.copyWith(tags: merged));
    }
  }
  return out;
}

/// Remove [tags] (por [tagKey]) só das transações que perdem alguma tag.
List<Transaction> bulkRemoveTags(
  Iterable<Transaction> selected,
  List<String> tags,
) {
  final keys = {for (final t in normalizeTags(tags)) tagKey(t)};
  final out = <Transaction>[];
  for (final t in selected) {
    final kept = [
      for (final tag in t.tags)
        if (!keys.contains(tagKey(tag))) tag,
    ];
    if (kept.length < t.tags.length) {
      out.add(t.copyWith(tags: kept));
    }
  }
  return out;
}

/// Uso por tag: grafia = a 1ª encontrada; ordena por contagem desc, depois [tagKey] asc.
List<({String tag, int count})> tagUsage(Iterable<Transaction> txs) {
  final spelling = <String, String>{};
  final counts = <String, int>{};
  for (final t in txs) {
    for (final tag in t.tags) {
      final k = tagKey(tag);
      spelling.putIfAbsent(k, () => tag);
      counts[k] = (counts[k] ?? 0) + 1;
    }
  }
  final keys = counts.keys.toList()
    ..sort((a, b) {
      final byCount = counts[b]!.compareTo(counts[a]!);
      return byCount != 0 ? byCount : a.compareTo(b);
    });
  return [for (final k in keys) (tag: spelling[k]!, count: counts[k]!)];
}
