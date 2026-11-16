import 'package:flutter/material.dart';

import '../../../core/models/year_month.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/utils/date_utils.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/layout.dart';
import '../domain/spending_heatmap.dart';

const _cellSize = 12.0;
const _stride = 14.0; // célula + gap de 2
const _labelWidth = 28.0;

/// Linha 0 = domingo (grade estilo calendário).
const _weekdayLabels = {0: 'Dom', 3: 'Qua', 6: 'Sáb'};

/// Tooltip de um dia (SPEC §7.3 Fase 12). [s] null = dia sem gasto; [hideValues] mascara o valor.
String heatmapTooltipText(
  DateTime day,
  DaySpending? s, {
  required bool hideValues,
}) {
  final head = formatDate(day);
  if (s == null) {
    return '$head · sem gastos';
  }
  final count = s.count == 1 ? '1 transação' : '${s.count} transações';
  return '$head · ${formatMoney(s.cents, hidden: hideValues)} · $count';
}

/// Gasto por dia: colunas = semanas, linhas = dias da semana, com rolagem horizontal.
class HeatmapView extends StatefulWidget {
  const HeatmapView({
    super.key,
    required this.heatmap,
    required this.hideValues,
  });

  final SpendingHeatmap heatmap;
  final bool hideValues;

  @override
  State<HeatmapView> createState() => _HeatmapViewState();
}

class _HeatmapViewState extends State<HeatmapView> {
  // maxDay e totalCents percorrem todos os dias: calculados só ao receber um heatmap novo.
  DaySpending? _maxDay;
  int _total = 0;

  @override
  void initState() {
    super.initState();
    _summarize();
  }

  @override
  void didUpdateWidget(HeatmapView old) {
    super.didUpdateWidget(old);
    if (!identical(old.heatmap, widget.heatmap)) {
      _summarize();
    }
  }

  void _summarize() {
    _maxDay = widget.heatmap.maxDay;
    _total = widget.heatmap.totalCents;
  }

  @override
  Widget build(BuildContext context) {
    final heatmap = widget.heatmap;
    final hideValues = widget.hideValues;
    if (heatmap.activeDays == 0) {
      return const EmptyState(
        icon: Icons.calendar_view_month,
        message: 'Sem gastos no período com estes filtros.',
      );
    }
    final maxDay = _maxDay;
    final total = _total;
    final c = context.colors;
    final textTheme = Theme.of(context).textTheme;
    final n = heatmap.activeDays;
    final base =
        'Total ${formatMoney(total, hidden: hideValues)} · '
        '${n == 1 ? '1 dia com gasto' : '$n dias com gasto'}';
    final summary = maxDay == null
        ? base
        : '$base · Maior dia: ${formatShortDate(maxDay.date)} '
              '(${formatMoney(maxDay.cents, hidden: hideValues)})';
    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpace.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _Grid(heatmap: heatmap, hideValues: hideValues),
          const SizedBox(height: AppSpace.lg),
          _Legend(colors: c),
          const SizedBox(height: AppSpace.sm),
          Text(
            summary,
            style: textTheme.bodyMedium?.copyWith(color: c.textPrimary),
          ),
        ],
      ),
    );
  }
}

/// Cor do nível 0..4 (0 = sem gasto; 1..4 = `primary` em intensidade crescente).
Color _levelColor(AppColors c, int level) => switch (level) {
  0 => c.border,
  1 => c.primary.withValues(alpha: 0.25),
  2 => c.primary.withValues(alpha: 0.45),
  3 => c.primary.withValues(alpha: 0.70),
  _ => c.primary,
};

class _Grid extends StatelessWidget {
  const _Grid({required this.heatmap, required this.hideValues});

  final SpendingHeatmap heatmap;
  final bool hideValues;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final labelStyle = TextStyle(fontSize: 11, color: c.textSecondary);
    final from = heatmap.from;
    final count =
        DateTime.utc(
          heatmap.to.year,
          heatmap.to.month,
          heatmap.to.day,
        ).difference(DateTime.utc(from.year, from.month, from.day)).inDays +
        1;
    final offset = from.weekday % 7;
    final weeks = (offset + count - 1) ~/ 7 + 1;
    final slots = List.generate(
      weeks,
      (_) => List<Widget>.filled(7, const SizedBox.square(dimension: _stride)),
    );
    final monthLabels = List<String?>.filled(weeks, null);
    for (var i = 0; i < count; i++) {
      final day = DateTime(from.year, from.month, from.day + i);
      final pos = i + offset;
      final col = pos ~/ 7;
      final s = heatmap.days[day];
      final level = heatmap.levelOf(s?.cents ?? 0);
      slots[col][pos % 7] = _cell(c, day, s, level);
      if (i == 0 || day.day == 1) {
        monthLabels[col] = formatMonth(
          YearMonth.fromDate(day),
        ).split('/').first;
      }
    }
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: _labelWidth,
            child: Column(
              children: [
                const SizedBox(height: _stride),
                for (var r = 0; r < 7; r++)
                  _label(_weekdayLabels[r] ?? '', labelStyle, _labelWidth),
              ],
            ),
          ),
          for (var w = 0; w < weeks; w++)
            Column(
              children: [
                _label(monthLabels[w] ?? '', labelStyle, _stride),
                ...slots[w],
              ],
            ),
        ],
      ),
    );
  }

  /// Rótulo de uma linha/coluna da grade; [extent] é a largura (linha) ou altura (coluna).
  Widget _label(String text, TextStyle style, double extent) => SizedBox(
    width: extent,
    height: _stride,
    child: Align(
      alignment: Alignment.centerLeft,
      // Rótulo de mês pode passar da coluna de 14 px; visível, sem quebra.
      child: Text(
        text,
        style: style,
        softWrap: false,
        overflow: TextOverflow.visible,
      ),
    ),
  );

  Widget _cell(AppColors c, DateTime day, DaySpending? s, int level) =>
      SizedBox.square(
        dimension: _stride,
        child: Align(
          alignment: Alignment.topLeft,
          child: Tooltip(
            key: ValueKey('heatmap-day-${dateKey(day)}'),
            message: heatmapTooltipText(day, s, hideValues: hideValues),
            child: Container(
              width: _cellSize,
              height: _cellSize,
              decoration: BoxDecoration(
                color: _levelColor(c, level),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
        ),
      );
}

class _Legend extends StatelessWidget {
  const _Legend({required this.colors});

  final AppColors colors;

  @override
  Widget build(BuildContext context) {
    final style = TextStyle(fontSize: 11, color: colors.textSecondary);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text('Menos', style: style),
        const SizedBox(width: AppSpace.xs),
        for (var level = 0; level <= 4; level++)
          Container(
            width: 10,
            height: 10,
            margin: const EdgeInsets.only(right: 2),
            decoration: BoxDecoration(
              color: _levelColor(colors, level),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        const SizedBox(width: AppSpace.xs),
        Text('Mais', style: style),
      ],
    );
  }
}
