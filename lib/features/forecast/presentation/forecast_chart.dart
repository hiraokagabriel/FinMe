import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/formatters.dart';
import '../domain/forecast.dart';

const _maxChartPoints = 400;

/// Índices de [daily] a plotar: 1 a cada n dias quando passa de [maxPoints], mais o dia de menor saldo.
/// shortcut: amostragem uniforme pode esconder picos de um dia, subir [_maxChartPoints] se incomodar.
List<int> sampleIndices(
  List<DailyBalance> daily, {
  int maxPoints = _maxChartPoints,
}) {
  final n = daily.length;
  if (n <= maxPoints) {
    return [for (var i = 0; i < n; i++) i];
  }
  final step = (n / maxPoints).ceil();
  final indices = [for (var i = 0; i < n; i += step) i];
  var minIndex = 0;
  for (var i = 1; i < n; i++) {
    if (daily[i].balanceCents < daily[minIndex].balanceCents) {
      minIndex = i;
    }
  }
  if (!indices.contains(minIndex)) {
    indices
      ..add(minIndex)
      ..sort();
  }
  return indices;
}

/// Fluxo do dia [day]: entradas, saídas (positivas) e nº de eventos. Transferências não contam.
/// Calculada só no toque do gráfico, nunca no build.
({int income, int expense, int count}) dayFlow(
  List<ForecastEvent> events,
  DateTime day,
) {
  var income = 0;
  var expense = 0;
  var count = 0;
  for (final e in events) {
    final d = e.date;
    if (e.kind == ForecastEventKind.transfer ||
        d.year != day.year ||
        d.month != day.month ||
        d.day != day.day) {
      continue;
    }
    count++;
    if (e.amountCents > 0) {
      income += e.amountCents;
    } else if (e.amountCents < 0) {
      expense -= e.amountCents;
    }
  }
  return (income: income, expense: expense, count: count);
}

String _tooltipText(
  DailyBalance d,
  List<ForecastEvent> events,
  bool hideValues,
) {
  final flow = dayFlow(events, d.date);
  return [
    formatDate(d.date),
    'Saldo ${formatMoney(d.balanceCents, hidden: hideValues)}',
    if (flow.income > 0)
      'Entradas ${formatMoney(flow.income, hidden: hideValues)}',
    if (flow.expense > 0)
      'Saídas ${formatMoney(flow.expense, hidden: hideValues)}',
    if (flow.count == 1) '1 evento',
    if (flow.count > 1) '${flow.count} eventos',
  ].join('\n');
}

/// Linha do saldo diário. x = índice em [daily]; y = reais (só para o gráfico).
class ForecastDailyChart extends StatelessWidget {
  const ForecastDailyChart({
    super.key,
    required this.daily,
    this.events = const [],
    this.hideValues = false,
  });

  final List<DailyBalance> daily;
  final List<ForecastEvent> events;
  final bool hideValues;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final textStyle = Theme.of(context).textTheme.bodySmall;
    final last = daily.length - 1;
    final spots = [
      for (final i in sampleIndices(daily))
        FlSpot(i.toDouble(), daily[i].balanceCents / 100),
    ];
    return SizedBox(
      height: 240,
      child: LineChart(
        LineChartData(
          minX: 0,
          maxX: last.toDouble(),
          lineBarsData: [
            LineChartBarData(
              spots: spots,
              color: c.primary,
              barWidth: 2,
              dotData: const FlDotData(show: false),
              belowBarData: BarAreaData(
                show: true,
                color: c.primary.withValues(alpha: 0.1),
              ),
            ),
          ],
          extraLinesData: ExtraLinesData(
            horizontalLines: [
              HorizontalLine(
                y: 0,
                color: c.danger,
                strokeWidth: 1,
                dashArray: [6, 4],
              ),
            ],
          ),
          lineTouchData: LineTouchData(
            touchTooltipData: LineTouchTooltipData(
              getTooltipColor: (_) => c.surface,
              tooltipBorder: BorderSide(color: c.border),
              getTooltipItems: (touched) => [
                for (final s in touched)
                  LineTooltipItem(
                    _tooltipText(daily[s.x.toInt()], events, hideValues),
                    TextStyle(color: c.textPrimary, fontSize: 12),
                  ),
              ],
            ),
          ),
          titlesData: FlTitlesData(
            topTitles: const AxisTitles(),
            rightTitles: const AxisTitles(),
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 56,
                getTitlesWidget: (v, meta) =>
                    Text(v.round().toString(), style: textStyle),
              ),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 24,
                interval: (last / 6).clamp(1, double.infinity).toDouble(),
                getTitlesWidget: (v, meta) => Text(
                  formatShortDate(daily[v.round().clamp(0, last)].date),
                  style: textStyle,
                ),
              ),
            ),
          ),
          gridData: const FlGridData(drawVerticalLine: false),
          borderData: FlBorderData(show: false),
        ),
      ),
    );
  }
}
