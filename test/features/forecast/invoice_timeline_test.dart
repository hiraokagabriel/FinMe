import 'package:finme/features/accounts/domain/account.dart';
import 'package:finme/features/cards/domain/invoice.dart';
import 'package:finme/features/cards/domain/payment_card.dart';
import 'package:finme/features/forecast/domain/forecast.dart';
import 'package:finme/features/forecast/domain/invoice_timeline.dart';
import 'package:finme/features/recurring/domain/recurring_rule.dart';
import 'package:finme/features/transactions/domain/transaction.dart';
import 'package:flutter_test/flutter_test.dart';

final today = DateTime(2026, 11, 14);

Account account(String id, {int cents = 0, bool archived = false}) => Account(
  id: id,
  name: id,
  bankName: 'Banco',
  type: AccountType.checking,
  initialBalanceCents: cents,
  colorValue: 0xFF1565C0,
  archived: archived,
);

// Fecha 25 / vence 4: compra de 14/11 cai na fatura de dezembro (vence 04/12).
PaymentCard card(String id, {String? payment, int closing = 25, int due = 4}) =>
    PaymentCard(
      id: id,
      name: 'Cartão $id',
      bankName: 'Banco',
      brand: CardBrand.visa,
      kind: CardKind.credit,
      last4: '1234',
      closingDay: closing,
      dueDay: due,
      colorValue: 0xFF1565C0,
      paymentAccountId: payment,
    );

Transaction purchase(String id, String cardId, int cents, DateTime date) =>
    Transaction(
      id: id,
      type: TransactionType.expense,
      amountCents: cents,
      date: date,
      description: id,
      cardId: cardId,
    );

List<InvoiceDue> timeline({
  required List<Account> accounts,
  required List<PaymentCard> cards,
  List<Transaction> txs = const [],
  List<RecurringRule> recurring = const [],
  int days = 60,
  int months = 6,
}) {
  final forecast = ForecastService.compute(
    accounts: accounts,
    cards: cards,
    transactions: txs,
    recurring: recurring,
    today: today,
    months: months,
  );
  final invoices = [
    for (final c in cards)
      ...InvoiceService.build(
        card: c,
        transactions: txs.where((t) => t.cardId == c.id),
      ),
  ];
  return invoiceTimeline(forecast: forecast, invoices: invoices, days: days);
}

void main() {
  test('conta sem saldo para a fatura → uncovered', () {
    final items = timeline(
      accounts: [account('A', cents: 100000)],
      cards: [card('X', payment: 'A')],
      txs: [purchase('p1', 'X', 150000, DateTime(2026, 11, 14))],
    );

    expect(items, hasLength(1));
    final due = items.single;
    expect(due.invoice.dueDate, DateTime(2026, 12, 4));
    expect(due.date, DateTime(2026, 12, 4));
    expect(due.amountCents, 150000);
    expect(due.accountId, 'A');
    expect(due.accountBalanceAfterCents, -50000);
    expect(due.uncovered, isTrue);
    expect(due.needsAttention, isTrue);
    expect(due.overdue, isFalse);
  });

  test('cartão sem paymentAccountId → sem conta', () {
    final items = timeline(
      accounts: [account('A', cents: 100000)],
      cards: [card('Y')],
      txs: [purchase('p1', 'Y', 100000, DateTime(2026, 11, 14))],
    );

    final due = items.single;
    expect(due.hasAccount, isFalse);
    expect(due.accountBalanceAfterCents, isNull);
    expect(due.needsAttention, isTrue);
  });

  test('conta de pagamento arquivada → tratada como sem conta', () {
    final items = timeline(
      accounts: [account('A', cents: 100000, archived: true)],
      cards: [card('X', payment: 'A')],
      txs: [purchase('p1', 'X', 100000, DateTime(2026, 11, 14))],
    );

    final due = items.single;
    expect(due.hasAccount, isFalse);
    expect(due.accountBalanceAfterCents, isNull);
    expect(due.needsAttention, isTrue);
  });

  test('fatura vencida não paga → date é hoje e overdue', () {
    final items = timeline(
      accounts: [account('A', cents: 500000)],
      cards: [card('X', payment: 'A')],
      txs: [purchase('p1', 'X', 150000, DateTime(2026, 10, 10))],
    );

    final due = items.single;
    expect(due.invoice.dueDate, DateTime(2026, 11, 4));
    expect(due.date, today);
    expect(due.overdue, isTrue);
    expect(due.uncovered, isFalse);
  });

  test(
    'horizonte: vencimento em 90 dias some com days 60 e aparece com 120',
    () {
      final cards = [card('Z', payment: 'A', closing: 5, due: 12)];
      final accounts = [account('A', cents: 100000)];
      final txs = [purchase('p1', 'Z', 80000, DateTime(2027, 1, 10))];

      expect(timeline(accounts: accounts, cards: cards, txs: txs), isEmpty);

      final items = timeline(
        accounts: accounts,
        cards: cards,
        txs: txs,
        days: 120,
        months: 6,
      );
      expect(items, hasLength(1));
      expect(items.single.date, DateTime(2027, 2, 12));
    },
  );

  test('mesmo dia na mesma conta: saldo-após inclui faturas e salário', () {
    final items = timeline(
      accounts: [account('A', cents: 100000)],
      cards: [
        card('X', payment: 'A'),
        card('W', payment: 'A'),
      ],
      txs: [
        purchase('p1', 'X', 150000, DateTime(2026, 11, 14)),
        purchase('p2', 'W', 50000, DateTime(2026, 11, 14)),
      ],
      recurring: [
        RecurringRule(
          id: 'sal',
          description: 'Salário',
          type: TransactionType.income,
          amountCents: 30000,
          frequency: Frequency.monthly,
          startDate: DateTime(2026, 12, 4),
          accountId: 'A',
        ),
      ],
    );

    expect(items, hasLength(2));
    for (final due in items) {
      expect(due.date, DateTime(2026, 12, 4));
      expect(due.accountBalanceAfterCents, -70000);
    }
  });

  test('fatura paga não aparece', () {
    final items = timeline(
      accounts: [account('A', cents: 100000)],
      cards: [card('X', payment: 'A')],
      txs: [
        purchase('p1', 'X', 150000, DateTime(2026, 11, 14)),
        Transaction(
          id: 'pg',
          type: TransactionType.invoicePayment,
          amountCents: 150000,
          date: DateTime(2026, 11, 20),
          description: 'Pagamento',
          cardId: 'X',
          accountId: 'A',
          invoiceKey: '2026-12',
        ),
      ],
    );

    expect(items, isEmpty);
  });
}
