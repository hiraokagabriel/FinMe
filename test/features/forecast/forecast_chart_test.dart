import 'package:finme/core/theme/app_theme.dart';
import 'package:finme/features/forecast/domain/forecast.dart';
import 'package:finme/features/forecast/presentation/forecast_chart.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

List<DailyBalance> series(List<int> balances) => [
  for (var i = 0; i < balances.length; i++)
    DailyBalance(
      date: DateTime(2026, 1, 1).add(Duration(days: i)),
      balanceCents: balances[i],
    ),
];

ForecastEvent event(DateTime date, int amountCents, ForecastEventKind kind) =>
    ForecastEvent(
      date: date,
      amountCents: amountCents,
      description: 'x',
      kind: kind,
      sourceId: 's',
    );

/// Texto do tooltip do ponto [index] com saldo [balance], via getTooltipItems do widget.
Future<String?> tooltipAt(
  WidgetTester tester,
  List<DailyBalance> daily,
  List<ForecastEvent> events, {
  bool hideValues = false,
  required int index,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.light(),
      home: Scaffold(
        body: SizedBox(
          width: 600,
          child: ForecastDailyChart(
            daily: daily,
            events: events,
            hideValues: hideValues,
          ),
        ),
      ),
    ),
  );
  final chart = tester.widget<LineChart>(find.byType(LineChart));
  final spot = FlSpot(index.toDouble(), daily[index].balanceCents / 100);
  final bar = chart.data.lineBarsData.single;
  final items = chart.data.lineTouchData.touchTooltipData.getTooltipItems([
    LineBarSpot(bar.copyWith(spots: [spot]), 0, spot),
  ]);
  return items.single?.text;
}

void main() {
  test('sem amostragem até 400 pontos', () {
    final daily = series(List.filled(400, 100));
    expect(sampleIndices(daily), [for (var i = 0; i < 400; i++) i]);
  });

  test('acima de 400 pontos amostra e mantém o dia de menor saldo', () {
    final balances = List<int>.filled(730, 100);
    balances[501] = -900;
    final idx = sampleIndices(series(balances));
    expect(idx.length, lessThanOrEqualTo(401));
    expect(idx.first, 0);
    expect(idx, contains(501));
    expect(idx, orderedEquals([...idx]..sort()));
  });

  group('dayFlow', () {
    final day = DateTime(2026, 1, 2);
    final events = [
      event(DateTime(2026, 1, 2, 9), 1000, ForecastEventKind.income),
      event(DateTime(2026, 1, 2, 15, 30), -300, ForecastEventKind.expense),
      event(DateTime(2026, 1, 2), -200, ForecastEventKind.boleto),
      event(DateTime(2026, 1, 2), -700, ForecastEventKind.transfer),
      event(DateTime(2026, 1, 3), -900, ForecastEventKind.expense),
    ];

    test(
      'soma entradas e saídas do dia, ignora transferência e outros dias',
      () {
        final flow = dayFlow(events, day);
        expect(flow.income, 1000);
        expect(flow.expense, 500);
        expect(flow.count, 3);
      },
    );

    test('dia sem eventos → zeros', () {
      final flow = dayFlow(events, DateTime(2026, 1, 9));
      expect((flow.income, flow.expense, flow.count), (0, 0, 0));
    });
  });

  testWidgets('monta com eventos e tooltip com saldo, fluxo e contagem', (
    tester,
  ) async {
    final daily = series([100, -50, 200]);
    final events = [
      event(DateTime(2026, 1, 2), 1000, ForecastEventKind.income),
      event(DateTime(2026, 1, 2), -300, ForecastEventKind.expense),
      event(DateTime(2026, 1, 2), -200, ForecastEventKind.expense),
      event(DateTime(2026, 1, 2), -700, ForecastEventKind.transfer),
    ];
    final text = await tooltipAt(tester, daily, events, index: 1);
    expect(
      text,
      '02/01/2026\nSaldo -R\$ 0,50\nEntradas R\$ 10,00\nSaídas R\$ 5,00\n3 eventos',
    );
  });

  testWidgets('tooltip sem eventos mostra só data e saldo; hideValues oculta', (
    tester,
  ) async {
    final daily = series([100, -50, 200]);
    final text = await tooltipAt(tester, daily, const [], index: 0);
    expect(text, '01/01/2026\nSaldo R\$ 1,00');

    final hidden = await tooltipAt(
      tester,
      daily,
      [event(DateTime(2026, 1, 1), -500, ForecastEventKind.expense)],
      hideValues: true,
      index: 0,
    );
    expect(hidden, '01/01/2026\nSaldo R\$ ••••\nSaídas R\$ ••••\n1 evento');
  });
}
