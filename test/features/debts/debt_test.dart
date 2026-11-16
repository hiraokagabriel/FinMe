import 'package:finme/features/debts/domain/debt.dart';
import 'package:finme/features/debts/domain/debt_math.dart';
import 'package:finme/features/forecast/domain/forecast.dart';
import 'package:finme/features/transactions/domain/transaction.dart';
import 'package:flutter_test/flutter_test.dart';

DateTime d(int day, int month, [int year = 2026]) => DateTime(year, month, day);

final today = d(15, 11);

Debt ana({List<DebtPayment> payments = const []}) => Debt(
  id: 'd1',
  person: 'Ana',
  direction: DebtDirection.owedToMe,
  amountCents: 50000,
  date: d(1, 10),
  dueDate: d(30, 11),
  description: 'Show',
  payments: payments,
);

Debt bruno() => Debt(
  id: 'd2',
  person: 'Bruno',
  direction: DebtDirection.iOwe,
  amountCents: 80000,
  date: d(20, 9),
  dueDate: d(1, 12),
);

void main() {
  group('Debt — construção e normalização', () {
    test('pessoa com espaços vira trim; descrição só espaços vira null', () {
      final debt = Debt(
        id: 'x',
        person: '  Ana ',
        direction: DebtDirection.owedToMe,
        amountCents: 100,
        date: d(1, 10),
        description: '  ',
      );
      expect(debt.person, 'Ana');
      expect(debt.description, isNull);
    });

    test(
      'pagamentos fora de ordem ficam por (data, id) e a lista é imutável',
      () {
        final p2 = DebtPayment(id: 'b', date: d(15, 11), amountCents: 1000);
        final p1 = DebtPayment(id: 'a', date: d(10, 11), amountCents: 1000);
        final debt = ana(payments: [p2, p1]);
        expect(debt.payments.map((p) => p.id), ['a', 'b']);
        expect(() => debt.payments.add(p1), throwsUnsupportedError);
      },
    );

    test('copyWith: dueDate null limpa; omitido mantém', () {
      final debt = ana();
      expect(debt.copyWith(dueDate: null).dueDate, isNull);
      expect(debt.copyWith(amountCents: 60000).dueDate, d(30, 11));
      expect(debt.copyWith(description: null).description, isNull);
    });
  });

  group('Debt — serialização', () {
    test(
      'round-trip com descrição, vencimento e 2 pagamentos (um sem transactionId)',
      () {
        final debt = ana(
          payments: [
            DebtPayment(
              id: 'p1',
              date: d(10, 11),
              amountCents: 20000,
              transactionId: 't1',
            ),
            DebtPayment(id: 'p2', date: d(15, 11), amountCents: 5000),
          ],
        );
        expect(Debt.fromMap(debt.toMap()), debt);
      },
    );

    test('round-trip sem descrição e sem vencimento', () {
      final debt = Debt(
        id: 'd4',
        person: 'Carla',
        direction: DebtDirection.iOwe,
        amountCents: 5000,
        date: d(5, 10),
      );
      final map = debt.toMap();
      expect(map.containsKey('description'), isFalse);
      expect(map.containsKey('dueDate'), isFalse);
      expect(Debt.fromMap(map), debt);
    });

    test('fromMap sem payments → []; direção desconhecida → iOwe', () {
      final map = bruno().toMap()
        ..remove('payments')
        ..['direction'] = 'desconhecida';
      final debt = Debt.fromMap(map);
      expect(debt.payments, isEmpty);
      expect(debt.direction, DebtDirection.iOwe);
    });

    test('pagamento inválido é ignorado; a dívida é preservada', () {
      final map = ana().toMap()
        ..['payments'] = [
          {'id': 'ok', 'date': '20261110', 'amountCents': 1000},
          {'id': 'zero', 'date': '20261110', 'amountCents': 0},
          {'date': '20261110', 'amountCents': 1000},
          'lixo',
        ];
      final debt = Debt.fromMap(map);
      expect(debt.payments.map((p) => p.id), ['ok']);
      expect(debt.amountCents, 50000);
    });

    test('dado inválido da dívida lança FormatException', () {
      expect(
        () => Debt.fromMap(bruno().toMap()..['amountCents'] = 0),
        throwsFormatException,
      );
      expect(
        () => Debt.fromMap(bruno().toMap()..['person'] = '   '),
        throwsFormatException,
      );
      expect(
        () => Debt.fromMap(bruno().toMap()..remove('id')),
        throwsFormatException,
      );
      expect(
        () => Debt.fromMap(bruno().toMap()..['date'] = '20261330'),
        throwsFormatException,
      );
    });

    test('DebtPayment.fromMap com valor ≤ 0 lança FormatException', () {
      expect(
        () => DebtPayment.fromMap({
          'id': 'p',
          'date': '20261110',
          'amountCents': -1,
        }),
        throwsFormatException,
      );
    });
  });

  group('settleDebt e undoDebtPayment', () {
    test('pagamento parcial de "me devem" cria income e reduz o restante', () {
      final result = settleDebt(
        ana(),
        paymentId: 'p1',
        transactionId: 't1',
        amountCents: 20000,
        date: d(10, 11),
        accountId: 'A',
      );
      final t = result.transaction;
      expect(t.type, TransactionType.income);
      expect(t.amountCents, 20000);
      expect(t.date, d(10, 11));
      expect(t.description, 'Recebido de Ana · Show');
      expect(t.accountId, 'A');
      expect(t.status, TransactionStatus.paid);
      expect(t.categoryId, isNull);

      final debt = result.debt;
      expect(debt.paidCents, 20000);
      expect(debt.remainingCents, 30000);
      expect(debt.settled, isFalse);
      expect(debt.remainingAt(d(15, 11)), 30000);
      expect(debt.remainingAt(d(31, 10)), 50000);
      expect(debt.remainingAt(d(30, 9)), 0);
    });

    test(
      'segundo pagamento quita; desfazer p1 devolve restante e transactionId',
      () {
        final first = settleDebt(
          ana(),
          paymentId: 'p1',
          transactionId: 't1',
          amountCents: 20000,
          date: d(10, 11),
          accountId: 'A',
        ).debt;
        final both = settleDebt(
          first,
          paymentId: 'p2',
          transactionId: 't2',
          amountCents: 30000,
          date: d(15, 11),
          accountId: 'A',
        ).debt;
        expect(both.settled, isTrue);
        expect(isDebtOverdue(both, today), isFalse);

        final undone = undoDebtPayment(both, 'p1');
        expect(undone.debt.remainingCents, 20000);
        expect(undone.transactionId, 't1');

        final missing = undoDebtPayment(both, 'x');
        expect(missing.debt, both);
        expect(missing.transactionId, isNull);
      },
    );

    test('dívida "devo" com categoria: expense com essa categoria', () {
      final result = settleDebt(
        bruno(),
        paymentId: 'p1',
        transactionId: 't1',
        amountCents: 80000,
        date: d(15, 11),
        accountId: 'A',
        categoryId: 'cat-1',
      );
      expect(result.transaction.type, TransactionType.expense);
      expect(result.transaction.description, 'Pago a Bruno');
      expect(result.transaction.categoryId, 'cat-1');
    });
  });

  group('debtPaymentError', () {
    test('ordem de validação e mensagens', () {
      final debt = ana();
      String? err(int cents, DateTime date) => debtPaymentError(
        debt: debt,
        amountCents: cents,
        date: date,
        today: today,
      );
      expect(err(50001, d(10, 11)), 'Restante: R\$ 500,00');
      expect(err(0, d(10, 11)), 'Informe um valor maior que zero');
      expect(err(20000, d(16, 11)), 'A data não pode ser no futuro');
      expect(err(20000, d(30, 9)), 'Data antes do registro da dívida');
      expect(err(20000, d(10, 11)), isNull);
    });
  });

  group('isDebtOverdue e debtTotalsAt', () {
    test('isDebtOverdue: vencimento passado e não quitada', () {
      final d3 = Debt(
        id: 'd3',
        person: 'Bruno',
        direction: DebtDirection.iOwe,
        amountCents: 10000,
        date: d(1, 11),
        dueDate: d(10, 11),
      );
      expect(isDebtOverdue(d3, today), isTrue);
      expect(isDebtOverdue(ana(), today), isFalse);
    });

    test('debtTotalsAt respeita a data e a direção', () {
      final debts = [
        ana(
          payments: [
            DebtPayment(
              id: 'p1',
              date: d(10, 11),
              amountCents: 20000,
              transactionId: 't1',
            ),
          ],
        ),
        bruno(),
        Debt(
          id: 'd3',
          person: 'Bruno',
          direction: DebtDirection.iOwe,
          amountCents: 10000,
          date: d(1, 11),
          dueDate: d(10, 11),
        ),
        Debt(
          id: 'd4',
          person: 'Carla',
          direction: DebtDirection.iOwe,
          amountCents: 5000,
          date: d(5, 10),
        ),
      ];
      final now = debtTotalsAt(debts, today);
      expect(now.receivableCents, 30000);
      expect(now.payableCents, 95000);
      final past = debtTotalsAt(debts, d(30, 9));
      expect(past.receivableCents, 0);
      expect(past.payableCents, 80000);
    });
  });

  group('debtForecastEvents', () {
    test('só "devo" com vencimento e restante gera evento sem conta', () {
      final d2 = bruno();
      final events = debtForecastEvents([
        ana(),
        d2,
        Debt(
          id: 'd4',
          person: 'Carla',
          direction: DebtDirection.iOwe,
          amountCents: 5000,
          date: d(5, 10),
        ),
        Debt(
          id: 'd6',
          person: 'Dani',
          direction: DebtDirection.iOwe,
          amountCents: 7000,
          date: d(1, 8),
          dueDate: d(1, 12),
          payments: [DebtPayment(id: 'p6', date: d(1, 8), amountCents: 7000)],
        ),
      ]);
      expect(events, hasLength(1));
      final e = events.single;
      expect(e.kind, ForecastEventKind.expense);
      expect(e.accountId, isNull);
      expect(e.sourceId, d2.id);
      expect(e.date, d(1, 12));
      expect(e.amountCents, -80000);
      expect(e.description, 'Devo a Bruno');
    });

    test(
      'descrição entra no texto; pagamento parcial reduz o valor do evento',
      () {
        final debt = bruno().copyWith(
          description: 'Cartão',
          payments: [DebtPayment(id: 'p', date: d(1, 10), amountCents: 30000)],
        );
        final e = debtForecastEvents([debt]).single;
        expect(e.description, 'Devo a Bruno · Cartão');
        expect(e.amountCents, -50000);
      },
    );

    test('dívida "devo" de 10/11 vencida (d3) entra com a data original', () {
      final d3 = Debt(
        id: 'd3',
        person: 'Bruno',
        direction: DebtDirection.iOwe,
        amountCents: 10000,
        date: d(1, 11),
        dueDate: d(10, 11),
      );
      expect(debtForecastEvents([d3]).single.date, d(10, 11));
    });
  });

  group('debtsByPerson e debtPeople', () {
    final d1Paid = ana(
      payments: [
        DebtPayment(
          id: 'p1',
          date: d(10, 11),
          amountCents: 20000,
          transactionId: 't1',
        ),
      ],
    );
    final d3 = Debt(
      id: 'd3',
      person: 'Bruno',
      direction: DebtDirection.iOwe,
      amountCents: 10000,
      date: d(1, 11),
      dueDate: d(10, 11),
    );
    final d4 = Debt(
      id: 'd4',
      person: 'Carla',
      direction: DebtDirection.iOwe,
      amountCents: 5000,
      date: d(5, 10),
    );
    final d6 = Debt(
      id: 'd6',
      person: 'Dani',
      direction: DebtDirection.iOwe,
      amountCents: 7000,
      date: d(1, 8),
      dueDate: d(1, 12),
      payments: [DebtPayment(id: 'p6', date: d(1, 8), amountCents: 7000)],
    );

    test('agrupa por pessoa, ignora quitadas e ordena por |líquido|', () {
      final summaries = debtsByPerson([d1Paid, bruno(), d3, d4, d6]);
      expect(summaries.map((s) => s.person), ['Bruno', 'Ana', 'Carla']);

      final brunoSummary = summaries[0];
      expect(brunoSummary.payableCents, 90000);
      expect(brunoSummary.receivableCents, 0);
      expect(brunoSummary.netCents, -90000);
      expect(brunoSummary.openCount, 2);

      final anaSummary = summaries[1];
      expect(anaSummary.receivableCents, 30000);
      expect(anaSummary.netCents, 30000);
      expect(anaSummary.openCount, 1);

      expect(summaries[2].netCents, -5000);
    });

    test('mesma pessoa com caixa e espaços nas pontas forma um grupo', () {
      final extra = Debt(
        id: 'd7',
        person: 'ANA ',
        direction: DebtDirection.iOwe,
        amountCents: 10000,
        date: d(5, 11),
      );
      final summaries = debtsByPerson([d1Paid, bruno(), d3, d4, d6, extra]);
      final anaSummary = summaries.singleWhere((s) => s.person == 'ANA');
      expect(anaSummary.receivableCents, 30000);
      expect(anaSummary.payableCents, 10000);
      expect(anaSummary.netCents, 20000);
      expect(anaSummary.openCount, 2);
    });

    test(
      'debtPeople inclui quitadas, ordena por data da dívida mais recente',
      () {
        expect(debtPeople([d1Paid, bruno(), d3, d4, d6]), [
          'Bruno',
          'Carla',
          'Ana',
          'Dani',
        ]);
      },
    );

    test('sem dívidas em aberto → []', () {
      expect(debtsByPerson([d6]), isEmpty);
    });
  });
}
