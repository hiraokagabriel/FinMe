import 'package:finme/core/models/year_month.dart';
import 'package:finme/features/accounts/domain/account.dart';
import 'package:finme/features/accounts/domain/monthly_history.dart';
import 'package:finme/features/cards/domain/payment_card.dart';
import 'package:finme/features/transactions/domain/transaction.dart';
import 'package:flutter_test/flutter_test.dart';

final _today = DateTime(2026, 11, 14);

Account _account(String id, int initial, {bool archived = false}) => Account(
  id: id,
  name: id,
  bankName: '',
  type: AccountType.checking,
  initialBalanceCents: initial,
  colorValue: 0,
  archived: archived,
);

PaymentCard _creditCard(String id) => PaymentCard(
  id: id,
  name: id,
  bankName: '',
  brand: CardBrand.visa,
  kind: CardKind.credit,
  last4: '0000',
  closingDay: 5,
  dueDay: 12,
  colorValue: 0,
  paymentAccountId: 'A',
);

Transaction _tx(
  String id,
  TransactionType type,
  int amount,
  DateTime date, {
  String? accountId,
  String? cardId,
  String? toAccountId,
  TransactionStatus status = TransactionStatus.paid,
}) => Transaction(
  id: id,
  type: type,
  amountCents: amount,
  date: date,
  description: id,
  accountId: accountId,
  cardId: cardId,
  toAccountId: toAccountId,
  status: status,
);

List<MonthSnapshot> _history(
  List<Transaction> txs, {
  int months = 6,
  DateTime? today,
}) => monthlyHistory(
  accounts: [_account('A', 100000), _account('B', 50000, archived: true)],
  cards: [_creditCard('C')],
  transactions: txs,
  today: today ?? _today,
  months: months,
);

void main() {
  test('sem transações: 6 meses em ordem, saldo inicial das ativas', () {
    final h = _history([]);
    expect(h.length, 6);
    expect(h.map((s) => s.month.key).toList(), [
      '2026-06',
      '2026-07',
      '2026-08',
      '2026-09',
      '2026-10',
      '2026-11',
    ]);
    expect(h.every((s) => s.endBalanceCents == 100000), isTrue);
    expect(h.every((s) => s.expenseCents == 0), isTrue);
  });

  test('receita paga muda o saldo a partir do mês dela; provisionada não', () {
    final h = _history([
      _tx(
        'r',
        TransactionType.income,
        20000,
        DateTime(2026, 9, 10),
        accountId: 'A',
      ),
      _tx(
        'p',
        TransactionType.expense,
        5000,
        DateTime(2026, 9, 12),
        accountId: 'A',
        status: TransactionStatus.planned,
      ),
    ]);
    expect(h.map((s) => s.endBalanceCents).toList(), [
      100000,
      100000,
      100000,
      120000,
      120000,
      120000,
    ]);
    expect(h.last.expenseCents, 0);
  });

  test('lançamento futuro entra no último saldo, não nas despesas do mês', () {
    final txs = [
      _tx(
        'f',
        TransactionType.expense,
        700,
        DateTime(2026, 11, 20),
        accountId: 'A',
      ),
      _tx(
        'b',
        TransactionType.income,
        9999,
        DateTime(2026, 11, 1),
        accountId: 'B',
      ),
    ];
    final h = _history(txs);
    expect(h.last.endBalanceCents, 100000 - 700);
    expect(h.last.expenseCents, 0);
    expect(h[4].endBalanceCents, 100000);
  });

  test('cartão de crédito não move saldo; pagamento de fatura move', () {
    final h = _history([
      _tx(
        'cc',
        TransactionType.expense,
        3000,
        DateTime(2026, 10, 5),
        cardId: 'C',
      ),
      _tx(
        'fat',
        TransactionType.invoicePayment,
        4000,
        DateTime(2026, 11, 10),
        accountId: 'A',
        cardId: 'C',
      ),
    ]);
    expect(h[4].expenseCents, 3000);
    expect(h[4].endBalanceCents, 100000);
    expect(h.last.endBalanceCents, 96000);
    expect(h.last.expenseCents, 0);
  });

  test('expenseUntilDay conta até o dia e clampa no fim do mês', () {
    final txs = [
      _tx('a', TransactionType.expense, 100, DateTime(2026, 10, 1)),
      _tx('b', TransactionType.expense, 200, DateTime(2026, 10, 14)),
      _tx('c', TransactionType.expense, 400, DateTime(2026, 10, 15)),
      _tx('d', TransactionType.expense, 800, DateTime(2026, 2, 28)),
    ];
    expect(expenseUntilDay(txs, const YearMonth(2026, 10), 14), 300);
    expect(expenseUntilDay(txs, const YearMonth(2026, 2), 31), 800);
  });

  test('today em 15/01/2027: seis meses cruzam dez/2026 com saldos certos', () {
    final txs = [
      _tx(
        'r',
        TransactionType.income,
        20000,
        DateTime(2026, 10, 10),
        accountId: 'A',
      ),
      _tx(
        'd',
        TransactionType.expense,
        5000,
        DateTime(2026, 12, 20),
        accountId: 'A',
      ),
      _tx(
        'i',
        TransactionType.income,
        1000,
        DateTime(2027, 1, 5),
        accountId: 'A',
      ),
      _tx(
        'e',
        TransactionType.expense,
        700,
        DateTime(2027, 1, 10),
        accountId: 'A',
      ),
    ];
    final h = _history(txs, today: DateTime(2027, 1, 15));
    expect(h.map((s) => s.month.key).toList(), [
      '2026-08',
      '2026-09',
      '2026-10',
      '2026-11',
      '2026-12',
      '2027-01',
    ]);
    expect(h.map((s) => s.endBalanceCents).toList(), [
      100000,
      100000,
      120000,
      120000,
      115000,
      115300,
    ]);
    expect(h.map((s) => s.expenseCents).toList(), [0, 0, 0, 0, 5000, 700]);
  });

  test(
    'expenseUntilDay: dia 31 em fev/2026 clampa em 28; dia 29 em fev/2028 é bissexto',
    () {
      final feb26 = [
        _tx('a', TransactionType.expense, 300, DateTime(2026, 2, 28)),
      ];
      expect(expenseUntilDay(feb26, const YearMonth(2026, 2), 31), 300);
      expect(expenseUntilDay(feb26, const YearMonth(2026, 2), 27), 0);

      final feb28 = [
        _tx('b', TransactionType.expense, 500, DateTime(2028, 2, 29)),
      ];
      expect(expenseUntilDay(feb28, const YearMonth(2028, 2), 29), 500);
      expect(expenseUntilDay(feb28, const YearMonth(2028, 2), 28), 0);
    },
  );

  test('deltaRatio', () {
    expect(deltaRatio(1000, 1500), 0.5);
    expect(deltaRatio(-1000, -500), 0.5);
    expect(deltaRatio(1000, 0), -1.0);
    expect(deltaRatio(0, 10), isNull);
  });
}
