import 'package:finme/app/app_scope.dart';
import 'package:finme/app/bootstrap.dart';
import 'package:finme/app/seed.dart';
import 'package:finme/core/models/app_settings.dart';
import 'package:finme/core/services/record_store.dart';
import 'package:finme/core/theme/app_theme.dart';
import 'package:finme/features/transactions/domain/transaction.dart';
import 'package:finme/features/transactions/domain/installments.dart';
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

/// Substitui as transações por um conjunto conhecido (linhas visíveis no 1400×900).
Future<void> _setTransactions(
  WidgetTester tester,
  AppServices s,
  List<Transaction> txs,
) async {
  await tester.runAsync(() => s.transactions.replaceAll(txs));
}

Transaction _tx(
  AppServices s,
  String id,
  String description, {
  TransactionType type = TransactionType.expense,
  String? category,
  int day = 10,
  int cents = 1000,
  TransactionStatus status = TransactionStatus.paid,
}) => Transaction(
  id: id,
  type: type,
  amountCents: cents,
  date: DateTime(2026, 11, day),
  description: description,
  categoryId: category,
  accountId: s.accounts.all.first.id,
  status: status,
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
  _tx(
    s,
    'd',
    'Padaria',
    category: 'cat_mercado',
    day: 7,
    status: TransactionStatus.planned,
  ),
  _tx(s, 'e', 'Lanche', day: 6),
];

Future<void> _pump(WidgetTester tester, AppServices s) async {
  await tester.binding.setSurfaceSize(const Size(1400, 900));
  await tester.pumpWidget(
    AppScope(
      services: s,
      child: MaterialApp(
        theme: AppTheme.light(),
        home: const Scaffold(body: TransactionsPage()),
      ),
    ),
  );
  await tester.pump();
}

/// Toca uma ação da barra de massa, rolando a barra até ela antes.
/// shortcut: nos testes as fontes reais não carregam e o texto fica largo; no app as ações cabem.
Future<void> _tapBar(WidgetTester tester, String label) async {
  final f = find.widgetWithText(TextButton, label);
  await tester.ensureVisible(f);
  await tester.pumpAndSettle();
  await tester.tap(f);
}

Future<void> _tapCheckbox(WidgetTester tester, String id) async {
  await tester.tap(find.byKey(Key('tx-select-$id')));
  await tester.pump();
}

Future<void> _shiftTapCheckbox(WidgetTester tester, String id) async {
  await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
  await _tapCheckbox(tester, id);
  await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
  await tester.pump();
}

void main() {
  testWidgets('Ultra mostra checkboxes; Simples não', (tester) async {
    final s = await _services(tester);
    await _setTransactions(tester, s, _baseTxs(s));
    await _pump(tester, s);
    expect(find.byKey(const Key('tx-select-a')), findsOneWidget);
    expect(find.byKey(const Key('tx-select-all')), findsOneWidget);

    await tester.runAsync(
      () => s.settings.update((x) => x.copyWith(mode: AppMode.simple)),
    );
    await tester.pump();
    expect(find.byKey(const Key('tx-select-a')), findsNothing);
    expect(find.byKey(const Key('tx-select-all')), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('marcar, Shift+clique e Esc: contagem e barra', (tester) async {
    final s = await _services(tester);
    await _setTransactions(tester, s, _baseTxs(s));
    await _pump(tester, s);

    await _tapCheckbox(tester, 'a');
    await _tapCheckbox(tester, 'b');
    expect(find.text('2 selecionadas'), findsOneWidget);

    // Âncora é a última linha marcada ('b'); Shift até 'e' marca b..e, somando a 'a'.
    await _shiftTapCheckbox(tester, 'e');
    expect(find.text('5 selecionadas'), findsOneWidget);

    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pump();
    expect(find.textContaining('selecionada'), findsNothing);
  });

  testWidgets('lista longa: última linha fica acima da folga do FAB', (
    tester,
  ) async {
    for (final mode in [AppMode.ultra, AppMode.simple]) {
      final s = await _services(tester, mode: mode);
      await _setTransactions(tester, s, [
        for (var i = 0; i < 40; i++) _tx(s, 't$i', 'Item $i', day: 1 + i % 28),
      ]);
      await _pump(tester, s);

      final listFinder = find.byWidgetPredicate(
        (w) => w is ListView && w.scrollDirection == Axis.vertical,
      );
      final padding = tester.widget<ListView>(listFinder).padding;
      expect(
        padding?.resolve(TextDirection.ltr).bottom,
        greaterThanOrEqualTo(64),
      );

      await tester.drag(listFinder, const Offset(0, -5000));
      await tester.pumpAndSettle();
      final listRect = tester.getRect(listFinder);
      final lastMenu = tester.getRect(find.byTooltip('Ações').last);
      expect(lastMenu.bottom, lessThanOrEqualTo(listRect.bottom - 64));
    }
  });

  testWidgets('mudar o filtro limpa a seleção', (tester) async {
    final s = await _services(tester);
    await _setTransactions(tester, s, _baseTxs(s));
    await _pump(tester, s);

    await _tapCheckbox(tester, 'a');
    expect(find.text('1 selecionada'), findsOneWidget);

    await tester.enterText(
      find.byWidgetPredicate(
        (w) =>
            w is TextField &&
            w.decoration?.hintText == 'Buscar descrição ou notas',
      ),
      'cinema',
    );
    await tester.pump();
    expect(find.textContaining('selecionada'), findsNothing);
  });

  testWidgets('sair do Ultra limpa a seleção', (tester) async {
    final s = await _services(tester);
    await _setTransactions(tester, s, _baseTxs(s));
    await _pump(tester, s);

    await _tapCheckbox(tester, 'a');
    expect(find.text('1 selecionada'), findsOneWidget);

    await tester.runAsync(
      () => s.settings.update((x) => x.copyWith(mode: AppMode.simple)),
    );
    await tester.pump();
    await tester.runAsync(
      () => s.settings.update((x) => x.copyWith(mode: AppMode.ultra)),
    );
    await tester.pump();
    expect(find.textContaining('selecionada'), findsNothing);
  });

  testWidgets('Ctrl+A marca as linhas visíveis', (tester) async {
    final s = await _services(tester);
    await _setTransactions(tester, s, _baseTxs(s));
    await _pump(tester, s);

    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyA);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    await tester.pump();
    expect(find.text('5 selecionadas'), findsOneWidget);
  });

  testWidgets('recategorizar: despesas ganham Lazer; receita é ignorada', (
    tester,
  ) async {
    final s = await _services(tester);
    await _setTransactions(tester, s, _baseTxs(s));
    await _pump(tester, s);

    await _tapCheckbox(tester, 'a');
    await _tapCheckbox(tester, 'b');
    await _tapCheckbox(tester, 'c');
    await _tapBar(tester, 'Recategorizar');
    await tester.pumpAndSettle();

    await tester.tap(find.byType(DropdownButtonFormField<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Lazer').last);
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Confirmar'));
    await tester.pumpAndSettle();

    expect(s.transactions.byId('a')!.categoryId, 'cat_lazer');
    expect(s.transactions.byId('b')!.categoryId, 'cat_lazer');
    expect(s.transactions.byId('c')!.categoryId, 'cat_salario');
    expect(
      find.text('2 recategorizadas · 1 ignoradas (tipo incompatível)'),
      findsOneWidget,
    );
  });

  testWidgets('confirmar pagamento: só com provisionado selecionado', (
    tester,
  ) async {
    final s = await _services(tester);
    await _setTransactions(tester, s, _baseTxs(s));
    await _pump(tester, s);

    await _tapCheckbox(tester, 'a');
    await tester.pump();
    final disabled = tester.widget<TextButton>(
      find.widgetWithText(TextButton, 'Confirmar pagamento'),
    );
    expect(disabled.onPressed, isNull);

    await _tapCheckbox(tester, 'd');
    await _tapBar(tester, 'Confirmar pagamento');
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Confirmar'));
    await tester.pumpAndSettle();

    final d = s.transactions.byId('d')!;
    expect(d.status, TransactionStatus.paid);
    expect(d.date, DateTime(2026, 11, 14));
    expect(find.text('1 provisionado confirmado'), findsOneWidget);
  });

  testWidgets('excluir 2 simples: some e SnackBar', (tester) async {
    final s = await _services(tester);
    await _setTransactions(tester, s, _baseTxs(s));
    await _pump(tester, s);

    await _tapCheckbox(tester, 'a');
    await _tapCheckbox(tester, 'e');
    await tester.tap(find.text('Excluir'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Excluir'));
    await tester.pumpAndSettle();

    expect(s.transactions.byId('a'), isNull);
    expect(s.transactions.byId('e'), isNull);
    expect(find.text('2 transações excluídas'), findsOneWidget);
    expect(find.textContaining('selecionada'), findsNothing);
  });

  testWidgets('parcela: só as selecionadas vs grupos inteiros', (tester) async {
    final s = await _services(tester);
    final base = _tx(s, 'p', 'Notebook', cents: 30000, day: 5);
    final parcels = buildInstallments(base: base, count: 3, groupId: 'g1');
    await _setTransactions(tester, s, [
      ...parcels,
      _tx(s, 'e', 'Lanche', day: 6),
    ]);
    await _pump(tester, s);

    final first = parcels.first.id;
    await _tapCheckbox(tester, first);
    await _tapCheckbox(tester, 'e');
    await tester.tap(find.text('Excluir'));
    await tester.pumpAndSettle();
    expect(find.text('1 grupo de parcelas na seleção.'), findsOneWidget);
    await tester.tap(find.text('Só as 2 selecionadas'));
    await tester.pumpAndSettle();

    expect(s.transactions.byId(first), isNull);
    expect(s.transactions.byId('e'), isNull);
    expect(s.transactions.byId(parcels[1].id), isNotNull);
    expect(find.text('2 transações excluídas'), findsOneWidget);
  });

  testWidgets('parcela: grupos inteiros remove o grupo e a simples', (
    tester,
  ) async {
    final s = await _services(tester);
    final base = _tx(s, 'p', 'Notebook', cents: 30000, day: 5);
    final parcels = buildInstallments(base: base, count: 3, groupId: 'g1');
    await _setTransactions(tester, s, [
      ...parcels,
      _tx(s, 'e', 'Lanche', day: 6),
    ]);
    await _pump(tester, s);

    await _tapCheckbox(tester, parcels.first.id);
    await _tapCheckbox(tester, 'e');
    await tester.tap(find.text('Excluir'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Grupos inteiros (4 lançamentos)'));
    await tester.pumpAndSettle();

    expect(s.transactions.all, isEmpty);
    expect(find.text('4 transações excluídas'), findsOneWidget);
  });

  testWidgets(
    'criar regra: padrão sugerido, categoria aplicada às selecionadas',
    (tester) async {
      final s = await _services(tester);
      await _setTransactions(tester, s, [
        _tx(s, 'u1', 'UBER *TRIP 1', day: 10),
        _tx(s, 'u2', 'UBER *TRIP 2', day: 9),
        _tx(s, 'x', 'Cinema', category: 'cat_lazer', day: 8),
      ]);
      await _pump(tester, s);

      await _tapCheckbox(tester, 'u1');
      await _tapCheckbox(tester, 'u2');
      await _tapBar(tester, 'Criar regra');
      await tester.pumpAndSettle();

      expect(
        find.byWidgetPredicate(
          (w) => w is EditableText && w.controller.text == 'UBER *TRIP',
        ),
        findsOneWidget,
      );
      await tester.tap(
        find.descendant(
          of: find.byType(Dialog),
          matching: find.byType(DropdownButtonFormField<String?>),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Transporte').last);
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Salvar'));
      await tester.pumpAndSettle();

      expect(s.transactions.byId('u1')!.categoryId, 'cat_transporte');
      expect(s.transactions.byId('u2')!.categoryId, 'cat_transporte');
      expect(
        find.text('Regra criada · 2 transações atualizadas'),
        findsOneWidget,
      );
    },
  );
}
