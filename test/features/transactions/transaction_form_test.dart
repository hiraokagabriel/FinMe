import 'package:finme/app/app_scope.dart';
import 'package:finme/app/bootstrap.dart';
import 'package:finme/app/seed.dart';
import 'package:finme/core/services/record_store.dart';
import 'package:finme/core/theme/app_theme.dart';
import 'package:finme/features/transactions/domain/transaction.dart';
import 'package:finme/features/transactions/presentation/transaction_form.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Future<AppServices> _boot(WidgetTester tester) async {
  return (await tester.runAsync(() async {
    final s = await bootstrap(
      storeFactory: (_) => MemoryRecordStore(),
      clock: () => DateTime(2026, 11, 14),
    );
    await seedDemo(s);
    return s;
  }))!;
}

Future<void> _openForm(
  WidgetTester tester,
  AppServices s, {
  Transaction? initial,
}) async {
  await tester.binding.setSurfaceSize(const Size(1400, 1000));
  await tester.pumpWidget(
    AppScope(
      services: s,
      child: MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(
          body: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () => showTransactionForm(context, initial: initial),
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

/// Campo de categoria (a key muda com o valor selecionado).
Finder _categoriaField() => find.byWidgetPredicate(
  (w) =>
      w.key is ValueKey<String> &&
      (w.key! as ValueKey<String>).value.startsWith('form-categoria-'),
);

Future<void> _pickCategoria(WidgetTester tester, String name) async {
  await tester.tap(_categoriaField());
  await tester.pumpAndSettle();
  await tester.tap(find.text(name).last);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('descrição sugere categoria pelo dicionário em nova despesa', (
    tester,
  ) async {
    final s = await _boot(tester);
    await _openForm(tester, s);

    await tester.enterText(
      find.widgetWithText(TextFormField, 'Descrição'),
      'IFOOD PEDIDO',
    );
    await tester.pumpAndSettle();

    expect(find.text('Alimentação'), findsOneWidget);
    expect(find.text('Sugerida pelo dicionário'), findsOneWidget);
  });

  testWidgets(
    'sugestão some ao mudar a descrição: categoria sugerida é limpa',
    (tester) async {
      final s = await _boot(tester);
      await _openForm(tester, s);

      await tester.enterText(
        find.widgetWithText(TextFormField, 'Descrição'),
        'IFOOD PEDIDO',
      );
      await tester.pumpAndSettle();
      expect(find.text('Sugerida pelo dicionário'), findsOneWidget);

      await tester.enterText(
        find.widgetWithText(TextFormField, 'Descrição'),
        'QWERTY LOJA',
      );
      await tester.pumpAndSettle();

      expect(find.text('Sugerida pelo dicionário'), findsNothing);
      expect(find.text('Alimentação'), findsNothing);
      expect(find.text('Sem categoria'), findsOneWidget);
    },
  );

  testWidgets('categoria escolhida manualmente não é trocada pela descrição', (
    tester,
  ) async {
    final s = await _boot(tester);
    await _openForm(tester, s);

    await _pickCategoria(tester, 'Lazer');
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Descrição'),
      'UBER',
    );
    await tester.pumpAndSettle();

    expect(find.text('Lazer'), findsOneWidget);
    expect(find.text('Sugerida pelo dicionário'), findsNothing);
  });

  testWidgets(
    'editar transação com categoria e mudar a descrição mantém a categoria',
    (tester) async {
      final s = await _boot(tester);
      final tx = Transaction(
        id: 'tx_edit_lazer',
        type: TransactionType.expense,
        amountCents: 5000,
        date: DateTime(2026, 11, 10),
        description: 'Cinema exemplo',
        categoryId: 'cat_lazer',
        accountId: 'acc_alfa',
      );
      await tester.runAsync(() => s.transactions.upsert(tx));
      await _openForm(tester, s, initial: tx);

      await tester.enterText(
        find.widgetWithText(TextFormField, 'Descrição'),
        'UBER',
      );
      await tester.pumpAndSettle();

      expect(find.text('Lazer'), findsOneWidget);
      expect(find.text('Sugerida pelo dicionário'), findsNothing);
    },
  );

  testWidgets('nova receita "SALARIO EMPRESA" sugere Salário', (tester) async {
    final s = await _boot(tester);
    await _openForm(tester, s);

    await tester.tap(find.text('Receita'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Descrição'),
      'SALARIO EMPRESA',
    );
    await tester.pumpAndSettle();

    expect(find.text('Salário'), findsOneWidget);
  });

  testWidgets(
    'despesa parcelada 3x no cartão de crédito grava 3 parcelas somando o valor',
    (tester) async {
      final s = (await tester.runAsync(() async {
        final s = await bootstrap(
          storeFactory: (_) => MemoryRecordStore(),
          clock: () => DateTime(2026, 11, 14),
        );
        await seedDemo(s);
        return s;
      }))!;
      await tester.binding.setSurfaceSize(const Size(1400, 900));
      await tester.pumpWidget(
        AppScope(
          services: s,
          child: MaterialApp(
            theme: AppTheme.light(),
            home: Scaffold(
              body: Builder(
                builder: (context) => ElevatedButton(
                  onPressed: () => showTransactionForm(context),
                  child: const Text('abrir'),
                ),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('abrir'));
      await tester.pumpAndSettle();

      await tester.enterText(
        find.widgetWithText(TextFormField, 'Valor'),
        '100,00',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Descrição'),
        'Compra teste parcelada',
      );

      await tester.tap(find.byKey(const ValueKey('form-origem')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cartão · Alfa Visa ••••1234').last);
      await tester.pumpAndSettle();

      await tester.enterText(
        find.widgetWithText(TextFormField, 'Parcelas'),
        '3',
      );
      await tester.tap(find.text('Salvar'));
      await tester.pumpAndSettle();

      final parcels = s.transactions.all
          .where(
            (t) =>
                t.installmentGroupId != null &&
                t.description == 'Compra teste parcelada',
          )
          .toList();
      expect(parcels, hasLength(3));
      expect(parcels.fold<int>(0, (sum, t) => sum + t.amountCents), 10000);
      expect(
        parcels.map((t) => t.installmentIndex),
        unorderedEquals([1, 2, 3]),
      );
      expect(parcels.every((t) => t.cardId == 'card_alfa_visa'), isTrue);
      expect(parcels.every((t) => t.type == TransactionType.expense), isTrue);
      expect(
        parcels.every((t) => t.description == 'Compra teste parcelada'),
        isTrue,
      );
      expect(find.text('Salvar'), findsNothing);
    },
  );
}
