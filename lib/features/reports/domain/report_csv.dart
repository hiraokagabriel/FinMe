import 'package:csv/csv.dart';

import '../../../core/utils/formatters.dart';
import '../../categories/domain/category_tree.dart';
import '../../net_worth/domain/net_worth.dart';
import 'category_pivot.dart';
import 'category_reports.dart';
import 'merchant_report.dart';
import 'monthly_flow.dart';
import 'report_filter.dart';
import 'spending_heatmap.dart';

/// CSV dos relatórios (SPEC §5.32): separador `;`, BOM fica por conta da gravação.
String reportCsv(List<List<String>> rows) =>
    const ListToCsvConverter(fieldDelimiter: ';').convert(rows);

String _pct(double? ratio) => ratio == null ? '' : formatPercent(ratio);

String _money(int? cents) => cents == null ? '' : formatCsvMoney(cents);

List<List<String>> comparisonCsvRows(
  CategoryComparison c, {
  required CategoryTree tree,
  required bool includeChildren,
}) {
  List<String> cells(String label, CategoryComparisonRow r) => [
    label,
    formatCsvMoney(r.currentCents),
    formatCsvMoney(r.previousCents),
    formatCsvMoney(r.averageCents),
    formatCsvMoney(r.deltaCents),
    _pct(r.changeRatio),
    _pct(r.averageChangeRatio),
  ];

  return [
    [
      'Categoria',
      formatMonth(c.month),
      formatMonth(c.month.prev()),
      'Média ${c.averageMonths} meses',
      'Variação',
      'Variação %',
      'Vs. média %',
    ],
    for (final r in c.rows) ...[
      cells(csvText(reportCategoryLabel(r.categoryId, tree)), r),
      if (includeChildren)
        for (final k in r.children)
          cells(
            csvText(
              reportCategoryLabel(k.categoryId, tree, isDirect: k.isDirect),
            ),
            k,
          ),
    ],
    cells('Total', c.total),
  ];
}

List<List<String>> trendCsvRows(
  List<TrendPoint> points, {
  required List<int?> expenseAverage,
  required List<int?> balanceAverage,
}) {
  var income = 0;
  var expense = 0;
  final rows = <List<String>>[
    [
      'Mês',
      'Receitas',
      'Despesas',
      'Saldo do mês',
      'Média 3m despesas',
      'Média 3m saldo',
    ],
  ];
  for (var i = 0; i < points.length; i++) {
    final p = points[i];
    income += p.incomeCents;
    expense += p.expenseCents;
    rows.add([
      formatMonth(p.month),
      formatCsvMoney(p.incomeCents),
      formatCsvMoney(p.expenseCents),
      formatCsvMoney(p.balanceCents),
      _money(expenseAverage[i]),
      _money(balanceAverage[i]),
    ]);
  }
  rows.add([
    'Total',
    formatCsvMoney(income),
    formatCsvMoney(expense),
    formatCsvMoney(income - expense),
    '',
    '',
  ]);
  return rows;
}

List<List<String>> pivotCsvRows(CategoryPivot p, {required CategoryTree tree}) {
  List<String> cells(String label, List<int> values, int total) => [
    label,
    for (final v in values) formatCsvMoney(v),
    formatCsvMoney(total),
  ];

  return [
    ['Categoria', for (final m in p.months) formatMonth(m), 'Total'],
    for (final r in p.rows) ...[
      cells(
        csvText(reportCategoryLabel(r.categoryId, tree)),
        r.cells,
        r.totalCents,
      ),
      for (final k in r.children)
        cells(
          csvText(
            reportCategoryLabel(k.categoryId, tree, isDirect: k.isDirect),
          ),
          k.cells,
          k.totalCents,
        ),
    ],
    cells('Total', p.columnTotals, p.grandTotalCents),
  ];
}

List<List<String>> heatmapCsvRows(SpendingHeatmap h) {
  final days = h.days.values.toList()..sort((a, b) => a.date.compareTo(b.date));
  return [
    ['Data', 'Total', 'Transações'],
    for (final d in days)
      [formatDate(d.date), formatCsvMoney(d.cents), '${d.count}'],
  ];
}

List<List<String>> merchantsCsvRows(
  List<MerchantTotal> list, {
  required CategoryTree tree,
}) => [
  [
    'Estabelecimento',
    'Chave',
    'Total',
    'Compras',
    'Ticket médio',
    'Última compra',
    'Categoria',
  ],
  for (final m in list)
    [
      csvText(m.label),
      csvText(m.key),
      formatCsvMoney(m.totalCents),
      '${m.purchaseCount}',
      formatCsvMoney(m.averageCents),
      formatDate(m.lastDate),
      csvText(reportCategoryLabel(m.categoryId, tree)),
    ],
];

List<List<String>> fixedVariableCsvRows(List<FixedVariableMonth> months) {
  var recurring = 0;
  var installment = 0;
  var variable = 0;
  final rows = <List<String>>[
    ['Mês', 'Recorrentes', 'Parcelas', 'Fixo', 'Variável', 'Total', '% fixo'],
  ];
  for (final m in months) {
    recurring += m.recurringCents;
    installment += m.installmentCents;
    variable += m.variableCents;
    rows.add([
      formatMonth(m.month),
      formatCsvMoney(m.recurringCents),
      formatCsvMoney(m.installmentCents),
      formatCsvMoney(m.fixedCents),
      formatCsvMoney(m.variableCents),
      formatCsvMoney(m.totalCents),
      _pct(m.fixedRatio),
    ]);
  }
  final fixed = recurring + installment;
  final total = fixed + variable;
  rows.add([
    'Total',
    formatCsvMoney(recurring),
    formatCsvMoney(installment),
    formatCsvMoney(fixed),
    formatCsvMoney(variable),
    formatCsvMoney(total),
    _pct(total == 0 ? null : fixed / total),
  ]);
  return rows;
}

List<List<String>> netWorthCsvRows(List<NetWorthPoint> points) => [
  [
    'Mês',
    'Data',
    'Contas',
    'Ativos',
    'A receber',
    'A pagar',
    'Dívida de cartão',
    'Patrimônio líquido',
  ],
  for (final p in points)
    [
      formatMonth(p.month),
      formatDate(p.date),
      formatCsvMoney(p.accountsCents),
      formatCsvMoney(p.assetsCents),
      formatCsvMoney(p.receivableCents),
      formatCsvMoney(p.payableCents),
      formatCsvMoney(p.cardDebtCents),
      formatCsvMoney(p.netCents),
    ],
];
