import 'package:finme/app/app_scope.dart';
import 'package:finme/app/bootstrap.dart';
import 'package:finme/core/models/year_month.dart';
import 'package:finme/core/services/record_store.dart';
import 'package:finme/core/theme/app_theme.dart';
import 'package:finme/features/categories/domain/category_tree.dart';
import 'package:finme/features/categories/domain/transaction_category.dart';
import 'package:finme/features/reports/domain/category_reports.dart';
import 'package:finme/features/reports/domain/report_filter.dart';
import 'package:finme/features/reports/presentation/category_comparison_view.dart';
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

/// Dados de SPEC §5.28 (despesas por mês e categoria própria).
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

CategoryComparison _comparison({
  YearMonth month = const YearMonth(2026, 11),
  int averageMonths = 3,
  MonthCategoryTotals? totals,
}) => categoryComparison(
  totals ?? _totals,
  month: month,
  averageMonths: averageMonths,
  tree: _tree,
);

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

Future<void> _pump(
  WidgetTester tester,
  AppServices s, {
  required CategoryComparison data,
  bool ultra = true,
  bool isCurrentMonth = true,
  ValueChanged<int>? onAverage,
}) async {
  await tester.binding.setSurfaceSize(const Size(1000, 900));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(
    AppScope(
      services: s,
      child: MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(
          body: SizedBox(
            height: 800,
            child: CategoryComparisonView(
              data: data,
              tree: _tree,
              ultra: ultra,
              flow: ReportFlow.expense,
              isCurrentMonth: isCurrentMonth,
              onAverageMonthsChanged: onAverage ?? (_) {},
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('Ultra: mês de referência, ordem padrão, média e total', (
    tester,
  ) async {
    final s = await _services(tester);
    await _pump(tester, s, data: _comparison());

    expect(
      find.text('Mês de referência: Novembro 2026 (até hoje)'),
      findsOneWidget,
    );
    final ali = tester.getTopLeft(find.text('Alimentação')).dy;
    final tra = tester.getTopLeft(find.text('Transporte')).dy;
    final semCat = tester.getTopLeft(find.text('Sem categoria')).dy;
    expect(ali < tra, isTrue);
    expect(tra < semCat, isTrue);
    expect(find.text('R\$ 516,67'), findsOneWidget);
    expect(find.text('R\$ 830,00'), findsOneWidget);
    expect(find.text('Total'), findsOneWidget);
    expect(find.byKey(const Key('comparison-average')), findsOneWidget);
    expect(find.text('▼ 75,0%'), findsOneWidget);
  });

  testWidgets('drill-down: abre e fecha as subcategorias de Alimentação', (
    tester,
  ) async {
    final s = await _services(tester);
    await _pump(tester, s, data: _comparison());

    expect(find.text('Mercado'), findsNothing);
    await tester.tap(find.byKey(const Key('comparison-expand-ali')));
    await tester.pumpAndSettle();
    expect(find.text('Mercado'), findsOneWidget);
    expect(find.text('Restaurante'), findsOneWidget);
    expect(find.text('(sem subcategoria)'), findsOneWidget);

    await tester.tap(find.byKey(const Key('comparison-expand-ali')));
    await tester.pumpAndSettle();
    expect(find.text('Mercado'), findsNothing);
    expect(find.text('(sem subcategoria)'), findsNothing);
  });

  testWidgets('Simples: coluna só do Ultra volta para o mês atual desc', (
    tester,
  ) async {
    final s = await _services(tester);
    await _pump(tester, s, data: _comparison());
    double y(String label) => tester.getTopLeft(find.text(label)).dy;

    // Média 3m: 1º toque desc, 2º asc. Asc põe Transporte (média 13.333) antes de Alimentação (51.667).
    await tester.tap(find.text('Média 3m'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Média 3m'));
    await tester.pumpAndSettle();
    expect(y('Transporte') < y('Alimentação'), isTrue);

    await _pump(tester, s, data: _comparison(), ultra: false);
    expect(y('Alimentação') < y('Transporte'), isTrue);
    expect(y('Transporte') < y('Sem categoria'), isTrue);
  });

  testWidgets(
    'cabeçalho do mês anterior: desc, depois asc; null sempre por último',
    (tester) async {
      final s = await _services(tester);
      await _pump(tester, s, data: _comparison());

      double y(String label) => tester.getTopLeft(find.text(label)).dy;

      await tester.tap(find.text('out/2026'));
      await tester.pumpAndSettle();
      expect(y('Alimentação') < y('Transporte'), isTrue);
      expect(y('Transporte') < y('Sem categoria'), isTrue);

      await tester.tap(find.text('out/2026'));
      await tester.pumpAndSettle();
      expect(y('Transporte') < y('Alimentação'), isTrue);
      expect(y('Alimentação') < y('Sem categoria'), isTrue);
    },
  );

  testWidgets('troca de média chama o callback com 6', (tester) async {
    final s = await _services(tester);
    int? chosen;
    await _pump(tester, s, data: _comparison(), onAverage: (v) => chosen = v);

    await tester.tap(find.text('Média 6 meses'));
    await tester.pumpAndSettle();
    expect(chosen, 6);
  });

  testWidgets('Simples: só raízes, sem média, sem chevron', (tester) async {
    final s = await _services(tester);
    await _pump(tester, s, data: _comparison(), ultra: false);

    expect(find.byKey(const Key('comparison-average')), findsNothing);
    expect(find.text('Média 3m'), findsNothing);
    expect(find.text('Vs. média'), findsNothing);
    expect(find.byIcon(Icons.chevron_right), findsNothing);
    expect(find.text('Alimentação'), findsOneWidget);
    expect(find.text('Mercado'), findsNothing);
  });

  testWidgets('hideValues mascara valores em claro', (tester) async {
    final s = await _services(tester, hideValues: true);
    await _pump(tester, s, data: _comparison());

    expect(find.text('R\$ 830,00'), findsNothing);
    expect(find.text('R\$ 516,67'), findsNothing);
    expect(find.text('R\$ ••••'), findsWidgets);
  });

  testWidgets('sem linhas → estado vazio', (tester) async {
    final s = await _services(tester);
    await _pump(tester, s, data: _comparison(totals: const {}));

    expect(
      find.text('Sem lançamentos no período com estes filtros.'),
      findsOneWidget,
    );
  });
}
