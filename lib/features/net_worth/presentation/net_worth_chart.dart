import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/layout.dart';
import '../domain/net_worth.dart';

const _chartHeight = 220.0;
const _xLabelEvery = 3;

/// Tooltip de um mês (SPEC §7.3 Fase 11). Linhas separadas por '\n'; [hideValues] mascara os valores.
String netWorthTooltipText(NetWorthPoint p, {required bool hideValues}) {
  String money(int cents) => formatMoney(cents, hidden: hideValues);
  // Mês atual: [date] é hoje, não o último dia do mês.
  final partial = p.date.day != p.month.lastDay.day;
  return [
    formatMonthLong(p.month) +
        (partial ? ' (até ${formatShortDate(p.date)})' : ''),
    'Patrimônio líquido: ${money(p.netCents)}',
    'Contas: ${money(p.accountsCents)}',
    'Ativos: ${money(p.assetsCents)}',
    'A receber: ${money(p.receivableCents)}',
    'A pagar: ${money(-p.payableCents)}',
    'Dívida de cartão: ${money(-p.cardDebtCents)}',
  ].join('\n');
}

/// Linha do patrimônio líquido mês a mês. x = índice em [points]; y = reais (só para o gráfico).
class NetWorthChart extends StatelessWidget {
  const NetWorthChart({
    super.key,
    required this.points,
    required this.hideValues,
  });

  final List<NetWorthPoint> points;
  final bool hideValues;

  @override
  Widget build(BuildContext context) {
    if (points.length < 2) {
      return const SizedBox(
        height: _chartHeight,
        child: EmptyState(
          icon: Icons.show_chart,
          message: 'Ainda sem histórico para o gráfico.',
        ),
      );
    }
    final c = context.colors;
    final labelStyle = TextStyle(fontSize: 11, color: c.textSecondary);
    final last = points.length - 1;
    final hasNegative = points.any((p) => p.netCents < 0);
    return SizedBox(
      height: _chartHeight,
      child: LineChart(
        LineChartData(
          minX: 0,
          maxX: last.toDouble(),
          lineBarsData: [
            LineChartBarData(
              spots: [
                for (var i = 0; i < points.length; i++)
                  FlSpot(i.toDouble(), points[i].netCents / 100),
              ],
              color: c.chartBar,
              barWidth: 2,
              dotData: const FlDotData(show: false),
            ),
          ],
          extraLinesData: ExtraLinesData(
            horizontalLines: [
              if (hasNegative)
                HorizontalLine(
                  y: 0,
                  color: c.danger.withValues(alpha: 0.4),
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
                    netWorthTooltipText(
                      points[s.x.round().clamp(0, last)],
                      hideValues: hideValues,
                    ),
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
                showTitles: !hideValues,
                reservedSize: 88,
                getTitlesWidget: (v, meta) =>
                    Text(formatMoney((v * 100).round()), style: labelStyle),
              ),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 24,
                interval: _xLabelEvery.toDouble(),
                getTitlesWidget: (v, meta) => Text(
                  formatMonth(points[v.round().clamp(0, last)].month),
                  style: labelStyle,
                ),
              ),
            ),
          ),
          gridData: FlGridData(
            drawVerticalLine: false,
            getDrawingHorizontalLine: (_) =>
                FlLine(color: c.border, strokeWidth: 1),
          ),
          borderData: FlBorderData(show: false),
        ),
      ),
    );
  }
}
