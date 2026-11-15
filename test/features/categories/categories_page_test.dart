import 'package:finme/app/app_scope.dart';
import 'package:finme/app/bootstrap.dart';
import 'package:finme/app/seed.dart';
import 'package:finme/core/models/app_settings.dart';
import 'package:finme/core/services/record_store.dart';
import 'package:finme/core/theme/app_theme.dart';
import 'package:finme/core/widgets/widgets.dart';
import 'package:finme/features/categories/domain/transaction_category.dart';
import 'package:finme/features/categories/presentation/categories_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Future<AppServices> _setup(WidgetTester tester, AppMode mode) async {
  final s = (await tester.runAsync(() async {
    final s = await bootstrap(
      storeFactory: (_) => MemoryRecordStore(),
      clock: () => DateTime(2026, 11, 14),
    );
    await seedDemo(s);
    await materializeRecurring(s);
    await s.settings.update((c) => c.copyWith(mode: mode));
    return s;
  }))!;
  return s;
}

Future<void> _pump(
  WidgetTester tester,
  AppServices s, {
  double width = 1400,
}) async {
  await tester.binding.setSurfaceSize(Size(width, 900));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(
    AppScope(
      services: s,
      child: MaterialApp(
        theme: AppTheme.light(),
        home: const Scaffold(body: CategoriesPage()),
      ),
    ),
  );
  await tester.pump();
}

/// Sem categorias: bootstrap cria as padrão, então são removidas. A página mostra o estado vazio.
Future<AppServices> _setupEmpty(WidgetTester tester, AppMode mode) async {
  return (await tester.runAsync(() async {
    final s = await bootstrap(
      storeFactory: (_) => MemoryRecordStore(),
      clock: () => DateTime(2026, 11, 14),
    );
    await s.categories.replaceAll(const []);
    await s.settings.update((c) => c.copyWith(mode: mode));
    return s;
  }))!;
}

void main() {
  for (final mode in AppMode.values) {
    testWidgets('estado vazio (${mode.name}): botão abre o form de despesa', (
      tester,
    ) async {
      final s = await _setupEmpty(tester, mode);
      await _pump(tester, s);

      expect(find.byType(EmptyState), findsOneWidget);
      await tester.tap(
        find.descendant(
          of: find.byType(EmptyState),
          matching: find.text('Nova categoria'),
        ),
      );
      await tester.pumpAndSettle();

      final kind = tester.widget<SegmentedButton<CategoryKind>>(
        find.byType(SegmentedButton<CategoryKind>).last,
      );
      expect(kind.selected, {CategoryKind.expense});
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('estado vazio na aba Receitas abre o form com tipo receita', (
    tester,
  ) async {
    final s = await _setupEmpty(tester, AppMode.simple);
    await _pump(tester, s);

    await tester.tap(find.text('Receitas'));
    await tester.pumpAndSettle();
    await tester.tap(
      find.descendant(
        of: find.byType(EmptyState),
        matching: find.text('Nova categoria'),
      ),
    );
    await tester.pumpAndSettle();

    final kind = tester.widget<SegmentedButton<CategoryKind>>(
      find.byType(SegmentedButton<CategoryKind>).last,
    );
    expect(kind.selected, {CategoryKind.income});
  });

  testWidgets('modo Simples: lista de despesas sem bloco de orçamentos', (
    tester,
  ) async {
    final s = await _setup(tester, AppMode.simple);
    await _pump(tester, s);

    expect(find.text('Categorias'), findsOneWidget);
    expect(find.text('Nova categoria'), findsOneWidget);
    expect(find.text('Despesas'), findsOneWidget);
    expect(find.text('Receitas'), findsOneWidget);
    expect(find.text('Alimentação'), findsOneWidget);
    expect(find.text('Orçamentos'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('modo Ultra: bloco de orçamentos e barra de limite', (
    tester,
  ) async {
    final s = await _setup(tester, AppMode.ultra);
    await s.categories.upsert(
      s.categories.byId('cat_mercado')!.copyWith(monthlyBudgetCents: 1000),
    );
    await _pump(tester, s);

    expect(find.text('Orçamentos'), findsOneWidget);
    expect(find.text('Estourado'), findsOneWidget);
    expect(find.text('Mercado'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('troca para Receitas lista categorias de receita', (
    tester,
  ) async {
    final s = await _setup(tester, AppMode.simple);
    await _pump(tester, s);

    await tester.tap(find.text('Receitas'));
    await tester.pumpAndSettle();

    expect(find.text('Salário'), findsOneWidget);
    expect(find.text('Alimentação'), findsNothing);
  });

  testWidgets('largura 390 (mobile) sem exceções de overflow', (tester) async {
    final s = await _setup(tester, AppMode.ultra);
    await _pump(tester, s, width: 390);

    expect(find.text('Nova categoria'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('formulário cria categoria de despesa com orçamento', (
    tester,
  ) async {
    final s = await _setup(tester, AppMode.ultra);
    await _pump(tester, s);

    await tester.tap(find.text('Nova categoria'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField).first, 'Pets');
    await tester.enterText(find.byType(TextFormField).last, '250');
    await tester.tap(find.text('Salvar'));
    await tester.pumpAndSettle();

    final created = s.categories.all.where((c) => c.name == 'Pets').toList();
    expect(created, hasLength(1));
    expect(created.single.monthlyBudgetCents, 25000);
    expect(created.single.kind, CategoryKind.expense);
  });

  testWidgets('excluir categoria em uso deixa lançamentos sem categoria', (
    tester,
  ) async {
    final s = await _setup(tester, AppMode.simple);
    await _pump(tester, s);

    final usedBefore = s.transactions.all
        .where((t) => t.categoryId == 'cat_mercado')
        .length;
    expect(usedBefore, greaterThan(0));

    final row = find.byKey(const ValueKey('cat-cat_mercado'));
    await tester.tap(
      find.descendant(of: row, matching: find.byIcon(Icons.more_vert)),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Excluir'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Excluir'));
    await tester.pumpAndSettle();

    expect(s.categories.byId('cat_mercado'), isNull);
    expect(
      s.transactions.all.where((t) => t.categoryId == 'cat_mercado'),
      isEmpty,
    );
    expect(
      s.transactions.all.where((t) => t.categoryId == null).length,
      greaterThanOrEqualTo(usedBefore),
    );
  });

  testWidgets('categoria em uso trava o tipo no formulário de edição', (
    tester,
  ) async {
    final s = await _setup(tester, AppMode.simple);
    await _pump(tester, s);

    final row = find.byKey(const ValueKey('cat-cat_mercado'));
    await tester.tap(
      find.descendant(of: row, matching: find.byIcon(Icons.more_vert)),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Editar'));
    await tester.pumpAndSettle();

    expect(find.textContaining('Tipo travado'), findsOneWidget);
    // O último SegmentedButton é o do diálogo, que está sobre a página.
    final kindControl = tester.widget<SegmentedButton<CategoryKind>>(
      find.byType(SegmentedButton<CategoryKind>).last,
    );
    expect(kindControl.onSelectionChanged, isNull);
  });

  testWidgets('excluir categoria sem uso pede confirmação', (tester) async {
    final s = await _setup(tester, AppMode.simple);
    await s.categories.upsert(
      const TransactionCategory(
        id: 'cat_pets',
        name: 'Pets',
        kind: CategoryKind.expense,
        iconCodePoint: 0,
        colorValue: 0xFF000000,
      ),
    );
    await _pump(tester, s);

    final row = find.byKey(const ValueKey('cat-cat_pets'));
    await tester.tap(
      find.descendant(of: row, matching: find.byIcon(Icons.more_vert)),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Excluir'));
    await tester.pumpAndSettle();

    expect(find.text('Excluir "Pets"?'), findsOneWidget);
    expect(s.categories.byId('cat_pets'), isNotNull);

    await tester.tap(find.widgetWithText(FilledButton, 'Excluir'));
    await tester.pumpAndSettle();
    expect(s.categories.byId('cat_pets'), isNull);
  });
}
