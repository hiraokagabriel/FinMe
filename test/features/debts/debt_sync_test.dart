import 'package:finme/features/debts/domain/debt.dart';
import 'package:finme/features/debts/domain/debt_math.dart';
import 'package:finme/features/transactions/domain/transaction.dart';
import 'package:flutter_test/flutter_test.dart';

DateTime d(int day, int month, [int year = 2026]) => DateTime(year, month, day);

/// d1 = Ana, a receber 50000, com p1 (20000 em 10/11) ligado à transação t1.
Debt ana() => Debt(
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
);

Transaction t1({int amountCents = 20000, DateTime? date}) => Transaction(
  id: 't1',
  type: TransactionType.income,
  amountCents: amountCents,
  date: date ?? d(10, 11),
  description: 'Recebido de Ana · Show',
  accountId: 'A',
);

void main() {
  test('linkedTransactionIds devolve só transações que existem', () {
    final ids = linkedTransactionIds([ana()], (id) => id == 't1');
    expect(ids, {'t1'});
    expect(linkedTransactionIds([ana()], (_) => false), isEmpty);
  });

  test('transação ausente com t1 conhecido remove o pagamento', () {
    final changed = syncDebtsWithTransactions(
      [ana()],
      knownIds: {'t1'},
      lookup: (_) => null,
    );
    expect(changed, hasLength(1));
    expect(changed.single.payments, isEmpty);
    expect(changed.single.remainingCents, 50000);
  });

  test('valor editado troca o pagamento mantendo id e transactionId', () {
    final changed = syncDebtsWithTransactions(
      [ana()],
      knownIds: {'t1'},
      lookup: (_) => t1(amountCents: 15000),
    );
    final payment = changed.single.payments.single;
    expect(payment.id, 'p1');
    expect(payment.transactionId, 't1');
    expect(payment.amountCents, 15000);
  });

  test('data editada troca a data do pagamento', () {
    final changed = syncDebtsWithTransactions(
      [ana()],
      knownIds: {'t1'},
      lookup: (_) => t1(date: d(12, 11)),
    );
    expect(changed.single.payments.single.date, d(12, 11));
    expect(changed.single.payments.single.amountCents, 20000);
  });

  test('t1 ausente mas fora de knownIds (órfão de backup) não muda nada', () {
    final changed = syncDebtsWithTransactions(
      [ana()],
      knownIds: {},
      lookup: (_) => null,
    );
    expect(changed, isEmpty);
  });

  test('dívida sem mudança não entra na lista', () {
    final changed = syncDebtsWithTransactions(
      [ana()],
      knownIds: {'t1'},
      lookup: (_) => t1(),
    );
    expect(changed, isEmpty);
  });
}
