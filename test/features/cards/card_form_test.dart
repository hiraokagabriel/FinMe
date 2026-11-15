import 'package:finme/app/app_scope.dart';
import 'package:finme/app/bootstrap.dart';
import 'package:finme/core/services/record_store.dart';
import 'package:finme/core/theme/app_theme.dart';
import 'package:finme/core/utils/formatters.dart';
import 'package:finme/features/cards/domain/payment_card.dart';
import 'package:finme/features/cards/presentation/card_form.dart';
import 'package:finme/features/transactions/domain/transaction.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

PaymentCard card({List<CardCycle> history = const []}) => PaymentCard(
  id: 'c1',
  name: 'Cartão Alfa',
  bankName: 'Banco Alfa',
  brand: CardBrand.visa,
  kind: CardKind.credit,
  last4: '1234',
  limitCents: 100000,
  closingDay: 5,
  dueDay: 12,
  colorValue: 0xFF1565C0,
  cycleHistory: history,
);

Transaction purchase() => Transaction(
  id: 't1',
  type: TransactionType.expense,
  amountCents: 5000,
  date: DateTime(2026, 11, 10),
  description: 'Mercado',
  cardId: 'c1',
);

/// Serviços limpos com relógio fixo em 14/11/2026 e [initial] já salvo.
Future<AppServices> servicesWith(
  WidgetTester tester, {
  required PaymentCard initial,
  bool withTransaction = false,
}) async {
  return (await tester.runAsync(() async {
    final s = await bootstrap(
      storeFactory: (_) => MemoryRecordStore(),
      clock: () => DateTime(2026, 11, 14),
    );
    await s.cards.upsert(initial);
    if (withTransaction) {
      await s.transactions.upsert(purchase());
    }
    return s;
  }))!;
}

Future<void> openForm(
  WidgetTester tester,
  AppServices s,
  PaymentCard initial,
) async {
  await tester.binding.setSurfaceSize(const Size(1000, 1000));
  await tester.pumpWidget(
    AppScope(
      services: s,
      child: MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(
          body: Builder(
            builder: (ctx) => ElevatedButton(
              onPressed: () => showCardForm(ctx, initial: initial),
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

void main() {
  testWidgets(
    'com transações: troca de vencimento pede vigência e guarda o ciclo antigo',
    (tester) async {
      final initial = card();
      final s = await servicesWith(
        tester,
        initial: initial,
        withTransaction: true,
      );
      await openForm(tester, s, initial);
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Dia de vencimento'),
        '20',
      );
      await tester.tap(find.widgetWithText(FilledButton, 'Salvar'));
      await tester.pumpAndSettle();

      expect(find.text('Vale a partir de'), findsOneWidget);
      expect(find.text(formatDate(DateTime(2026, 11, 14))), findsOneWidget);
      await tester.tap(find.widgetWithText(FilledButton, 'Salvar').last);
      await tester.pumpAndSettle();

      final saved = s.cards.all.single;
      expect(saved.closingDay, 5);
      expect(saved.dueDay, 20);
      expect(saved.cycleHistory, [
        CardCycle(until: DateTime(2026, 11, 14), closingDay: 5, dueDay: 12),
      ]);
      expect(find.text('Editar cartão'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('cancelar a vigência não salva a mudança', (tester) async {
    final initial = card();
    final s = await servicesWith(
      tester,
      initial: initial,
      withTransaction: true,
    );
    await openForm(tester, s, initial);
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Dia de vencimento'),
      '20',
    );
    await tester.tap(find.widgetWithText(FilledButton, 'Salvar'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(TextButton, 'Cancelar').last);
    await tester.pumpAndSettle();

    expect(s.cards.all.single, initial);
    expect(find.text('Vale a partir de'), findsNothing);
  });

  testWidgets('data de vigência inválida mostra erro e mantém o diálogo', (
    tester,
  ) async {
    // Último ciclo termina em 20/11; "hoje" é 14/11, então a data é inválida.
    final initial = card(
      history: [
        CardCycle(until: DateTime(2026, 11, 20), closingDay: 1, dueDay: 8),
      ],
    );
    final s = await servicesWith(
      tester,
      initial: initial,
      withTransaction: true,
    );
    await openForm(tester, s, initial);
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Dia de vencimento'),
      '20',
    );
    await tester.tap(find.widgetWithText(FilledButton, 'Salvar'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Salvar').last);
    await tester.pumpAndSettle();

    expect(find.textContaining('Data inválida'), findsOneWidget);
    expect(find.text('Vale a partir de'), findsOneWidget);
    expect(s.cards.all.single, initial);
  });

  testWidgets('sem transações: troca só os dias e não pergunta vigência', (
    tester,
  ) async {
    final initial = card();
    final s = await servicesWith(tester, initial: initial);
    await openForm(tester, s, initial);
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Dia de vencimento'),
      '20',
    );
    await tester.tap(find.widgetWithText(FilledButton, 'Salvar'));
    await tester.pumpAndSettle();

    final saved = s.cards.all.single;
    expect(saved.dueDay, 20);
    expect(saved.cycleHistory, isEmpty);
    expect(find.text('Vale a partir de'), findsNothing);
  });

  testWidgets('editar só o nome preserva o histórico de ciclos', (
    tester,
  ) async {
    final history = [
      CardCycle(until: DateTime(2026, 10, 1), closingDay: 1, dueDay: 8),
    ];
    final initial = card(history: history);
    final s = await servicesWith(
      tester,
      initial: initial,
      withTransaction: true,
    );
    await openForm(tester, s, initial);
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Nome do cartão'),
      'Cartão Beta',
    );
    await tester.tap(find.widgetWithText(FilledButton, 'Salvar'));
    await tester.pumpAndSettle();

    final saved = s.cards.all.single;
    expect(saved.name, 'Cartão Beta');
    expect(saved.cycleHistory, history);
    expect(find.text('Vale a partir de'), findsNothing);
  });
}
