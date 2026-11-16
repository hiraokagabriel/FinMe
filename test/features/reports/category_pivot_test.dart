import 'package:finme/core/models/year_month.dart';
import 'package:finme/features/categories/domain/category_tree.dart';
import 'package:finme/features/categories/domain/transaction_category.dart';
import 'package:finme/features/reports/domain/category_pivot.dart';
import 'package:finme/features/reports/domain/category_reports.dart';
import 'package:finme/features/reports/domain/report_filter.dart';
import 'package:finme/features/transactions/domain/transaction.dart';
import 'package:flutter_test/flutter_test.dart';

final DateTime _hoje = DateTime(2026, 11, 30);

TransactionCategory _cat(
  String id,
  String name,
  CategoryKind kind, {
  String? parentId,
}) => TransactionCategory(
  id: id,
  name: name,
  kind: kind,
  iconCodePoint: 0,
  colorValue: 0,
  parentId: parentId,
);

final CategoryTree _tree = CategoryTree([
  _cat('ali', 'Alimentação', CategoryKind.expense),
  _cat('mer', 'Mercado', CategoryKind.expense, parentId: 'ali'),
  _cat('res', 'Restaurante', CategoryKind.expense, parentId: 'ali'),
  _cat('tra', 'Transporte', CategoryKind.expense),
  _cat('sal', 'Salário', CategoryKind.income),
]);

const _ago = YearMonth(2026, 8);
const _sep = YearMonth(2026, 9);
const _oct = YearMonth(2026, 10);
const _nov = YearMonth(2026, 11);
const _months = [_ago, _sep, _oct, _nov];

Transaction _exp(String id, DateTime date, String? categoryId, int cents) =>
    Transaction(
      id: id,
      type: TransactionType.expense,
      amountCents: cents,
      date: date,
      description: 'x',
      accountId: 'A',
      categoryId: categoryId,
    );

/// Dados de §5.28 (despesas pagas por mês e categoria própria).
List<Transaction> _base() => [
  _exp('a1', DateTime(2026, 8, 10), 'mer', 30000),
  _exp('a2', DateTime(2026, 8, 10), 'tra', 10000),
  _exp('s1', DateTime(2026, 9, 10), 'mer', 40000),
  _exp('s2', DateTime(2026, 9, 10), 'res', 10000),
  _exp('s3', DateTime(2026, 9, 10), 'tra', 10000),
  _exp('o1', DateTime(2026, 10, 10), 'mer', 50000),
  _exp('o2', DateTime(2026, 10, 10), 'res', 20000),
  _exp('o3', DateTime(2026, 10, 10), 'ali', 5000),
  _exp('o4', DateTime(2026, 10, 10), 'tra', 20000),
  _exp('n1', DateTime(2026, 11, 3), 'mer', 60000),
  _exp('n2', DateTime(2026, 11, 3), 'res', 15000),
  _exp('n3', DateTime(2026, 11, 3), 'tra', 5000),
  _exp('n4', DateTime(2026, 11, 3), null, 3000),
];

MonthCategoryTotals _totals([List<Transaction>? txs]) => monthlyCategoryTotals(
  txs ?? _base(),
  ReportFilter(),
  from: _ago,
  to: _nov,
  tree: _tree,
  today: _hoje,
);

CategoryPivot _pivot() =>
    categoryPivot(_totals(), months: _months, tree: _tree);

PivotRow _ali(List<PivotRow> rows) =>
    rows.firstWhere((r) => r.categoryId == 'ali');

List<String?> _ids(List<PivotRow> rows) => [for (final r in rows) r.categoryId];

void main() {
  group('categoryPivot (exemplo de §5.29)', () {
    test('linhas, células, totais e rodapé', () {
      final p = _pivot();
      expect(_ids(p.rows), ['ali', 'tra', null]);

      final ali = p.rows[0];
      expect(ali.cells, [30000, 50000, 75000, 75000]);
      expect(ali.totalCents, 230000);
      expect(_ids(ali.children), ['mer', 'res', 'ali']);
      expect(ali.children[2].isDirect, isTrue);
      expect(ali.children[0].cells, [30000, 40000, 50000, 60000]);
      expect(ali.children[0].totalCents, 180000);
      expect(ali.children[1].cells, [0, 10000, 20000, 15000]);
      expect(ali.children[1].totalCents, 45000);
      expect(ali.children[2].cells, [0, 0, 5000, 0]);
      expect(ali.children[2].totalCents, 5000);

      final tra = p.rows[1];
      expect(tra.cells, [10000, 10000, 20000, 5000]);
      expect(tra.totalCents, 45000);
      expect(tra.children, isEmpty);

      expect(p.rows[2].cells, [0, 0, 0, 3000]);
      expect(p.rows[2].totalCents, 3000);

      expect(p.columnTotals, [40000, 60000, 95000, 83000]);
      expect(p.grandTotalCents, 278000);
      expect(p.maxCellCents, 75000);
      expect(p.months, _months);
    });
  });

  group('sortPivotRows', () {
    test('as quatro ordenações do exemplo de §5.29', () {
      final rows = _pivot().rows;
      expect(
        _ids(
          sortPivotRows(
            rows,
            key: PivotSortKey.month,
            monthIndex: 0,
            ascending: false,
            tree: _tree,
          ),
        ),
        ['ali', 'tra', null],
      );
      expect(
        _ids(
          sortPivotRows(
            rows,
            key: PivotSortKey.total,
            ascending: true,
            tree: _tree,
          ),
        ),
        ['tra', 'ali', null],
      );
      expect(
        _ids(
          sortPivotRows(
            rows,
            key: PivotSortKey.label,
            ascending: false,
            tree: _tree,
          ),
        ),
        ['tra', 'ali', null],
      );
      expect(
        _ids(
          sortPivotRows(
            rows,
            key: PivotSortKey.label,
            ascending: true,
            tree: _tree,
          ),
        ),
        ['ali', 'tra', null],
      );
    });

    test('filhas de ali por total asc: res, mer, direta', () {
      final sorted = sortPivotRows(
        _pivot().rows,
        key: PivotSortKey.total,
        ascending: true,
        tree: _tree,
      );
      expect(_ids(_ali(sorted).children), ['res', 'mer', 'ali']);
      expect(_ali(sorted).children[2].isDirect, isTrue);
    });

    test('devolve lista nova e não altera a original', () {
      final rows = _pivot().rows;
      final before = _ids(rows);
      final sorted = sortPivotRows(
        rows,
        key: PivotSortKey.total,
        ascending: true,
        tree: _tree,
      );
      expect(identical(sorted, rows), isFalse);
      expect(_ids(rows), before);
      expect(_ids(rows[0].children), ['mer', 'res', 'ali']);
    });

    test('null e isDirect ficam por último em qualquer ordenação', () {
      final rows = _pivot().rows;
      for (final key in PivotSortKey.values) {
        for (final asc in [true, false]) {
          final sorted = sortPivotRows(
            rows,
            key: key,
            ascending: asc,
            tree: _tree,
          );
          final ctx = '$key asc=$asc';
          expect(sorted.last.categoryId, isNull, reason: ctx);
          expect(_ali(sorted).children.last.isDirect, isTrue, reason: ctx);
        }
      }
    });
  });

  test('somas: colunas == grand == soma das raízes; filhas == pai', () {
    final p = _pivot();
    final rootSum = p.rows.fold(0, (a, r) => a + r.totalCents);
    expect(p.columnTotals.fold(0, (a, b) => a + b), p.grandTotalCents);
    expect(p.grandTotalCents, rootSum);
    for (final r in p.rows) {
      if (r.children.isNotEmpty) {
        expect(
          r.children.fold(0, (a, c) => a + c.totalCents),
          r.totalCents,
          reason: '${r.categoryId}',
        );
      }
    }
  });

  test('categoria apagada vira raiz própria antes de Sem categoria', () {
    final p = categoryPivot(
      _totals([
        _exp('z', DateTime(2026, 11, 3), 'zzz', 700),
        _exp('n', DateTime(2026, 11, 3), null, 3000),
      ]),
      months: _months,
      tree: _tree,
    );
    expect(_ids(p.rows), ['zzz', null]);
  });

  test('sem dados: rows vazio, zeros e maxCellCents 0', () {
    final p = categoryPivot(const {}, months: _months, tree: _tree);
    expect(p.rows, isEmpty);
    expect(p.columnTotals, [0, 0, 0, 0]);
    expect(p.grandTotalCents, 0);
    expect(p.maxCellCents, 0);
  });
}
