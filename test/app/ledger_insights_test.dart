import 'package:finme/app/app_scope.dart';
import 'package:finme/app/bootstrap.dart';
import 'package:finme/app/seed.dart';
import 'package:finme/core/models/year_month.dart';
import 'package:finme/core/services/record_store.dart';
import 'package:finme/core/theme/app_palettes.dart';
import 'package:finme/features/cards/domain/payment_card.dart';
import 'package:finme/features/forecast/domain/forecast.dart';
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
}
