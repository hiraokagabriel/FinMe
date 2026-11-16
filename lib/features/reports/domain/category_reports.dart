import '../../../core/models/year_month.dart';
import '../../../core/utils/text_normalize.dart';
import '../../accounts/domain/monthly_history.dart';
import '../../categories/domain/category_tree.dart';
import '../../transactions/domain/transaction.dart';
import 'report_filter.dart';

/// Gasto por mês e categoria própria (sem rollUp). Mês sem valor fica ausente.
typedef MonthCategoryTotals = Map<YearMonth, Map<String?, int>>;

/// Uma passada: flow, período [from, to] e escopo do filtro. Categoria guardada é a própria.
/// Lançamento sem provisionar com data depois de [today] fica fora.
MonthCategoryTotals monthlyCategoryTotals(
  Iterable<Transaction> txs,
  ReportFilter f, {
  required YearMonth from,
  required YearMonth to,
  required CategoryTree tree,
  required DateTime today,
}) {
  final out = <YearMonth, Map<String?, int>>{};
  for (final t in txs) {
    if (reportFlowOf(t) != f.flow || isFutureUnplanned(t, today)) {
      continue;
    }
    final month = YearMonth.fromDate(t.date);
    if (month < from || month > to || !matchesReportScope(t, f, tree)) {
      continue;
    }
    final byCategory = out.putIfAbsent(month, () => {});
    byCategory[t.categoryId] = (byCategory[t.categoryId] ?? 0) + t.amountCents;
  }
  return out;
}

class CategoryComparisonRow {
  const CategoryComparisonRow({
    required this.categoryId,
    this.isDirect = false,
    required this.currentCents,
    required this.previousCents,
    required this.averageCents,
    this.children = const [],
  });

  /// Raiz (ou null = Sem categoria); no drill-down: filha, ou o próprio pai com isDirect.
  final String? categoryId;

  /// Linha "(sem subcategoria)": gasto lançado direto no pai.
  final bool isDirect;
  final int currentCents, previousCents, averageCents;

  /// Só em raiz com filhas; senão const [].
  final List<CategoryComparisonRow> children;

  int get deltaCents => currentCents - previousCents;

  double? get changeRatio => deltaRatio(previousCents, currentCents);

  double? get averageChangeRatio => deltaRatio(averageCents, currentCents);
}

class CategoryComparison {
  const CategoryComparison({
    required this.month,
    required this.averageMonths,
    required this.rows,
    required this.total,
  });

  final YearMonth month;
  final int averageMonths;

  /// Raízes, ordenadas.
  final List<CategoryComparisonRow> rows;

  /// categoryId null, sem children: somas das raízes.
  final CategoryComparisonRow total;
}

/// Comparativo de [month] com [month] − 1 e a média dos [averageMonths] meses anteriores.
CategoryComparison categoryComparison(
  MonthCategoryTotals totals, {
  required YearMonth month,
  required int averageMonths,
  required CategoryTree tree,
}) {
  assert(averageMonths > 0, 'averageMonths deve ser > 0');
  final previousMonth = month.prev();
  final cur = _ownSums(totals, month, month);
  final prev = _ownSums(totals, previousMonth, previousMonth);
  final win = _ownSums(totals, month.addMonths(-averageMonths), previousMonth);

  final rootCur = tree.rollUp(cur);
  final rootPrev = tree.rollUp(prev);
  final rootWin = tree.rollUp(win);
  final rows = <CategoryComparisonRow>[];
  for (final id in <String?>{
    ...rootCur.keys,
    ...rootPrev.keys,
    ...rootWin.keys,
  }) {
    final c = rootCur[id] ?? 0;
    final p = rootPrev[id] ?? 0;
    final w = rootWin[id] ?? 0;
    if (c == 0 && p == 0 && w == 0) {
      continue;
    }
    rows.add(
      CategoryComparisonRow(
        categoryId: id,
        currentCents: c,
        previousCents: p,
        averageCents: roundDiv(w, averageMonths),
        children: id == null
            ? const []
            : _childRows(
                id,
                cur: cur,
                prev: prev,
                win: win,
                averageMonths: averageMonths,
                tree: tree,
              ),
      ),
    );
  }
  rows.sort((a, b) => _compareRows(a, b, tree));

  return CategoryComparison(
    month: month,
    averageMonths: averageMonths,
    rows: rows,
    total: CategoryComparisonRow(
      categoryId: null,
      currentCents: _sum(cur),
      previousCents: _sum(prev),
      averageCents: roundDiv(_sum(win), averageMonths),
    ),
  );
}

/// Soma própria por categoria em from..to (inclusive).
Map<String?, int> _ownSums(
  MonthCategoryTotals totals,
  YearMonth from,
  YearMonth to,
) {
  final out = <String?, int>{};
  for (var m = from; m <= to; m = m.next()) {
    totals[m]?.forEach((id, cents) => out[id] = (out[id] ?? 0) + cents);
  }
  return out;
}

/// Filhas com algum valor + a linha isDirect (id do pai) se o pai tem valor próprio.
List<CategoryComparisonRow> _childRows(
  String root, {
  required Map<String?, int> cur,
  required Map<String?, int> prev,
  required Map<String?, int> win,
  required int averageMonths,
  required CategoryTree tree,
}) {
  if (!tree.hasChildren(root)) {
    return const [];
  }
  final ids = <String>{};
  for (final id in [...cur.keys, ...prev.keys, ...win.keys]) {
    if (id != null && (id == root || tree.parentOf(id) == root)) {
      ids.add(id);
    }
  }
  final rows = <CategoryComparisonRow>[];
  for (final id in ids) {
    final c = cur[id] ?? 0;
    final p = prev[id] ?? 0;
    final w = win[id] ?? 0;
    if (c == 0 && p == 0 && w == 0) {
      continue;
    }
    rows.add(
      CategoryComparisonRow(
        categoryId: id,
        isDirect: id == root,
        currentCents: c,
        previousCents: p,
        averageCents: roundDiv(w, averageMonths),
      ),
    );
  }
  rows.sort((a, b) => _compareRows(a, b, tree));
  return rows;
}

/// Atual desc, anterior desc, rótulo dobrado asc; null e isDirect por último.
int _compareRows(
  CategoryComparisonRow a,
  CategoryComparisonRow b,
  CategoryTree tree,
) {
  if (a.isDirect != b.isDirect) {
    return a.isDirect ? 1 : -1;
  }
  if ((a.categoryId == null) != (b.categoryId == null)) {
    return a.categoryId == null ? 1 : -1;
  }
  final byCurrent = b.currentCents.compareTo(a.currentCents);
  if (byCurrent != 0) {
    return byCurrent;
  }
  final byPrevious = b.previousCents.compareTo(a.previousCents);
  if (byPrevious != 0) {
    return byPrevious;
  }
  return foldText(
    reportCategoryLabel(a.categoryId, tree, isDirect: a.isDirect),
  ).compareTo(
    foldText(reportCategoryLabel(b.categoryId, tree, isDirect: b.isDirect)),
  );
}

int _sum(Map<String?, int> values) => values.values.fold(0, (a, b) => a + b);
