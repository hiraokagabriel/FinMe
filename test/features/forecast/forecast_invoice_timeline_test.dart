import 'package:finme/app/app_scope.dart';
import 'package:finme/app/bootstrap.dart';
import 'package:finme/core/models/year_month.dart';
import 'package:finme/core/services/record_store.dart';
import 'package:finme/core/theme/app_colors.dart';
import 'package:finme/core/theme/app_theme.dart';
import 'package:finme/core/utils/formatters.dart';
import 'package:finme/features/accounts/domain/account.dart';
import 'package:finme/features/cards/domain/invoice.dart';
import 'package:finme/features/cards/domain/payment_card.dart';
import 'package:finme/features/forecast/domain/invoice_timeline.dart';
import 'package:finme/features/forecast/presentation/forecast_invoice_timeline.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

PaymentCard _card(String id, String name) => PaymentCard(
  id: id,
  name: name,
  bankName: 'Banco Alfa',
  brand: CardBrand.visa,
  kind: CardKind.credit,
  last4: '1234',
  closingDay: 25,
  dueDay: 4,
  colorValue: 0xFF1565C0,
);

InvoiceDue _due({
  required PaymentCard card,
  required DateTime date,
  required DateTime dueDate,
  required int amountCents,
  String? accountId,
  int? balanceAfterCents,
}) {
  final invoice = Invoice(
    card: card,
    dueMonth: YearMonth.fromDate(dueDate),
    closingDate: dueDate.subtract(const Duration(days: 10)),
    dueDate: dueDate,
    items: const [],
    chargesCents: amountCents,
    creditsCents: 0,
    paidCents: 0,
  );
  return InvoiceDue(
    invoice: invoice,
    date: date,
    amountCents: amountCents,
    accountId: accountId,
    accountBalanceAfterCents: balanceAfterCents,
  );
}

void main() {
  testWidgets('linhas: badge Vencida, Sem conta e saldo após negativo', (
    tester,
  ) async {
    // Em 390px a linha de saldo longo estoura a Row do cabeçalho (fonte de teste Ahem é larga).
    await tester.binding.setSurfaceSize(const Size(1400, 900));
    final s = await tester.runAsync(
      () => bootstrap(
        storeFactory: (_) => MemoryRecordStore(),
        clock: () => DateTime(2026, 11, 14),
      ),
    );
    const account = Account(
      id: 'acc1',
      name: 'Conta Principal',
      bankName: 'Banco Alfa',
      type: AccountType.checking,
      initialBalanceCents: 0,
      colorValue: 0xFF1565C0,
    );
    // Vencida: vencimento (10/11) antes do evento (hoje 14/11).
    final items = [
      _due(
        card: _card('a', 'Cartão Alfa'),
        date: DateTime(2026, 11, 14),
        dueDate: DateTime(2026, 11, 10),
        amountCents: 10000,
        accountId: 'acc1',
        balanceAfterCents: 50000,
      ),
      // Sem conta de pagamento: saldo não se aplica.
      _due(
        card: _card('b', 'Cartão Beta'),
        date: DateTime(2026, 11, 20),
        dueDate: DateTime(2026, 11, 20),
        amountCents: 25000,
      ),
      _due(
        card: _card('g', 'Cartão Gama'),
        date: DateTime(2026, 11, 25),
        dueDate: DateTime(2026, 11, 25),
        amountCents: 30000,
        accountId: 'acc1',
        balanceAfterCents: -120000,
      ),
    ];

    await tester.pumpWidget(
      AppScope(
        services: s!,
        child: MaterialApp(
          theme: AppTheme.light(),
          home: Scaffold(
            body: InvoiceTimelineSection(
              items: items,
              accounts: {'acc1': account},
            ),
          ),
        ),
      ),
    );

    expect(find.text('Vencimentos (60 dias)'), findsOneWidget);
    expect(find.text('Cartão Alfa'), findsOneWidget);
    expect(find.text('Vencida'), findsOneWidget);
    expect(find.text('Sem conta'), findsOneWidget);
    expect(find.text('—'), findsOneWidget);
    expect(find.text('Conta Principal'), findsNWidgets(2));
    expect(find.text('Saldo após '), findsNWidgets(2));
    expect(find.text(formatMoney(50000)), findsOneWidget);

    final negative = tester.widget<Text>(find.text(formatMoney(-120000)));
    expect(negative.style?.color, AppColors.light.danger);
    expect(tester.takeException(), isNull);
  });
}
