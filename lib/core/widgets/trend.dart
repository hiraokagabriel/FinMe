import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_text.dart';
import '../utils/formatters.dart';

/// Variação vs. mês anterior. Verde se a direção é boa, vermelho se ruim, neutro em zero.
class DeltaBadge extends StatelessWidget {
  const DeltaBadge({
    super.key,
    required this.ratio,
    this.higherIsBetter = true,
  });

  final double? ratio;
  final bool higherIsBetter;

  @override
  Widget build(BuildContext context) {
    final value = ratio;
    if (value == null) {
      return const SizedBox.shrink();
    }
    final c = context.colors;
    final pct = formatPercent(value.abs());
    // Arredonda para "0,0%": sem seta e em neutro, sem sinal de melhora ou piora.
    final neutral = pct == '0,0%';
    final color = neutral
        ? c.textSecondary
        : (value > 0) == higherIsBetter
        ? c.success
        : c.danger;
    final arrow = value < 0 ? '▼' : '▲';
    return Tooltip(
      message: 'vs. mês anterior',
      child: Text(
        neutral ? pct : '$arrow $pct',
        style: AppText.tabular(
          TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: color),
        ),
      ),
    );
  }
}

/// Linha mínima de tendência, sem eixos, grade, borda ou toque. Menos de 2 valores → só o espaço.
/// Valores em centavos, plotados em reais.
class Sparkline extends StatelessWidget {
  const Sparkline({
    super.key,
    required this.values,
    this.width = 80,
    this.height = 24,
    this.color,
  });

  final List<int> values;
  final double width;
  final double height;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    if (values.length < 2) {
      return SizedBox(width: width, height: height);
    }
    return SizedBox(
      width: width,
      height: height,
      child: LineChart(
        LineChartData(
          lineTouchData: const LineTouchData(enabled: false),
          titlesData: const FlTitlesData(show: false),
          gridData: const FlGridData(show: false),
          borderData: FlBorderData(show: false),
          lineBarsData: [
            LineChartBarData(
              spots: [
                for (var i = 0; i < values.length; i++)
                  FlSpot(i.toDouble(), values[i] / 100),
              ],
              isCurved: false,
              barWidth: 1.5,
              dotData: const FlDotData(show: false),
              color: color ?? context.colors.primary,
            ),
          ],
        ),
        duration: Duration.zero,
      ),
    );
  }
}
