import 'package:finme/app/app_scope.dart';
import 'package:finme/app/bootstrap.dart';
import 'package:finme/app/ledger.dart';
import 'package:finme/core/services/record_store.dart';
import 'package:finme/features/accounts/domain/account.dart';
import 'package:finme/features/debts/domain/debt.dart';
import 'package:finme/features/debts/domain/debt_math.dart';
import 'package:finme/features/net_worth/domain/asset.dart';
import 'package:finme/features/recurring/domain/recurring_rule.dart';
import 'package:finme/features/transactions/domain/transaction.dart';
import 'package:flutter_test/flutter_test.dart';

DateTime _now() => DateTime(2026, 11, 15);

void main() {
  late AppServices s;

  setUp(() async {
    s = await bootstrap(storeFactory: (_) => MemoryRecordStore(), clock: _now);
    await s.accounts.upsert(
      const Account(
        id: 'acc_alfa',
        name: 'Conta Alfa',
        bankName: 'Banco Alfa',
        type: AccountType.checking,
        initialBalanceCents: 500000,
        colorValue: 0xFF42A5F5,
      ),
    );
  });

  test('ativos e dívidas começam vazios e upsert notifica o Ledger', () async {
    expect(s.assets.all, isEmpty);
    expect(s.debts.all, isEmpty);
    var notified = 0;
    s.ledger.addListener(() => notified++);

    await s.assets.upsert(
      Asset(id: 'carro', name: 'Carro', kind: AssetKind.vehicle),
    );
    final afterAsset = notified;
    await s.debts.upsert(
      Debt(
        id: 'd1',
        person: 'Ana',
        direction: DebtDirection.owedToMe,
        amountCents: 50000,
        date: DateTime(2026, 10, 1),
      ),
    );

    expect(afterAsset, greaterThan(0));
    expect(notified, greaterThan(afterAsset));
  });

  test('netWorthHistory tem 24 meses, é memoizado e reflete ativos', () async {
    final history = s.ledger.netWorthHistory;
    expect(history.length, 24);
    expect(identical(s.ledger.netWorthHistory, history), isTrue);
    expect(history.last.date, DateTime(2026, 11, 15));

    await s.assets.upsert(
      Asset(
        id: 'carro',
        name: 'Carro',
        kind: AssetKind.vehicle,
        snapshots: [AssetSnapshot(id: 's1', date: _now(), valueCents: 100000)],
      ),
    );

    expect(s.ledger.netWorthHistory.last.assetsCents, 100000);
    expect(
      s.ledger.netWorthHistory.last.accountsCents,
      s.ledger.forecast.currentTotalCents,
    );
  });

  test(
    'devo com vencimento entra na previsão e no "posso gastar"; me devem não',
    () async {
      await s.accounts.upsert(
        const Account(
          id: 'acc_alfa',
          name: 'Conta Alfa',
          bankName: 'Banco Alfa',
          type: AccountType.checking,
          initialBalanceCents: 300000,
          colorValue: 0xFF42A5F5,
        ),
      );
      await s.recurring.upsert(
        RecurringRule(
          id: 'salario',
          description: 'Salário',
          type: TransactionType.income,
          amountCents: 500000,
          frequency: Frequency.monthly,
          startDate: DateTime(2026, 12, 5),
          accountId: 'acc_alfa',
        ),
      );
      await s.debts.upsert(
        Debt(
          id: 'd2',
          person: 'Bruno',
          direction: DebtDirection.iOwe,
          amountCents: 80000,
          date: DateTime(2026, 9, 20),
          dueDate: DateTime(2026, 12, 1),
        ),
      );
      await s.debts.upsert(
        Debt(
          id: 'd5',
          person: 'Eva',
          direction: DebtDirection.owedToMe,
          amountCents: 50000,
          date: DateTime(2026, 10, 1),
          dueDate: DateTime(2026, 11, 20),
        ),
      );

      final spendable = s.ledger.spendableToday;
      expect(spendable.plannedCents, 80000);
      expect(spendable.freeCents, 220000);
      expect(spendable.perDayCents, 11000);

      final events = s.ledger.forecast.events;
      expect(
        events.where((e) => e.description.startsWith('Devo a Bruno')).length,
        1,
      );
      expect(events.any((e) => e.description.contains('Eva')), isFalse);
    },
  );

  test('quitar a dívida remove o evento da previsão', () async {
    final debt = Debt(
      id: 'd2',
      person: 'Bruno',
      direction: DebtDirection.iOwe,
      amountCents: 80000,
      date: DateTime(2026, 9, 20),
      dueDate: DateTime(2026, 12, 1),
    );
    await s.debts.upsert(debt);
    expect(
      s.ledger.forecast.events.any(
        (e) => e.description.startsWith('Devo a Bruno'),
      ),
      isTrue,
    );

    final settled = settleDebt(
      debt,
      paymentId: 'p1',
      transactionId: 't1',
      amountCents: 80000,
      date: _now(),
      accountId: 'acc_alfa',
    );
    await s.transactions.upsert(settled.transaction);
    await s.debts.upsert(settled.debt);

    expect(
      s.ledger.forecast.events.any(
        (e) => e.description.startsWith('Devo a Bruno'),
      ),
      isFalse,
    );
  });

  test('debtsByPerson e debtPeople seguem debts.all', () async {
    expect(s.ledger.debtsByPerson, isEmpty);
    expect(s.ledger.debtPeople, isEmpty);

    await s.debts.upsert(
      Debt(
        id: 'd2',
        person: 'Bruno',
        direction: DebtDirection.iOwe,
        amountCents: 80000,
        date: DateTime(2026, 9, 20),
      ),
    );

    expect(s.ledger.debtsByPerson.single.person, 'Bruno');
    expect(s.ledger.debtsByPerson.single.payableCents, 80000);
    expect(s.ledger.debtPeople, ['Bruno']);
  });

  test('Ledger sem assets e debts: vazio e sem ativos no patrimônio', () {
    final ledger = Ledger(
      accounts: s.accounts,
      cards: s.cards,
      categories: s.categories,
      transactions: s.transactions,
      recurring: s.recurring,
      settings: s.settings,
      clock: _now,
      scheduleMidnightTimer: false,
    );
    addTearDown(ledger.dispose);

    expect(ledger.debtsByPerson, isEmpty);
    expect(ledger.debtPeople, isEmpty);
    expect(ledger.netWorthHistory.last.assetsCents, 0);
    expect(ledger.netWorthHistory.last.payableCents, 0);
  });
}
