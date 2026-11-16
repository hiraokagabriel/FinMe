import 'package:finme/core/theme/app_theme.dart';
import 'package:finme/features/categories/domain/transaction_category.dart';
import 'package:finme/features/transactions/presentation/inline_cells.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

const _mercado = TransactionCategory(
  id: 'cat_mercado',
  name: 'Mercado',
  kind: CategoryKind.expense,
  iconCodePoint: 0,
  colorValue: 0,
);

const _lazer = TransactionCategory(
  id: 'cat_lazer',
  name: 'Lazer',
  kind: CategoryKind.expense,
  iconCodePoint: 0,
  colorValue: 0,
);

Future<void> _pump(WidgetTester tester, Widget body) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.light(),
      home: Scaffold(body: Center(child: body)),
    ),
  );
  await tester.pump();
}

Finder get _field => find.byKey(const Key('inline-amount-field'));

Future<void> _openAmount(WidgetTester tester, int cents) async {
  await _pump(
    tester,
    InlineAmountCell(
      display: const Text('R\$ 12,50'),
      amountCents: cents,
      onSubmit: (_) {},
    ),
  );
  await tester.tap(find.text('R\$ 12,50'));
  await tester.pump();
}

void main() {
  group('InlineCategoryCell', () {
    testWidgets('escolher a 2ª opção chama onChanged com o id', (tester) async {
      String? picked = 'unset';
      await _pump(
        tester,
        InlineCategoryCell(
          categoryId: null,
          options: const [_mercado, _lazer],
          onChanged: (v) => picked = v,
        ),
      );
      await tester.tap(find.byType(DropdownButton<String?>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Lazer').last);
      await tester.pumpAndSettle();
      expect(picked, 'cat_lazer');
    });

    testWidgets('escolher Sem categoria chama onChanged com null', (
      tester,
    ) async {
      String? picked = 'unset';
      await _pump(
        tester,
        InlineCategoryCell(
          categoryId: 'cat_mercado',
          options: const [_mercado, _lazer],
          onChanged: (v) => picked = v,
        ),
      );
      await tester.tap(find.byType(DropdownButton<String?>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Sem categoria').last);
      await tester.pumpAndSettle();
      expect(picked, isNull);
    });
  });

  group('InlineAmountCell', () {
    testWidgets('clique abre campo com valor atual; novo valor + Enter grava', (
      tester,
    ) async {
      int? submitted;
      await _pump(
        tester,
        InlineAmountCell(
          display: const Text('R\$ 12,50'),
          amountCents: 1250,
          onSubmit: (v) => submitted = v,
        ),
      );
      await tester.tap(find.text('R\$ 12,50'));
      await tester.pump();
      expect(tester.widget<TextField>(_field).controller!.text, '12,50');

      await tester.enterText(_field, '20,00');
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pump();

      expect(submitted, 2000);
      expect(_field, findsNothing);
      expect(find.text('R\$ 12,50'), findsOneWidget);
    });

    testWidgets('0 e abc + Enter não gravam e mantêm o campo', (tester) async {
      var calls = 0;
      await _pump(
        tester,
        InlineAmountCell(
          display: const Text('R\$ 12,50'),
          amountCents: 1250,
          onSubmit: (_) => calls++,
        ),
      );
      await tester.tap(find.text('R\$ 12,50'));
      await tester.pump();

      for (final bad in ['0', 'abc']) {
        await tester.enterText(_field, bad);
        await tester.sendKeyEvent(LogicalKeyboardKey.enter);
        await tester.pump();
        expect(calls, 0);
        expect(_field, findsOneWidget);
      }
    });

    testWidgets('valor igual sai sem chamar onSubmit', (tester) async {
      var calls = 0;
      await _pump(
        tester,
        InlineAmountCell(
          display: const Text('R\$ 12,50'),
          amountCents: 1250,
          onSubmit: (_) => calls++,
        ),
      );
      await tester.tap(find.text('R\$ 12,50'));
      await tester.pump();
      await tester.enterText(_field, '12,50');
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pump();
      expect(calls, 0);
      expect(_field, findsNothing);
    });

    testWidgets('Esc sai sem chamar onSubmit', (tester) async {
      var calls = 0;
      await _pump(
        tester,
        InlineAmountCell(
          display: const Text('R\$ 12,50'),
          amountCents: 1250,
          onSubmit: (_) => calls++,
        ),
      );
      await tester.tap(find.text('R\$ 12,50'));
      await tester.pump();
      await tester.enterText(_field, '99,90');
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pump();
      expect(calls, 0);
      expect(_field, findsNothing);
      expect(find.text('R\$ 12,50'), findsOneWidget);
    });

    testWidgets('tirar o foco (tap fora) sai sem chamar onSubmit', (
      tester,
    ) async {
      var calls = 0;
      await _pump(
        tester,
        Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('fora'),
            InlineAmountCell(
              display: const Text('R\$ 12,50'),
              amountCents: 1250,
              onSubmit: (_) => calls++,
            ),
          ],
        ),
      );
      await tester.tap(find.text('R\$ 12,50'));
      await tester.pump();
      await tester.enterText(_field, '99,90');
      await tester.tap(find.text('fora'));
      await tester.pump();
      expect(calls, 0);
      expect(_field, findsNothing);
    });

    testWidgets('clicar no valor não dispara o onTap do InkWell da linha', (
      tester,
    ) async {
      var rowTaps = 0;
      await _pump(
        tester,
        InkWell(
          onTap: () => rowTaps++,
          child: InlineAmountCell(
            display: const Text('R\$ 12,50'),
            amountCents: 1250,
            onSubmit: (_) {},
          ),
        ),
      );
      await tester.tap(find.text('R\$ 12,50'));
      await tester.pump();
      expect(rowTaps, 0);
      expect(_field, findsOneWidget);
    });
  });

  testWidgets('campo de valor usa algarismos tabulares', (tester) async {
    await _openAmount(tester, 1250);
    final style = tester.widget<TextField>(_field).style!;
    expect(style.fontFeatures, isNotNull);
  });
}
