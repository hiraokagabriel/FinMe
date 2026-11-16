import 'package:finme/core/models/year_month.dart';
import 'package:finme/core/theme/app_theme.dart';
import 'package:finme/core/widgets/layout.dart';
import 'package:finme/features/net_worth/domain/net_worth.dart';
import 'package:finme/features/net_worth/presentation/net_worth_chart.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

NetWorthPoint point(
  YearMonth month,
  DateTime date, {
  int accounts = 0,
  int assets = 0,
  int receivable = 0,
  int payable = 0,
  int card = 0,
}) => NetWorthPoint(
  month: month,
  date: date,
  accountsCents: accounts,
  assetsCents: assets,
  receivableCents: receivable,
  payableCents: payable,
  cardDebtCents: card,
);

/// Ponto de out/2026 com patrimônio líquido de R$ 49.200,00.
NetWorthPoint outubro() => point(
  const YearMonth(2026, 10),
  DateTime(2026, 10, 31),
  accounts: 870000,
  assets: 4200000,
  receivable: 50000,
  payable: 80000,
  card: 120000,
);

Future<void> pumpChart(
  WidgetTester tester,
  List<NetWorthPoint> points, {
  bool hideValues = false,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.light(),
      home: Scaffold(
        body: SizedBox(
          width: 600,
          child: NetWorthChart(points: points, hideValues: hideValues),
        ),
      ),
    ),
  );
}

void main() {
  test('tooltip do mês fechado de out/2026', () {
    expect(
      netWorthTooltipText(outubro(), hideValues: false),
      'Outubro 2026\n'
      'Patrimônio líquido: R\$ 49.200,00\n'
      'Contas: R\$ 8.700,00\n'
      'Ativos: R\$ 42.000,00\n'
      'A receber: R\$ 500,00\n'
      'A pagar: -R\$ 800,00\n'
      'Dívida de cartão: -R\$ 1.200,00',
    );
  });

  test('mês atual mostra até o dia de hoje na primeira linha', () {
    final now = point(
      const YearMonth(2026, 11),
      DateTime(2026, 11, 15),
      accounts: 100000,
    );
    expect(
      netWorthTooltipText(now, hideValues: false).split('\n').first,
      'Novembro 2026 (até 15/11)',
    );
  });

  test('hideValues mascara todos os valores do tooltip', () {
    expect(
      netWorthTooltipText(outubro(), hideValues: true),
      'Outubro 2026\n'
      'Patrimônio líquido: R\$ ••••\n'
      'Contas: R\$ ••••\n'
      'Ativos: R\$ ••••\n'
      'A receber: R\$ ••••\n'
      'A pagar: R\$ ••••\n'
      'Dívida de cartão: R\$ ••••',
    );
  });

  testWidgets('12 pontos renderizam LineChart sem exceção', (tester) async {
    final points = [
      for (var i = 0; i < 12; i++)
        point(
          YearMonth(2026, i + 1),
          DateTime(2026, i + 1, 28),
          accounts: 100000 * (i + 1),
        ),
    ];
    await pumpChart(tester, points);
    expect(tester.takeException(), isNull);
    expect(find.byType(LineChart), findsOneWidget);
  });

  testWidgets('1 ponto mostra estado vazio', (tester) async {
    await pumpChart(tester, [outubro()]);
    expect(find.byType(LineChart), findsNothing);
    expect(find.byType(EmptyState), findsOneWidget);
    expect(find.text('Ainda sem histórico para o gráfico.'), findsOneWidget);
  });

  testWidgets('ponto negativo desenha a linha de zero', (tester) async {
    final points = [
      point(const YearMonth(2026, 10), DateTime(2026, 10, 31), accounts: 1000),
      point(const YearMonth(2026, 11), DateTime(2026, 11, 15), payable: 5000),
    ];
    await pumpChart(tester, points);
    final chart = tester.widget<LineChart>(find.byType(LineChart));
    expect(chart.data.extraLinesData.horizontalLines, isNotEmpty);
  });

  testWidgets('sem valor negativo não há linha de zero', (tester) async {
    final points = [
      point(const YearMonth(2026, 10), DateTime(2026, 10, 31), accounts: 1000),
      point(const YearMonth(2026, 11), DateTime(2026, 11, 15), accounts: 2000),
    ];
    await pumpChart(tester, points);
    final chart = tester.widget<LineChart>(find.byType(LineChart));
    expect(chart.data.extraLinesData.horizontalLines, isEmpty);
  });

  testWidgets('tooltip do toque respeita hideValues', (tester) async {
    final points = [
      outubro(),
      point(const YearMonth(2026, 11), DateTime(2026, 11, 15)),
    ];
    await pumpChart(tester, points, hideValues: true);
    final chart = tester.widget<LineChart>(find.byType(LineChart));
    final bar = chart.data.lineBarsData.single;
    final spot = bar.spots.first;
    final items = chart.data.lineTouchData.touchTooltipData.getTooltipItems([
      LineBarSpot(bar, 0, spot),
    ]);
    expect(items.single?.text, contains('Patrimônio líquido: R\$ ••••'));
    expect(items.single?.text, isNot(contains('49.200')));
  });
}
