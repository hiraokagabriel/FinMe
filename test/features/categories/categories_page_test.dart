import 'package:finme/app/app_scope.dart';
import 'package:finme/app/bootstrap.dart';
import 'package:finme/app/seed.dart';
import 'package:finme/core/models/app_settings.dart';
import 'package:finme/core/models/year_month.dart';
import 'package:finme/core/services/record_store.dart';
import 'package:finme/core/theme/app_theme.dart';
import 'package:finme/core/utils/formatters.dart';
import 'package:finme/core/widgets/widgets.dart';
import 'package:finme/features/categories/domain/transaction_category.dart';
import 'package:finme/features/categories/presentation/categories_page.dart';
import 'package:finme/features/transactions/domain/transaction.dart';
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

  testWidgets('nova subcategoria herda ícone e cor do pai e grava parentId', (
    tester,
  ) async {
    final s = await _setup(tester, AppMode.simple);
    await _pump(tester, s);
    final pai = s.categories.byId('cat_alimentacao')!;

    await tester.tap(
      find.descendant(
        of: find.byKey(const ValueKey('cat-cat_alimentacao')),
        matching: find.byIcon(Icons.more_vert),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Nova subcategoria'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField).first, 'Mercado X');
    await tester.tap(find.text('Salvar'));
    await tester.pumpAndSettle();

    final filha = s.categories.all.singleWhere((c) => c.name == 'Mercado X');
    expect(filha.parentId, 'cat_alimentacao');
    expect(filha.iconCodePoint, pai.iconCodePoint);
    expect(filha.colorValue, pai.colorValue);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'modo Simples: subcategoria recuada abaixo da raiz, com gasto agregado',
    (tester) async {
      final s = await _setup(tester, AppMode.simple);
      await _addFilha(s);
      await s.transactions.upsert(_gasto('tx_filha', 'cat_mercadox', 5000));
      await _pump(tester, s);

      final raiz = tester.getTopLeft(find.text('Alimentação')).dy;
      final filha = tester.getTopLeft(find.text('Mercado X')).dy;
      expect(filha, greaterThan(raiz));
      expect(filha, lessThan(tester.getTopLeft(find.text('Mercado')).dy));

      final total =
          s.ledger.rolledSpendingFor(
            const YearMonth(2026, 11),
          )['cat_alimentacao'] ??
          0;
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('cat-cat_alimentacao')),
          matching: find.text(formatMoney(total)),
        ),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'modo Ultra: filha oculta até expandir; orçamento da raiz soma a filha',
    (tester) async {
      final s = await _setup(tester, AppMode.ultra);
      await s.transactions.replaceAll(const []);
      await _addFilha(s);
      await s.categories.upsert(
        s.categories
            .byId('cat_alimentacao')!
            .copyWith(monthlyBudgetCents: 100000),
      );
      await s.transactions.upsertAll([
        _gasto('tx_raiz', 'cat_alimentacao', 10000),
        _gasto('tx_filha', 'cat_mercadox', 50000),
      ]);
      await _pump(tester, s);

      expect(find.text('Mercado X'), findsNothing);
      await tester.tap(
        find.byKey(const ValueKey('category-toggle-cat_alimentacao')),
      );
      await tester.pumpAndSettle();
      expect(find.text('Mercado X'), findsOneWidget);

      final barra = tester.widget<LimitBar>(
        find.descendant(
          of: find.byKey(const ValueKey('cat-cat_alimentacao')),
          matching: find.byType(LimitBar),
        ),
      );
      expect(barra.usedCents, 60000);
      expect(barra.limitCents, 100000);
    },
  );

  testWidgets(
    'editar categoria com filhas desabilita o pai; receitas não viram pai',
    (tester) async {
      final s = await _setup(tester, AppMode.simple);
      await _addFilha(s);
      await _pump(tester, s);

      await tester.tap(
        find.descendant(
          of: find.byKey(const ValueKey('cat-cat_alimentacao')),
          matching: find.byIcon(Icons.more_vert),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Editar'));
      await tester.pumpAndSettle();

      // Helper do seletor de tipo e helper do dropdown de pai.
      expect(find.text('Tem subcategorias'), findsNWidgets(2));
      final campo = tester.widget<DropdownButtonFormField<String?>>(
        find.byKey(const ValueKey('category-parent')),
      );
      expect(campo.onChanged, isNull);
      final kindControl = tester.widget<SegmentedButton<CategoryKind>>(
        find.byType(SegmentedButton<CategoryKind>).last,
      );
      expect(kindControl.onSelectionChanged, isNull);
    },
  );

  testWidgets('dropdown de pai lista só raízes do mesmo tipo', (tester) async {
    final s = await _setup(tester, AppMode.simple);
    await _pump(tester, s);

    await tester.tap(find.text('Nova categoria'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('category-parent')));
    await tester.pumpAndSettle();

    // A página de despesas não mostra receitas; só o menu do dropdown mostraria 'Salário'.
    expect(find.text('Salário'), findsNothing);
    expect(find.text('Nenhuma (categoria principal)'), findsWidgets);
    expect(find.text('Transporte'), findsWidgets);
  });

  testWidgets('excluir categoria com subcategorias é bloqueado', (
    tester,
  ) async {
    final s = await _setup(tester, AppMode.simple);
    await _addFilha(s);
    await _pump(tester, s);

    await tester.tap(
      find.descendant(
        of: find.byKey(const ValueKey('cat-cat_alimentacao')),
        matching: find.byIcon(Icons.more_vert),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Excluir'));
    await tester.pumpAndSettle();

    expect(find.text('Mova ou exclua as subcategorias antes'), findsOneWidget);
    expect(s.categories.byId('cat_alimentacao'), isNotNull);
    expect(s.categories.byId('cat_mercadox'), isNotNull);
  });

  testWidgets(
    'excluir categoria mantém tags e campos de importação do lançamento',
    (tester) async {
      final s = await _setup(tester, AppMode.simple);
      await s.transactions.upsert(
        _gasto(
          'tx_tags',
          'cat_mercado',
          9000,
          tags: ['viagem'],
        ).copyWith(externalId: 'ext-1', importedDescription: 'PGTO MERC'),
      );
      await _pump(tester, s);

      await tester.tap(
        find.descendant(
          of: find.byKey(const ValueKey('cat-cat_mercado')),
          matching: find.byIcon(Icons.more_vert),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Excluir'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Excluir'));
      await tester.pumpAndSettle();

      final t = s.transactions.byId('tx_tags')!;
      expect(t.categoryId, isNull);
      expect(t.tags, ['viagem']);
      expect(t.externalId, 'ext-1');
      expect(t.importedDescription, 'PGTO MERC');
    },
  );
}

/// Subcategoria de Alimentação (`cat_mercadox`), para os testes de árvore.
Future<void> _addFilha(AppServices s) => s.categories.upsert(
  const TransactionCategory(
    id: 'cat_mercadox',
    name: 'Mercado X',
    kind: CategoryKind.expense,
    iconCodePoint: 0,
    colorValue: 0xFF000000,
    parentId: 'cat_alimentacao',
  ),
);

Transaction _gasto(
  String id,
  String categoryId,
  int cents, {
  List<String> tags = const [],
}) => Transaction(
  id: id,
  type: TransactionType.expense,
  amountCents: cents,
  date: DateTime(2026, 11, 10),
  description: 'Teste $id',
  categoryId: categoryId,
  tags: tags,
);
