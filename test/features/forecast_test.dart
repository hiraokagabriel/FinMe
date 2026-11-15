import 'package:finme/features/accounts/domain/account.dart';
import 'package:finme/features/cards/domain/payment_card.dart';
import 'package:finme/features/forecast/domain/forecast.dart';
import 'package:finme/features/recurring/domain/recurrence.dart';
import 'package:finme/features/recurring/domain/recurring_rule.dart';
import 'package:finme/features/transactions/domain/installments.dart';
import 'package:finme/features/transactions/domain/transaction.dart';
import 'package:flutter_test/flutter_test.dart';

final today = DateTime(2026, 11, 14);

Account acc(String id, {int initial = 0, bool archived = false}) => Account(
  id: id,
  name: 'Conta $id',
  bankName: 'Banco',
  type: AccountType.checking,
  initialBalanceCents: initial,
  colorValue: 0xFF000000,
  archived: archived,
);

PaymentCard card(
  String id, {
  CardKind kind = CardKind.credit,
  String? paymentAccountId,
  int closingDay = 5,
  int dueDay = 12,
}) => PaymentCard(
  id: id,
  name: 'Cartão $id',
  bankName: 'Banco',
  brand: CardBrand.visa,
  kind: kind,
  last4: '0000',
  closingDay: closingDay,
  dueDay: dueDay,
  colorValue: 0xFF000000,
  paymentAccountId: paymentAccountId,
);

Transaction tx(
  String id,
  TransactionType type,
  int cents,
  DateTime date, {
  String? accountId,
  String? cardId,
  String? toAccountId,
  bool planned = false,
  bool boleto = false,
  String? invoiceKey,
  String? description,
}) => Transaction(
  id: id,
  type: type,
  amountCents: cents,
  date: date,
  description: description ?? id,
  accountId: accountId,
  cardId: cardId,
  toAccountId: toAccountId,
  status: planned ? TransactionStatus.planned : TransactionStatus.paid,
  isBoleto: boleto,
  invoiceKey: invoiceKey,
);

RecurringRule rule(
  String id, {
  required String description,
  required TransactionType type,
  required int cents,
  required DateTime start,
  Frequency frequency = Frequency.monthly,
  String? accountId,
  String? cardId,
}) => RecurringRule(
  id: id,
  description: description,
  type: type,
  amountCents: cents,
  frequency: frequency,
  startDate: start,
  accountId: accountId,
  cardId: cardId,
);

ForecastEvent only(Forecast f, String sourceId) =>
    f.events.singleWhere((e) => e.sourceId == sourceId);

int balOn(Forecast f, DateTime d) =>
    f.daily.singleWhere((p) => p.date == d).balanceCents;

void main() {
  test('cenário completo: contas, cartões, parcelas, assinatura, salário, '
      'boleto atrasado, transferência, fatura paga e arquivada', () {
    final salary = rule(
      'S',
      description: 'Salário',
      type: TransactionType.income,
      cents: 500000,
      start: DateTime(2026, 9, 5),
      accountId: 'A',
    );
    final sub = rule(
      'Sub',
      description: 'Streaming',
      type: TransactionType.expense,
      cents: 1990,
      start: DateTime(2026, 10, 3),
      cardId: 'X',
    );
    final installments = buildInstallments(
      base: tx(
        'base',
        TransactionType.expense,
        9000,
        DateTime(2026, 11, 20),
        cardId: 'X',
        description: 'Notebook',
      ),
      count: 3,
      groupId: 'g1',
    );

    final f = ForecastService.compute(
      accounts: [
        acc('A', initial: 100000),
        acc('B', initial: 50000),
        acc('Z', initial: 777777, archived: true),
      ],
      cards: [
        card('X', paymentAccountId: 'A'),
        card('Y'),
      ],
      transactions: [
        ...installments,
        tx(
          'out',
          TransactionType.expense,
          5000,
          DateTime(2026, 10, 10),
          cardId: 'X',
        ),
        tx(
          'pagX',
          TransactionType.invoicePayment,
          5000,
          DateTime(2026, 11, 12),
          accountId: 'A',
          cardId: 'X',
          invoiceKey: '2026-11',
        ),
        tx(
          'mercadoY',
          TransactionType.expense,
          8000,
          DateTime(2026, 10, 20),
          cardId: 'Y',
        ),
        tx(
          'boleto',
          TransactionType.expense,
          20000,
          DateTime(2026, 11, 10),
          accountId: 'B',
          planned: true,
          boleto: true,
          description: 'Boleto Luz',
        ),
        tx(
          'transf',
          TransactionType.transfer,
          10000,
          DateTime(2026, 11, 20),
          accountId: 'A',
          toAccountId: 'B',
          planned: true,
        ),
        tx(
          'zPlanned',
          TransactionType.expense,
          5000,
          DateTime(2026, 11, 25),
          accountId: 'Z',
          planned: true,
        ),
        tx(
          'ahead',
          TransactionType.expense,
          1000,
          DateTime(2027, 5, 1),
          accountId: 'A',
          planned: true,
        ),
        // Ocorrência de dezembro já materializada: não pode duplicar.
        tx(
          occurrenceId(salary, DateTime(2026, 12, 5)),
          TransactionType.income,
          500000,
          DateTime(2026, 12, 5),
          accountId: 'A',
          planned: true,
          description: 'Salário',
        ),
      ],
      recurring: [salary, sub],
      today: today,
    );

    // Saldos: Z arquivada fora; pagamento de Nov já descontado em A.
    expect(f.currentBalances, {'A': 95000, 'B': 50000});
    expect(f.currentTotalCents, 145000);

    // 14 eventos: boleto, fatura Y, 2 da transferência, 5 salários, 5 faturas X.
    expect(f.events, hasLength(14));

    final boleto = only(f, 'boleto');
    expect(boleto.date, today);
    expect(boleto.amountCents, -20000);
    expect(boleto.kind, ForecastEventKind.boleto);
    expect(boleto.accountId, 'B');
    expect(boleto.isProjected, isFalse);

    final invoiceY = only(f, 'Y_2026-11');
    expect(invoiceY.date, today);
    expect(invoiceY.amountCents, -8000);
    expect(invoiceY.kind, ForecastEventKind.invoice);
    expect(invoiceY.accountId, isNull);
    expect(invoiceY.description, 'Fatura Cartão Y');

    final transfers = f.events.where((e) => e.sourceId == 'transf').toList();
    expect(transfers, hasLength(2));
    final origin = transfers.singleWhere((e) => e.accountId == 'A');
    final destination = transfers.singleWhere((e) => e.accountId == 'B');
    expect(origin.amountCents, -10000);
    expect(destination.amountCents, 10000);
    for (final e in transfers) {
      expect(e.kind, ForecastEventKind.transfer);
      expect(e.date, DateTime(2026, 11, 20));
      expect(e.toAccountId, 'B');
    }

    final decSalaries = f.events.where(
      (e) => e.sourceId == occurrenceId(salary, DateTime(2026, 12, 5)),
    );
    expect(decSalaries, hasLength(1));
    expect(decSalaries.single.isProjected, isFalse);

    final projectedSalaries = f.events.where((e) => e.isProjected).toList();
    expect(projectedSalaries.map((e) => e.date), [
      DateTime(2027, 1, 5),
      DateTime(2027, 2, 5),
      DateTime(2027, 3, 5),
      DateTime(2027, 4, 5),
    ]);
    for (final e in projectedSalaries) {
      expect(e.amountCents, 500000);
      expect(e.accountId, 'A');
      expect(e.kind, ForecastEventKind.income);
    }

    // Assinatura no crédito vai para a fatura (projected), nunca vira evento.
    expect(f.events.any((e) => e.description == 'Streaming'), isFalse);

    // Fatura X: Dez (parcela 1 + assinatura), Jan, Fev (parcela 2/3 + assinatura), Mar/Abr só assinatura.
    final invoicesX = {
      'X_2026-12': (DateTime(2026, 12, 12), -4990),
      'X_2027-01': (DateTime(2027, 1, 12), -4990),
      'X_2027-02': (DateTime(2027, 2, 12), -4990),
      'X_2027-03': (DateTime(2027, 3, 12), -1990),
      'X_2027-04': (DateTime(2027, 4, 12), -1990),
    };
    for (final entry in invoicesX.entries) {
      final e = only(f, entry.key);
      expect(e.date, entry.value.$1, reason: entry.key);
      expect(e.amountCents, entry.value.$2, reason: entry.key);
      expect(e.accountId, 'A', reason: entry.key);
      expect(e.kind, ForecastEventKind.invoice);
    }
    // Fatura X de Nov paga integralmente: sem evento.
    expect(f.events.any((e) => e.sourceId == 'X_2026-11'), isFalse);

    // Provisionados fora do horizonte e de conta arquivada: fora.
    expect(f.events.any((e) => e.sourceId == 'zPlanned'), isFalse);
    expect(f.events.any((e) => e.sourceId == 'ahead'), isFalse);

    expect(f.months.map((m) => m.month.key), [
      '2026-11',
      '2026-12',
      '2027-01',
      '2027-02',
      '2027-03',
      '2027-04',
    ]);
    expect(f.months.map((m) => m.incomeCents), [
      0,
      500000,
      500000,
      500000,
      500000,
      500000,
    ]);
    expect(f.months.map((m) => m.expenseCents), [20000, 0, 0, 0, 0, 0]);
    expect(f.months.map((m) => m.invoiceCents), [
      8000,
      4990,
      4990,
      4990,
      1990,
      1990,
    ]);
    expect(f.months.map((m) => m.endBalanceCents), [
      117000,
      612010,
      1107020,
      1602030,
      2100040,
      2598050,
    ]);

    expect(f.daily, hasLength(168));
    expect(f.daily.first.date, today);
    expect(f.daily.last.date, DateTime(2027, 4, 30));
    expect(f.daily.last.balanceCents, 2598050);
    // Transferência é neutra: o consolidado não muda em 20/11.
    expect(balOn(f, DateTime(2026, 11, 19)), 117000);
    expect(balOn(f, DateTime(2026, 11, 20)), 117000);
    expect(balOn(f, DateTime(2026, 12, 5)), 617000);

    expect(f.firstNegativeDate, isNull);
    expect(f.accountNegativeDates, isEmpty);
    expect(f.lowestBalanceCents, 117000);
  });

  test('débito: planejado e recorrência saem da conta do cartão', () {
    final f = ForecastService.compute(
      accounts: [acc('B', initial: 10000)],
      cards: [card('D', kind: CardKind.debit, paymentAccountId: 'B')],
      transactions: [
        tx(
          'p',
          TransactionType.expense,
          3000,
          DateTime(2026, 11, 18),
          cardId: 'D',
          planned: true,
        ),
      ],
      recurring: [
        rule(
          'R',
          description: 'Academia',
          type: TransactionType.expense,
          cents: 1500,
          start: DateTime(2026, 11, 1),
          cardId: 'D',
        ),
      ],
      today: today,
    );

    expect(f.events, hasLength(6));
    expect(f.events.every((e) => e.accountId == 'B'), isTrue);
    expect(only(f, 'p').isProjected, isFalse);
    expect(f.events.where((e) => e.isProjected).map((e) => e.date), [
      DateTime(2026, 12, 1),
      DateTime(2027, 1, 1),
      DateTime(2027, 2, 1),
      DateTime(2027, 3, 1),
      DateTime(2027, 4, 1),
    ]);
    // 10000 - 3000 = 7000 (18/11); - 1500 x5 → -500 em 01/04.
    expect(f.accountNegativeDates, {'B': DateTime(2027, 4, 1)});
    expect(f.firstNegativeDate, DateTime(2027, 4, 1));
    expect(f.lowestBalanceCents, -500);
  });

  test('compra planejada no crédito compõe a fatura, sem evento próprio', () {
    final f = ForecastService.compute(
      accounts: const [],
      cards: [card('X')],
      transactions: [
        tx(
          'p',
          TransactionType.expense,
          1000,
          DateTime(2026, 11, 25),
          cardId: 'X',
          planned: true,
        ),
      ],
      recurring: const [],
      today: today,
    );

    final e = f.events.single;
    expect(e.kind, ForecastEventKind.invoice);
    expect(e.sourceId, 'X_2026-12');
    expect(e.amountCents, -1000);
    expect(e.date, DateTime(2026, 12, 12));
    expect(e.accountId, isNull);
  });

  test(
    'fatura vencida com conta de pagamento arquivada vai só ao consolidado',
    () {
      final f = ForecastService.compute(
        accounts: [acc('Z', initial: 500, archived: true)],
        cards: [card('W', paymentAccountId: 'Z')],
        transactions: [
          tx(
            'c',
            TransactionType.expense,
            4000,
            DateTime(2026, 10, 20),
            cardId: 'W',
          ),
        ],
        recurring: const [],
        today: today,
      );

      final e = f.events.single;
      expect(e.accountId, isNull);
      expect(e.amountCents, -4000);
      // Vencida em 12/11: entra hoje.
      expect(e.date, today);
      expect(f.currentBalances, isEmpty);
      expect(f.firstNegativeDate, today);
      expect(f.lowestBalanceCents, -4000);
    },
  );

  test('months: 1 limita o horizonte ao mês atual', () {
    final f = ForecastService.compute(
      accounts: [acc('A', initial: 1000)],
      cards: const [],
      transactions: [
        tx(
          'ok',
          TransactionType.expense,
          100,
          DateTime(2026, 11, 30),
          accountId: 'A',
          planned: true,
        ),
        tx(
          'fora',
          TransactionType.expense,
          100,
          DateTime(2026, 12, 1),
          accountId: 'A',
          planned: true,
        ),
      ],
      recurring: const [],
      today: today,
      months: 1,
    );

    expect(f.events.map((e) => e.sourceId), ['ok']);
    expect(f.daily, hasLength(17));
    expect(f.daily.last.date, DateTime(2026, 11, 30));
    expect(f.months.single.expenseCents, 100);
    expect(f.months.single.endBalanceCents, 900);
  });

  test('minDays estende o horizonte diário sem mudar o número de meses', () {
    final jan31 = DateTime(2027, 1, 31);
    Forecast run(int minDays) => ForecastService.compute(
      accounts: [acc('A', initial: 1000)],
      cards: const [],
      transactions: const [],
      recurring: const [],
      today: jan31,
      months: 3,
      minDays: minDays,
    );

    expect(run(0).daily.last.date, DateTime(2027, 3, 31));
    final ext = run(60);
    expect(ext.daily.last.date, DateTime(2027, 4, 1));
    expect(ext.months, hasLength(3));
    expect(ext.months.last.month.key, '2027-03');
  });

  test('fatura que vence após o fim dos meses entra só com minDays', () {
    Forecast run(int minDays) => ForecastService.compute(
      accounts: [acc('A', initial: 1000)],
      cards: [card('X', paymentAccountId: 'A', closingDay: 25, dueDay: 1)],
      transactions: [
        tx(
          'c',
          TransactionType.expense,
          4000,
          DateTime(2027, 3, 10),
          cardId: 'X',
        ),
      ],
      recurring: const [],
      today: DateTime(2027, 1, 31),
      months: 3,
      minDays: minDays,
    );

    expect(run(0).events.any((e) => e.sourceId == 'X_2027-04'), isFalse);
    final e = only(run(60), 'X_2027-04');
    expect(e.date, DateTime(2027, 4, 1));
    expect(e.amountCents, -4000);
    expect(e.accountId, 'A');
  });
}
