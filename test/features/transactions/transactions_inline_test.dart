import 'package:finme/app/app_scope.dart';
import 'package:finme/app/bootstrap.dart';
import 'package:finme/app/seed.dart';
import 'package:finme/core/models/app_settings.dart';
import 'package:finme/core/services/record_store.dart';
import 'package:finme/core/theme/app_theme.dart';
import 'package:finme/features/transactions/domain/transaction.dart';
import 'package:finme/features/transactions/presentation/inline_cells.dart';
import 'package:finme/features/transactions/presentation/transactions_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

Future<AppServices> _services(
  WidgetTester tester, {
  AppMode mode = AppMode.ultra,
}) async {
  return (await tester.runAsync(() async {
    final s = await bootstrap(
      storeFactory: (_) => MemoryRecordStore(),
      clock: () => DateTime(2026, 11, 14),
    );
    await seedDemo(s);
    await s.settings.update((x) => x.copyWith(mode: mode));
    return s;
  }))!;
}

Transaction _tx(
  AppServices s,
  String id,
  String description, {
  TransactionType type = TransactionType.expense,
  String? category,
  int day = 10,
  int cents = 1000,
  String? group,
}) => Transaction(
  id: id,
  type: type,
  amountCents: cents,
  date: DateTime(2026, 11, day),
  description: description,
  categoryId: category,
  accountId: s.accounts.all.first.id,
  installmentGroupId: group,
  installmentIndex: group == null ? null : 1,
  installmentCount: group == null ? null : 3,
);

List<Transaction> _baseTxs(AppServices s) => [
  _tx(s, 'a', 'Mercado A', category: 'cat_mercado', day: 10),
  _tx(s, 'b', 'Cinema', day: 9),
  _tx(
    s,
    'c',
    'Freela',
    type: TransactionType.income,
    category: 'cat_salario',
    day: 8,
  ),
  _tx(s, 'p', 'Notebook', category: 'cat_compras', day: 7, group: 'g1'),
];

Future<void> _setTransactions(
  WidgetTester tester,
  AppServices s,
  List<Transaction> txs,
) async {
  await tester.runAsync(() => s.transactions.replaceAll(txs));
}

Future<void> _pump(
  WidgetTester tester,
  AppServices s, {
  String? initialQuery,
  FocusNode? searchFocusNode,
}) async {
  await tester.binding.setSurfaceSize(const Size(1400, 900));
  await tester.pumpWidget(
    AppScope(
      services: s,
      child: MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(
          body: TransactionsPage(
            initialQuery: initialQuery,
            searchFocusNode: searchFocusNode,
          ),
        ),
      ),
    ),
  );
  await tester.pump();
}

Transaction _saved(AppServices s, String id) =>
    s.transactions.all.firstWhere((t) => t.id == id);

void main() {
  testWidgets('Ultra: trocar categoria pelo dropdown grava e não abre o form', (
    tester,
  ) async {
    final s = await _services(tester);
    await _setTransactions(tester, s, _baseTxs(s));
    await _pump(tester, s);

    final dropdown = find.descendant(
      of: find.byKey(const Key('inline-category-a')),
      matching: find.byType(DropdownButton<String?>),
    );
    await tester.tap(dropdown);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Lazer').last);
    await tester.pumpAndSettle();

    expect(_saved(s, 'a').categoryId, 'cat_lazer');
    expect(find.text('Editar transação'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Ultra: valor digitado + Enter grava; Esc não muda', (
    tester,
  ) async {
    final s = await _services(tester);
    await _setTransactions(tester, s, _baseTxs(s));
    await _pump(tester, s);

    await tester.tap(find.byKey(const Key('inline-amount-a')));
    await tester.pump();
    await tester.enterText(
      find.byKey(const Key('inline-amount-field')),
      '99,90',
    );
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
    expect(_saved(s, 'a').amountCents, 9990);

    await tester.tap(find.byKey(const Key('inline-amount-a')));
    await tester.pump();
    await tester.enterText(
      find.byKey(const Key('inline-amount-field')),
      '5,00',
    );
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(_saved(s, 'a').amountCents, 9990);
    expect(find.byKey(const Key('inline-amount-field')), findsNothing);
    expect(find.text('Editar transação'), findsNothing);
  });

  testWidgets('parcela não tem célula de valor; hideValues esconde todas', (
    tester,
  ) async {
    final s = await _services(tester);
    await _setTransactions(tester, s, _baseTxs(s));
    await _pump(tester, s);

    expect(find.byKey(const Key('inline-amount-p')), findsNothing);
    expect(find.byKey(const Key('inline-amount-a')), findsOneWidget);
    expect(find.byKey(const Key('inline-category-p')), findsOneWidget);

    await tester.runAsync(
      () => s.settings.update((x) => x.copyWith(hideValues: true)),
    );
    await tester.pump();
    expect(find.byType(InlineAmountCell), findsNothing);
    expect(find.byType(InlineCategoryCell), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Simples: nenhuma célula inline', (tester) async {
    final s = await _services(tester, mode: AppMode.simple);
    await _setTransactions(tester, s, _baseTxs(s));
    await _pump(tester, s);

    expect(find.byType(InlineCategoryCell), findsNothing);
    expect(find.byType(InlineAmountCell), findsNothing);
    expect(find.text('Mercado A'), findsOneWidget);
  });

  testWidgets('initialQuery pré-preenche a busca e filtra as linhas', (
    tester,
  ) async {
    final s = await _services(tester);
    await _setTransactions(tester, s, _baseTxs(s));
    await _pump(tester, s, initialQuery: 'Mercado');

    final field = tester.widget<TextField>(find.byType(TextField));
    expect(field.controller!.text, 'Mercado');
    expect(find.text('Mercado A'), findsOneWidget);
    expect(find.text('Cinema'), findsNothing);
    expect(find.text('Freela'), findsNothing);
  });

  testWidgets('searchFocusNode.requestFocus() foca o campo de busca', (
    tester,
  ) async {
    final s = await _services(tester);
    await _setTransactions(tester, s, _baseTxs(s));
    final node = FocusNode();
    addTearDown(node.dispose);
    await _pump(tester, s, searchFocusNode: node);

    node.requestFocus();
    await tester.pump();
    expect(node.hasFocus, isTrue);
    expect(
      find.byWidgetPredicate((w) => w is TextField && w.focusNode == node),
      findsOneWidget,
    );
  });

  testWidgets('dicas: Atalho N (lista vazia) e Ctrl+I nos dois modos', (
    tester,
  ) async {
    for (final mode in AppMode.values) {
      final s = await _services(tester, mode: mode);
      await _setTransactions(tester, s, _baseTxs(s));
      await _pump(tester, s);
      expect(find.byTooltip('Atalho: Ctrl+I'), findsOneWidget);

      await _setTransactions(tester, s, const []);
      await tester.pump();
      expect(find.byTooltip('Atalho: N'), findsOneWidget);
    }
  });
}
