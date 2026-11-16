import 'package:finme/app/app_scope.dart';
import 'package:finme/app/bootstrap.dart';
import 'package:finme/core/models/year_month.dart';
import 'package:finme/core/services/record_store.dart';
import 'package:finme/core/theme/app_theme.dart';
import 'package:finme/core/widgets/layout.dart';
import 'package:finme/features/reports/domain/monthly_flow.dart';
import 'package:finme/features/reports/presentation/trend_view.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Exemplo de SPEC §5.30: set, out e nov/2026.
final _points = [
  const TrendPoint(
    month: YearMonth(2026, 9),
    incomeCents: 500000,
    expenseCents: 60000,
  ),
  const TrendPoint(
    month: YearMonth(2026, 10),
    incomeCents: 500000,
    expenseCents: 95000,
  ),
  const TrendPoint(
    month: YearMonth(2026, 11),
    incomeCents: 520000,
    expenseCents: 83000,
  ),
];

Future<void> pumpView(
  WidgetTester tester, {
  required List<TrendPoint> points,
  bool ultra = true,
  bool hideValues = false,
  List<int?> expenseAverage = const [null, null, 79333],
  List<int?> balanceAverage = const [null, null, 427333],
}) async {
  final services = (await tester.runAsync(
    () => bootstrap(
      storeFactory: (_) => MemoryRecordStore(),
      clock: () => DateTime(2026, 11, 15),
    ),
  ))!;
  await tester.pumpWidget(
    AppScope(
      services: services,
      child: MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(
          body: SizedBox(
            width: 900,
            height: 1400,
            child: TrendView(
              points: points,
              expenseAverage: expenseAverage,
              balanceAverage: balanceAverage,
              ultra: ultra,
              hideValues: hideValues,
            ),
          ),
        ),
      ),
    ),
  );
  if (hideValues) {
    await tester.runAsync(
      () => services.settings.update((s) => s.copyWith(hideValues: true)),
    );
    await tester.pump();
  }
}

LineChart lineChart(WidgetTester tester) =>
    tester.widget<LineChart>(find.byType(LineChart));

void main() {
  test('tooltip de nov/2026', () {
    expect(
      trendTooltipText(_points[2], hideValues: false),
      'Novembro 2026\n'
      'Receitas: R\$ 5.200,00\n'
      'Despesas: R\$ 830,00\n'
      'Saldo do mês: R\$ 4.370,00',
    );
  });

  test('hideValues mascara as três linhas de valor', () {
    expect(
      trendTooltipText(_points[2], hideValues: true),
      'Novembro 2026\n'
      'Receitas: R\$ ••••\n'
      'Despesas: R\$ ••••\n'
      'Saldo do mês: R\$ ••••',
    );
  });

  testWidgets('Ultra: 1 BarChart e 1 LineChart; média liga 3 linhas', (
    tester,
  ) async {
    await pumpView(tester, points: _points);
    expect(find.byType(BarChart), findsOneWidget);
    expect(find.byType(LineChart), findsOneWidget);
    expect(lineChart(tester).data.lineBarsData, hasLength(1));

    await tester.tap(find.byKey(const Key('trend-average')));
    await tester.pump();
    expect(lineChart(tester).data.lineBarsData, hasLength(3));

    await tester.tap(find.byKey(const Key('trend-average')));
    await tester.pump();
    expect(lineChart(tester).data.lineBarsData, hasLength(1));
  });

  testWidgets('Simples: só BarChart e sem média móvel', (tester) async {
    await pumpView(tester, points: _points, ultra: false);
    expect(find.byType(BarChart), findsOneWidget);
    expect(find.byType(LineChart), findsNothing);
    expect(find.byKey(const Key('trend-average')), findsNothing);
  });

  testWidgets('tabela lista os meses e soma receitas no rodapé', (
    tester,
  ) async {
    await pumpView(tester, points: _points);
    expect(find.text('set/2026'), findsWidgets);
    expect(find.text('nov/2026'), findsWidgets);
    expect(find.text('Total'), findsOneWidget);
    expect(find.text('R\$ 15.200,00'), findsOneWidget);
  });

  testWidgets('clicar em Despesas ordena desc e leva o maior mês ao topo', (
    tester,
  ) async {
    await pumpView(tester, points: _points);
    await tester.tap(
      find.descendant(of: find.byType(Table), matching: find.text('Despesas')),
    );
    await tester.pump();
    final firstRow = tester.widget<Table>(find.byType(Table)).children[1];
    final firstMonth = (firstRow.children.first as Padding).child as Text;
    expect(firstMonth.data, 'out/2026');
  });

  testWidgets('hideValues: nenhum valor em claro', (tester) async {
    await pumpView(tester, points: _points, hideValues: true);
    expect(find.text('R\$ 15.200,00'), findsNothing);
    expect(find.text('R\$ ••••'), findsWidgets);
  });

  testWidgets('saldo negativo num mês desenha a linha de zero', (tester) async {
    final points = [
      _points[0],
      const TrendPoint(
        month: YearMonth(2026, 10),
        incomeCents: 0,
        expenseCents: 60000,
      ),
      _points[2],
    ];
    await pumpView(tester, points: points);
    expect(lineChart(tester).data.extraLinesData.horizontalLines, isNotEmpty);
  });

  testWidgets('sem saldo negativo não há linha de zero', (tester) async {
    await pumpView(tester, points: _points);
    expect(lineChart(tester).data.extraLinesData.horizontalLines, isEmpty);
  });

  testWidgets('todos os meses zerados mostram estado vazio', (tester) async {
    final zero = [
      for (final m in _points)
        TrendPoint(month: m.month, incomeCents: 0, expenseCents: 0),
    ];
    await pumpView(tester, points: zero, expenseAverage: [null, null, 0]);
    expect(find.byType(EmptyState), findsOneWidget);
    expect(
      find.text('Sem lançamentos no período com estes filtros.'),
      findsOneWidget,
    );
    expect(find.byType(BarChart), findsNothing);
  });
}
