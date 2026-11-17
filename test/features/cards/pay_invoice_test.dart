import 'package:finme/app/app_scope.dart';
import 'package:finme/app/bootstrap.dart';
import 'package:finme/app/seed.dart';
import 'package:finme/core/services/record_store.dart';
import 'package:finme/core/theme/app_theme.dart';
import 'package:finme/features/cards/domain/invoice.dart';
import 'package:finme/features/cards/presentation/pay_invoice_dialog.dart';
import 'package:finme/features/transactions/domain/transaction.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const _purchaseId = 'tx_compra_fatura';
const _payDescription = 'Pagamento fatura Alfa Visa';

Future<AppServices> _boot(WidgetTester tester) async {
  return (await tester.runAsync(() async {
    final s = await bootstrap(
      storeFactory: (_) => MemoryRecordStore(),
      clock: () => DateTime(2026, 11, 14),
    );
    await seedDemo(s);
    await s.transactions.upsert(
      Transaction(
        id: _purchaseId,
        type: TransactionType.expense,
        amountCents: 30000,
        date: DateTime(2026, 11, 5),
        description: 'Compra para fatura',
        cardId: 'card_alfa_visa',
      ),
    );
    return s;
  }))!;
}

/// Fatura que contém a compra de teste (sem depender da data de fechamento).
Invoice _invoice(AppServices s) => s.ledger
    .invoicesFor('card_alfa_visa')
    .firstWhere((i) => i.items.any((t) => t.id == _purchaseId));

Future<void> _openDialog(
  WidgetTester tester,
  AppServices s,
  Invoice invoice,
) async {
  await tester.binding.setSurfaceSize(const Size(1400, 900));
  await tester.pumpWidget(
    AppScope(
      services: s,
      child: MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(
          body: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () => showPayInvoiceDialog(context, invoice),
              child: const Text('abrir'),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('abrir'));
  await tester.pumpAndSettle();
}

List<Transaction> _payments(AppServices s, Invoice invoice) => s
    .transactions
    .all
    .where(
      (t) =>
          t.type == TransactionType.invoicePayment &&
          t.description == _payDescription &&
          t.invoiceKey == invoice.dueMonth.key,
    )
    .toList();

void main() {
  testWidgets(
    'pagar fatura grava invoicePayment com invoiceKey == dueMonth.key',
    (tester) async {
      final s = await _boot(tester);
      final invoice = _invoice(s);
      await _openDialog(tester, s, invoice);

      await tester.tap(find.text('Salvar'));
      await tester.pumpAndSettle();

      final payments = _payments(s, invoice);
      expect(payments, hasLength(1));
      expect(payments.single.type, TransactionType.invoicePayment);
      expect(payments.single.invoiceKey, invoice.dueMonth.key);
      expect(payments.single.cardId, 'card_alfa_visa');
      expect(payments.single.amountCents, invoice.remainingCents);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('duplo tap no Salvar grava só 1 pagamento', (tester) async {
    final s = await _boot(tester);
    final invoice = _invoice(s);
    await _openDialog(tester, s, invoice);

    // Dois cliques no mesmo frame: o 2º chega antes do rebuild que desabilita o botão.
    final save = tester
        .widget<FilledButton>(find.byType(FilledButton))
        .onPressed!;
    save();
    save();
    await tester.pumpAndSettle();

    expect(_payments(s, invoice), hasLength(1));
    expect(tester.takeException(), isNull);
  });
}
