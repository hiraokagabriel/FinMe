import 'package:finme/features/categories/domain/category_tree.dart';
import 'package:finme/features/categories/domain/transaction_category.dart';
import 'package:finme/features/reports/domain/report_filter.dart';
import 'package:finme/features/reports/domain/spending_heatmap.dart';
import 'package:finme/features/transactions/domain/transaction.dart';
import 'package:flutter_test/flutter_test.dart';

final CategoryTree _tree = CategoryTree([
  const TransactionCategory(
    id: 'ali',
    name: 'Alimentação',
    kind: CategoryKind.expense,
    iconCodePoint: 0,
    colorValue: 0,
  ),
]);

final DateTime _from = DateTime(2026, 11, 1);
final DateTime _to = DateTime(2026, 11, 30);

int _seq = 0;

Transaction _tx(
  int cents,
  DateTime date, {
  TransactionType type = TransactionType.expense,
  TransactionStatus status = TransactionStatus.paid,
}) => Transaction(
  id: 't${_seq++}',
  type: type,
  amountCents: cents,
  date: date,
  description: 'x',
  accountId: type == TransactionType.income ? 'A' : null,
  cardId: type == TransactionType.expense ? 'C' : null,
  categoryId: 'ali',
  status: status,
);

SpendingHeatmap _heat(
  List<Transaction> txs, {
  ReportFilter? filter,
  DateTime? from,
  DateTime? to,
}) => spendingHeatmap(
  txs,
  filter ?? ReportFilter(),
  from: from ?? _from,
  to: to ?? _to,
  tree: _tree,
);

/// Exemplo de §5.31: 8 dias com gasto, receita e despesa fora do período.
List<Transaction> _specExample() => [
  _tx(1000, DateTime(2026, 11, 1)),
  _tx(2000, DateTime(2026, 11, 2)),
  _tx(1500, DateTime(2026, 11, 3)),
  _tx(1500, DateTime(2026, 11, 3)),
  _tx(4000, DateTime(2026, 11, 4)),
  _tx(5000, DateTime(2026, 11, 5)),
  _tx(6000, DateTime(2026, 11, 6)),
  _tx(7000, DateTime(2026, 11, 7)),
  _tx(8000, DateTime(2026, 11, 8)),
  _tx(9000, DateTime(2026, 11, 9), type: TransactionType.income),
  _tx(50000, DateTime(2026, 10, 31)),
];

void main() {
  group('spendingHeatmap', () {
    test('categoryIds vale na despesa; com receita no filtro é ignorado', () {
      final txs = _specExample();
      final despesa = _heat(
        txs,
        filter: ReportFilter(categoryIds: const {'tra'}),
      );
      expect(despesa.totalCents, 0);

      final receita = ReportFilter(
        flow: ReportFlow.income,
        categoryIds: const {'tra'},
      );
      expect(_heat(txs, filter: receita).totalCents, _heat(txs).totalCents);
      expect(ignoredFilters(ReportKind.heatmap, receita), [
        'categorias',
        'tipo',
      ]);
    });

    test('exemplo de §5.31: dias, limiares, níveis, maxDay e total', () {
      final h = _heat(_specExample());
      expect(h.days.length, 8);
      expect(h.days[DateTime(2026, 11, 3)]!.cents, 3000);
      expect(h.days[DateTime(2026, 11, 3)]!.count, 2);
      expect(h.thresholds, [2000, 4000, 6000]);
      expect(h.levelOf(0), 0);
      expect(h.levelOf(1000), 1);
      expect(h.levelOf(2000), 1);
      expect(h.levelOf(2500), 2);
      expect(h.levelOf(4000), 2);
      expect(h.levelOf(6000), 3);
      expect(h.levelOf(7000), 4);
      expect(h.maxDay!.date, DateTime(2026, 11, 8));
      expect(h.maxDay!.cents, 8000);
      expect(h.totalCents, 36000);
      expect(h.activeDays, 8);
      expect(h.from, _from);
      expect(h.to, _to);
    });

    test('dia único: limiares iguais e nível 1 para o valor', () {
      final h = _heat([_tx(500, DateTime(2026, 11, 10))]);
      expect(h.thresholds, [500, 500, 500]);
      expect(h.levelOf(500), 1);
      expect(h.activeDays, 1);
      expect(h.totalCents, 500);
    });

    test('período sem despesas: vazio, sem limiares, maxDay null', () {
      final h = _heat([
        _tx(9000, DateTime(2026, 11, 9), type: TransactionType.income),
      ]);
      expect(h.days, isEmpty);
      expect(h.thresholds, isEmpty);
      expect(h.maxDay, isNull);
      expect(h.totalCents, 0);
      expect(h.activeDays, 0);
      expect(h.levelOf(0), 0);
      expect(h.levelOf(100), 4);
    });

    test('maxDay com empate fica com o dia mais antigo', () {
      final h = _heat([
        _tx(8000, DateTime(2026, 11, 20)),
        _tx(8000, DateTime(2026, 11, 12)),
        _tx(100, DateTime(2026, 11, 13)),
      ]);
      expect(h.maxDay!.date, DateTime(2026, 11, 12));
    });

    test('transação com hora cai no dia; from e to são inclusivos', () {
      final h = _heat(
        [
          _tx(700, DateTime(2026, 11, 3, 23, 59)),
          _tx(300, DateTime(2026, 11, 30, 15)),
          _tx(900, DateTime(2026, 10, 31, 23, 59)),
        ],
        from: DateTime(2026, 11, 3, 10),
        to: DateTime(2026, 11, 30, 8),
      );
      expect(h.days.keys.toList(), [
        DateTime(2026, 11, 3),
        DateTime(2026, 11, 30),
      ]);
      expect(h.totalCents, 1000);
    });

    test('flow income é ignorado: mesmo resultado do padrão', () {
      final txs = _specExample();
      final base = _heat(txs);
      final income = _heat(txs, filter: ReportFilter(flow: ReportFlow.income));
      expect(income.totalCents, base.totalCents);
      expect(income.days.length, base.days.length);
      expect(income.thresholds, base.thresholds);
    });

    test('despesa provisionada só entra com includePlanned', () {
      final planned = _tx(
        2500,
        DateTime(2026, 11, 15),
        status: TransactionStatus.planned,
      );
      expect(_heat([planned]).days, isEmpty);
      final withPlanned = _heat([
        planned,
      ], filter: ReportFilter(includePlanned: true));
      expect(withPlanned.totalCents, 2500);
    });
  });
}
