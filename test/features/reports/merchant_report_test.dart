import 'package:finme/core/models/year_month.dart';
import 'package:finme/features/categories/domain/category_tree.dart';
import 'package:finme/features/reports/domain/merchant_report.dart';
import 'package:finme/features/reports/domain/report_filter.dart';
import 'package:finme/features/transactions/domain/installments.dart';
import 'package:finme/features/transactions/domain/transaction.dart';
import 'package:flutter_test/flutter_test.dart';

final DateTime _hoje = DateTime(2026, 11, 30);

final CategoryTree _tree = CategoryTree([]);

Transaction _tx(
  String id,
  DateTime date,
  int cents, {
  String description = 'x',
  String? imported,
  TransactionType type = TransactionType.expense,
  String? accountId = 'A',
  String? categoryId,
  TransactionStatus status = TransactionStatus.paid,
}) => Transaction(
  id: id,
  type: type,
  amountCents: cents,
  date: date,
  description: description,
  accountId: accountId,
  categoryId: categoryId,
  status: status,
  importedDescription: imported,
);

/// (key, label, totalCents, purchaseCount, averageCents, lastDate)
List<(String, String, int, int, int, DateTime)> _rows(
  List<MerchantTotal> list,
) => [
  for (final m in list)
    (m.key, m.label, m.totalCents, m.purchaseCount, m.averageCents, m.lastDate),
];

/// Exemplo de §5.31 (estabelecimentos).
List<Transaction> _exemplo() => [
  _tx(
    'u1',
    DateTime(2026, 9, 10),
    2500,
    description: 'Uber',
    imported: 'UBER *TRIP 8X7Y2 SAO PAULO BR',
  ),
  _tx(
    'u2',
    DateTime(2026, 10, 20),
    3500,
    description: 'Uber',
    imported: 'UBER *TRIP 1A2B3 SAO PAULO BR',
  ),
  _tx('u3', DateTime(2026, 11, 5), 1500, description: 'Uber Trip'),
  _tx(
    'i1',
    DateTime(2026, 9, 12),
    4000,
    description: 'IFOOD*RESTAURANTE 12/09',
  ),
  _tx(
    'i2',
    DateTime(2026, 11, 12),
    6000,
    description: 'iFood*Restaurante 12/11',
  ),
  ...buildInstallments(
    base: _tx('l0', DateTime(2026, 9, 20), 30000, description: 'LOJA EXEMPLO'),
    count: 3,
    groupId: 'g-loja',
  ),
  _tx('n1', DateTime(2026, 10, 1), 700, description: '123456'),
  _tx(
    's1',
    DateTime(2026, 11, 5),
    500000,
    description: 'Salário',
    type: TransactionType.income,
  ),
];

void main() {
  group('merchantKey', () {
    test('importedDescription vence description', () {
      final t = _tx(
        't',
        DateTime(2026, 11, 3),
        100,
        description: 'Mercado Manual',
        imported: 'MERCADO ABC',
      );
      expect(merchantKey(t), 'MERCADO ABC');
    });

    test('descrição só de dígitos sem importedDescription → foldText', () {
      final t = _tx('t', DateTime(2026, 11, 3), 100, description: '123456');
      expect(merchantKey(t), '123456');
    });

    test('memo por texto bruto dá a mesma chave', () {
      final memo = <String, String>{};
      final t = _tx(
        't',
        DateTime(2026, 11, 3),
        100,
        description: 'Uber',
        imported: 'UBER *TRIP 8X7Y2 SAO PAULO BR',
      );
      expect(merchantKey(t, memo), 'UBER TRIP');
      expect(merchantKey(t, memo), 'UBER TRIP');
      expect(memo, {'UBER *TRIP 8X7Y2 SAO PAULO BR': 'UBER TRIP'});
    });
  });

  group('topMerchants', () {
    test('exemplo de §5.31, período 2026-09..2026-11, despesas', () {
      final list = topMerchants(
        _exemplo(),
        ReportFilter(),
        from: const YearMonth(2026, 9),
        to: const YearMonth(2026, 11),
        tree: _tree,
        today: _hoje,
      );
      expect(_rows(list), [
        (
          'LOJA EXEMPLO',
          'LOJA EXEMPLO',
          30000,
          1,
          30000,
          DateTime(2026, 11, 20),
        ),
        (
          'IFOOD RESTAURANTE',
          'iFood*Restaurante 12/11',
          10000,
          2,
          5000,
          DateTime(2026, 11, 12),
        ),
        ('UBER TRIP', 'Uber Trip', 7500, 3, 2500, DateTime(2026, 11, 5)),
        ('123456', '123456', 700, 1, 700, DateTime(2026, 10, 1)),
      ]);
    });

    test('período 2026-10..2026-11', () {
      final list = topMerchants(
        _exemplo(),
        ReportFilter(),
        from: const YearMonth(2026, 10),
        to: const YearMonth(2026, 11),
        tree: _tree,
        today: _hoje,
      );
      expect(
        [for (final m in list) (m.key, m.totalCents, m.purchaseCount)],
        [
          ('LOJA EXEMPLO', 20000, 1),
          ('IFOOD RESTAURANTE', 6000, 1),
          ('UBER TRIP', 5000, 2),
          ('123456', 700, 1),
        ],
      );
    });

    test('flow income só traz a receita (com conta)', () {
      final list = topMerchants(
        _exemplo(),
        ReportFilter(flow: ReportFlow.income),
        from: const YearMonth(2026, 9),
        to: const YearMonth(2026, 11),
        tree: _tree,
        today: _hoje,
      );
      expect(_rows(list), [
        ('SALARIO', 'Salário', 500000, 1, 500000, DateTime(2026, 11, 5)),
      ]);
    });

    test('empate de total → mais compras primeiro; depois key asc', () {
      final txs = [
        _tx('a1', DateTime(2026, 11, 1), 500, description: 'ZETA'),
        _tx('a2', DateTime(2026, 11, 2), 500, description: 'ZETA'),
        _tx('b1', DateTime(2026, 11, 1), 1000, description: 'BETA'),
        _tx('c1', DateTime(2026, 11, 1), 1000, description: 'ALFA'),
      ];
      final list = topMerchants(
        txs,
        ReportFilter(),
        from: const YearMonth(2026, 11),
        to: const YearMonth(2026, 11),
        tree: _tree,
        today: _hoje,
      );
      expect([for (final m in list) m.key], ['ZETA', 'ALFA', 'BETA']);
    });

    test('categoryId vem da transação mais recente (empate → maior id)', () {
      final txs = [
        _tx(
          'a',
          DateTime(2026, 11, 10),
          100,
          description: 'LOJA',
          categoryId: 'mer',
        ),
        _tx(
          'b',
          DateTime(2026, 11, 12),
          100,
          description: 'LOJA',
          categoryId: 'ali',
        ),
        _tx(
          'c',
          DateTime(2026, 11, 12),
          100,
          description: 'LOJA',
          categoryId: 'tra',
        ),
      ];
      final list = topMerchants(
        txs,
        ReportFilter(),
        from: const YearMonth(2026, 11),
        to: const YearMonth(2026, 11),
        tree: _tree,
        today: _hoje,
      );
      expect(list.single.categoryId, 'tra');
      expect(list.single.lastDate, DateTime(2026, 11, 12));
    });

    test('ticket médio arredonda (3002 / 3 → 1001)', () {
      final txs = [
        _tx('a', DateTime(2026, 11, 1), 1000, description: 'X'),
        _tx('b', DateTime(2026, 11, 2), 1000, description: 'X'),
        _tx('c', DateTime(2026, 11, 3), 1002, description: 'X'),
      ];
      final list = topMerchants(
        txs,
        ReportFilter(),
        from: const YearMonth(2026, 11),
        to: const YearMonth(2026, 11),
        tree: _tree,
        today: _hoje,
      );
      expect(list.single.totalCents, 3002);
      expect(list.single.averageCents, 1001);
    });

    test('exclui fora do período, provisionado e outra conta', () {
      final txs = [
        _tx('o', DateTime(2026, 8, 31), 50000, description: 'FORA'),
        _tx(
          'p',
          DateTime(2026, 11, 3),
          9000,
          description: 'PLANEJADO',
          status: TransactionStatus.planned,
        ),
        _tx(
          'x',
          DateTime(2026, 11, 3),
          800,
          description: 'OUTRA',
          accountId: 'B',
        ),
        _tx('ok', DateTime(2026, 11, 3), 300, description: 'DENTRO'),
      ];
      final base = topMerchants(
        txs,
        ReportFilter(accountIds: const {'A'}),
        from: const YearMonth(2026, 9),
        to: const YearMonth(2026, 11),
        tree: _tree,
        today: _hoje,
      );
      expect([for (final m in base) m.key], ['DENTRO']);

      final withPlanned = topMerchants(
        txs,
        ReportFilter(accountIds: const {'A'}, includePlanned: true),
        from: const YearMonth(2026, 9),
        to: const YearMonth(2026, 11),
        tree: _tree,
        today: _hoje,
      );
      expect([for (final m in withPlanned) m.key], ['PLANEJADO', 'DENTRO']);
    });

    test('compra paga com data futura no mês atual não entra', () {
      final txs = [
        _tx('f1', DateTime(2026, 11, 20), 9000, description: 'FUTURA'),
        _tx('ok', DateTime(2026, 11, 3), 300, description: 'DENTRO'),
      ];
      final list = topMerchants(
        txs,
        ReportFilter(includePlanned: true),
        from: const YearMonth(2026, 11),
        to: const YearMonth(2026, 11),
        tree: _tree,
        today: DateTime(2026, 11, 15),
      );
      expect([for (final m in list) m.key], ['DENTRO']);
    });
  });
}
