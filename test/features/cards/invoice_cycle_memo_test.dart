import 'package:finme/features/cards/domain/invoice.dart';
import 'package:finme/features/cards/domain/invoice_cycle.dart';
import 'package:finme/features/cards/domain/payment_card.dart';
import 'package:finme/features/transactions/domain/transaction.dart';
import 'package:flutter_test/flutter_test.dart';

/// Cartão com 3 mudanças de ciclo (SPEC §9.2): a linha de fechamentos é memoizada por instância.
PaymentCard threeChangesCard() =>
    const PaymentCard(
          id: 'c1',
          name: 'Cartão',
          bankName: 'Banco A',
          brand: CardBrand.visa,
          kind: CardKind.credit,
          last4: '1234',
          closingDay: 5,
          dueDay: 12,
          colorValue: 0xFF1565C0,
        )
        .withCycleChange(
          closingDay: 10,
          dueDay: 20,
          effectiveFrom: DateTime(2026, 3, 1),
        )
        .withCycleChange(
          closingDay: 25,
          dueDay: 5,
          effectiveFrom: DateTime(2026, 6, 1),
        )
        .withCycleChange(
          closingDay: 15,
          dueDay: 25,
          effectiveFrom: DateTime(2026, 9, 1),
        );

List<Transaction> manyPurchases() => [
  for (var i = 0; i < 5000; i++)
    Transaction(
      id: 't$i',
      type: TransactionType.expense,
      amountCents: 100 + i,
      date: DateTime(2025, 1, 1).add(Duration(days: (i * 7) % 900)),
      description: 'Compra $i',
      cardId: 'c1',
    ),
];

/// Resumo comparável de cada fatura (datas, totais e quantidade de itens).
List<(String, DateTime, DateTime, int, int)> summary(
  List<Invoice> invoices,
) => [
  for (final i in invoices)
    (i.dueMonth.key, i.closingDate, i.dueDate, i.totalCents, i.items.length),
];

void main() {
  test(
    'faturas com 3 mudanças de ciclo e 5.000 compras: igual à instância nova e < 200 ms',
    () {
      final card = threeChangesCard();
      final txs = manyPurchases();

      // Primeira chamada popula a linha (aquecimento); o tempo medido é o da chamada seguinte.
      final first = InvoiceService.build(card: card, transactions: txs);
      final watch = Stopwatch()..start();
      final cached = InvoiceService.build(card: card, transactions: txs);
      watch.stop();
      expect(summary(cached), summary(first));

      // copyWith cria instância nova (linha de fechamentos vazia), sem o cache da primeira.
      final fresh = card.copyWith(name: 'Outro nome');
      final rebuilt = InvoiceService.build(card: fresh, transactions: txs);

      expect(summary(cached), summary(rebuilt));
      expect(cached.length, greaterThan(20));
      expect(watch.elapsedMilliseconds, lessThan(200));
    },
  );

  test(
    'instância nova com os mesmos ciclos calcula o mesmo vencimento de compra',
    () {
      final card = threeChangesCard();
      final again = card.copyWith(name: 'Outro nome');
      for (var day = 0; day < 900; day += 13) {
        final date = DateTime(2025, 1, 1).add(Duration(days: day));
        expect(
          invoiceDueMonth(date, again),
          invoiceDueMonth(date, card),
          reason: 'compra em $date',
        );
      }
    },
  );
}
