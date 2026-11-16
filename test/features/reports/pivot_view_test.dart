import 'package:finme/app/app_scope.dart';
import 'package:finme/app/bootstrap.dart';
import 'package:finme/core/models/year_month.dart';
import 'package:finme/core/services/record_store.dart';
import 'package:finme/core/theme/app_theme.dart';
import 'package:finme/features/categories/domain/category_tree.dart';
import 'package:finme/features/categories/domain/transaction_category.dart';
import 'package:finme/features/reports/domain/category_pivot.dart';
import 'package:finme/features/reports/domain/category_reports.dart';
import 'package:finme/features/reports/presentation/pivot_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

TransactionCategory _cat(
  String id,
  String name,
  CategoryKind kind, {
  String? parentId,
}) => TransactionCategory(
  id: id,
  name: name,
  kind: kind,
  iconCodePoint: 0,
  colorValue: 0,
  parentId: parentId,
);

final CategoryTree _tree = CategoryTree([
  _cat('ali', 'Alimentação', CategoryKind.expense),
  _cat('mer', 'Mercado', CategoryKind.expense, parentId: 'ali'),
  _cat('res', 'Restaurante', CategoryKind.expense, parentId: 'ali'),
  _cat('tra', 'Transporte', CategoryKind.expense),
]);

/// Dados de SPEC §5.29 (despesas por mês e categoria própria), ago..nov/2026.
const _months = [
  YearMonth(2026, 8),
  YearMonth(2026, 9),
  YearMonth(2026, 10),
  YearMonth(2026, 11),
];

final MonthCategoryTotals _totals = {
  const YearMonth(2026, 8): {'mer': 30000, 'tra': 10000},
  const YearMonth(2026, 9): {'mer': 40000, 'res': 10000, 'tra': 10000},
  const YearMonth(2026, 10): {
    'mer': 50000,
    'res': 20000,
    'ali': 5000,
    'tra': 20000,
  },
  const YearMonth(2026, 11): {
    'mer': 60000,
    'res': 15000,
    'tra': 5000,
    null: 3000,
  },
};

CategoryPivot _pivot([MonthCategoryTotals? totals]) =>
    categoryPivot(totals ?? _totals, months: _months, tree: _tree);

Future<AppServices> _services(
  WidgetTester tester, {
  bool hideValues = false,
}) async {
  return (await tester.runAsync(() async {
    final s = await bootstrap(
      storeFactory: (_) => MemoryRecordStore(),
      clock: () => DateTime(2026, 11, 15),
    );
    await s.settings.update((x) => x.copyWith(hideValues: hideValues));
    return s;
  }))!;
}

Widget _app(AppServices s, CategoryPivot pivot, CategoryTree tree) => AppScope(
  services: s,
  child: MaterialApp(
    theme: AppTheme.light(),
    home: Scaffold(
      body: SizedBox(
        height: 800,
        child: PivotView(pivot: pivot, tree: tree),
      ),
    ),
  ),
);

Future<void> _pump(
  WidgetTester tester,
  AppServices s, {
  required CategoryPivot pivot,
  CategoryTree? tree,
  double width = 1000,
}) async {
  await tester.binding.setSurfaceSize(Size(width, 900));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(_app(s, pivot, tree ?? _tree));
  await tester.pumpAndSettle();
}

double _y(WidgetTester tester, String text) =>
    tester.getTopLeft(find.text(text)).dy;

void main() {
  testWidgets('ordem padrão, totais e célula zero com traço', (tester) async {
    final s = await _services(tester);
    await _pump(tester, s, pivot: _pivot());

    expect(find.byKey(const Key('pivot-row-ali')), findsOneWidget);
    expect(find.byKey(const Key('pivot-row-tra')), findsOneWidget);
    expect(find.byKey(const Key('pivot-row-none')), findsOneWidget);
    expect(_y(tester, 'Alimentação') < _y(tester, 'Transporte'), isTrue);
    expect(_y(tester, 'Transporte') < _y(tester, 'Sem categoria'), isTrue);
    expect(find.text('R\$ 2.780,00'), findsOneWidget);
    expect(find.text('R\$ 2.300,00'), findsOneWidget);
    expect(find.text('–'), findsWidgets);
  });

  testWidgets('ordenação: coluna nova desc/asc, coluna ativa inverte', (
    tester,
  ) async {
    final s = await _services(tester);
    await _pump(tester, s, pivot: _pivot());

    // Padrão: total desc.
    expect(_y(tester, 'Alimentação') < _y(tester, 'Transporte'), isTrue);

    // Total já ativo: inverte para asc.
    await tester.tap(find.byKey(const Key('pivot-sort-total')));
    await tester.pumpAndSettle();
    expect(_y(tester, 'Transporte') < _y(tester, 'Alimentação'), isTrue);
    expect(_y(tester, 'Alimentação') < _y(tester, 'Sem categoria'), isTrue);

    // Rótulo em coluna nova: asc.
    await tester.tap(find.byKey(const Key('pivot-sort-label')));
    await tester.pumpAndSettle();
    expect(_y(tester, 'Alimentação') < _y(tester, 'Transporte'), isTrue);
    expect(_y(tester, 'Transporte') < _y(tester, 'Sem categoria'), isTrue);

    // Mês em coluna nova (ago): desc; Sem categoria segue por último.
    await tester.tap(find.byKey(const Key('pivot-sort-0')));
    await tester.pumpAndSettle();
    expect(_y(tester, 'Alimentação') < _y(tester, 'Transporte'), isTrue);
    expect(_y(tester, 'Transporte') < _y(tester, 'Sem categoria'), isTrue);
  });

  testWidgets('drill-down: abre filhas de Alimentação na ordem do domínio', (
    tester,
  ) async {
    final s = await _services(tester);
    await _pump(tester, s, pivot: _pivot());

    expect(find.text('Mercado'), findsNothing);
    await tester.tap(find.byKey(const Key('pivot-expand-ali')));
    await tester.pumpAndSettle();

    expect(find.text('Mercado'), findsOneWidget);
    expect(find.text('Restaurante'), findsOneWidget);
    expect(find.text('(sem subcategoria)'), findsOneWidget);
    expect(_y(tester, 'Alimentação') < _y(tester, 'Mercado'), isTrue);
    expect(_y(tester, 'Mercado') < _y(tester, 'Restaurante'), isTrue);
    expect(
      _y(tester, 'Restaurante') < _y(tester, '(sem subcategoria)'),
      isTrue,
    );
    expect(_y(tester, '(sem subcategoria)') < _y(tester, 'Transporte'), isTrue);

    await tester.tap(find.byKey(const Key('pivot-expand-ali')));
    await tester.pumpAndSettle();
    expect(find.text('Mercado'), findsNothing);
  });

  testWidgets('hideValues mascara os valores', (tester) async {
    final s = await _services(tester, hideValues: true);
    await _pump(tester, s, pivot: _pivot());

    expect(find.text('R\$ 2.780,00'), findsNothing);
    expect(find.text('R\$ ••••'), findsWidgets);
  });

  testWidgets('vazio mostra EmptyState', (tester) async {
    final s = await _services(tester);
    await _pump(tester, s, pivot: _pivot(const {}));

    expect(
      find.text('Sem lançamentos no período com estes filtros.'),
      findsOneWidget,
    );
    expect(find.byKey(const Key('pivot-sort-total')), findsNothing);
  });

  testWidgets('didUpdateWidget reordena com o novo pivot e a escolha atual', (
    tester,
  ) async {
    final s = await _services(tester);
    await _pump(tester, s, pivot: _pivot());

    await tester.tap(find.byKey(const Key('pivot-sort-total')));
    await tester.pumpAndSettle();
    expect(_y(tester, 'Transporte') < _y(tester, 'Alimentação'), isTrue);

    // Transporte passa a ter mais gasto: asc mantido, ordem recalculada.
    final bigger = _pivot({
      ..._totals,
      const YearMonth(2026, 11): {'tra': 900000, 'mer': 60000, 'res': 15000},
    });
    await tester.pumpWidget(_app(s, bigger, _tree));
    await tester.pumpAndSettle();
    expect(_y(tester, 'Alimentação') < _y(tester, 'Transporte'), isTrue);
  });

  testWidgets(
    'coluna de rótulo fixa; valores rolam na horizontal (24 meses, 800 px)',
    (tester) async {
      final s = await _services(tester);
      final wide = _wide();
      await _pump(tester, s, pivot: wide.pivot, tree: wide.tree, width: 800);

      expect(
        find.byWidgetPredicate(
          (w) =>
              w is SingleChildScrollView &&
              w.scrollDirection == Axis.horizontal,
        ),
        findsOneWidget,
      );
      final labelX = tester.getTopLeft(find.text('Categoria')).dx;
      final monthX = tester
          .getTopLeft(find.byKey(const Key('pivot-sort-0')))
          .dx;
      // Primeiro '–' é o mês 0 da primeira linha, visível.
      await tester.drag(find.text('–').first, const Offset(-200, 0));
      await tester.pumpAndSettle();
      expect(tester.getTopLeft(find.text('Categoria')).dx, labelX);
      expect(
        tester.getTopLeft(find.byKey(const Key('pivot-sort-0'))).dx < monthX,
        isTrue,
      );
    },
  );

  testWidgets('cabeçalho continua visível ao rolar a lista na vertical', (
    tester,
  ) async {
    final s = await _services(tester);
    final wide = _wide();
    await _pump(tester, s, pivot: wide.pivot, tree: wide.tree, width: 800);

    // Cat 05 (995,00 em ago) segue visível depois de rolar 96 px.
    final headerY = _y(tester, 'Categoria');
    final rowBefore = _y(tester, 'Cat 05');
    final cellBefore = tester.getTopLeft(find.text('R\$ 995,00').first).dy;
    // Arraste lento: sem fling (um arraste rápido de teste rola além da janela de cache).
    await tester.timedDrag(
      find.text('Cat 00'),
      const Offset(0, -96),
      const Duration(seconds: 1),
    );
    await tester.pumpAndSettle();

    expect(_y(tester, 'Categoria'), headerY);
    final rowMoved = _y(tester, 'Cat 05') - rowBefore;
    final cellMoved =
        tester.getTopLeft(find.text('R\$ 995,00').first).dy - cellBefore;
    expect(rowMoved, closeTo(-96, 0.01));
    // Painel de valores acompanha o de rótulos.
    expect(cellMoved, closeTo(rowMoved, 0.01));
  });
}

/// 30 categorias (Cat 00 é a maior) e 24 meses: rola na vertical e na horizontal.
({CategoryTree tree, CategoryPivot pivot}) _wide() {
  final tree = CategoryTree([
    for (var i = 0; i < 30; i++)
      _cat('k$i', 'Cat ${i.toString().padLeft(2, '0')}', CategoryKind.expense),
  ]);
  final months = [
    for (var i = 0; i < 24; i++) const YearMonth(2024, 12).addMonths(i),
  ];
  final pivot = categoryPivot(
    {
      const YearMonth(2026, 8): {
        for (var i = 0; i < 30; i++) 'k$i': 100000 - i * 100,
      },
    },
    months: months,
    tree: tree,
  );
  return (tree: tree, pivot: pivot);
}
