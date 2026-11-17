import 'package:finme/core/services/collection_repository.dart';
import 'package:finme/core/services/record_store.dart';
import 'package:finme/features/debts/domain/debt.dart';
import 'package:finme/features/debts/presentation/debt_transaction_sync.dart';
import 'package:finme/features/transactions/domain/transaction.dart';
import 'package:flutter_test/flutter_test.dart';

DateTime d(int day, int month, [int year = 2026]) => DateTime(year, month, day);

Future<void> settle() => Future<void>.delayed(Duration.zero);

CollectionRepository<Transaction> txRepo() => CollectionRepository<Transaction>(
  store: MemoryRecordStore(),
  fromMap: Transaction.fromMap,
  toMap: (t) => t.toMap(),
  idOf: (t) => t.id,
);

CollectionRepository<Debt> debtRepo() => CollectionRepository<Debt>(
  store: MemoryRecordStore(),
  fromMap: Debt.fromMap,
  toMap: (x) => x.toMap(),
  idOf: (x) => x.id,
);

Transaction quitacao(String id, int amountCents, DateTime date) => Transaction(
  id: id,
  type: TransactionType.income,
  amountCents: amountCents,
  date: date,
  description: 'Recebido de Ana · Show',
  accountId: 'A',
);

/// d1 = Ana, a receber 50000, com p1 (20000, t1) e p2 (10000, t2).
Debt ana({List<DebtPayment>? payments}) => Debt(
  id: 'd1',
  person: 'Ana',
  direction: DebtDirection.owedToMe,
  amountCents: 50000,
  date: d(1, 10),
  payments:
      payments ??
      [
        DebtPayment(
          id: 'p1',
          date: d(10, 11),
          amountCents: 20000,
          transactionId: 't1',
        ),
        DebtPayment(
          id: 'p2',
          date: d(11, 11),
          amountCents: 10000,
          transactionId: 't2',
        ),
      ],
);

void main() {
  late CollectionRepository<Transaction> transactions;
  late CollectionRepository<Debt> debts;
  late DebtTransactionSync sync;

  /// Estado inicial: t1 e t2 existem e d1 aponta para elas (como depois de um boot).
  Future<void> seed() async {
    transactions = txRepo();
    debts = debtRepo();
    await transactions.upsertAll([
      quitacao('t1', 20000, d(10, 11)),
      quitacao('t2', 10000, d(11, 11)),
    ]);
    await debts.upsertAll([ana()]);
    sync = DebtTransactionSync(transactions: transactions, debts: debts);
  }

  tearDown(() => sync.dispose());

  test('excluir a transação remove o pagamento', () async {
    await seed();
    expect(debts.byId('d1')!.remainingCents, 20000);
    await transactions.delete('t1');
    await settle();
    expect(debts.byId('d1')!.remainingCents, 40000);
    expect(debts.byId('d1')!.payments.map((p) => p.id), ['p2']);
  });

  test('editar o valor da transação ajusta o pagamento', () async {
    await seed();
    await transactions.upsert(quitacao('t1', 25000, d(10, 11)));
    await settle();
    expect(debts.byId('d1')!.payments.first.amountCents, 25000);
    expect(debts.byId('d1')!.remainingCents, 15000);
  });

  test('quitar (transação antes da dívida) não grava dívida extra', () async {
    transactions = txRepo();
    debts = debtRepo();
    await debts.upsertAll([ana(payments: const [])]);
    sync = DebtTransactionSync(transactions: transactions, debts: debts);
    final before = debts.version;
    await transactions.upsertAll([quitacao('t1', 20000, d(10, 11))]);
    await settle();
    await debts.upsert(
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
    );
    await settle();
    expect(debts.version, before + 1);
    expect(debts.byId('d1')!.remainingCents, 30000);
  });

  test('desfazer (dívida antes da transação) não grava dívida extra', () async {
    await seed();
    final before = debts.version;
    await debts.upsert(ana(payments: const []));
    await transactions.delete('t1');
    await settle();
    expect(debts.version, before + 1);
    expect(debts.byId('d1')!.payments, isEmpty);
  });

  test('suspendDuring não sincroniza; depois _known é recalculado', () async {
    await seed();
    await sync.suspendDuring(() async {
      await transactions.delete('t1');
    });
    await settle();
    expect(debts.byId('d1')!.remainingCents, 20000);

    await transactions.delete('t2');
    await settle();
    expect(debts.byId('d1')!.remainingCents, 30000);
  });
}
