import 'package:finme/core/models/year_month.dart';
import 'package:finme/features/cards/domain/invoice.dart';
import 'package:finme/features/cards/domain/invoice_cycle.dart';
import 'package:finme/features/cards/domain/payment_card.dart';
import 'package:finme/features/transactions/domain/installments.dart';
import 'package:finme/features/transactions/domain/transaction.dart';
import 'package:flutter_test/flutter_test.dart';

PaymentCard card({
  int closing = 5,
  int due = 12,
  List<CardCycle> history = const [],
}) => PaymentCard(
  id: 'c1',
  name: 'Cartão',
  bankName: 'Banco A',
  brand: CardBrand.visa,
  kind: CardKind.credit,
  last4: '1234',
  closingDay: closing,
  dueDay: due,
  colorValue: 0xFF1565C0,
  cycleHistory: history,
);

/// Cenário do SPEC §5.1: fecha 5/vence 12 até 30/11/2026; fecha 25/vence 5 a partir de 01/12/2026.
PaymentCard changedCard() => card().withCycleChange(
  closingDay: 25,
  dueDay: 5,
  effectiveFrom: DateTime(2026, 12, 1),
);

Transaction tx(
  String id,
  TransactionType type,
  int cents,
  DateTime date, {
  String? invoiceKey,
}) => Transaction(
  id: id,
  type: type,
  amountCents: cents,
  date: date,
  description: id,
  cardId: 'c1',
  invoiceKey: invoiceKey,
);

Invoice invoiceOf(List<Invoice> invoices, String key) =>
    invoices.firstWhere((i) => i.dueMonth == YearMonth.fromKey(key));

void main() {
  group('CardCycle / PaymentCard.fromMap', () {
    test('sem cycleHistory, null ou não-lista → lista vazia', () {
      final base = card().toMap()..remove('cycleHistory');
      expect(PaymentCard.fromMap(base).cycleHistory, isEmpty);
      expect(
        PaymentCard.fromMap({...base, 'cycleHistory': null}).cycleHistory,
        isEmpty,
      );
      expect(
        PaymentCard.fromMap({...base, 'cycleHistory': 'x'}).cycleHistory,
        isEmpty,
      );
    });

    test('item inválido é ignorado, os válidos são mantidos', () {
      final valid = changedCard().cycleHistory.single.toMap();
      final map = card().toMap()
        ..['cycleHistory'] = [
          {'until': 'nao-e-data', 'closingDay': 5, 'dueDay': 12},
          {'until': '20261201'},
          'lixo',
          valid,
        ];
      final parsed = PaymentCard.fromMap(map);
      expect(parsed.cycleHistory, [changedCard().cycleHistory.single]);
    });

    test('ciclos fora de ordem no backup são ordenados por until', () {
      final a = CardCycle(
        until: DateTime(2026, 12, 1),
        closingDay: 5,
        dueDay: 12,
      );
      final b = CardCycle(
        until: DateTime(2027, 2, 1),
        closingDay: 10,
        dueDay: 20,
      );
      final map = card().toMap()..['cycleHistory'] = [b.toMap(), a.toMap()];
      expect(PaymentCard.fromMap(map).cycleHistory, [a, b]);
    });

    test('round-trip com 2 ciclos preserva igualdade e hashCode', () {
      final two = changedCard().withCycleChange(
        closingDay: 10,
        dueDay: 20,
        effectiveFrom: DateTime(2027, 2, 1),
      );
      expect(two.cycleHistory, hasLength(2));
      final back = PaymentCard.fromMap(two.toMap());
      expect(back, two);
      expect(back.hashCode, two.hashCode);
      expect(back.cycleHistory.first.until, DateTime(2026, 12, 1));
    });
  });

  group('cycleOn', () {
    final c = card(
      closing: 25,
      due: 5,
      history: [
        CardCycle(until: DateTime(2026, 12, 1), closingDay: 5, dueDay: 12),
      ],
    );

    test('usa o ciclo antigo antes de until e o atual a partir dele', () {
      final before = c.cycleOn(DateTime(2026, 11, 30, 23, 59));
      expect((before.closingDay, before.dueDay), (5, 12));
      final after = c.cycleOn(DateTime(2026, 12, 1, 8));
      expect((after.closingDay, after.dueDay), (25, 5));
    });

    test('sem histórico devolve sempre o ciclo atual', () {
      final plain = card(closing: 25, due: 5).cycleOn(DateTime(2020));
      expect((plain.closingDay, plain.dueDay), (25, 5));
    });
  });

  group('withCycleChange', () {
    test('dias iguais aos atuais → mesma instância', () {
      final c = card();
      expect(
        identical(
          c.withCycleChange(
            closingDay: 5,
            dueDay: 12,
            effectiveFrom: DateTime(2026, 12, 1),
          ),
          c,
        ),
        isTrue,
      );
    });

    test('data não posterior ao último until → ArgumentError', () {
      final c = changedCard();
      expect(
        () => c.withCycleChange(
          closingDay: 10,
          dueDay: 20,
          effectiveFrom: DateTime(2026, 12, 1, 15),
        ),
        throwsArgumentError,
      );
      expect(
        () => c.withCycleChange(
          closingDay: 10,
          dueDay: 20,
          effectiveFrom: DateTime(2026, 11, 30),
        ),
        throwsArgumentError,
      );
    });

    test('caso normal empilha o ciclo antigo e atualiza os dias', () {
      final c = changedCard();
      expect(c.closingDay, 25);
      expect(c.dueDay, 5);
      expect(c.cycleHistory, [
        CardCycle(until: DateTime(2026, 12, 1), closingDay: 5, dueDay: 12),
      ]);
    });
  });

  group('transição de ciclo', () {
    final c = changedCard();

    test('compra 20/11 → fatura 2026-12 vence 12/12/2026', () {
      final invoices = InvoiceService.build(
        card: c,
        transactions: [
          tx('a', TransactionType.expense, 1000, DateTime(2026, 11, 20)),
        ],
      );
      final dec = invoiceOf(invoices, '2026-12');
      expect(dec.dueDate, DateTime(2026, 12, 12));
      expect(dec.closingDate, DateTime(2026, 12, 5));
    });

    test('compra 02/12 → fatura 2027-01 vence 05/01/2027', () {
      final invoices = InvoiceService.build(
        card: c,
        transactions: [
          tx('b', TransactionType.expense, 1000, DateTime(2026, 12, 2)),
        ],
      );
      final jan = invoiceOf(invoices, '2027-01');
      expect(jan.dueDate, DateTime(2027, 1, 5));
    });

    test('pagamento de nov feito antes da mudança quita a fatura de nov', () {
      final invoices = InvoiceService.build(
        card: c,
        transactions: [
          tx('compra', TransactionType.expense, 1000, DateTime(2026, 11, 4)),
          tx(
            'pag',
            TransactionType.invoicePayment,
            1000,
            DateTime(2026, 11, 13),
            invoiceKey: '2026-11',
          ),
        ],
      );
      final nov = invoiceOf(invoices, '2026-11');
      expect(nov.dueDate, DateTime(2026, 11, 12));
      expect(nov.remainingCents, 0);
      expect(nov.statusOn(DateTime(2026, 11, 14)), InvoiceStatus.paid);
    });

    test('parcelado 3x comprado 15/10/2026 cai em nov, dez e jan', () {
      final installments = buildInstallments(
        base: tx('p', TransactionType.expense, 9000, DateTime(2026, 10, 15)),
        count: 3,
        groupId: 'g',
      );
      final invoices = InvoiceService.build(
        card: c,
        transactions: installments,
      );
      expect(invoices.map((i) => i.dueMonth.key), [
        '2026-11',
        '2026-12',
        '2027-01',
      ]);
      expect(invoiceOf(invoices, '2027-01').dueDate, DateTime(2027, 1, 5));
    });

    test('purchaseDueDate(14/11/2026) com fecha 5/vence 12 → 12/12/2026', () {
      expect(
        purchaseDueDate(DateTime(2026, 11, 14), card()),
        DateTime(2026, 12, 12),
      );
    });
  });

  group('fatura fundida (regressão)', () {
    // Fecha 5/vence 12 até 30/11; fecha 10/vence 20 a partir de 01/12. Ambas caem em dez/2026.
    final c = card().withCycleChange(
      closingDay: 10,
      dueDay: 20,
      effectiveFrom: DateTime(2026, 12, 1),
    );
    final oldPurchase = tx(
      'old',
      TransactionType.expense,
      1000,
      DateTime(2026, 11, 20),
    );
    final newPurchase = tx(
      'new',
      TransactionType.expense,
      2000,
      DateTime(2026, 12, 2),
    );

    test(
      'só com a compra do ciclo antigo: fatura vence 12/12, fecha 05/12',
      () {
        final dec = invoiceOf(
          InvoiceService.build(card: c, transactions: [oldPurchase]),
          '2026-12',
        );
        expect(dec.dueDate, DateTime(2026, 12, 12));
        expect(dec.closingDate, DateTime(2026, 12, 5));
      },
    );

    test(
      'entra a 1ª compra do ciclo novo: fatura fundida passa a vencer 20/12, fecha 10/12',
      () {
        final invoices = InvoiceService.build(
          card: c,
          transactions: [oldPurchase, newPurchase],
        );
        expect(invoices, hasLength(1));
        expect(invoices.single.items, hasLength(2));
        expect(invoices.single.dueDate, DateTime(2026, 12, 20));
        expect(invoices.single.closingDate, DateTime(2026, 12, 10));
      },
    );

    test(
      'purchaseDueDate segue o ciclo da compra, não o da fatura fundida',
      () {
        expect(
          purchaseDueDate(DateTime(2026, 11, 20), c),
          DateTime(2026, 12, 12),
        );
        expect(
          purchaseDueDate(DateTime(2026, 12, 2), c),
          DateTime(2026, 12, 20),
        );
      },
    );
  });
}
