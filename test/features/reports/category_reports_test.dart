import 'package:finme/core/models/year_month.dart';
import 'package:finme/features/categories/domain/category_tree.dart';
import 'package:finme/features/categories/domain/transaction_category.dart';
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
const _nov = YearMonth(2026, 11);

Transaction _exp(
  String id,
  DateTime date,
  String? categoryId,
  int cents, {
  bool planned = false,
}) => Transaction(
  id: id,
  type: TransactionType.expense,
  amountCents: cents,
  date: date,
  description: 'x',
  accountId: 'A',
  categoryId: categoryId,
  status: planned ? TransactionStatus.planned : TransactionStatus.paid,
);

final DateTime _aug = DateTime(2026, 8, 10);
final DateTime _sep = DateTime(2026, 9, 10);
final DateTime _oct = DateTime(2026, 10, 10);
final DateTime _novDay = DateTime(2026, 11, 3);

/// Dados de §5.28 mais os lançamentos que devem ser ignorados em nov.
List<Transaction> _base() => [
  _exp('a1', _aug, 'mer', 30000),
  _exp('a2', _aug, 'tra', 10000),
  _exp('s1', _sep, 'mer', 40000),
  _exp('s2', _sep, 'res', 10000),
  _exp('s3', _sep, 'tra', 10000),
  _exp('o1', _oct, 'mer', 50000),
  _exp('o2', _oct, 'res', 20000),
  _exp('o3', _oct, 'ali', 5000),
  _exp('o4', _oct, 'tra', 20000),
  _exp('n1', _novDay, 'mer', 60000),
  _exp('n2', _novDay, 'res', 15000),
  _exp('n3', _novDay, 'tra', 5000),
  _exp('n4', _novDay, null, 3000),
  Transaction(
    id: 'r1',
    type: TransactionType.income,
    amountCents: 500000,
    date: _novDay,
    description: 'salario',
    accountId: 'A',
    categoryId: 'sal',
  ),
  Transaction(
    id: 'r2',
    type: TransactionType.transfer,
    amountCents: 100000,
    date: _novDay,
    description: 'transf',
    accountId: 'A',
    toAccountId: 'B',
    categoryId: 'tra',
  ),
  Transaction(
    id: 'r3',
    type: TransactionType.invoicePayment,
    amountCents: 50000,
    date: _novDay,
    description: 'fatura',
    accountId: 'A',
  ),
  Transaction(
    id: 'r4',
    type: TransactionType.income,
    amountCents: 1000,
    date: _novDay,
    description: 'estorno',
    cardId: 'K',
    categoryId: 'tra',
  ),
  _exp('n5', _novDay, 'mer', 99999, planned: true),
];

MonthCategoryTotals _totals(
  List<Transaction> txs, {
  ReportFilter? filter,
  YearMonth from = _ago,
  YearMonth to = _nov,
}) => monthlyCategoryTotals(
  txs,
  filter ?? ReportFilter(),
  from: from,
  to: to,
  tree: _tree,
  today: _hoje,
);

CategoryComparisonRow _rowOf(List<CategoryComparisonRow> rows, String? id) =>
    rows.firstWhere((r) => r.categoryId == id);

void main() {
  group('monthlyCategoryTotals', () {
    test('guarda a categoria própria e ignora o que não entra', () {
      final m = _totals(_base());
      expect(m[_nov], {'mer': 60000, 'res': 15000, 'tra': 5000, null: 3000});
      expect(m[const YearMonth(2026, 10)]!['ali'], 5000);
      expect(m[const YearMonth(2026, 10)]!.containsKey('mer'), isTrue);
      expect(m[_nov]!['sal'], isNull);
    });

    test('mês sem lançamento fica ausente do mapa', () {
      final txs = [_exp('a', _aug, 'mer', 100), _exp('b', _oct, 'mer', 1)];
      final m = _totals(txs, from: _ago, to: _nov);
      expect(m.containsKey(_ago), isTrue);
      expect(m.containsKey(const YearMonth(2026, 9)), isFalse);
    });

    test('despesa fora de [from, to] é ignorada', () {
      final m = _totals(_base(), from: const YearMonth(2026, 9), to: _nov);
      expect(m.containsKey(_ago), isFalse);
      expect(m.containsKey(const YearMonth(2026, 9)), isTrue);
    });
  });

  group('categoryComparison (exemplo de §5.28)', () {
    final cmp = categoryComparison(
      _totals(_base()),
      month: _nov,
      averageMonths: 3,
      tree: _tree,
    );

    test('raízes na ordem ali, tra, null', () {
      expect(cmp.rows.map((r) => r.categoryId).toList(), ['ali', 'tra', null]);
    });

    test('ali: valores, delta e razões', () {
      final ali = cmp.rows.first;
      expect(ali.currentCents, 75000);
      expect(ali.previousCents, 75000);
      expect(ali.averageCents, 51667);
      expect(ali.deltaCents, 0);
      expect(ali.changeRatio, 0.0);
      expect(ali.averageChangeRatio, closeTo(0.4516, 0.0001));
    });

    test('filhas de ali: mer, res e a linha direta, nessa ordem', () {
      final kids = cmp.rows.first.children;
      expect(kids.map((r) => r.categoryId).toList(), ['mer', 'res', 'ali']);
      expect(kids.map((r) => r.isDirect).toList(), [false, false, true]);

      final mer = kids[0];
      expect(
        (mer.currentCents, mer.previousCents, mer.averageCents, mer.deltaCents),
        (60000, 50000, 40000, 10000),
      );
      expect(mer.changeRatio, 0.2);

      final res = kids[1];
      expect(
        (res.currentCents, res.previousCents, res.averageCents, res.deltaCents),
        (15000, 20000, 10000, -5000),
      );
      expect(res.changeRatio, -0.25);

      final direct = kids[2];
      expect(
        (
          direct.currentCents,
          direct.previousCents,
          direct.averageCents,
          direct.deltaCents,
        ),
        (0, 5000, 1667, -5000),
      );
      expect(direct.changeRatio, -1.0);
    });

    test('tra sem filhas', () {
      final tra = _rowOf(cmp.rows, 'tra');
      expect(
        (tra.currentCents, tra.previousCents, tra.averageCents),
        (5000, 20000, 13333),
      );
      expect(tra.changeRatio, -0.75);
      expect(tra.children, isEmpty);
    });

    test('Sem categoria: sem razão de variação e por último', () {
      final none = cmp.rows.last;
      expect(none.categoryId, isNull);
      expect(
        (none.currentCents, none.previousCents, none.averageCents),
        (3000, 0, 0),
      );
      expect(none.changeRatio, isNull);
    });

    test('total das raízes', () {
      expect(cmp.total.categoryId, isNull);
      expect(cmp.total.children, isEmpty);
      expect(
        (
          cmp.total.currentCents,
          cmp.total.previousCents,
          cmp.total.averageCents,
        ),
        (83000, 95000, 65000),
      );
    });

    test('mês de referência e média guardados', () {
      expect(cmp.month, _nov);
      expect(cmp.averageMonths, 3);
    });
  });

  group('variações de §5.28', () {
    test('includePlanned soma o provisionado', () {
      final cmp = categoryComparison(
        _totals(_base(), filter: ReportFilter(includePlanned: true)),
        month: _nov,
        averageMonths: 3,
        tree: _tree,
      );
      expect(_rowOf(cmp.rows, 'ali').currentCents, 174999);
      final kids = _rowOf(cmp.rows, 'ali').children;
      expect(_rowOf(kids, 'mer').currentCents, 159999);
    });

    test('averageMonths 6 muda só a média', () {
      final cmp = categoryComparison(
        _totals(_base()),
        month: _nov,
        averageMonths: 6,
        tree: _tree,
      );
      expect(_rowOf(cmp.rows, 'ali').averageCents, 25833);
      expect(_rowOf(cmp.rows, 'ali').currentCents, 75000);
    });

    test('categoryIds {tra} deixa só a linha tra', () {
      final cmp = categoryComparison(
        _totals(_base(), filter: ReportFilter(categoryIds: {'tra'})),
        month: _nov,
        averageMonths: 3,
        tree: _tree,
      );
      expect(cmp.rows.map((r) => r.categoryId).toList(), ['tra']);
    });

    test('flow income deixa só a linha sal', () {
      final cmp = categoryComparison(
        _totals(_base(), filter: ReportFilter(flow: ReportFlow.income)),
        month: _nov,
        averageMonths: 3,
        tree: _tree,
      );
      expect(cmp.rows.length, 1);
      final sal = cmp.rows.single;
      expect(sal.categoryId, 'sal');
      expect(
        (sal.currentCents, sal.previousCents, sal.averageCents),
        (500000, 0, 0),
      );
    });
  });

  group('ordem e casos de borda', () {
    test('categoria apagada é raiz própria, antes de Sem categoria', () {
      final txs = [..._base(), _exp('x1', _novDay, 'apagada', 2000)];
      final cmp = categoryComparison(
        _totals(txs),
        month: _nov,
        averageMonths: 3,
        tree: _tree,
      );
      expect(cmp.rows.map((r) => r.categoryId).toList(), [
        'ali',
        'tra',
        'apagada',
        null,
      ]);
    });

    test(
      'raiz com filhas só com gasto direto: children só com a linha direta',
      () {
        final txs = [_exp('d1', _novDay, 'ali', 5000)];
        final cmp = categoryComparison(
          _totals(txs),
          month: _nov,
          averageMonths: 3,
          tree: _tree,
        );
        final ali = cmp.rows.single;
        expect(ali.categoryId, 'ali');
        expect(ali.children.length, 1);
        expect(ali.children.single.categoryId, 'ali');
        expect(ali.children.single.isDirect, isTrue);
      },
    );

    test('sem lançamentos: rows vazio e total zerado', () {
      final cmp = categoryComparison(
        const {},
        month: _nov,
        averageMonths: 3,
        tree: _tree,
      );
      expect(cmp.rows, isEmpty);
      expect(cmp.total.currentCents, 0);
      expect(cmp.total.averageCents, 0);
    });
  });

  group('mês atual até hoje', () {
    test(
      'não provisionado com data futura fica fora; provisionado segue includePlanned',
      () {
        final txs = [
          _exp('f1', DateTime(2026, 11, 20), 'mer', 70000),
          _exp('f2', DateTime(2026, 11, 21), 'mer', 80000, planned: true),
        ];
        MonthCategoryTotals run(ReportFilter f) => monthlyCategoryTotals(
          txs,
          f,
          from: _nov,
          to: _nov,
          tree: _tree,
          today: DateTime(2026, 11, 15),
        );
        expect(run(ReportFilter()), isEmpty);
        expect(run(ReportFilter(includePlanned: true)), {
          _nov: {'mer': 80000},
        });
      },
    );
  });
}
