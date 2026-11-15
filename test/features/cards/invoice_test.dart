import 'package:finme/core/models/year_month.dart';
import 'package:finme/features/cards/domain/invoice.dart';
import 'package:finme/features/cards/domain/invoice_cycle.dart';
import 'package:finme/features/cards/domain/payment_card.dart';
import 'package:finme/features/transactions/domain/transaction.dart';
import 'package:flutter_test/flutter_test.dart';

PaymentCard creditCard({required int closing, required int due}) => PaymentCard(
  id: 'c1',
  name: 'Cartão',
  bankName: 'Banco A',
  brand: CardBrand.visa,
  kind: CardKind.credit,
  last4: '1234',
  closingDay: closing,
  dueDay: due,
  colorValue: 0xFF1565C0,
);

Transaction tx(
  String id,
  TransactionType type,
  int cents,
  DateTime date, {
  String? cardId = 'c1',
  String? invoiceKey,
}) => Transaction(
  id: id,
  type: type,
  amountCents: cents,
  date: date,
  description: id,
  cardId: cardId,
  invoiceKey: invoiceKey,
);

Invoice invoiceOf(List<Invoice> invoices, String key) =>
    invoices.firstWhere((i) => i.dueMonth == YearMonth.fromKey(key));

void main() {
  group('invoice_cycle', () {
    final c512 = creditCard(closing: 5, due: 12);
    final c255 = creditCard(closing: 25, due: 5);

    test('exemplos do SPEC §5.1', () {
      // fecha 5, vence 12
      expect(
        invoiceDueMonth(DateTime(2026, 11, 4), c512),
        const YearMonth(2026, 11),
      );
      expect(
        invoiceDueDate(invoiceDueMonth(DateTime(2026, 11, 4), c512), c512),
        DateTime(2026, 11, 12),
      );
      expect(
        invoiceDueMonth(DateTime(2026, 11, 5), c512),
        const YearMonth(2026, 12),
      );
      // fecha 25, vence 5
      expect(
        invoiceDueMonth(DateTime(2026, 11, 24), c255),
        const YearMonth(2026, 12),
      );
      expect(
        invoiceDueMonth(DateTime(2026, 11, 25), c255),
        const YearMonth(2027, 1),
      );
    });

    test('datas de fechamento e vencimento', () {
      expect(
        invoiceClosingDate(const YearMonth(2026, 11), c512),
        DateTime(2026, 11, 5),
      );
      expect(
        invoiceClosingDate(const YearMonth(2026, 12), c255),
        DateTime(2026, 11, 25),
      );
      expect(
        invoiceDueDate(const YearMonth(2027, 1), c255),
        DateTime(2027, 1, 5),
      );
    });

    test('fechamento dia 31 em fevereiro é limitado ao mês', () {
      final c = creditCard(closing: 31, due: 10);
      expect(
        invoiceDueMonth(DateTime(2027, 1, 30), c),
        const YearMonth(2027, 2),
      );
      // 31/01 é o fechamento: vai para o ciclo seguinte.
      expect(
        invoiceDueMonth(DateTime(2027, 1, 31), c),
        const YearMonth(2027, 3),
      );
      // 27/02 < 28/02 (fechamento limitado): fatura de fevereiro.
      expect(
        invoiceDueMonth(DateTime(2027, 2, 27), c),
        const YearMonth(2027, 3),
      );
      // 28/02 é o fechamento efetivo: vai para o ciclo seguinte.
      expect(
        invoiceDueMonth(DateTime(2027, 2, 28), c),
        const YearMonth(2027, 4),
      );
      expect(
        invoiceClosingDate(const YearMonth(2027, 3), c),
        DateTime(2027, 2, 28),
      );
      expect(
        invoiceClosingDate(const YearMonth(2027, 4), c),
        DateTime(2027, 3, 31),
      );
    });

    test('virada de ano: fecha 25, vence 5', () {
      final purchase = DateTime(2026, 12, 28);
      final due = invoiceDueMonth(purchase, c255);
      expect(due, const YearMonth(2027, 2));
      expect(invoiceClosingDate(due, c255), DateTime(2027, 1, 25));
      expect(invoiceDueDate(due, c255), DateTime(2027, 2, 5));
    });
  });

  group('InvoiceService.build', () {
    final card = creditCard(closing: 5, due: 12);

    test('cartão de débito não tem faturas', () {
      final debit = const PaymentCard(
        id: 'c1',
        name: 'Débito',
        bankName: 'Banco A',
        brand: CardBrand.visa,
        kind: CardKind.debit,
        last4: '0000',
        closingDay: 5,
        dueDay: 12,
        colorValue: 0xFF1565C0,
      );
      final invoices = InvoiceService.build(
        card: debit,
        transactions: [
          tx('d', TransactionType.expense, 100, DateTime(2026, 11, 4)),
        ],
      );
      expect(invoices, isEmpty);
    });

    test(
      'agrupa compras, estornos e pagamento; ignora outros cartões e transfer',
      () {
        final invoices = InvoiceService.build(
          card: card,
          transactions: [
            // Fora de ordem de propósito: items devem sair ordenados por data.
            tx('compra', TransactionType.expense, 10000, DateTime(2026, 11, 4)),
            tx('estorno', TransactionType.income, 2000, DateTime(2026, 11, 3)),
            tx('dez', TransactionType.expense, 5000, DateTime(2026, 11, 5)),
            tx(
              'transf',
              TransactionType.transfer,
              999,
              DateTime(2026, 11, 4),
              cardId: null,
            ),
            tx(
              'outro',
              TransactionType.expense,
              777,
              DateTime(2026, 11, 4),
              cardId: 'c2',
            ),
            tx(
              'pag',
              TransactionType.invoicePayment,
              3000,
              DateTime(2026, 11, 20),
              invoiceKey: '2026-11',
            ),
          ],
        );

        expect(invoices.map((i) => i.dueMonth.key), ['2026-11', '2026-12']);

        final nov = invoices.first;
        expect(nov.chargesCents, 10000);
        expect(nov.creditsCents, 2000);
        expect(nov.totalCents, 8000);
        expect(nov.paidCents, 3000);
        expect(nov.remainingCents, 5000);
        expect(nov.closingDate, DateTime(2026, 11, 5));
        expect(nov.dueDate, DateTime(2026, 11, 12));
        expect(nov.items.map((t) => t.id), ['estorno', 'compra']);
        expect(nov.id, 'c1_2026-11');

        final dec = invoices.last;
        expect(dec.totalCents, 5000);
        expect(dec.items.map((t) => t.id), ['dez']);
      },
    );

    test('pagamento sem compras cria a fatura', () {
      final invoices = InvoiceService.build(
        card: card,
        transactions: [
          tx(
            'pag',
            TransactionType.invoicePayment,
            500,
            DateTime(2027, 3, 1),
            invoiceKey: '2027-03',
          ),
        ],
      );
      expect(invoices, hasLength(1));
      expect(invoices.single.dueMonth, const YearMonth(2027, 3));
      expect(invoices.single.items, isEmpty);
      expect(invoices.single.totalCents, 0);
      expect(invoices.single.paidCents, 500);
    });

    test('projetados entram na fatura e no total', () {
      final invoices = InvoiceService.build(
        card: card,
        transactions: [
          tx('a', TransactionType.expense, 1000, DateTime(2026, 11, 4)),
        ],
        projected: [
          tx('p', TransactionType.expense, 300, DateTime(2026, 11, 3)),
        ],
      );
      final nov = invoices.single;
      expect(nov.totalCents, 1300);
      expect(nov.items.map((t) => t.id), ['p', 'a']);
    });

    test('parcelas futuras geram faturas futuras', () {
      final invoices = InvoiceService.build(
        card: card,
        transactions: [
          for (var i = 0; i < 3; i++)
            tx(
              'parcela$i',
              TransactionType.expense,
              1000,
              DateTime(2026, 11 + i, 4),
            ),
        ],
      );
      expect(invoices.map((i) => i.dueMonth.key), [
        '2026-11',
        '2026-12',
        '2027-01',
      ]);
    });
  });

  group('status e limite', () {
    final card = creditCard(closing: 5, due: 12);
    final purchase = [
      tx('a', TransactionType.expense, 1000, DateTime(2026, 11, 4)),
    ];

    test('status open/closed/overdue/paid', () {
      final invoice = invoiceOf(
        InvoiceService.build(card: card, transactions: purchase),
        '2026-11',
      );
      expect(invoice.statusOn(DateTime(2026, 11, 4)), InvoiceStatus.open);
      expect(invoice.statusOn(DateTime(2026, 11, 5)), InvoiceStatus.closed);
      expect(
        invoice.statusOn(DateTime(2026, 11, 12, 23, 59)),
        InvoiceStatus.closed,
      );
      expect(invoice.statusOn(DateTime(2026, 11, 13)), InvoiceStatus.overdue);
    });

    test('quitada vira paid mesmo após o vencimento', () {
      final invoices = InvoiceService.build(
        card: card,
        transactions: [
          ...purchase,
          tx(
            'pag',
            TransactionType.invoicePayment,
            1000,
            DateTime(2026, 11, 13),
            invoiceKey: '2026-11',
          ),
        ],
      );
      final invoice = invoices.single;
      expect(invoice.remainingCents, 0);
      expect(invoice.statusOn(DateTime(2026, 11, 13)), InvoiceStatus.paid);
    });

    test('pagamento a maior não gera saldo negativo', () {
      final invoices = InvoiceService.build(
        card: card,
        transactions: [
          ...purchase,
          tx(
            'pag',
            TransactionType.invoicePayment,
            1500,
            DateTime(2026, 11, 6),
            invoiceKey: '2026-11',
          ),
        ],
      );
      expect(invoices.single.remainingCents, 0);
    });

    test('usedLimitCents soma faturas não quitadas, incluindo futuras', () {
      final invoices = InvoiceService.build(
        card: card,
        transactions: [
          tx('n', TransactionType.expense, 1000, DateTime(2026, 11, 4)),
          tx('d', TransactionType.expense, 2000, DateTime(2026, 12, 4)),
          tx('j', TransactionType.expense, 3000, DateTime(2027, 1, 4)),
          tx(
            'pag',
            TransactionType.invoicePayment,
            400,
            DateTime(2026, 11, 13),
            invoiceKey: '2026-11',
          ),
        ],
      );
      expect(
        InvoiceService.usedLimitCents(invoices, DateTime(2026, 11, 14)),
        600 + 2000 + 3000,
      );
    });

    test('currentInvoice: fatura não paga mais antiga, inclusive vencida', () {
      final invoices = InvoiceService.build(
        card: card,
        transactions: [
          tx('n', TransactionType.expense, 1000, DateTime(2026, 11, 4)),
          tx('d', TransactionType.expense, 2000, DateTime(2026, 12, 4)),
          tx('j', TransactionType.expense, 3000, DateTime(2027, 1, 4)),
        ],
      );
      // Nov vencida (12/11) e não paga: é a atual.
      expect(
        InvoiceService.currentInvoice(
          invoices,
          DateTime(2026, 11, 14),
        )?.dueMonth,
        const YearMonth(2026, 11),
      );
      // Mesmo após todos os vencimentos, a mais antiga não paga continua sendo Nov.
      expect(
        InvoiceService.currentInvoice(invoices, DateTime(2027, 3, 1))?.dueMonth,
        const YearMonth(2026, 11),
      );
    });

    test('currentInvoice: pula quitadas e é null se todas quitadas', () {
      final purchases = [
        tx('n', TransactionType.expense, 1000, DateTime(2026, 11, 4)),
        tx('d', TransactionType.expense, 2000, DateTime(2026, 12, 4)),
        tx('j', TransactionType.expense, 3000, DateTime(2027, 1, 4)),
      ];
      final payNov = tx(
        'pagN',
        TransactionType.invoicePayment,
        1000,
        DateTime(2026, 11, 13),
        invoiceKey: '2026-11',
      );
      final payDec = tx(
        'pagD',
        TransactionType.invoicePayment,
        2000,
        DateTime(2026, 12, 13),
        invoiceKey: '2026-12',
      );
      final payJan = tx(
        'pagJ',
        TransactionType.invoicePayment,
        3000,
        DateTime(2027, 1, 13),
        invoiceKey: '2027-01',
      );
      final partial = InvoiceService.build(
        card: card,
        transactions: [...purchases, payNov],
      );
      expect(
        InvoiceService.currentInvoice(
          partial,
          DateTime(2026, 11, 14),
        )?.dueMonth,
        const YearMonth(2026, 12),
      );
      final allPaid = InvoiceService.build(
        card: card,
        transactions: [...purchases, payNov, payDec, payJan],
      );
      expect(
        InvoiceService.currentInvoice(allPaid, DateTime(2026, 11, 14)),
        isNull,
      );
    });
  });
}
