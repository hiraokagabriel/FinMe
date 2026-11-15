import 'package:finme/core/models/year_month.dart';
import 'package:finme/features/cards/domain/invoice_cycle.dart';
import 'package:finme/features/cards/domain/payment_card.dart';
import 'package:finme/features/importing/domain/import_installments.dart';
import 'package:finme/features/importing/domain/import_profile.dart';
import 'package:flutter_test/flutter_test.dart';

PaymentCard _card({
  int closing = 5,
  int due = 12,
  CardKind kind = CardKind.credit,
  List<CardCycle> history = const [],
}) => PaymentCard(
  id: 'card_1',
  name: 'Cartão Exemplo',
  bankName: 'Banco Alfa',
  brand: CardBrand.visa,
  kind: kind,
  last4: '0000',
  closingDay: closing,
  dueDay: due,
  colorValue: 0,
  cycleHistory: history,
);

List<DateTime> _dates(
  DateTime line,
  int index,
  int count,
  InstallmentDateMode mode, [
  PaymentCard? card,
]) => [
  for (final e in importedInstallmentDates(
    lineDate: line,
    index: index,
    count: count,
    mode: mode,
    card: card,
  ))
    e.date,
];

List<YearMonth> _invoices(List<DateTime> dates, PaymentCard card) => [
  for (final d in dates) invoiceDueMonth(d, card),
];

void main() {
  group('detectInstallment', () {
    test('padrões do SPEC §5.12', () {
      expect(detectInstallment('LOJA X PARC 03/10'), (index: 3, count: 10));
      expect(detectInstallment('LOJA X 3/10'), (index: 3, count: 10));
      expect(detectInstallment('LOJA X 03 DE 10'), (index: 3, count: 10));
      expect(detectInstallment('PARC.03/10 LOJA'), (index: 3, count: 10));
      expect(detectInstallment('Loja Exemplo - Parcela 2/6'), (
        index: 2,
        count: 6,
      ));
      expect(detectInstallment('PARCELA 3 DE 10 LOJA'), (index: 3, count: 10));
      expect(detectInstallment('LOJA X 15/11/2026'), isNull);
      expect(detectInstallment('LOJA X 11/05'), isNull);
      expect(detectInstallment('LOJA X 1/1'), isNull);
    });

    test('casa sobre foldText (acento e caixa) e ignora texto sem parcela', () {
      expect(detectInstallment('loja açúcar parcela 2 de 4'), (
        index: 2,
        count: 4,
      ));
      expect(detectInstallment('PADARIA PAO BOM'), isNull);
      expect(detectInstallment('IFOOD RESTAURANTE X 12/11'), isNull);
    });

    test('"3/10" só no fim é fraco; "05/11" em lançamento de 05/11 é data', () {
      expect(isWeakInstallment('UBER *TRIP 05/11'), isTrue);
      expect(isWeakInstallment('LOJA X PARC 03/10'), isFalse);
      expect(isWeakInstallment('LOJA X 03 DE 10'), isFalse);
      expect(
        detectInstallment('UBER *TRIP 05/11', date: DateTime(2026, 11, 5)),
        isNull,
      );
      expect(
        detectInstallment('UBER *TRIP 05/11', date: DateTime(2026, 11, 6)),
        (index: 5, count: 11),
      );
      expect(
        detectInstallment('LOJA X PARC 05/11', date: DateTime(2026, 11, 5)),
        (index: 5, count: 11),
      );
    });
  });

  group('importedInstallmentDates', () {
    test('fecha 5/vence 12, posting, 08/11/2026 PARC 03/10', () {
      final card = _card();
      final line = DateTime(2026, 11, 8);
      final dates = _dates(line, 3, 10, InstallmentDateMode.posting, card);
      expect(dates.length, 8);
      expect(dates.first, DateTime(2026, 11, 8));
      expect(dates[1], DateTime(2026, 12, 8));
      expect(dates.last, DateTime(2027, 6, 8));
      expect(_invoices(dates, card).first, const YearMonth(2026, 12));
      expect(_invoices(dates, card)[1], const YearMonth(2027, 1));
      expect(_invoices(dates, card).last, const YearMonth(2027, 7));
    });

    test(
      'fecha 5/vence 12, purchase, 15/09/2026 PARC 03/10 → 1ª 15/11 (fatura 2026-12)',
      () {
        final card = _card();
        final dates = _dates(
          DateTime(2026, 9, 15),
          3,
          10,
          InstallmentDateMode.purchase,
          card,
        );
        expect(dates.first, DateTime(2026, 11, 15));
        expect(invoiceDueMonth(dates.first, card), const YearMonth(2026, 12));
        expect(dates.length, 8);
      },
    );

    test(
      'fecha 31/vence 7, posting, 30/01/2027 PARC 01/03 → 30/01, 27/02 (ajuste), 30/03',
      () {
        final card = _card(closing: 31, due: 7);
        final dates = _dates(
          DateTime(2027, 1, 30),
          1,
          3,
          InstallmentDateMode.posting,
          card,
        );
        expect(dates, [
          DateTime(2027, 1, 30),
          DateTime(2027, 2, 27),
          DateTime(2027, 3, 30),
        ]);
        expect(_invoices(dates, card), [
          const YearMonth(2027, 2),
          const YearMonth(2027, 3),
          const YearMonth(2027, 4),
        ]);
      },
    );

    test(
      'histórico de ciclo (5/12 até 01/12/2026, depois 25/5): faturas nov, jan, fev',
      () {
        final card = _card(
          closing: 25,
          due: 5,
          history: [
            CardCycle(until: DateTime(2026, 12, 1), closingDay: 5, dueDay: 12),
          ],
        );
        final dates = _dates(
          DateTime(2026, 11, 4),
          1,
          3,
          InstallmentDateMode.posting,
          card,
        );
        expect(_invoices(dates, card), [
          const YearMonth(2026, 11),
          const YearMonth(2027, 1),
          const YearMonth(2027, 2),
        ]);
      },
    );

    test('conta corrente (sem cartão), 10/01/2027 "3/4" → 10/01, 10/02', () {
      final dates = _dates(
        DateTime(2027, 1, 10),
        3,
        4,
        InstallmentDateMode.posting,
      );
      expect(dates, [DateTime(2027, 1, 10), DateTime(2027, 2, 10)]);
    });

    test('débito é tratado como sem cartão de crédito', () {
      final dates = _dates(
        DateTime(2027, 1, 10),
        3,
        4,
        InstallmentDateMode.posting,
        _card(kind: CardKind.debit),
      );
      expect(dates, [DateTime(2027, 1, 10), DateTime(2027, 2, 10)]);
    });

    test('index == count → lista de 1 item', () {
      final card = _card();
      final dates = importedInstallmentDates(
        lineDate: DateTime(2026, 11, 8),
        index: 10,
        count: 10,
        mode: InstallmentDateMode.posting,
        card: card,
      );
      expect(dates.length, 1);
      expect(dates.single.index, 10);
      expect(dates.single.date, DateTime(2026, 11, 8));
    });
  });
}
