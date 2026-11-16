import 'package:finme/core/models/year_month.dart';
import 'package:finme/features/categories/domain/category_tree.dart';
import 'package:finme/features/categories/domain/transaction_category.dart';
import 'package:finme/features/reports/domain/monthly_flow.dart';
import 'package:finme/features/reports/domain/report_filter.dart';
import 'package:finme/features/transactions/domain/installments.dart';
import 'package:finme/features/transactions/domain/transaction.dart';
import 'package:flutter_test/flutter_test.dart';

final DateTime _hoje = DateTime(2026, 11, 30);
// Dia 15/11: lançamentos de 20/11 são futuros (provisionados ou não).
final DateTime _meioNov = DateTime(2026, 11, 15);

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

const List<YearMonth> _setNov = [
  YearMonth(2026, 9),
  YearMonth(2026, 10),
  YearMonth(2026, 11),
];

int _n = 0;

/// Lançamento pago na conta A por padrão.
Transaction _tx({
  TransactionType type = TransactionType.expense,
  required int amountCents,
  required DateTime date,
  String? accountId = 'A',
  String? cardId,
  String? toAccountId,
  String? categoryId,
  TransactionStatus status = TransactionStatus.paid,
  String? recurringId,
}) {
  _n++;
  return Transaction(
    id: 't$_n',
    type: type,
    amountCents: amountCents,
    date: date,
    description: 'x',
    accountId: accountId,
    cardId: cardId,
    toAccountId: toAccountId,
    categoryId: categoryId,
    status: status,
    recurringId: recurringId,
  );
}

/// Dados de §5.30 (tendência).
List<Transaction> _trendBase() => [
  _tx(
    type: TransactionType.income,
    amountCents: 500000,
    date: DateTime(2026, 9, 5),
    categoryId: 'sal',
  ),
  _tx(amountCents: 60000, date: DateTime(2026, 9, 10), categoryId: 'mer'),
  _tx(
    type: TransactionType.income,
    amountCents: 500000,
    date: DateTime(2026, 10, 5),
    categoryId: 'sal',
  ),
  _tx(
    amountCents: 95000,
    date: DateTime(2026, 10, 12),
    accountId: null,
    cardId: 'K',
    categoryId: 'mer',
  ),
  _tx(
    type: TransactionType.transfer,
    amountCents: 100000,
    date: DateTime(2026, 10, 15),
    toAccountId: 'B',
  ),
  _tx(
    type: TransactionType.invoicePayment,
    amountCents: 50000,
    date: DateTime(2026, 10, 20),
  ),
  _tx(
    type: TransactionType.income,
    amountCents: 520000,
    date: DateTime(2026, 11, 5),
    categoryId: 'sal',
  ),
  _tx(amountCents: 83000, date: DateTime(2026, 11, 3), categoryId: 'mer'),
  _tx(
    type: TransactionType.income,
    amountCents: 1000,
    date: DateTime(2026, 11, 4),
    accountId: null,
    cardId: 'K',
    categoryId: 'tra',
  ),
  _tx(
    amountCents: 99999,
    date: DateTime(2026, 11, 20),
    status: TransactionStatus.planned,
    categoryId: 'mer',
  ),
];

/// Pares (receita, despesa) para comparar pontos sem depender de `==`.
List<(int, int)> _pairs(List<TrendPoint> ps) => [
  for (final p in ps) (p.incomeCents, p.expenseCents),
];

void main() {
  group('monthlyTrend', () {
    test('exemplo de §5.30', () {
      final ps = monthlyTrend(
        _trendBase(),
        ReportFilter(),
        months: _setNov,
        tree: _tree,
        today: _hoje,
      );
      expect(_pairs(ps), [(500000, 60000), (500000, 95000), (520000, 83000)]);
      expect(ps.map((p) => p.balanceCents).toList(), [440000, 405000, 437000]);
    });

    test('includePlanned soma o provisionado de novembro', () {
      final ps = monthlyTrend(
        _trendBase(),
        ReportFilter(includePlanned: true),
        months: _setNov,
        tree: _tree,
        today: _hoje,
      );
      expect(ps.last.expenseCents, 182999);
      expect(ps.last.balanceCents, 337001);
    });

    test('cardIds {K}: só o cartão K entra', () {
      final ps = monthlyTrend(
        _trendBase(),
        ReportFilter(cardIds: const {'K'}),
        months: _setNov,
        tree: _tree,
        today: _hoje,
      );
      expect(_pairs(ps), [(0, 0), (0, 95000), (0, 0)]);
    });

    test('flow income é ignorado (igual ao padrão)', () {
      final base = monthlyTrend(
        _trendBase(),
        ReportFilter(),
        months: _setNov,
        tree: _tree,
        today: _hoje,
      );
      final income = monthlyTrend(
        _trendBase(),
        ReportFilter(flow: ReportFlow.income),
        months: _setNov,
        tree: _tree,
        today: _hoje,
      );
      expect(_pairs(income), _pairs(base));
    });

    test('um ponto por mês, meses sem lançamento viram zero', () {
      final months = [
        const YearMonth(2025, 12),
        const YearMonth(2026, 1),
        const YearMonth(2026, 2),
      ];
      final ps = monthlyTrend(
        _trendBase(),
        ReportFilter(),
        months: months,
        tree: _tree,
        today: _hoje,
      );
      expect(ps.map((p) => p.month).toList(), months);
      expect(_pairs(ps), [(0, 0), (0, 0), (0, 0)]);
    });

    test('parcela paga com data futura no mês atual não entra', () {
      final ps = monthlyTrend(
        [
          ..._trendBase(),
          _tx(
            amountCents: 70000,
            date: DateTime(2026, 11, 20),
            categoryId: 'mer',
          ),
        ],
        ReportFilter(includePlanned: true),
        months: _setNov,
        tree: _tree,
        today: _meioNov,
      );
      // 83000 (pago em 03/11) + 99999 (provisionado em 20/11); o pago em 20/11 fica fora.
      expect(ps.last.expenseCents, 182999);
    });

    test('categoryIds restringe só o lado do fluxo do filtro', () {
      // Despesa com filtro de categoria 'tra' (nenhuma despesa): zera a despesa; a receita segue inteira.
      final expenseOnly = monthlyTrend(
        _trendBase(),
        ReportFilter(categoryIds: const {'tra'}),
        months: _setNov,
        tree: _tree,
        today: _hoje,
      );
      expect(_pairs(expenseOnly), [(500000, 0), (500000, 0), (520000, 0)]);

      // Receita com filtro 'mer': a receita some; a despesa segue sem categoria.
      final incomeSide = monthlyTrend(
        _trendBase(),
        ReportFilter(flow: ReportFlow.income, categoryIds: const {'mer'}),
        months: _setNov,
        tree: _tree,
        today: _hoje,
      );
      expect(_pairs(incomeSide), [(0, 60000), (0, 95000), (0, 83000)]);
    });
  });

  group('movingAverage', () {
    test('exemplos de §5.30', () {
      expect(movingAverage([440000, 405000, 437000]), [null, null, 427333]);
      expect(movingAverage([5, -6, -5], window: 2), [null, -1, -6]);
      expect(movingAverage([]), isEmpty);
    });

    test('window maior que a lista → tudo null', () {
      expect(movingAverage([1, 2], window: 5), [null, null]);
    });
  });

  group('fixedVariableByMonth', () {
    const out = YearMonth(2026, 10);
    const nov = YearMonth(2026, 11);

    List<Transaction> fixedBase() {
      final loja = buildInstallments(
        base: _tx(amountCents: 60000, date: DateTime(2026, 10, 20)),
        count: 3,
        groupId: 'loja',
      );
      return [
        _tx(
          amountCents: 150000,
          date: DateTime(2026, 10, 5),
          recurringId: 'rent',
        ),
        _tx(
          amountCents: 4000,
          date: DateTime(2026, 10, 6),
          accountId: null,
          cardId: 'K',
          recurringId: 'st',
        ),
        _tx(amountCents: 46000, date: DateTime(2026, 10, 7)),
        ...loja,
        _tx(
          amountCents: 150000,
          date: DateTime(2026, 11, 5),
          recurringId: 'rent',
        ),
        _tx(
          amountCents: 4000,
          date: DateTime(2026, 11, 6),
          accountId: null,
          cardId: 'K',
          recurringId: 'st',
        ),
        _tx(amountCents: 26000, date: DateTime(2026, 11, 7)),
        _tx(
          type: TransactionType.income,
          amountCents: 500000,
          date: DateTime(2026, 11, 8),
          recurringId: 'sal',
        ),
      ];
    }

    test('exemplo de §5.30', () {
      final items = fixedVariableByMonth(
        fixedBase(),
        ReportFilter(),
        months: [out, nov],
        tree: _tree,
        today: _hoje,
      );
      final o = items[0];
      expect(o.recurringCents, 154000);
      expect(o.installmentCents, 20000);
      expect(o.variableCents, 46000);
      expect(o.fixedCents, 174000);
      expect(o.totalCents, 220000);
      expect(o.fixedRatio, closeTo(0.7909, 0.0001));

      final n = items[1];
      expect(n.recurringCents, 154000);
      expect(n.installmentCents, 20000);
      expect(n.variableCents, 26000);
      expect(n.fixedCents, 174000);
      expect(n.totalCents, 200000);
      expect(n.fixedRatio, closeTo(0.87, 0.0001));
    });

    test('categoryIds {tra}: só Aluguel (tra) entra', () {
      final items = fixedVariableByMonth(
        [
          _tx(
            amountCents: 150000,
            date: DateTime(2026, 10, 5),
            categoryId: 'tra',
            recurringId: 'rent',
          ),
          _tx(amountCents: 4000, date: DateTime(2026, 10, 6)),
          ...buildInstallments(
            base: _tx(amountCents: 60000, date: DateTime(2026, 10, 20)),
            count: 3,
            groupId: 'loja',
          ),
        ],
        ReportFilter(categoryIds: const {'tra'}),
        months: [out],
        tree: _tree,
        today: _hoje,
      );
      expect(items.single.recurringCents, 150000);
      expect(items.single.installmentCents, 0);
      expect(items.single.variableCents, 0);
    });

    test('parcela com recurringId conta como recorrente', () {
      final items = fixedVariableByMonth(
        [
          ...buildInstallments(
            base: _tx(
              amountCents: 30000,
              date: DateTime(2026, 10, 20),
              recurringId: 'r1',
            ),
            count: 3,
            groupId: 'g',
          ),
        ],
        ReportFilter(),
        months: [out],
        tree: _tree,
        today: _hoje,
      );
      expect(items.single.recurringCents, 10000);
      expect(items.single.installmentCents, 0);
    });

    test('mês sem despesas → zeros e fixedRatio null', () {
      final items = fixedVariableByMonth(
        const [],
        ReportFilter(),
        months: [out],
        tree: _tree,
        today: _hoje,
      );
      expect(items.single.totalCents, 0);
      expect(items.single.fixedRatio, isNull);
    });

    test('despesa paga com data futura no mês atual não entra', () {
      final items = fixedVariableByMonth(
        [_tx(amountCents: 70000, date: DateTime(2026, 11, 20))],
        ReportFilter(includePlanned: true),
        months: [nov],
        tree: _tree,
        today: _meioNov,
      );
      expect(items.single.totalCents, 0);
    });

    test('provisionada com data futura entra só com includePlanned', () {
      final planned = [
        _tx(
          amountCents: 70000,
          date: DateTime(2026, 11, 20),
          status: TransactionStatus.planned,
        ),
      ];
      final sem = fixedVariableByMonth(
        planned,
        ReportFilter(),
        months: [nov],
        tree: _tree,
        today: _meioNov,
      );
      final com = fixedVariableByMonth(
        planned,
        ReportFilter(includePlanned: true),
        months: [nov],
        tree: _tree,
        today: _meioNov,
      );
      expect(sem.single.totalCents, 0);
      expect(com.single.totalCents, 70000);
    });

    test('flow income: categoryIds é ignorado, a despesa segue inteira', () {
      final items = fixedVariableByMonth(
        fixedBase(),
        ReportFilter(flow: ReportFlow.income, categoryIds: const {'tra'}),
        months: [out, nov],
        tree: _tree,
        today: _hoje,
      );
      expect(items[0].totalCents, 220000);
      expect(items[1].totalCents, 200000);
    });
  });
}
