import 'package:finme/app/app_scope.dart';
import 'package:finme/app/bootstrap.dart';
import 'package:finme/app/seed.dart';
import 'package:finme/core/models/app_settings.dart';
import 'package:finme/core/services/record_store.dart';
import 'package:finme/core/theme/app_theme.dart';
import 'package:finme/features/categories/domain/transaction_category.dart';
import 'package:finme/features/transactions/domain/transaction.dart';
import 'package:finme/features/transactions/presentation/transactions_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Ultra com categoria filha 'Mercado X' (de 'Alimentação') e três lançamentos:
/// a = Alimentação, b = Mercado X com #viagem, c = Transporte com #Trabalho.
Future<AppServices> _services(WidgetTester tester) async {
  return (await tester.runAsync(() async {
    final s = await bootstrap(
      storeFactory: (_) => MemoryRecordStore(),
      clock: () => DateTime(2026, 11, 14),
    );
    await seedDemo(s);
    final mercado = s.categories.all.firstWhere((c) => c.id == 'cat_mercado');
    await s.categories.upsert(
      TransactionCategory(
        id: 'cat_mercado_x',
        name: 'Mercado X',
        kind: mercado.kind,
        iconCodePoint: mercado.iconCodePoint,
        colorValue: mercado.colorValue,
        parentId: 'cat_alimentacao',
      ),
    );
    await s.transactions.replaceAll([
      _tx(s, 'a', 'Restaurante', 'cat_alimentacao', 10),
      _tx(s, 'b', 'Feira', 'cat_mercado_x', 9, tags: const ['viagem']),
      _tx(s, 'c', 'Uber', 'cat_transporte', 8, tags: const ['Trabalho']),
    ]);
    await s.settings.update((x) => x.copyWith(mode: AppMode.ultra));
    return s;
  }))!;
}

Transaction _tx(
  AppServices s,
  String id,
  String description,
  String category,
  int day, {
  List<String> tags = const [],
}) => Transaction(
  id: id,
  type: TransactionType.expense,
  amountCents: 1000,
  date: DateTime(2026, 11, day),
  description: description,
  categoryId: category,
  accountId: s.accounts.all.first.id,
  tags: tags,
);

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
  await tester.pumpAndSettle();
}

Future<void> _select(WidgetTester tester, List<String> ids) async {
  for (final id in ids) {
    await tester.tap(find.byKey(Key('tx-select-$id')));
    await tester.pump();
  }
}

/// Abre a ação 'Tags' da barra de massa.
Future<void> _openTags(WidgetTester tester) async {
  await tester.ensureVisible(find.widgetWithText(TextButton, 'Tags'));
  await tester.pumpAndSettle();
  await tester.tap(find.widgetWithText(TextButton, 'Tags'));
  await tester.pumpAndSettle();
}

/// Digita [tag] no campo do diálogo e confirma com Enter.
Future<void> _typeTag(WidgetTester tester, String tag) async {
  await tester.enterText(find.byKey(const ValueKey('tag-input')), tag);
  await tester.testTextInput.receiveAction(TextInputAction.done);
  await tester.pump();
}

Future<void> _apply(WidgetTester tester) async {
  await tester.tap(find.widgetWithText(FilledButton, 'Aplicar'));
  await tester.pumpAndSettle();
}

List<String> _tagsOf(AppServices s, String id) =>
    s.transactions.byId(id)?.tags ?? const [];

void main() {
  testWidgets('adicionar tag a 2 selecionadas grava e mantém a seleção', (
    tester,
  ) async {
    final s = await _services(tester);
    await _pump(tester, s);
    await _select(tester, ['a', 'c']);

    await _openTags(tester);
    await _typeTag(tester, 'viagem');
    await _apply(tester);

    expect(_tagsOf(s, 'a'), ['viagem']);
    expect(_tagsOf(s, 'c'), ['Trabalho', 'viagem']);
    expect(find.text('Tags atualizadas em 2 transações'), findsOneWidget);
    expect(find.text('2 selecionadas'), findsOneWidget);
  });

  testWidgets('remover: só conta transações que perdem a tag', (tester) async {
    final s = await _services(tester);
    await _pump(tester, s);
    // 'a' não tem a tag: não entra na contagem nem é gravada.
    await _select(tester, ['a', 'b']);

    await _openTags(tester);
    await tester.tap(find.text('Remover'));
    await tester.pump();
    await _typeTag(tester, 'VIAGEM');
    await _apply(tester);

    expect(_tagsOf(s, 'b'), isEmpty);
    expect(_tagsOf(s, 'a'), isEmpty);
    expect(find.text('Tags atualizadas em 1 transação'), findsOneWidget);
  });

  testWidgets('célula inline mostra o rótulo da subcategoria', (tester) async {
    final s = await _services(tester);
    await _pump(tester, s);

    expect(
      find.descendant(
        of: find.byKey(const Key('inline-category-b')),
        matching: find.text('Alimentação › Mercado X'),
      ),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const Key('inline-category-a')));
    await tester.pumpAndSettle();
    // 2 = o valor fechado da linha b + o item aberto do menu de a.
    expect(find.text('Alimentação › Mercado X'), findsNWidgets(2));
  });

  testWidgets('recategorizar lista o rótulo da subcategoria', (tester) async {
    final s = await _services(tester);
    await _pump(tester, s);
    await _select(tester, ['a', 'b']);

    await tester.tap(find.widgetWithText(TextButton, 'Recategorizar'));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(DropdownButton<String>));
    await tester.pumpAndSettle();

    // 2 = o valor fechado da linha b + o item do menu aberto do diálogo.
    expect(find.text('Alimentação › Mercado X'), findsNWidgets(2));
    expect(tester.takeException(), isNull);
  });
}
