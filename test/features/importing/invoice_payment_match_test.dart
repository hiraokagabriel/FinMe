import 'package:finme/core/models/year_month.dart';
import 'package:finme/features/cards/domain/invoice.dart';
import 'package:finme/features/cards/domain/payment_card.dart';
import 'package:finme/features/importing/domain/invoice_payment_match.dart';
import 'package:finme/features/transactions/domain/transaction.dart';
import 'package:flutter_test/flutter_test.dart';

PaymentCard card(
  String id, {
  String? paymentAccountId = 'acc1',
  CardKind kind = CardKind.credit,
  bool archived = false,
  int closing = 5,
  int due = 12,
}) => PaymentCard(
  id: id,
  name: 'Cartão $id',
  bankName: 'Banco',
  brand: CardBrand.visa,
  kind: kind,
  last4: '1234',
  closingDay: closing,
  dueDay: due,
  colorValue: 0xFF1565C0,
  paymentAccountId: paymentAccountId,
  archived: archived,
);

Transaction purchase(String cardId, DateTime date, int cents, {String? id}) =>
    Transaction(
      id: id ?? 'p-$cardId-${date.month}',
      type: TransactionType.expense,
      amountCents: cents,
      date: date,
      description: 'compra',
      cardId: cardId,
    );

InvoiceCandidate cand(
  String cardId,
  DateTime due,
  int cents, {
  int month = 11,
}) => InvoiceCandidate(
  cardId: cardId,
  dueMonth: YearMonth(due.year, month),
  dueDate: due,
  remainingCents: cents,
);

void main() {
  group('invoiceCandidatesFor', () {
    test('só crédito, não arquivado, da conta; quitada fica fora', () {
      final a = card('a');
      final b = card('b');
      final cards = [
        b,
        card('debit', kind: CardKind.debit),
        card('other', paymentAccountId: 'acc2'),
        card('old', archived: true),
        a,
      ];
      // Fatura de nov do cartão `a` em aberto; a de dez está quitada.
      final txs = {
        'a': [
          purchase('a', DateTime(2026, 11, 4), 120000),
          purchase('a', DateTime(2026, 12, 4), 50000, id: 'dez'),
          Transaction(
            id: 'pag-dez',
            type: TransactionType.invoicePayment,
            amountCents: 50000,
            date: DateTime(2026, 12, 20),
            description: 'pagamento',
            cardId: 'a',
            invoiceKey: '2026-12',
          ),
        ],
        'b': [purchase('b', DateTime(2026, 11, 4), 80000)],
        'other': [purchase('other', DateTime(2026, 11, 4), 1000)],
        'old': [purchase('old', DateTime(2026, 11, 4), 1000)],
        'debit': [purchase('debit', DateTime(2026, 11, 4), 1000)],
      };
      final out = invoiceCandidatesFor(
        accountId: 'acc1',
        cards: cards,
        invoicesFor: (id) => InvoiceService.build(
          card: cards.firstWhere((c) => c.id == id),
          transactions: txs[id] ?? const [],
        ),
      );

      expect(out.map((c) => c.cardId), ['a', 'b']);
      expect(out.map((c) => c.remainingCents), [120000, 80000]);
      expect(out.map((c) => c.invoiceKey), ['2026-11', '2026-11']);
    });

    test('ordena por vencimento asc e depois cardId asc', () {
      // `c` fecha dia 1 e vence dia 5: vence antes de `a` e `b` (dia 12).
      final cards = [card('b'), card('a'), card('c', closing: 1, due: 5)];
      final out = invoiceCandidatesFor(
        accountId: 'acc1',
        cards: cards,
        invoicesFor: (id) => InvoiceService.build(
          card: cards.firstWhere((c) => c.id == id),
          transactions: [purchase(id, DateTime(2026, 10, 20), 1000)],
        ),
      );

      expect(out.map((c) => c.cardId), ['c', 'a', 'b']);
      expect(out.first.dueDate.isBefore(out[1].dueDate), isTrue);
    });
  });

  group('suggestInvoicePayment', () {
    final due = DateTime(2026, 11, 12);

    test('valor igual e vencimento a 10 dias sugere', () {
      final c = cand('a', due, 12000);
      expect(
        suggestInvoicePayment(
          amountCents: 12000,
          date: DateTime(2026, 11, 2),
          candidates: [c],
        ),
        c,
      );
      expect(
        suggestInvoicePayment(
          amountCents: 12000,
          date: DateTime(2026, 11, 22),
          candidates: [c],
        ),
        c,
      );
    });

    test('11 dias de distância não sugere', () {
      expect(
        suggestInvoicePayment(
          amountCents: 12000,
          date: DateTime(2026, 11, 1),
          candidates: [cand('a', due, 12000)],
        ),
        isNull,
      );
    });

    test('valor diferente não sugere', () {
      expect(
        suggestInvoicePayment(
          amountCents: 12001,
          date: due,
          candidates: [cand('a', due, 12000)],
        ),
        isNull,
      );
    });

    test('dois cartões com o mesmo valor: o de vencimento mais próximo', () {
      final near = cand('a', DateTime(2026, 11, 10), 5000);
      final far = cand('b', DateTime(2026, 11, 14), 5000);
      final pick = suggestInvoicePayment(
        amountCents: 5000,
        date: DateTime(2026, 11, 9),
        candidates: [far, near],
      );
      expect(pick, near);
    });

    test('empate de distância: vencimento asc, depois cardId asc', () {
      // Ambos a 2 dias de 12/11.
      final earlier = cand('z', DateTime(2026, 11, 10), 5000);
      final later = cand('a', DateTime(2026, 11, 14), 5000);
      expect(
        suggestInvoicePayment(
          amountCents: 5000,
          date: DateTime(2026, 11, 12),
          candidates: [later, earlier],
        ),
        earlier,
      );
      // Mesmo vencimento: cardId asc.
      final sameDueB = cand('b', due, 5000);
      final sameDueA = cand('a', due, 5000);
      expect(
        suggestInvoicePayment(
          amountCents: 5000,
          date: due,
          candidates: [sameDueB, sameDueA],
        ),
        sameDueA,
      );
    });
  });

  group('invoiceChoicesFor', () {
    test('uma candidata por cartão, a mais próxima; empate fica a anterior', () {
      final candidates = [
        cand('b', DateTime(2026, 11, 12), 1000),
        cand('b', DateTime(2026, 12, 12), 2000, month: 12),
        cand('a', DateTime(2026, 11, 12), 3000),
        cand('a', DateTime(2026, 12, 2), 4000, month: 12),
      ];
      // 22/11: a de 12/11 e a de 02/12 estão ambas a 10 dias em `a`; a anterior vence.
      final out = invoiceChoicesFor(DateTime(2026, 11, 22), candidates);

      expect(out.map((c) => c.cardId), ['a', 'b']);
      expect(out[0].dueDate, DateTime(2026, 11, 12));
      expect(out[0].remainingCents, 3000);
      expect(out[1].dueDate, DateTime(2026, 11, 12));
      expect(out[1].remainingCents, 1000);
    });

    test('sem limite de dias: escolhe a fatura mais próxima mesmo longe', () {
      final out = invoiceChoicesFor(DateTime(2027, 3, 1), [
        cand('a', DateTime(2026, 11, 12), 1000),
        cand('a', DateTime(2026, 12, 12), 2000, month: 12),
      ]);
      expect(out.single.remainingCents, 2000);
    });
  });

  test('invoiceKey == dueMonth.key', () {
    expect(cand('a', DateTime(2026, 11, 12), 1).invoiceKey, '2026-11');
  });
}
