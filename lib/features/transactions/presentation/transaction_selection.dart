/// Seleção de transações na tabela (Ultra). Imutável: cada operação devolve nova instância.
/// Dart puro: a UI só guarda o objeto e chama as operações.
class TransactionSelection {
  const TransactionSelection({this.ids = const {}, this.anchorId});

  static const empty = TransactionSelection();

  final Set<String> ids;
  final String? anchorId;

  bool contains(String id) => ids.contains(id);

  /// Inverte `id` e vira a âncora do Shift+clique.
  TransactionSelection toggle(String id) {
    final next = {...ids};
    if (!next.remove(id)) {
      next.add(id);
    }
    return TransactionSelection(ids: next, anchorId: id);
  }

  /// Shift+clique: marca o intervalo da âncora até `id` em `order`.
  /// Sem âncora válida em `order` (ou `id` fora dele) cai em `toggle`.
  TransactionSelection extendTo(String id, List<String> order) {
    final anchor = anchorId == null ? -1 : order.indexOf(anchorId!);
    final target = order.indexOf(id);
    if (anchor < 0 || target < 0) {
      return toggle(id);
    }
    final from = anchor < target ? anchor : target;
    final to = anchor < target ? target : anchor;
    return TransactionSelection(
      ids: {...ids, ...order.sublist(from, to + 1)},
      anchorId: anchorId,
    );
  }

  TransactionSelection selectAll(List<String> order) =>
      TransactionSelection(ids: {...order}, anchorId: anchorId);

  /// Ids selecionados que estão em `order`, na ordem de `order`.
  List<String> selectedIn(List<String> order) => [
    for (final id in order)
      if (ids.contains(id)) id,
  ];

  /// Estado do checkbox de cabeçalho: false se vazio ou nada marcado, true se tudo marcado, null se parcial.
  bool? allState(List<String> order) {
    if (order.isEmpty) {
      return false;
    }
    final marked = order.where(ids.contains).length;
    if (marked == 0) {
      return false;
    }
    return marked == order.length ? true : null;
  }
}
