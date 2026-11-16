import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/layout.dart';
import '../../../core/widgets/sortable_header.dart';
import '../domain/monthly_flow.dart';

const _chartHeight = 220.0;
const _headerHeight = 36.0;
const _rowExtent = 32.0;
const _xLabelEvery = 3;

/// Colunas da tabela, na ordem dos cabeçalhos. A de mês ordena asc ao ser escolhida; as demais por valor.
enum _FixedCol { month, recurring, installment, fixed, variable, total, ratio }

String _headerOf(_FixedCol c) => switch (c) {
  _FixedCol.month => 'Mês',
  _FixedCol.recurring => 'Recorrentes',
  _FixedCol.installment => 'Parcelas',
  _FixedCol.fixed => 'Fixo',
  _FixedCol.variable => 'Variável',
  _FixedCol.total => 'Total',
  _FixedCol.ratio => '% fixo',
};

/// Chave de ordenação de [col] no mês [m] (posição [i] na série). Null = sem despesas (% fixo).
num? _keyOf(_FixedCol col, FixedVariableMonth m, int i) => switch (col) {
  _FixedCol.month => i,
  _FixedCol.recurring => m.recurringCents,
  _FixedCol.installment => m.installmentCents,
  _FixedCol.fixed => m.fixedCents,
  _FixedCol.variable => m.variableCents,
  _FixedCol.total => m.totalCents,
  _FixedCol.ratio => m.fixedRatio,
};

const _colWidths = <double>[96, 120, 120, 120, 120, 120, 96];
final _tableWidth = _colWidths.fold(0.0, (a, b) => a + b);

/// Tooltip de um mês (SPEC §7.3 Fase 12). Sem despesas no mês, a última linha é 'Fixo: –'.
String fixedVariableTooltipText(
  FixedVariableMonth m, {
  required bool hideValues,
}) {
  String money(int cents) => formatMoney(cents, hidden: hideValues);
  final ratio = m.fixedRatio;
  return [
    formatMonthLong(m.month),
    'Recorrentes: ${money(m.recurringCents)}',
    'Parcelas: ${money(m.installmentCents)}',
    'Variável: ${money(m.variableCents)}',
    if (ratio == null) 'Fixo: –' else 'Fixo: ${formatPercent(ratio)} do total',
  ].join('\n');
}

/// Somas do período (rodapé da tabela). Calculadas uma vez na construção, não no build.
class _Totals {
  _Totals(List<FixedVariableMonth> months)
    : recurring = months.fold(0, (s, m) => s + m.recurringCents),
      installment = months.fold(0, (s, m) => s + m.installmentCents),
      variable = months.fold(0, (s, m) => s + m.variableCents),
      hasSpend = months.any((m) => m.totalCents != 0);

  final int recurring;
  final int installment;
  final int variable;
  final bool hasSpend;

  int get fixed => recurring + installment;
  int get total => fixed + variable;
  double? get fixedRatio => total == 0 ? null : fixed / total;
}

/// Fixo × variável por mês (SPEC §7.3 Fase 12). Só Ultra. Recebe os itens prontos de `fixedVariableByMonth`.
class FixedVariableView extends StatefulWidget {
  const FixedVariableView({
    super.key,
    required this.months,
    required this.hideValues,
  });

  final List<FixedVariableMonth> months;
  final bool hideValues;

  @override
  State<FixedVariableView> createState() => _FixedVariableViewState();
}

class _FixedVariableViewState extends State<FixedVariableView> {
  _FixedCol _column = _FixedCol.month;
  bool _ascending = true;
  late _Totals _totals = _Totals(widget.months);
  late List<int> _order = _sortedOrder();

  @override
  void didUpdateWidget(FixedVariableView old) {
    super.didUpdateWidget(old);
    if (!identical(old.months, widget.months)) {
      _totals = _Totals(widget.months);
      _order = _sortedOrder();
    }
  }

  /// Ordem das linhas (índices de `months`). Nulos sempre no fim; empate pela ordem cronológica.
  List<int> _sortedOrder() {
    final months = widget.months;
    final order = [for (var i = 0; i < months.length; i++) i];
    order.sort((a, b) {
      final ka = _keyOf(_column, months[a], a);
      final kb = _keyOf(_column, months[b], b);
      if (ka == null || kb == null) {
        return (ka == null ? 1 : 0) - (kb == null ? 1 : 0);
      }
      final cmp = _ascending ? ka.compareTo(kb) : kb.compareTo(ka);
      return cmp != 0 ? cmp : a.compareTo(b);
    });
    return order;
  }

  /// Coluna nova: mês asc, valor desc. Coluna ativa: inverte. Só em toque no cabeçalho.
  void _sortBy(_FixedCol col) {
    setState(() {
      if (col == _column) {
        _ascending = !_ascending;
      } else {
        _column = col;
        _ascending = col == _FixedCol.month;
      }
      _order = _sortedOrder();
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!_totals.hasSpend) {
      return const EmptyState(
        icon: Icons.pie_chart_outline,
        message: 'Sem gastos no período com estes filtros.',
      );
    }
    final c = context.colors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          height: _chartHeight,
          child: _FixedVariableChart(
            months: widget.months,
            hideValues: widget.hideValues,
          ),
        ),
        const SizedBox(height: AppSpace.sm),
        const _Legend(),
        const SizedBox(height: AppSpace.sm),
        Text(
          'Fixo = lançamentos de recorrências e parcelas. Variável = o resto.',
          style: Theme.of(
            context,
          ).textTheme.bodySmall?.copyWith(color: c.textSecondary),
        ),
        const SizedBox(height: AppSpace.md),
        Expanded(
          child: _FixedVariableTable(
            months: widget.months,
            order: _order,
            totals: _totals,
            hideValues: widget.hideValues,
            column: _column,
            ascending: _ascending,
            onSort: _sortBy,
          ),
        ),
      ],
    );
  }
}

class _FixedVariableChart extends StatelessWidget {
  const _FixedVariableChart({required this.months, required this.hideValues});

  final List<FixedVariableMonth> months;
  final bool hideValues;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final labelStyle = TextStyle(fontSize: 11, color: c.textSecondary);
    final labelEvery = months.length > 12 ? _xLabelEvery : 1;
    return BarChart(
      BarChartData(
        barGroups: [
          for (var i = 0; i < months.length; i++) _group(i, months[i], c),
        ],
        barTouchData: BarTouchData(
          touchTooltipData: BarTouchTooltipData(
            getTooltipColor: (_) => c.surface,
            tooltipBorder: BorderSide(color: c.border),
            getTooltipItem: (group, groupIndex, rod, rodIndex) =>
                BarTooltipItem(
                  fixedVariableTooltipText(
                    months[groupIndex],
                    hideValues: hideValues,
                  ),
                  TextStyle(color: c.textPrimary, fontSize: 12),
                ),
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
              getTitlesWidget: (v, meta) {
                final i = v.round();
                if (i % labelEvery != 0) {
                  return const SizedBox.shrink();
                }
                return Text(formatMonth(months[i].month), style: labelStyle);
              },
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
    );
  }
}

/// Uma barra empilhada por mês: recorrentes, parcelas e variável (reais, eixo do gráfico).
BarChartGroupData _group(int i, FixedVariableMonth m, AppColors c) {
  final recurring = m.recurringCents / 100;
  final fixed = recurring + m.installmentCents / 100;
  final total = fixed + m.variableCents / 100;
  return BarChartGroupData(
    x: i,
    barRods: [
      BarChartRodData(
        toY: total,
        width: 16,
        color: c.chartBar,
        rodStackItems: [
          BarChartRodStackItem(0, recurring, c.primary),
          BarChartRodStackItem(recurring, fixed, c.warning),
          BarChartRodStackItem(
            fixed,
            total,
            c.chartBar.withValues(alpha: 0.35),
          ),
        ],
      ),
    ],
  );
}

class _Legend extends StatelessWidget {
  const _Legend();

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Wrap(
      spacing: AppSpace.lg,
      runSpacing: AppSpace.xs,
      children: [
        _LegendItem(color: c.primary, label: 'Recorrentes'),
        _LegendItem(color: c.warning, label: 'Parcelas'),
        _LegendItem(
          color: c.chartBar.withValues(alpha: 0.35),
          label: 'Variável',
        ),
      ],
    );
  }
}

class _LegendItem extends StatelessWidget {
  const _LegendItem({required this.color, required this.label});

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            color: color,
            borderRadius: AppRadius.chipBorder,
          ),
        ),
        const SizedBox(width: AppSpace.xs),
        Text(
          label,
          style: TextStyle(fontSize: 12, color: context.colors.textSecondary),
        ),
      ],
    );
  }
}

/// Tabela com cabeçalho e rodapé fixos; o miolo rola na vertical e a tabela inteira na horizontal.
class _FixedVariableTable extends StatelessWidget {
  const _FixedVariableTable({
    required this.months,
    required this.order,
    required this.totals,
    required this.hideValues,
    required this.column,
    required this.ascending,
    required this.onSort,
  });

  final List<FixedVariableMonth> months;

  /// Índices de `months` na ordem exibida.
  final List<int> order;
  final _Totals totals;
  final bool hideValues;
  final _FixedCol column;
  final bool ascending;
  final ValueChanged<_FixedCol> onSort;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: SizedBox(
          width: math.max(constraints.maxWidth, _tableWidth),
          child: Column(
            children: [
              Container(
                height: _headerHeight,
                decoration: BoxDecoration(
                  border: Border(bottom: BorderSide(color: c.border)),
                ),
                child: Row(
                  children: [
                    for (final col in _FixedCol.values)
                      SizedBox(
                        width: _colWidths[col.index],
                        child: SortableHeaderLabel(
                          label: _headerOf(col),
                          active: column == col,
                          ascending: ascending,
                          onTap: () => onSort(col),
                          alignEnd: col != _FixedCol.month,
                        ),
                      ),
                  ],
                ),
              ),
              Expanded(
                child: ListView.builder(
                  itemExtent: _rowExtent,
                  itemCount: order.length,
                  itemBuilder: (context, i) {
                    final m = months[order[i]];
                    return _TableRow(
                      cells: [
                        formatMonth(m.month),
                        formatMoney(m.recurringCents, hidden: hideValues),
                        formatMoney(m.installmentCents, hidden: hideValues),
                        formatMoney(m.fixedCents, hidden: hideValues),
                        formatMoney(m.variableCents, hidden: hideValues),
                        formatMoney(m.totalCents, hidden: hideValues),
                        _ratioText(m.fixedRatio),
                      ],
                    );
                  },
                ),
              ),
              Container(
                height: _headerHeight,
                decoration: BoxDecoration(
                  border: Border(top: BorderSide(color: c.border)),
                ),
                child: _TableRow(
                  strong: true,
                  cells: [
                    'Total',
                    formatMoney(totals.recurring, hidden: hideValues),
                    formatMoney(totals.installment, hidden: hideValues),
                    formatMoney(totals.fixed, hidden: hideValues),
                    formatMoney(totals.variable, hidden: hideValues),
                    formatMoney(totals.total, hidden: hideValues),
                    _ratioText(totals.fixedRatio),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

String _ratioText(double? ratio) => ratio == null ? '–' : formatPercent(ratio);

class _TableRow extends StatelessWidget {
  const _TableRow({required this.cells, this.strong = false});

  final List<String> cells;
  final bool strong;

  @override
  Widget build(BuildContext context) {
    final style = AppText.tabular(
      TextStyle(
        fontSize: 13,
        color: context.colors.textPrimary,
        fontWeight: strong ? FontWeight.w600 : FontWeight.w400,
      ),
    );
    return Row(
      children: [
        for (var i = 0; i < cells.length; i++)
          SizedBox(
            width: _colWidths[i],
            child: Align(
              alignment: i == 0 ? Alignment.centerLeft : Alignment.centerRight,
              child: Text(cells[i], style: style),
            ),
          ),
      ],
    );
  }
}
