import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/widgets.dart';
import '../../categories/domain/category_tree.dart';
import '../domain/category_pivot.dart';
import '../domain/report_filter.dart';

const _labelW = 240.0;
const _indent = 24.0;
const _chevronW = 18.0;
const _monthW = 96.0;
const _totalW = 112.0;
const _headerH = 36.0;
const _rowH = 32.0;

/// Linha visível: raiz ou filha (drill-down). Rótulo calculado ao reconstruir, não no build.
class _Line {
  const _Line(this.row, {required this.label, this.child = false});

  final PivotRow row;
  final String label;
  final bool child;
}

/// Pivot categoria × mês (SPEC §7.3 Fase 12). Coluna de rótulos fixa; valores rolam na horizontal.
/// Ordenação e drill-down são estado da view: recalculados só em evento e em didUpdateWidget.
class PivotView extends StatefulWidget {
  const PivotView({super.key, required this.pivot, required this.tree});

  final CategoryPivot pivot;
  final CategoryTree tree;

  @override
  State<PivotView> createState() => _PivotViewState();
}

class _PivotViewState extends State<PivotView> {
  // Padrão: total desc (mesma ordem do domínio).
  PivotSortKey _key = PivotSortKey.total;
  int _monthIndex = 0;
  bool _ascending = false;
  final Set<String> _expanded = {};
  List<_Line> _lines = const [];

  final _hScroll = ScrollController();
  // Dois painéis verticais (rótulos e valores) com offset sincronizado.
  final _vLabels = ScrollController();
  final _vCells = ScrollController();

  @override
  void initState() {
    super.initState();
    _rebuild();
    _vLabels.addListener(() => _follow(_vLabels, _vCells));
    _vCells.addListener(() => _follow(_vCells, _vLabels));
  }

  @override
  void dispose() {
    _hScroll.dispose();
    _vLabels.dispose();
    _vCells.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(PivotView old) {
    super.didUpdateWidget(old);
    if (old.pivot != widget.pivot || old.tree != widget.tree) {
      // Coluna de mês de um pivot com menos meses sai de cena: volta para Total.
      if (_key == PivotSortKey.month &&
          _monthIndex >= widget.pivot.months.length) {
        _key = PivotSortKey.total;
        _monthIndex = 0;
        _ascending = false;
      }
      _rebuild();
    }
  }

  void _follow(ScrollController from, ScrollController to) {
    if (from.hasClients && to.hasClients && to.offset != from.offset) {
      to.jumpTo(from.offset);
    }
  }

  /// Ordena o domínio com a escolha atual e achata raízes + filhas abertas.
  void _rebuild() {
    final rows = sortPivotRows(
      widget.pivot.rows,
      key: _key,
      monthIndex: _monthIndex,
      ascending: _ascending,
      tree: widget.tree,
    );
    final lines = <_Line>[];
    for (final root in rows) {
      lines.add(_Line(root, label: _labelOf(root, child: false)));
      final id = root.categoryId;
      if (id != null && _expanded.contains(id)) {
        for (final kid in root.children) {
          lines.add(_Line(kid, label: _labelOf(kid, child: true), child: true));
        }
      }
    }
    _lines = lines;
  }

  String _labelOf(PivotRow r, {required bool child}) {
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

  void _sortBy(PivotSortKey key, {int monthIndex = 0}) {
    final same =
        _key == key && (key != PivotSortKey.month || _monthIndex == monthIndex);
    setState(() {
      // Coluna nova: texto asc, valores desc; coluna ativa: inverte.
      _ascending = same ? !_ascending : key == PivotSortKey.label;
      _key = key;
      _monthIndex = monthIndex;
      _rebuild();
    });
  }

  void _toggle(String id) {
    setState(() {
      if (!_expanded.remove(id)) {
        _expanded.add(id);
      }
      _rebuild();
    });
  }

  @override
  Widget build(BuildContext context) {
    if (widget.pivot.rows.isEmpty) {
      return const EmptyState(
        icon: Icons.grid_on,
        message: 'Sem lançamentos no período com estes filtros.',
      );
    }
    return Padding(
      padding: const EdgeInsets.all(AppSpace.lg),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final cellsW = _monthW * widget.pivot.months.length + _totalW;
          return Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(width: _labelW, child: _labelPane()),
              Expanded(
                child: Scrollbar(
                  controller: _hScroll,
                  child: SingleChildScrollView(
                    controller: _hScroll,
                    scrollDirection: Axis.horizontal,
                    child: SizedBox(
                      width: math.max(constraints.maxWidth - _labelW, cellsW),
                      height: constraints.maxHeight,
                      child: _valuePane(),
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _labelPane() {
    final c = context.colors;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: c.surface,
        border: Border(right: BorderSide(color: c.border)),
      ),
      child: Column(
        children: [
          _bar(
            top: false,
            child: Padding(
              padding: const EdgeInsets.only(left: AppSpace.md),
              child: Align(
                alignment: Alignment.centerLeft,
                child: SortableHeaderLabel(
                  key: const Key('pivot-sort-label'),
                  label: 'Categoria',
                  active: _key == PivotSortKey.label,
                  ascending: _ascending,
                  onTap: () => _sortBy(PivotSortKey.label),
                ),
              ),
            ),
          ),
          Expanded(
            child: ListView.builder(
              controller: _vLabels,
              itemExtent: _rowH,
              itemCount: _lines.length,
              itemBuilder: (_, i) => _labelRow(_lines[i]),
            ),
          ),
          _bar(
            top: true,
            child: Padding(
              padding: const EdgeInsets.only(left: AppSpace.md),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Total',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: c.textPrimary,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _valuePane() {
    final pivot = widget.pivot;
    return Column(
      children: [
        _bar(
          top: false,
          child: Row(
            children: [
              for (var i = 0; i < pivot.months.length; i++)
                _headCell(
                  _monthW,
                  SortableHeaderLabel(
                    key: Key('pivot-sort-$i'),
                    label: formatMonth(pivot.months[i]),
                    active: _key == PivotSortKey.month && _monthIndex == i,
                    ascending: _ascending,
                    alignEnd: true,
                    onTap: () => _sortBy(PivotSortKey.month, monthIndex: i),
                  ),
                ),
              _headCell(
                _totalW,
                SortableHeaderLabel(
                  key: const Key('pivot-sort-total'),
                  label: 'Total',
                  active: _key == PivotSortKey.total,
                  ascending: _ascending,
                  alignEnd: true,
                  onTap: () => _sortBy(PivotSortKey.total),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView.builder(
            controller: _vCells,
            itemExtent: _rowH,
            itemCount: _lines.length,
            itemBuilder: (_, i) => _valueRow(_lines[i]),
          ),
        ),
        _bar(
          top: true,
          child: Row(
            children: [
              for (var i = 0; i < pivot.months.length; i++)
                _valueCell(_monthW, pivot.columnTotals[i], bold: true),
              _valueCell(_totalW, pivot.grandTotalCents, bold: true),
            ],
          ),
        ),
      ],
    );
  }

  /// Faixa de cabeçalho ou rodapé: mesma altura nos dois painéis.
  Widget _bar({required bool top, required Widget child}) {
    final c = context.colors;
    final side = BorderSide(color: c.border);
    return Container(
      height: _headerH,
      decoration: BoxDecoration(
        border: top ? Border(top: side) : Border(bottom: side),
      ),
      child: child,
    );
  }

  Widget _headCell(double w, Widget child) => SizedBox(
    width: w,
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpace.sm),
      child: Align(alignment: Alignment.centerRight, child: child),
    ),
  );

  Widget _labelRow(_Line line) {
    final c = context.colors;
    final r = line.row;
    final id = r.categoryId;
    final expandable = !line.child && r.children.isNotEmpty;
    final muted = r.isDirect || id == null;
    final chevron = expandable && id != null
        ? _chevron(id)
        : const SizedBox(width: _chevronW);
    final key = line.child
        ? 'pivot-child-${id ?? 'none'}${r.isDirect ? '-direct' : ''}'
        : 'pivot-row-${id ?? 'none'}';
    return SizedBox(
      key: Key(key),
      height: _rowH,
      child: Padding(
        padding: const EdgeInsets.only(left: AppSpace.md, right: AppSpace.sm),
        child: Row(
          children: [
            SizedBox(width: line.child ? _indent : 0),
            chevron,
            const SizedBox(width: AppSpace.xs),
            Expanded(
              child: Text(
                line.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: line.child ? 12 : 13,
                  color: muted ? c.textSecondary : c.textPrimary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _chevron(String id) {
    final open = _expanded.contains(id);
    return InkWell(
      key: Key('pivot-expand-$id'),
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

  Widget _valueRow(_Line line) {
    final r = line.row;
    return SizedBox(
      height: _rowH,
      child: Row(
        children: [
          for (final cents in r.cells)
            _valueCell(_monthW, cents, tint: line.child ? null : _tint(cents)),
          _valueCell(_totalW, r.totalCents),
        ],
      ),
    );
  }

  /// Intensidade do fundo da raiz: primary com alpha 0.04 a 0.24, pela maior célula do pivot.
  Color? _tint(int cents) {
    final max = widget.pivot.maxCellCents;
    if (max == 0) {
      return null;
    }
    return context.colors.primary.withValues(alpha: 0.04 + 0.20 * cents / max);
  }

  Widget _valueCell(double w, int cents, {Color? tint, bool bold = false}) {
    final c = context.colors;
    final style = TextStyle(
      fontSize: 13,
      fontWeight: bold ? FontWeight.w600 : FontWeight.w400,
      color: c.textPrimary,
    );
    return Container(
      width: w,
      color: tint,
      padding: const EdgeInsets.symmetric(horizontal: AppSpace.sm),
      alignment: Alignment.centerRight,
      child: cents == 0
          ? Text('–', style: style.copyWith(color: c.textSecondary))
          : FittedBox(
              fit: BoxFit.scaleDown,
              child: MoneyText(cents, style: style),
            ),
    );
  }
}
