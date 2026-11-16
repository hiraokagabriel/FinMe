import 'package:finme/app/app_scope.dart';
import 'package:finme/app/bootstrap.dart';
import 'package:finme/app/ledger.dart';
import 'package:finme/core/models/year_month.dart';
import 'package:finme/core/services/record_store.dart';
import 'package:finme/features/accounts/domain/account.dart';
import 'package:finme/features/categories/domain/transaction_category.dart';
import 'package:finme/features/goals/domain/goal.dart';
import 'package:finme/features/transactions/domain/transaction.dart';
import 'package:flutter_test/flutter_test.dart';

DateTime _now() => DateTime(2026, 11, 15);

final _month = YearMonth.fromDate(DateTime(2026, 11, 15));

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

  test('metas começam vazias e goals.upsert notifica o Ledger', () async {
    expect(s.goals.all, isEmpty);
    var notified = 0;
    s.ledger.addListener(() => notified++);

    await s.goals.upsert(
      Goal(
        id: 'g1',
        name: 'Viagem',
        accountId: 'acc_alfa',
        targetCents: 600000,
      ),
    );

    expect(s.goals.all.length, 1);
    expect(notified, greaterThan(0));
  });

  test('categoryTree é memoizado e subcategoria soma no pai', () async {
    final tree = s.ledger.categoryTree;
    expect(identical(s.ledger.categoryTree, tree), isTrue);

    await s.categories.upsert(
      const TransactionCategory(
        id: 'cat_mercado_x',
        name: 'Mercado X',
        kind: CategoryKind.expense,
        iconCodePoint: 0xe59c,
        colorValue: 0xFF42A5F5,
        parentId: 'cat_alimentacao',
      ),
    );
    expect(
      s.ledger.categoryTree.label('cat_mercado_x'),
      'Alimentação › Mercado X',
    );

    await s.transactions.upsert(
      Transaction(
        id: 'tx_mercado',
        type: TransactionType.expense,
        amountCents: 30000,
        date: DateTime(2026, 11, 10),
        description: 'Supermercado',
        categoryId: 'cat_mercado_x',
        accountId: 'acc_alfa',
      ),
    );
    final rolled = s.ledger.rolledSpendingFor(_month);
    expect(rolled['cat_alimentacao'], 30000);
    expect(rolled.containsKey('cat_mercado_x'), isFalse);
    expect(identical(s.ledger.rolledSpendingFor(_month), rolled), isTrue);
  });

  test('reservedByAccount e spendableToday refletem aportes', () async {
    expect(s.ledger.reservedByAccount, isEmpty);
    final meta = Goal(
      id: 'g1',
      name: 'Viagem',
      accountId: 'acc_alfa',
      targetCents: 600000,
    );
    await s.goals.upsert(meta);
    expect(s.ledger.spendableToday.reservedCents, 0);

    await s.goals.upsert(
      meta.withMovement(
        GoalMovement(
          id: 'm1',
          date: DateTime(2026, 11, 10),
          amountCents: 150000,
        ),
      ),
    );

    expect(s.ledger.reservedByAccount, {'acc_alfa': 150000});
    final spendable = s.ledger.spendableToday;
    expect(spendable.reservedCents, 150000);
    expect(identical(s.ledger.spendableToday, spendable), isTrue);
    expect(spendable.balanceCents, s.ledger.forecast.currentTotalCents);
  });

  test('allTags junta tags das transações, sem duplicar grafia', () async {
    await s.transactions.upsertAll([
      Transaction(
        id: 't1',
        type: TransactionType.expense,
        amountCents: 100,
        date: DateTime(2026, 11, 10),
        description: 'Passagem',
        accountId: 'acc_alfa',
        tags: const ['Viagem'],
      ),
      Transaction(
        id: 't2',
        type: TransactionType.expense,
        amountCents: 200,
        date: DateTime(2026, 11, 11),
        description: 'Panela',
        accountId: 'acc_alfa',
        tags: const ['viagem', 'casa'],
      ),
      Transaction(
        id: 't3',
        type: TransactionType.expense,
        amountCents: 300,
        date: DateTime(2026, 11, 12),
        description: 'Café',
        accountId: 'acc_alfa',
      ),
    ]);

    expect(s.ledger.allTags, ['Viagem', 'casa']);
  });

  test('Ledger sem goals tem reservedByAccount vazio', () {
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

    expect(ledger.reservedByAccount, isEmpty);
  });
}
