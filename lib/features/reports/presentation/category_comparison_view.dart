import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/utils/text_normalize.dart';
import '../../../core/widgets/widgets.dart';
import '../../categories/domain/category_tree.dart';
import '../domain/category_reports.dart';
import '../domain/report_filter.dart';

const _labelMin = 240.0;
const _indent = 24.0;
const _chevronW = 18.0;
const _moneyW = 112.0;
const _pctW = 72.0;
const _headerH = 32.0;
const _rowUltraH = 36.0;
const _rowSimpleH = 44.0;

/// Colunas da tabela. As de valor ordenam desc no 1º clique; a de texto, asc.
enum _Col { label, current, previous, average, delta, changePct, averagePct }

/// Colunas que só existem no Ultra (média e variação vs. média).
const _ultraOnlyCols = {_Col.average, _Col.delta, _Col.averagePct};

/// Linha visível: raiz ou filha (drill-down, só Ultra).
class _Line {
  const _Line(this.row, {this.child = false});

  final CategoryComparisonRow row;
  final bool child;
}

/// Comparativo por categoria (SPEC §7.3 Fase 12). Dados prontos vindos de `categoryComparison`;
/// ordenação e drill-down são estado da view, recalculados só em eventos e quando os dados mudam.
class CategoryComparisonView extends StatefulWidget {
  const CategoryComparisonView({
    super.key,
    required this.data,
    required this.tree,
    required this.ultra,
    required this.flow,
    required this.isCurrentMonth,
    required this.onAverageMonthsChanged,
  });

  final CategoryComparison data;
  final CategoryTree tree;
  final bool ultra;
  final ReportFlow flow;
  final bool isCurrentMonth;
  final ValueChanged<int> onAverageMonthsChanged;

  @override
  State<CategoryComparisonView> createState() => _CategoryComparisonViewState();
}

class _CategoryComparisonViewState extends State<CategoryComparisonView> {
  // Padrão: mês atual desc (mesma ordem do domínio).
  _Col _sort = _Col.current;
  bool _ascending = false;
  final Set<String> _expanded = {};
  List<_Line> _lines = const [];

  @override
  void initState() {
    super.initState();
    _lines = _buildLines();
  }

  @override
  void didUpdateWidget(CategoryComparisonView old) {
    super.didUpdateWidget(old);
    var rebuild =
        old.data != widget.data ||
        old.tree != widget.tree ||
        old.ultra != widget.ultra;
    // Colunas só do Ultra somem no Simples: volta para o mês atual desc.
    if (!widget.ultra && _ultraOnlyCols.contains(_sort)) {
      _sort = _Col.current;
      _ascending = false;
      rebuild = true;
    }
    if (rebuild) {
      _lines = _buildLines();
    }
  }

  List<_Line> _buildLines() {
    final lines = <_Line>[];
    for (final root in _sorted(widget.data.rows, child: false)) {
      lines.add(_Line(root));
      if (widget.ultra && _expanded.contains(root.categoryId)) {
        for (final child in _sorted(root.children, child: true)) {
          lines.add(_Line(child, child: true));
        }
      }
    }
    return lines;
  }

  List<CategoryComparisonRow> _sorted(
    List<CategoryComparisonRow> rows, {
    required bool child,
  }) {
    // Empate na ordem escolhida cai na ordem do domínio (índice original).
    final order = {for (var i = 0; i < rows.length; i++) rows[i]: i};
    return [...rows]..sort((a, b) {
      if (a.isDirect != b.isDirect) {
        return a.isDirect ? 1 : -1;
      }
      final aNull = a.categoryId == null;
      if (aNull != (b.categoryId == null)) {
        return aNull ? 1 : -1;
      }
      final c = _compare(a, b, child: child);
      return c != 0 ? c : order[a]! - order[b]!;
    });
  }

  int _compare(
    CategoryComparisonRow a,
    CategoryComparisonRow b, {
    required bool child,
  }) {
    final asc = _ascending;
    if (_sort == _Col.label) {
      final c = foldText(
        _label(a, child: child),
      ).compareTo(foldText(_label(b, child: child)));
      return asc ? c : -c;
    }
    final x = _value(a, _sort);
    final y = _value(b, _sort);
    if (x == null || y == null) {
      // Variação sem base (ratio null) vai para o fim em qualquer direção.
      return x == y ? 0 : (x == null ? 1 : -1);
    }
    final c = x.compareTo(y);
    return asc ? c : -c;
  }

  String _label(CategoryComparisonRow r, {required bool child}) {
    final id = r.categoryId;
    if (r.isDirect) {
      return '(sem subcategoria)';
    }
    if (id == null) {
      return 'Sem categoria';
    }
    if (child) {
      return widget.tree.byId(id)?.name ?? 'Categoria removida';
    }
    return reportCategoryLabel(id, widget.tree);
  }

  void _sortBy(_Col col) {
    setState(() {
      _ascending = _sort == col ? !_ascending : col == _Col.label;
      _sort = col;
      _lines = _buildLines();
    });
  }

  void _toggle(String id) {
    setState(() {
      if (!_expanded.remove(id)) {
        _expanded.add(id);
      }
      _lines = _buildLines();
    });
  }

  List<_Col> get _columns => widget.ultra
      ? const [
          _Col.current,
          _Col.previous,
          _Col.average,
          _Col.delta,
          _Col.changePct,
          _Col.averagePct,
        ]
      : const [_Col.current, _Col.previous, _Col.changePct];

  double get _rowH => widget.ultra ? _rowUltraH : _rowSimpleH;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final data = widget.data;
    return Padding(
      padding: const EdgeInsets.all(AppSpace.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: AppSpace.md,
            runSpacing: AppSpace.sm,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text(
                'Mês de referência: ${formatMonthLong(data.month)}'
                '${widget.isCurrentMonth ? ' (até hoje)' : ''}',
                style: TextStyle(fontSize: 13, color: c.textSecondary),
              ),
              if (widget.ultra)
                SegmentedButton<int>(
                  key: const Key('comparison-average'),
                  showSelectedIcon: false,
                  segments: const [
                    ButtonSegment(value: 3, label: Text('Média 3 meses')),
                    ButtonSegment(value: 6, label: Text('Média 6 meses')),
                  ],
                  selected: {data.averageMonths},
                  onSelectionChanged: (s) =>
                      widget.onAverageMonthsChanged(s.first),
                ),
            ],
          ),
          const SizedBox(height: AppSpace.md),
          Expanded(
            child: data.rows.isEmpty
                ? const EmptyState(
                    icon: Icons.category_outlined,
                    message: 'Sem lançamentos no período com estes filtros.',
                  )
                : _table(),
          ),
        ],
      ),
    );
  }

  Widget _table() {
    final numericW = _columns.fold(0.0, (w, col) => w + _widthOf(col));
    return LayoutBuilder(
      builder: (context, constraints) {
        // Rótulo ocupa o resto da largura; abaixo de 240 + colunas, a tabela rola na horizontal.
        final room = constraints.maxWidth - numericW;
        final labelW = room > _labelMin ? room : _labelMin;
        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: SizedBox(
            width: labelW + numericW,
            height: constraints.maxHeight,
            child: Column(
              children: [
                _row(
                  height: _headerH,
                  labelW: labelW,
                  label: SortableHeaderLabel(
                    label: 'Categoria',
                    active: _sort == _Col.label,
                    ascending: _ascending,
                    onTap: () => _sortBy(_Col.label),
                  ),
                  cells: [
                    for (final col in _columns)
                      (
                        _widthOf(col),
                        SortableHeaderLabel(
                          label: _headerText(col),
                          active: _sort == col,
                          ascending: _ascending,
                          onTap: () => _sortBy(col),
                          alignEnd: true,
                        ),
                      ),
                  ],
                ),
                Expanded(
                  child: ListView.builder(
                    itemCount: _lines.length,
                    itemBuilder: (_, i) => _lineRow(_lines[i], labelW),
                  ),
                ),
                Divider(height: 1, color: context.colors.border),
                _row(
                  height: _rowH,
                  labelW: labelW,
                  label: Text(
                    'Total',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: context.colors.textPrimary,
                    ),
                  ),
                  cells: [
                    for (final col in _columns)
                      (
                        _widthOf(col),
                        _cell(col, widget.data.total, bold: true),
                      ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _lineRow(_Line line, double labelW) {
    final r = line.row;
    final toggleId = widget.ultra && !line.child && r.children.isNotEmpty
        ? r.categoryId
        : null;
    return _row(
      height: _rowH,
      labelW: labelW,
      label: _labelCell(r, child: line.child, toggleId: toggleId),
      cells: [for (final col in _columns) (_widthOf(col), _cell(col, r))],
    );
  }

  Widget _labelCell(
    CategoryComparisonRow r, {
    required bool child,
    String? toggleId,
  }) {
    final c = context.colors;
    final muted = r.isDirect || r.categoryId == null;
    final chevron = toggleId == null
        ? const SizedBox(width: _chevronW)
        : _chevron(toggleId);
    return Row(
      children: [
        SizedBox(width: child ? _indent : 0),
        chevron,
        const SizedBox(width: AppSpace.xs),
        Expanded(
          child: Text(
            _label(r, child: child),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 13,
              color: muted ? c.textSecondary : c.textPrimary,
            ),
          ),
        ),
      ],
    );
  }

  Widget _chevron(String id) {
    final open = _expanded.contains(id);
    return InkWell(
      key: Key('comparison-expand-$id'),
      borderRadius: AppRadius.chipBorder,
      onTap: () => _toggle(id),
      child: AnimatedRotation(
        turns: open ? 0.25 : 0,
        duration: AppMotion.fast,
        child: Icon(
          Icons.chevron_right,
          size: _chevronW,
          color: context.colors.textSecondary,
        ),
      ),
    );
  }

  Widget _cell(_Col col, CategoryComparisonRow r, {bool bold = false}) {
    final style = TextStyle(
      fontSize: 13,
      fontWeight: bold ? FontWeight.w600 : FontWeight.w400,
      color: context.colors.textPrimary,
    );
    final higher = widget.flow == ReportFlow.income;
    return switch (col) {
      _Col.current => MoneyText(r.currentCents, style: style),
      _Col.previous => MoneyText(r.previousCents, style: style),
      _Col.average => MoneyText(r.averageCents, style: style),
      _Col.delta => MoneyText(r.deltaCents, style: style, signed: true),
      _Col.changePct => DeltaBadge(
        ratio: r.changeRatio,
        higherIsBetter: higher,
      ),
      _Col.averagePct => DeltaBadge(
        ratio: r.averageChangeRatio,
        higherIsBetter: higher,
      ),
      _Col.label => const SizedBox.shrink(),
    };
  }

  Widget _row({
    required double height,
    required double labelW,
    required Widget label,
    required List<(double, Widget)> cells,
  }) {
    return SizedBox(
      height: height,
      child: Row(
        children: [
          SizedBox(width: labelW, child: label),
          for (final (w, cell) in cells)
            SizedBox(
              width: w,
              child: Align(alignment: Alignment.centerRight, child: cell),
            ),
        ],
      ),
    );
  }

  String _headerText(_Col col) => switch (col) {
    _Col.current => formatMonth(widget.data.month),
    _Col.previous => formatMonth(widget.data.month.prev()),
    _Col.average => 'Média ${widget.data.averageMonths}m',
    _Col.delta => 'Variação',
    _Col.changePct => '%',
    _Col.averagePct => 'Vs. média',
    _Col.label => 'Categoria',
  };

  double _widthOf(_Col col) => switch (col) {
    _Col.changePct || _Col.averagePct => _pctW,
    _ => _moneyW,
  };
}

num? _value(CategoryComparisonRow r, _Col col) => switch (col) {
  _Col.current => r.currentCents,
  _Col.previous => r.previousCents,
  _Col.average => r.averageCents,
  _Col.delta => r.deltaCents,
  _Col.changePct => r.changeRatio,
  _Col.averagePct => r.averageChangeRatio,
  _Col.label => null,
};
