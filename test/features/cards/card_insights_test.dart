import 'package:finme/core/models/year_month.dart';
import 'package:finme/features/cards/domain/card_insights.dart';
import 'package:finme/features/cards/domain/invoice.dart';
import 'package:finme/features/cards/domain/payment_card.dart';
import 'package:finme/features/transactions/domain/installments.dart';
import 'package:finme/features/transactions/domain/transaction.dart';
import 'package:flutter_test/flutter_test.dart';

PaymentCard card(
  String id, {
  int closing = 5,
  int due = 12,
  int limit = 100000,
  CardKind kind = CardKind.credit,
  bool archived = false,
  String? account,
  String? name,
}) => PaymentCard(
  id: id,
  name: name ?? id,
  bankName: 'Banco',
  brand: CardBrand.visa,
  kind: kind,
  last4: '1234',
  limitCents: limit,
  closingDay: closing,
  dueDay: due,
  paymentAccountId: account,
  colorValue: 0xFF1565C0,
  archived: archived,
);

Transaction expense(
  String id,
  int cents,
  DateTime date,
  String cardId, {
  String? groupId,
  int? index,
  String? recurringId,
}) => Transaction(
  id: id,
  type: TransactionType.expense,
  amountCents: cents,
  date: date,
  description: id,
  cardId: cardId,
  installmentGroupId: groupId,
  installmentIndex: index,
  installmentCount: groupId == null ? null : 3,
  recurringId: recurringId,
);

void main() {
  group('bestCardsToBuy', () {
    final today = DateTime(2026, 11, 14);

    test('exemplo do SPEC §5.8: ordem A, B, C com dias 28, 21, 13', () {
      final options = bestCardsToBuy(
        cards: [
          card('C', closing: 20, due: 27),
          card('B', closing: 25, due: 5),
          card('A'),
        ],
        usedLimitByCard: const {},
        today: today,
      );
      expect(options.map((o) => o.card.id), ['A', 'B', 'C']);
      expect(options.map((o) => o.daysUntilDue), [28, 21, 13]);
      expect(options.first.dueDate, DateTime(2026, 12, 12));
    });

    test('cartão sem limite livre vai para o fim', () {
      final options = bestCardsToBuy(
        cards: [
          card('A'),
          card('B', closing: 25, due: 5),
          card('C', closing: 20, due: 27),
        ],
        usedLimitByCard: const {'A': 100000},
        today: today,
      );
      expect(options.map((o) => o.card.id), ['B', 'C', 'A']);
      expect(options.last.hasLimit, isFalse);
    });

    test('débito e arquivado excluídos; limite 0 → hasLimit false', () {
      final options = bestCardsToBuy(
        cards: [
          card('D', kind: CardKind.debit),
          card('X', archived: true),
          card('Z', limit: 0),
        ],
        usedLimitByCard: const {},
        today: today,
      );
      expect(options.map((o) => o.card.id), ['Z']);
      expect(options.single.hasLimit, isFalse);
    });

    test('daysUntilDue atravessa mudança de horário (out → fev)', () {
      final october = bestCardsToBuy(
        cards: [card('A', closing: 25, due: 5)],
        usedLimitByCard: const {},
        today: DateTime(2026, 10, 20),
      ).single;
      expect(october.dueDate, DateTime(2026, 11, 5));
      expect(october.daysUntilDue, 16);

      final february = bestCardsToBuy(
        cards: [card('A', closing: 5, due: 20)],
        usedLimitByCard: const {},
        today: DateTime(2027, 2, 10),
      ).single;
      expect(february.dueDate, DateTime(2027, 3, 20));
      expect(february.daysUntilDue, 38);
    });
  });

  group('installmentCommitments', () {
    final purchase = DateTime(2026, 11, 10);
    final parcels = buildInstallments(
      base: expense('base', 10000, purchase, 'c1'),
      count: 3,
      groupId: 'g1',
    );

    test('3x de 100,00 comprado 10/11 entra em dez/jan/fev', () {
      final invoices = InvoiceService.build(
        card: card('c1'),
        transactions: parcels,
      );
      final result = installmentCommitments(
        invoices: invoices,
        from: const YearMonth(2026, 12),
      );
      expect(result, hasLength(12));
      expect(result[0].month, const YearMonth(2026, 12));
      expect(result[0].byCard, {'c1': 3334});
      expect(result[1].byCard, {'c1': 3333});
      expect(result[2].byCard, {'c1': 3333});
      expect(result[2].totalCents, 3333);
      for (final entry in result.skip(3)) {
        expect(entry.byCard, isEmpty);
        expect(entry.totalCents, 0);
      }
    });

    test('à vista e recorrência projetada não entram', () {
      final invoices = InvoiceService.build(
        card: card('c1'),
        transactions: [
          ...parcels,
          expense('avista', 5000, DateTime(2026, 11, 20), 'c1'),
        ],
        projected: [
          expense('rec', 7000, DateTime(2026, 12, 3), 'c1', recurringId: 'r1'),
        ],
      );
      final result = installmentCommitments(
        invoices: invoices,
        from: const YearMonth(2026, 12),
      );
      expect(result[0].byCard, {'c1': 3334});
      expect(result[0].totalCents, 3334);
    });

    test('dois cartões somam em totalCents e separam em byCard', () {
      final other = buildInstallments(
        base: expense('base2', 6000, purchase, 'c2'),
        count: 3,
        groupId: 'g2',
      );
      final invoices = [
        ...InvoiceService.build(card: card('c1'), transactions: parcels),
        ...InvoiceService.build(card: card('c2'), transactions: other),
      ];
      final result = installmentCommitments(
        invoices: invoices,
        from: const YearMonth(2026, 12),
      );
      expect(result[0].byCard, {'c1': 3334, 'c2': 2000});
      expect(result[0].totalCents, 5334);
    });

    test('fora do intervalo não entra', () {
      final invoices = InvoiceService.build(
        card: card('c1'),
        transactions: parcels,
      );
      final result = installmentCommitments(
        invoices: invoices,
        from: const YearMonth(2027, 3),
        months: 2,
      );
      expect(result, hasLength(2));
      expect(result.every((e) => e.byCard.isEmpty), isTrue);
    });
  });

  group('cardsWithoutPaymentAccount', () {
    test(
      'null e conta inexistente entram; arquivado não entra; ordem mantida',
      () {
        final cards = [
          card('A', account: 'acc1'),
          card('B'),
          card('C', account: 'gone'),
          card('D', account: 'acc1', archived: true),
          card('E', account: 'acc1'),
        ];
        final result = cardsWithoutPaymentAccount(cards, {'acc1'});
        expect(result.map((c) => c.id), ['B', 'C']);
      },
    );
  });
}
