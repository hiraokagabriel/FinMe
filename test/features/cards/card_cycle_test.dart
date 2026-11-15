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

  group('transição de ciclo (SPEC §5.1)', () {
    // Fecha 5/vence 12 até 30/11; fecha 25/vence 5 a partir de 01/12.
    final c = changedCard();

    test('compra antes da 1ª fronteira usa o ciclo antigo', () {
      final jun = invoiceOf(
        InvoiceService.build(
          card: c,
          transactions: [
            tx('j', TransactionType.expense, 1000, DateTime(2026, 6, 4)),
          ],
        ),
        '2026-06',
      );
      expect(jun.dueDate, DateTime(2026, 6, 12));
      expect(jun.closingDate, DateTime(2026, 6, 5));
    });

    test('compra 04/11 fica em nov e vence 12/11', () {
      final nov = invoiceOf(
        InvoiceService.build(
          card: c,
          transactions: [
            tx('a', TransactionType.expense, 1000, DateTime(2026, 11, 4)),
          ],
        ),
        '2026-11',
      );
      expect(nov.dueDate, DateTime(2026, 11, 12));
      expect(nov.closingDate, DateTime(2026, 11, 5));
    });

    test('compras 20/11 e 02/12 viram 2027-01 (fecha 25/12, vence 05/01)', () {
      final invoices = InvoiceService.build(
        card: c,
        transactions: [
          tx('a', TransactionType.expense, 1000, DateTime(2026, 11, 20)),
          tx('b', TransactionType.expense, 1000, DateTime(2026, 12, 2)),
        ],
      );
      expect(invoices.map((i) => i.dueMonth.key), ['2027-01']);
      final jan = invoices.single;
      expect(jan.dueDate, DateTime(2027, 1, 5));
      expect(jan.closingDate, DateTime(2026, 12, 25));
      expect(jan.items, hasLength(2));
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

    test('parcelado 3x com 1ª em 15/10 cai em 2026-11, 2027-01 e 2027-02', () {
      final invoices = InvoiceService.build(
        card: c,
        transactions: buildInstallments(
          base: tx('p', TransactionType.expense, 9000, DateTime(2026, 10, 15)),
          count: 3,
          groupId: 'g',
        ),
      );
      expect(invoices.map((i) => i.dueMonth.key), [
        '2026-11',
        '2027-01',
        '2027-02',
      ]);
      expect(invoiceOf(invoices, '2027-01').dueDate, DateTime(2027, 1, 5));
    });

    test('purchaseDueDate(04/11/2026) segue o ciclo antigo → 12/11/2026', () {
      expect(purchaseDueDate(DateTime(2026, 11, 4), c), DateTime(2026, 11, 12));
    });
  });

  group('transição para fecha 20/vence 27 a partir de 15/11 (SPEC §5.1)', () {
    final c = card().withCycleChange(
      closingDay: 20,
      dueDay: 27,
      effectiveFrom: DateTime(2026, 11, 15),
    );

    test('compra 04/11 fica em nov (vence 12/11)', () {
      final nov = invoiceOf(
        InvoiceService.build(
          card: c,
          transactions: [
            tx('a', TransactionType.expense, 1000, DateTime(2026, 11, 4)),
          ],
        ),
        '2026-11',
      );
      expect(nov.dueDate, DateTime(2026, 11, 12));
    });

    test('compras 10/11 e 16/11 viram 2026-12 (fecha 20/12, vence 27/12)', () {
      final invoices = InvoiceService.build(
        card: c,
        transactions: [
          tx('a', TransactionType.expense, 1000, DateTime(2026, 11, 10)),
          tx('b', TransactionType.expense, 1000, DateTime(2026, 11, 16)),
        ],
      );
      expect(invoices.map((i) => i.dueMonth.key), ['2026-12']);
      final dec = invoiceOf(invoices, '2026-12');
      expect(dec.closingDate, DateTime(2026, 12, 20));
      expect(dec.dueDate, DateTime(2026, 12, 27));
    });

    test(
      'fatura 2026-12 com só um item do ciclo antigo tem as mesmas datas',
      () {
        final dec = invoiceOf(
          InvoiceService.build(
            card: c,
            transactions: [
              tx('a', TransactionType.expense, 1000, DateTime(2026, 11, 10)),
            ],
          ),
          '2026-12',
        );
        expect(dec.closingDate, DateTime(2026, 12, 20));
        expect(dec.dueDate, DateTime(2026, 12, 27));
      },
    );
  });

  group('transição para fecha 5/vence 12 a partir de 01/12 (SPEC §5.1)', () {
    final c = card(closing: 25, due: 5).withCycleChange(
      closingDay: 5,
      dueDay: 12,
      effectiveFrom: DateTime(2026, 12, 1),
    );

    test('compra 24/11 vai para 2026-12 (vence 05/12)', () {
      final dec = invoiceOf(
        InvoiceService.build(
          card: c,
          transactions: [
            tx('a', TransactionType.expense, 1000, DateTime(2026, 11, 24)),
          ],
        ),
        '2026-12',
      );
      expect(dec.dueDate, DateTime(2026, 12, 5));
    });

    test('compra 28/11 vai para 2027-01 (fecha 05/01, vence 12/01)', () {
      final jan = invoiceOf(
        InvoiceService.build(
          card: c,
          transactions: [
            tx('a', TransactionType.expense, 1000, DateTime(2026, 11, 28)),
          ],
        ),
        '2027-01',
      );
      expect(jan.closingDate, DateTime(2027, 1, 5));
      expect(jan.dueDate, DateTime(2027, 1, 12));
    });

    test(
      'dois descartes seguidos na fronteira: compra 06/12 vai para 2027-02',
      () {
        // Fecha 5/vence 3 até 20/12; fecha 25/vence 28 a partir de 20/12.
        // Fechamentos 25/12 e 25/01 repetem vencimento já usado → descartados.
        final odd = card(closing: 5, due: 3).withCycleChange(
          closingDay: 25,
          dueDay: 28,
          effectiveFrom: DateTime(2026, 12, 20),
        );
        final invoices = InvoiceService.build(
          card: odd,
          transactions: [
            tx('a', TransactionType.expense, 1000, DateTime(2026, 12, 6)),
          ],
        );
        expect(invoices.map((i) => i.dueMonth.key), ['2027-02']);
        expect(invoices.single.dueDate, DateTime(2027, 2, 28));
        expect(
          installmentDueMonth(DateTime(2026, 12, 6), 2, odd),
          const YearMonth(2027, 3),
        );
      },
    );
  });

  group('pagamento com invoiceKey de mês descartado (SPEC §5.1)', () {
    // Fecha 5/vence 12 → fecha 25/vence 5 a partir de 01/12: 2026-12 não tem fechamento mantido.
    final c = changedCard();

    test('invoiceMonthForKey: mês descartado vai para o próximo mantido', () {
      expect(
        invoiceMonthForKey(const YearMonth(2026, 12), c),
        const YearMonth(2027, 1),
      );
      expect(
        invoiceMonthForKey(const YearMonth(2026, 11), c),
        const YearMonth(2026, 11),
      );
      expect(
        invoiceMonthForKey(const YearMonth(2027, 1), c),
        const YearMonth(2027, 1),
      );
    });

    test('sem histórico, invoiceMonthForKey devolve o mês', () {
      expect(
        invoiceMonthForKey(const YearMonth(2026, 12), card()),
        const YearMonth(2026, 12),
      );
    });

    test(
      'pagamento antecipado de 2026-12 abate a fatura de transição 2027-01',
      () {
        final invoices = InvoiceService.build(
          card: c,
          transactions: [
            tx(
              'compra',
              TransactionType.expense,
              10000,
              DateTime(2026, 11, 10),
            ),
            tx(
              'pag',
              TransactionType.invoicePayment,
              4000,
              DateTime(2026, 11, 20),
              invoiceKey: '2026-12',
            ),
          ],
        );
        expect(invoices.map((i) => i.dueMonth.key), ['2027-01']);
        final jan = invoiceOf(invoices, '2027-01');
        expect(jan.paidCents, 4000);
        expect(jan.remainingCents, 6000);
        expect(jan.statusOn(DateTime(2026, 12, 1)), InvoiceStatus.open);
      },
    );

    test('sem histórico, pagamento de 2026-12 continua em 2026-12', () {
      final invoices = InvoiceService.build(
        card: card(),
        transactions: [
          tx('compra', TransactionType.expense, 1000, DateTime(2026, 11, 4)),
          tx(
            'pag',
            TransactionType.invoicePayment,
            300,
            DateTime(2026, 11, 20),
            invoiceKey: '2026-12',
          ),
        ],
      );
      expect(invoices.map((i) => i.dueMonth.key), ['2026-11', '2026-12']);
      expect(invoiceOf(invoices, '2026-12').paidCents, 300);
    });
  });

  group('purchaseDueDate e vencimento da fatura', () {
    final cards = {
      'sem mudança': card(),
      'fecha 25/vence 5 → 5/12': card(closing: 25, due: 5).withCycleChange(
        closingDay: 5,
        dueDay: 12,
        effectiveFrom: DateTime(2026, 12, 1),
      ),
      'fecha 5/vence 12 → 20/27': card().withCycleChange(
        closingDay: 20,
        dueDay: 27,
        effectiveFrom: DateTime(2026, 11, 15),
      ),
      'duas mudanças': card(closing: 25, due: 5)
          .withCycleChange(
            closingDay: 5,
            dueDay: 12,
            effectiveFrom: DateTime(2026, 12, 1),
          )
          .withCycleChange(
            closingDay: 10,
            dueDay: 20,
            effectiveFrom: DateTime(2027, 2, 1),
          ),
    };

    for (final entry in cards.entries) {
      test('${entry.key}: vencimento da compra = vencimento da fatura', () {
        final c = entry.value;
        final purchases = [
          for (var i = 0; i < 200; i += 3)
            tx('t$i', TransactionType.expense, 100, DateTime(2026, 10, 1 + i)),
        ];
        final invoices = InvoiceService.build(card: c, transactions: purchases);
        for (final p in purchases) {
          final owner = invoices.firstWhere(
            (inv) => inv.items.any((item) => item.id == p.id),
          );
          expect(purchaseDueDate(p.date, c), owner.dueDate, reason: p.id);
        }
      });
    }

    test('duas mudanças seguidas: dueMonth crescente, sem duplicata', () {
      final c = changedCard().withCycleChange(
        closingDay: 10,
        dueDay: 20,
        effectiveFrom: DateTime(2027, 2, 1),
      );
      final invoices = InvoiceService.build(
        card: c,
        transactions: [
          for (var i = 0; i < 300; i += 2)
            tx('t$i', TransactionType.expense, 100, DateTime(2026, 9, 1 + i)),
        ],
      );
      for (var i = 1; i < invoices.length; i++) {
        expect(invoices[i].dueMonth > invoices[i - 1].dueMonth, isTrue);
      }
      expect(
        invoices.map((i) => i.dueMonth).toSet(),
        hasLength(invoices.length),
      );
    });
  });

  group('installmentDueMonth', () {
    test('sem histórico: igual a invoiceDueMonth(d1) + (i - 1) meses', () {
      for (final c in [card(), card(closing: 25, due: 5)]) {
        for (final d1 in [DateTime(2026, 11, 4), DateTime(2027, 1, 31)]) {
          for (var i = 1; i <= 12; i++) {
            expect(
              installmentDueMonth(d1, i, c),
              invoiceDueMonth(d1, c).addMonths(i - 1),
              reason: '$d1 parcela $i',
            );
          }
        }
      }
    });
  });
}
