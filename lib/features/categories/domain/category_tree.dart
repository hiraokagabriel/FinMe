import '../../../core/utils/text_normalize.dart';
import 'transaction_category.dart';

/// Separador de caminho em rótulos: "Alimentação › Mercado" (SPEC §5.20).
const String kCategoryPathSeparator = ' › ';

/// Hierarquia de 1 nível. Índice montado no construtor; consultas são O(1) (ou O(filhas)).
class CategoryTree {
  CategoryTree(Iterable<TransactionCategory> categories)
    : _byId = {for (final c in categories) c.id: c} {
    for (final c in _byId.values) {
      final parentId = c.parentId;
      if (parentId == null) {
        continue;
      }
      final parent = _byId[parentId];
      // Vínculo inválido (§4.3): a categoria vira raiz.
      if (parent == null ||
          parent.id == c.id ||
          parent.parentId != null ||
          parent.kind != c.kind) {
        continue;
      }
      _parentOf[c.id] = parentId;
      _children.putIfAbsent(parentId, () => []).add(c);
    }
    _children.updateAll((_, kids) => List.unmodifiable(kids..sort(_byName)));

    final roots = <CategoryKind, List<TransactionCategory>>{};
    final options = <CategoryKind, List<TransactionCategory>>{};
    for (final c in [..._byId.values]..sort(_byName)) {
      if (_parentOf.containsKey(c.id)) {
        continue;
      }
      roots.putIfAbsent(c.kind, () => []).add(c);
      options.putIfAbsent(c.kind, () => []).add(c);
      options[c.kind]!.addAll(childrenOf(c.id));
    }
    _roots = {for (final e in roots.entries) e.key: List.unmodifiable(e.value)};
    _options = {
      for (final e in options.entries) e.key: List.unmodifiable(e.value),
    };
  }

  /// Árvore vazia: toda categoria é raiz e o rótulo é ''.
  static final CategoryTree empty = CategoryTree(const []);

  final Map<String, TransactionCategory> _byId;
  final Map<String, String> _parentOf = {};
  final Map<String, List<TransactionCategory>> _children = {};
  late final Map<CategoryKind, List<TransactionCategory>> _roots;
  late final Map<CategoryKind, List<TransactionCategory>> _options;

  static int _byName(TransactionCategory a, TransactionCategory b) {
    final byFold = foldText(a.name).compareTo(foldText(b.name));
    return byFold != 0 ? byFold : a.id.compareTo(b.id);
  }

  TransactionCategory? byId(String id) => _byId[id];

  /// Id do pai se o vínculo é válido; null para raiz, órfã ou id desconhecido.
  String? parentOf(String id) => _parentOf[id];

  /// Raiz do caminho: o próprio pai se válido, senão o id (desconhecido → ele mesmo).
  String rootOf(String id) => _parentOf[id] ?? id;

  bool isRoot(String id) => !_parentOf.containsKey(id);

  bool hasChildren(String id) => _children.containsKey(id);

  List<TransactionCategory> childrenOf(String id) =>
      _children[id] ?? const <TransactionCategory>[];

  /// Raízes do tipo, incluindo as de vínculo inválido, por nome dobrado.
  List<TransactionCategory> roots(CategoryKind kind) =>
      _roots[kind] ?? const <TransactionCategory>[];

  /// Ordem do dropdown: cada raiz seguida das suas filhas.
  List<TransactionCategory> options(CategoryKind kind) =>
      _options[kind] ?? const <TransactionCategory>[];

  /// "Pai › Filha" para filha válida; nome para raiz; '' para id desconhecido.
  String label(String id) {
    final c = _byId[id];
    if (c == null) {
      return '';
    }
    final parentId = _parentOf[id];
    if (parentId == null) {
      return c.name;
    }
    return '${_byId[parentId]!.name}$kCategoryPathSeparator${c.name}';
  }

  /// Agrega gasto na raiz. Chave null e ids desconhecidos ficam como estão; soma total preservada.
  Map<String?, int> rollUp(Map<String?, int> spending) {
    final out = <String?, int>{};
    for (final e in spending.entries) {
      final key = e.key == null ? null : rootOf(e.key!);
      out[key] = (out[key] ?? 0) + e.value;
    }
    return out;
  }
}

/// Erro de validação do pai no formulário; null = vínculo permitido (SPEC §5.20).
String? categoryParentError({
  required String? id,
  required CategoryKind kind,
  required String? parentId,
  required Iterable<TransactionCategory> categories,
}) {
  if (parentId == null) {
    return null;
  }
  if (parentId == id) {
    return 'Uma categoria não pode ser pai dela mesma';
  }
  final parent = CategoryTree(categories).byId(parentId);
  if (parent == null) {
    return 'Categoria pai não encontrada';
  }
  if (parent.parentId != null) {
    return 'A categoria pai não pode ser uma subcategoria';
  }
  if (parent.kind != kind) {
    return 'A categoria pai precisa ser do mesmo tipo';
  }
  if (id != null && categories.any((c) => c.parentId == id)) {
    return 'Esta categoria tem subcategorias e não pode virar subcategoria';
  }
  return null;
}
