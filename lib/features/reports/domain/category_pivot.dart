import '../../../core/models/year_month.dart';
import '../../../core/utils/text_normalize.dart';
import '../../categories/domain/category_tree.dart';
import 'category_reports.dart';
import 'report_filter.dart';

/// Linha do pivot: raiz, filha ou a linha isDirect (gasto lançado direto no pai).
class PivotRow {
  const PivotRow({
    required this.categoryId,
    this.isDirect = false,
    required this.cells,
    required this.totalCents,
    this.children = const [],
  });

  /// null = Sem categoria.
  final String? categoryId;
  final bool isDirect;

  /// Um valor por mês, na ordem de CategoryPivot.months.
  final List<int> cells;
  final int totalCents;

  /// Só em raiz com filhas; senão const [].
  final List<PivotRow> children;
}

class CategoryPivot {
  const CategoryPivot({
    required this.months,
    required this.rows,
    required this.columnTotals,
    required this.grandTotalCents,
    required this.maxCellCents,
  });

  final List<YearMonth> months;

  /// Raízes, na ordem padrão (total desc, rótulo asc).
  final List<PivotRow> rows;

  /// Soma das raízes por mês.
  final List<int> columnTotals;
  final int grandTotalCents;

  /// Maior célula entre as raízes (0 se vazio); intensidade do fundo na UI.
  final int maxCellCents;
}

enum PivotSortKey { label, total, month }

/// Pivot de [months]. Raízes por tree.rootOf; entra linha com total diferente de zero.
CategoryPivot categoryPivot(
  MonthCategoryTotals totals, {
  required List<YearMonth> months,
  required CategoryTree tree,
}) {
  final n = months.length;
  final rootCells = <String?, List<int>>{};
  final kidCells = <String, Map<String?, List<int>>>{};
  for (var i = 0; i < n; i++) {
    totals[months[i]]?.forEach((id, cents) {
      final root = id == null ? null : tree.rootOf(id);
      _addCell(rootCells, root, n, i, cents);
      if (root != null && tree.hasChildren(root)) {
        _addCell(kidCells.putIfAbsent(root, () => {}), id, n, i, cents);
      }
    });
  }

  final rows = <PivotRow>[
    for (final e in rootCells.entries)
      if (_sum(e.value) != 0)
        PivotRow(
          categoryId: e.key,
          cells: e.value,
          totalCents: _sum(e.value),
          children: _childRows(
            e.key,
            kidCells[e.key] ?? const <String?, List<int>>{},
          ),
        ),
  ];
  final sorted = sortPivotRows(
    rows,
    key: PivotSortKey.total,
    ascending: false,
    tree: tree,
  );

  final columnTotals = [
    for (var i = 0; i < n; i++) _sum([for (final r in sorted) r.cells[i]]),
  ];
  var maxCell = 0;
  for (final r in sorted) {
    for (final c in r.cells) {
      if (c > maxCell) {
        maxCell = c;
      }
    }
  }

  return CategoryPivot(
    months: months,
    rows: sorted,
    columnTotals: columnTotals,
    grandTotalCents: _sum(columnTotals),
    maxCellCents: maxCell,
  );
}

/// Ordena raízes e filhas (lista nova). Null sempre por último; isDirect por último
/// entre as filhas; empate → rótulo dobrado asc. [monthIndex] só vale com key month.
List<PivotRow> sortPivotRows(
  List<PivotRow> rows, {
  required PivotSortKey key,
  int monthIndex = 0,
  required bool ascending,
  required CategoryTree tree,
}) {
  final dir = ascending ? 1 : -1;
  int compare(PivotRow a, PivotRow b) {
    if (a.isDirect != b.isDirect) {
      return a.isDirect ? 1 : -1;
    }
    if ((a.categoryId == null) != (b.categoryId == null)) {
      return a.categoryId == null ? 1 : -1;
    }
    final byKey = switch (key) {
      PivotSortKey.label => foldText(
        _label(a, tree),
      ).compareTo(foldText(_label(b, tree))),
      PivotSortKey.total => a.totalCents.compareTo(b.totalCents),
      PivotSortKey.month => a.cells[monthIndex].compareTo(b.cells[monthIndex]),
    };
    if (byKey != 0) {
      return byKey * dir;
    }
    return foldText(_label(a, tree)).compareTo(foldText(_label(b, tree)));
  }

  final copy = [
    for (final r in rows)
      PivotRow(
        categoryId: r.categoryId,
        isDirect: r.isDirect,
        cells: r.cells,
        totalCents: r.totalCents,
        children: sortPivotRows(
          r.children,
          key: key,
          monthIndex: monthIndex,
          ascending: ascending,
          tree: tree,
        ),
      ),
  ];
  copy.sort(compare);
  return copy;
}

/// Filhas com total != 0 e a linha isDirect (id do pai) quando o pai tem gasto próprio.
List<PivotRow> _childRows(String? root, Map<String?, List<int>> kids) => [
  for (final e in kids.entries)
    if (_sum(e.value) != 0)
      PivotRow(
        categoryId: e.key,
        isDirect: e.key == root,
        cells: e.value,
        totalCents: _sum(e.value),
      ),
];

void _addCell<K>(Map<K, List<int>> m, K key, int n, int i, int cents) {
  final cells = m.putIfAbsent(key, () => List<int>.filled(n, 0));
  cells[i] += cents;
}

String _label(PivotRow r, CategoryTree tree) =>
    reportCategoryLabel(r.categoryId, tree, isDirect: r.isDirect);

int _sum(Iterable<int> values) => values.fold(0, (a, b) => a + b);
