import 'package:finme/app/app_scope.dart';
import 'package:finme/app/bootstrap.dart';
import 'package:finme/app/ledger.dart';
import 'package:finme/app/seed.dart';
import 'package:finme/core/services/record_store.dart';
import 'package:finme/core/utils/date_utils.dart';
import 'package:finme/features/recurring/domain/recurring_rule.dart';
import 'package:finme/features/transactions/domain/transaction.dart';
import 'package:flutter_test/flutter_test.dart';

DateTime _now() => DateTime(2026, 11, 14);

void main() {
  late AppServices s;

  setUp(() async {
    s = await bootstrap(storeFactory: (_) => MemoryRecordStore(), clock: _now);
    await seedDemo(s);
    await materializeRecurring(s);
  });

  test('categorias padrão: 12 de despesa e 4 de receita', () {
    expect(defaultCategories().length, 16);
    expect(s.categories.all.length, 16);
  });

  test('forecast é memoizado e recalcula após upsert', () async {
    final first = s.ledger.forecast;
    expect(identical(s.ledger.forecast, first), isTrue);

    await s.transactions.upsert(
      Transaction(
        id: 'extra_planned',
        type: TransactionType.expense,
        amountCents: 100,
        date: DateTime(2026, 11, 20),
        description: 'Extra',
        accountId: 'acc_alfa',
        status: TransactionStatus.planned,
      ),
    );
    final second = s.ledger.forecast;
    expect(identical(second, first), isFalse);
    expect(second.events.length, first.events.length + 1);
  });

  test('fatura de cartão de crédito não vazia; débito sem faturas', () {
    expect(s.ledger.invoicesFor('card_alfa_visa'), isNotEmpty);
    expect(s.ledger.invoicesFor('card_alfa_debito'), isEmpty);
  });

  test('materialização não duplica ao chamar duas vezes', () async {
    final count = s.transactions.all.length;
    await materializeRecurring(s);
    expect(s.transactions.all.length, count);
  });

  test('ocorrência apagada não volta após materializeRecurring', () async {
    final salary = s.transactions.all.firstWhere(
      (t) => t.recurringId == 'rec_salario',
    );
    await s.transactions.delete(salary.id);
    await materializeRecurring(s);
    expect(s.transactions.byId(salary.id), isNull);
  });

  test('upcoming inclui provisionado atrasado e boleto de 5 dias', () {
    final list = s.ledger.upcoming();
    final today = dateOnly(_now());
    expect(list.any((t) => t.isPlanned && t.date.isBefore(today)), isTrue);
    expect(
      list.any((t) => t.isBoleto && isSameDay(t.date, DateTime(2026, 11, 19))),
      isTrue,
    );
  });

  test(
    'ocorrência de hoje não é gravada, mas aparece em upcoming e forecast',
    () async {
      final today = dateOnly(_now());
      await s.recurring.upsert(
        RecurringRule(
          id: 'rec_hoje',
          description: 'Conta de hoje',
          type: TransactionType.expense,
          amountCents: 1234,
          frequency: Frequency.monthly,
          startDate: today,
          accountId: 'acc_alfa',
          categoryId: 'cat_outros',
        ),
      );
      await materializeRecurring(s);

      expect(
        s.transactions.all.any((t) => t.recurringId == 'rec_hoje'),
        isFalse,
      );
      // Regra que começa hoje não tem nada pendente até ontem: materializedUntil fica null.
      expect(s.recurring.byId('rec_hoje')!.materializedUntil, isNull);
      expect(
        s.ledger.upcoming().any(
          (t) => t.recurringId == 'rec_hoje' && isSameDay(t.date, today),
        ),
        isTrue,
      );
      expect(
        s.ledger.forecast.events.any(
          (e) =>
              e.isProjected &&
              e.description == 'Conta de hoje' &&
              isSameDay(e.date, today),
        ),
        isTrue,
      );
    },
  );

  test('upcoming é memoizado por dias e só traz saídas de conta', () {
    final list = s.ledger.upcoming();
    expect(identical(s.ledger.upcoming(), list), isTrue);
    expect(identical(s.ledger.upcoming(days: 7), list), isFalse);
    expect(
      list.every(
        (t) => t.type == TransactionType.expense && t.accountId != null,
      ),
      isTrue,
    );
  });

  test('virada de dia invalida o cache e chama onDayChanged', () async {
    var day = _now();
    var calls = 0;
    final ledger = Ledger(
      accounts: s.accounts,
      cards: s.cards,
      categories: s.categories,
      transactions: s.transactions,
      recurring: s.recurring,
      settings: s.settings,
      clock: () => day,
      onDayChanged: () async => calls++,
    );
    addTearDown(ledger.dispose);

    final first = ledger.forecast;
    expect(identical(ledger.forecast, first), isTrue);
    expect(calls, 0);

    day = DateTime(2026, 11, 15);
    expect(identical(ledger.forecast, first), isFalse);
    await Future<void>.delayed(Duration.zero);
    expect(calls, 1);

    ledger.forecast;
    await Future<void>.delayed(Duration.zero);
    expect(calls, 1);
  });
}
