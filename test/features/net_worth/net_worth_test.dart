import 'package:finme/core/models/year_month.dart';
import 'package:finme/features/accounts/domain/account.dart';
import 'package:finme/features/cards/domain/payment_card.dart';
import 'package:finme/features/debts/domain/debt.dart';
import 'package:finme/features/forecast/domain/forecast.dart';
import 'package:finme/features/net_worth/domain/asset.dart';
import 'package:finme/features/net_worth/domain/net_worth.dart';
import 'package:finme/features/transactions/domain/installments.dart';
import 'package:finme/features/transactions/domain/transaction.dart';
import 'package:flutter_test/flutter_test.dart';

DateTime d(int day, int month, [int year = 2026]) => DateTime(year, month, day);

final today = d(15, 11);

Account account(
  String id,
  AccountType type,
  int initial, {
  bool archived = false,
}) => Account(
  id: id,
  name: id,
  bankName: 'Banco',
  type: type,
  initialBalanceCents: initial,
  colorValue: 0,
  archived: archived,
);

PaymentCard cardK({bool archived = false, CardKind kind = CardKind.credit}) =>
    PaymentCard(
      id: 'K',
      name: 'Cartão K',
      bankName: 'Banco',
      brand: CardBrand.visa,
      kind: kind,
      last4: '1234',
      closingDay: 28,
      dueDay: 5,
      colorValue: 0,
      paymentAccountId: 'A',
      archived: archived,
    );

Transaction tx(
  String id,
  TransactionType type,
  int cents,
  DateTime date, {
  String? accountId,
  String? cardId,
  String? invoiceKey,
  TransactionStatus status = TransactionStatus.paid,
}) => Transaction(
  id: id,
  type: type,
  amountCents: cents,
  date: date,
  description: id,
  accountId: accountId,
  cardId: cardId,
  invoiceKey: invoiceKey,
  status: status,
);

/// Compra de 120000 em 3× em 15/10 no cartão K (40000 em 15/10, 15/11 e 15/12).
List<Transaction> compraParcelada() => buildInstallments(
  base: tx('base', TransactionType.expense, 120000, d(15, 10), cardId: 'K'),
  count: 3,
  groupId: 'g1',
);

/// Exemplo de SPEC §5.26: contas A e Inv (X arquivada), cartão K, ativos e dívidas d1 e d2.
List<Transaction> exemploTxs() => [
  tx('r1', TransactionType.income, 300000, d(5, 10), accountId: 'A'),
  tx('e1', TransactionType.expense, 50000, d(10, 11), accountId: 'A'),
  tx(
    'p0',
    TransactionType.expense,
    70000,
    d(20, 11),
    accountId: 'A',
    status: TransactionStatus.planned,
  ),
  tx('r2', TransactionType.income, 20000, d(10, 11), accountId: 'A'),
  tx('k0', TransactionType.expense, 30000, d(5, 9), cardId: 'K'),
  ...compraParcelada(),
  tx(
    'pay1',
    TransactionType.invoicePayment,
    30000,
    d(5, 10),
    accountId: 'A',
    cardId: 'K',
    invoiceKey: '2026-10',
  ),
];

final exemploContas = [
  account('A', AccountType.checking, 100000),
  account('Inv', AccountType.investment, 500000),
  account('X', AccountType.checking, 999999, archived: true),
];

final exemploAtivos = [
  Asset(
    id: 'carro',
    name: 'Carro',
    kind: AssetKind.vehicle,
    snapshots: [
      AssetSnapshot(id: 's1', date: d(1, 8), valueCents: 4000000),
      AssetSnapshot(id: 's2', date: d(1, 11), valueCents: 3800000),
    ],
  ),
  Asset(
    id: 'tesouro',
    name: 'Tesouro',
    kind: AssetKind.investment,
    snapshots: [AssetSnapshot(id: 't1', date: d(10, 10), valueCents: 200000)],
  ),
];

final exemploDividas = [
  Debt(
    id: 'd1',
    person: 'Ana',
    direction: DebtDirection.owedToMe,
    amountCents: 50000,
    date: d(1, 10),
    dueDate: d(30, 11),
    description: 'Show',
    payments: [
      DebtPayment(
        id: 'p1',
        date: d(10, 11),
        amountCents: 20000,
        transactionId: 't1',
      ),
    ],
  ),
  Debt(
    id: 'd2',
    person: 'Bruno',
    direction: DebtDirection.iOwe,
    amountCents: 80000,
    date: d(20, 9),
    dueDate: d(1, 12),
  ),
];

List<NetWorthPoint> historico({
  List<Transaction>? txs,
  List<Account>? contas,
  List<PaymentCard>? cartoes,
  int months = 3,
}) => netWorthHistory(
  accounts: contas ?? exemploContas,
  cards: cartoes ?? [cardK()],
  transactions: txs ?? exemploTxs(),
  assets: exemploAtivos,
  debts: exemploDividas,
  today: today,
  months: months,
);

void main() {
  group('netWorthHistory — exemplo de §5.26', () {
    test('set, out e nov com patrimônio líquido e componentes', () {
      final history = historico();

      expect(history.length, 3);
      expect(history.map((p) => p.date).toList(), [
        d(30, 9),
        d(31, 10),
        d(15, 11),
      ]);
      expect(history.map((p) => p.month).toList(), [
        const YearMonth(2026, 9),
        const YearMonth(2026, 10),
        const YearMonth(2026, 11),
      ]);
      expect(history.map((p) => p.accountsCents).toList(), [
        600000,
        870000,
        840000,
      ]);
      expect(history.map((p) => p.assetsCents).toList(), [
        4000000,
        4200000,
        4000000,
      ]);
      expect(history.map((p) => p.receivableCents).toList(), [0, 50000, 30000]);
      expect(history.map((p) => p.payableCents).toList(), [
        80000,
        80000,
        80000,
      ]);
      expect(history.map((p) => p.cardDebtCents).toList(), [
        30000,
        120000,
        120000,
      ]);
      expect(history.map((p) => p.netCents).toList(), [
        4490000,
        4920000,
        4670000,
      ]);
    });

    test('último saldo de contas == Forecast.currentTotalCents', () {
      final history = historico();
      final forecast = ForecastService.compute(
        accounts: exemploContas,
        cards: [cardK()],
        transactions: exemploTxs(),
        recurring: const [],
        today: today,
      );

      expect(history.last.accountsCents, forecast.currentTotalCents);
      expect(history.last.accountsCents, 840000);
    });

    test('estorno de 10000 no cartão em 12/11 → cartão de nov 110000', () {
      final txs = [
        ...exemploTxs(),
        tx('est', TransactionType.income, 10000, d(12, 11), cardId: 'K'),
      ];

      expect(historico(txs: txs).last.cardDebtCents, 110000);
    });

    test(
      'invoicePayment de 40000 de A em 20/11 → cartão 80000, contas 800000, líquido igual',
      () {
        final txs = [
          ...exemploTxs(),
          tx(
            'pay2',
            TransactionType.invoicePayment,
            40000,
            d(20, 11),
            accountId: 'A',
            cardId: 'K',
            invoiceKey: '2026-11',
          ),
        ];
        final last = historico(txs: txs).last;

        expect(last.cardDebtCents, 80000);
        expect(last.accountsCents, 800000);
        expect(last.netCents, 4670000);
      },
    );

    test(
      'pagamento maior que a dívida do cartão → cartão 0, nunca negativo',
      () {
        final debt = cardDebtAt(
          cards: [cardK()],
          transactions: [
            tx('k0', TransactionType.expense, 30000, d(5, 9), cardId: 'K'),
            tx(
              'pay',
              TransactionType.invoicePayment,
              50000,
              d(5, 10),
              accountId: 'A',
              cardId: 'K',
            ),
          ],
          date: today,
          allPayments: true,
        );

        expect(debt, 0);
      },
    );
  });

  group('cardPurchaseDate e cardDebtAt', () {
    test('2ª parcela de compra de 31/01/2026 em 3× → compra em 28/01/2026', () {
      final installments = buildInstallments(
        base: tx('base', TransactionType.expense, 90000, d(31, 1), cardId: 'K'),
        count: 3,
        groupId: 'g2',
      );

      expect(installments[1].date, d(28, 2));
      expect(cardPurchaseDate(installments[1]), d(28, 1));
      expect(cardPurchaseDate(installments[0]), d(31, 1));
    });

    test('cartão de débito com despesa paga não entra na dívida de cartão', () {
      final debt = cardDebtAt(
        cards: [cardK(kind: CardKind.debit)],
        transactions: [
          tx('dd', TransactionType.expense, 30000, d(5, 11), cardId: 'K'),
        ],
        date: today,
        allPayments: true,
      );

      expect(debt, 0);
    });

    test('cartão sem lançamento materializado → dívida 0', () {
      expect(
        cardDebtAt(
          cards: [cardK()],
          transactions: const [],
          date: today,
          allPayments: true,
        ),
        0,
      );
    });

    test('pagamento de fatura provisionado não abate a dívida do cartão', () {
      final expense = tx(
        'k0',
        TransactionType.expense,
        30000,
        d(5, 9),
        cardId: 'K',
      );
      final planned = tx(
        'pay-p',
        TransactionType.invoicePayment,
        10000,
        d(5, 11),
        accountId: 'A',
        cardId: 'K',
        status: TransactionStatus.planned,
      );
      final paid = tx(
        'pay-ok',
        TransactionType.invoicePayment,
        5000,
        d(5, 11),
        accountId: 'A',
        cardId: 'K',
      );

      int debtOf(List<Transaction> txs, {bool allPayments = false}) =>
          cardDebtAt(
            cards: [cardK()],
            transactions: txs,
            date: today,
            allPayments: allPayments,
          );

      expect(debtOf([expense, planned]), 30000);
      expect(debtOf([expense, planned], allPayments: true), 30000);
      expect(debtOf([expense, planned, paid]), 25000);
    });

    test('cartão arquivado com saldo devedor entra', () {
      final debt = cardDebtAt(
        cards: [cardK(archived: true)],
        transactions: [
          tx('k0', TransactionType.expense, 30000, d(5, 9), cardId: 'K'),
        ],
        date: today,
        allPayments: true,
      );

      expect(debt, 30000);
    });
  });

  test('netWorthHistory(months: 24) → 24 pontos em ordem, último em hoje', () {
    final history = historico(months: 24);

    expect(history.length, 24);
    expect(history.first.month, const YearMonth(2024, 12));
    expect(history.last.month, const YearMonth(2026, 11));
    expect(history.last.date, today);
    for (var i = 1; i < history.length; i++) {
      expect(history[i].month > history[i - 1].month, isTrue);
    }
  });
}
