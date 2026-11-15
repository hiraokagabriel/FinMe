import 'package:finme/app/app_scope.dart';
import 'package:finme/app/bootstrap.dart';
import 'package:finme/app/seed.dart';
import 'package:finme/core/models/year_month.dart';
import 'package:finme/core/services/record_store.dart';
import 'package:finme/core/theme/app_palettes.dart';
import 'package:finme/features/accounts/domain/account.dart';
import 'package:finme/features/cards/domain/payment_card.dart';
import 'package:finme/features/forecast/domain/forecast.dart';
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

  test('getters da Fase 5 são memoizados', () {
    final ledger = s.ledger;
    expect(identical(ledger.invoiceTimeline, ledger.invoiceTimeline), isTrue);
    expect(identical(ledger.bestCardsToday, ledger.bestCardsToday), isTrue);
    expect(
      identical(ledger.installmentCommitments, ledger.installmentCommitments),
      isTrue,
    );
    expect(
      identical(
        ledger.cardsWithoutPaymentAccount,
        ledger.cardsWithoutPaymentAccount,
      ),
      isTrue,
    );
  });

  test(
    'cards.upsert recalcula bestCardsToday e cardsWithoutPaymentAccount',
    () async {
      final bestBefore = s.ledger.bestCardsToday;
      expect(s.ledger.cardsWithoutPaymentAccount, isEmpty);

      await s.cards.upsert(
        PaymentCard(
          id: 'card_novo',
          name: 'Novo',
          bankName: 'Banco Novo',
          brand: CardBrand.visa,
          kind: CardKind.credit,
          last4: '0001',
          limitCents: 100000,
          closingDay: 1,
          dueDay: 10,
          colorValue: kEntityColors[0],
        ),
      );

      expect(identical(s.ledger.bestCardsToday, bestBefore), isFalse);
      expect(
        s.ledger.bestCardsToday.any((o) => o.card.id == 'card_novo'),
        isTrue,
      );
      expect(s.ledger.cardsWithoutPaymentAccount.map((c) => c.id), [
        'card_novo',
      ]);
    },
  );

  test('invoiceTimeline usa faturas de crédito com ids de forecast.events', () {
    final due = s.ledger.invoiceTimeline;
    final sources = {
      for (final e in s.ledger.forecast.events)
        if (e.kind == ForecastEventKind.invoice) e.sourceId,
    };
    expect(due, isNotEmpty);
    expect(due.every((d) => sources.contains(d.invoice.id)), isTrue);
    expect(due.every((d) => d.invoice.card.kind == CardKind.credit), isTrue);
  });

  test('installmentCommitments tem 12 meses a partir do mês seguinte', () {
    final list = s.ledger.installmentCommitments;
    expect(list.length, 12);
    expect(list.first.month, const YearMonth(2026, 12));
    expect(list.last.month, const YearMonth(2027, 11));
  });

  test('invoiceTimeline cobre 60 dias com forecastMonths 3 em 31/01', () async {
    final s31 = await bootstrap(
      storeFactory: (_) => MemoryRecordStore(),
      clock: () => DateTime(2027, 1, 31),
    );
    await s31.settings.update((x) => x.copyWith(forecastMonths: 3));
    await s31.accounts.upsert(
      const Account(
        id: 'acc_a',
        name: 'Conta',
        bankName: 'Banco',
        type: AccountType.checking,
        initialBalanceCents: 100000,
        colorValue: 0xFF000000,
      ),
    );
    await s31.cards.upsert(
      PaymentCard(
        id: 'card_x',
        name: 'X',
        bankName: 'Banco',
        brand: CardBrand.visa,
        kind: CardKind.credit,
        last4: '0001',
        closingDay: 25,
        dueDay: 1,
        colorValue: kEntityColors[0],
        paymentAccountId: 'acc_a',
      ),
    );
    await s31.transactions.upsert(
      Transaction(
        id: 'compra',
        type: TransactionType.expense,
        amountCents: 4000,
        date: DateTime(2027, 3, 10),
        description: 'Compra',
        cardId: 'card_x',
      ),
    );

    final ledger = s31.ledger;
    expect(ledger.forecast.months, hasLength(3));
    final due = ledger.invoiceTimeline.singleWhere(
      (d) => d.invoice.card.id == 'card_x',
    );
    expect(due.date, DateTime(2027, 4, 1));
    expect(due.amountCents, 4000);
    expect(due.accountBalanceAfterCents, 96000);
  });

  test(
    'recorrência de cartão é projetada até o fim da previsão (hoje + 60 dias)',
    () async {
      // Com 3 meses em 31/01/2027 o fim dos meses é 31/03; hoje + 60 dias é 01/04.
      final s31 = await bootstrap(
        storeFactory: (_) => MemoryRecordStore(),
        clock: () => DateTime(2027, 1, 31),
      );
      await s31.settings.update((x) => x.copyWith(forecastMonths: 3));
      await s31.cards.upsert(
        PaymentCard(
          id: 'card_x',
          name: 'X',
          bankName: 'Banco',
          brand: CardBrand.visa,
          kind: CardKind.credit,
          last4: '0001',
          closingDay: 25,
          dueDay: 5,
          colorValue: kEntityColors[0],
        ),
      );
      await s31.recurring.upsert(
        RecurringRule(
          id: 'rec_card',
          description: 'Assinatura',
          type: TransactionType.expense,
          amountCents: 1000,
          frequency: Frequency.monthly,
          startDate: DateTime(2027, 4, 1),
          cardId: 'card_x',
        ),
      );

      final items = s31.ledger.invoicesFor('card_x').expand((i) => i.items);
      expect(items.any((t) => t.date == DateTime(2027, 4, 1)), isTrue);
    },
  );

  test('monthlyHistory é memoizado e recalcula após upsert', () async {
    final before = s.ledger.monthlyHistory;
    expect(identical(s.ledger.monthlyHistory, before), isTrue);

    await s.transactions.upsert(
      _expense('hist_extra', DateTime(2026, 11, 5), 700),
    );

    expect(identical(s.ledger.monthlyHistory, before), isFalse);
    expect(
      s.ledger.monthlyHistory.last.expenseCents,
      before.last.expenseCents + 700,
    );
  });

  test('último endBalanceCents do histórico bate com o saldo consolidado', () {
    final ledger = s.ledger;
    final activeTotal = ledger.accounts.all
        .where((a) => !a.archived)
        .fold(0, (sum, a) => sum + ledger.accountBalances[a.id]!);

    expect(ledger.monthlyHistory.last.endBalanceCents, activeTotal);
    expect(
      ledger.monthlyHistory.last.endBalanceCents,
      ledger.forecast.currentTotalCents,
    );
  });

  test('expenseMonthToDate compara com o mesmo dia do mês anterior', () async {
    final s14 = await bootstrap(
      storeFactory: (_) => MemoryRecordStore(),
      clock: _now,
    );
    await s14.transactions.upsert(
      _expense('out_10', DateTime(2026, 10, 10), 1000),
    );
    await s14.transactions.upsert(
      _expense('out_20', DateTime(2026, 10, 20), 2000),
    );
    await s14.transactions.upsert(
      _expense('nov_05', DateTime(2026, 11, 5), 500),
    );

    expect(s14.ledger.expenseMonthToDate, (current: 500, previous: 1000));
  });
}

Transaction _expense(String id, DateTime date, int cents) => Transaction(
  id: id,
  type: TransactionType.expense,
  amountCents: cents,
  date: date,
  description: id,
  accountId: 'acc_alfa',
);
