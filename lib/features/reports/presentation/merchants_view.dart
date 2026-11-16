import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/utils/text_normalize.dart';
import '../../../core/widgets/widgets.dart';
import '../../categories/domain/category_tree.dart';
import '../domain/merchant_report.dart';
import '../domain/report_filter.dart';

/// Colunas ordenáveis. Texto (estabelecimento, categoria) começa asc; valor começa desc.
enum _Col {
  label,
  total,
  count,
  average,
  lastDate,
  category;

  bool get isText => this == label || this == category;
  bool get isUltraOnly =>
      this == average || this == lastDate || this == category;
}

typedef _Column = ({_Col col, String title, double? width, bool end});

/// Ordem das colunas. Simples usa as três primeiras (`take(3)`).
const _columns = <_Column>[
  (col: _Col.label, title: 'Estabelecimento', width: null, end: false),
  (col: _Col.total, title: 'Total', width: 120.0, end: true),
  (col: _Col.count, title: 'Compras', width: 80.0, end: true),
  (col: _Col.average, title: 'Ticket médio', width: 120.0, end: true),
  (col: _Col.lastDate, title: 'Última compra', width: 112.0, end: false),
  (col: _Col.category, title: 'Categoria', width: 160.0, end: false),
];

const _kUltraMinWidth = 820.0;
const _kHeaderHeight = 36.0;
const _kFooterHeight = 32.0;
const _kFirstCount = 50;

/// Top estabelecimentos. Recebe a lista pronta do domínio; ordenar por cabeçalho só reordena essa lista.
class MerchantsView extends StatefulWidget {
  const MerchantsView({
    super.key,
    required this.merchants,
    required this.tree,
    required this.ultra,
  });

  final List<MerchantTotal> merchants;
  final CategoryTree tree;
  final bool ultra;

  @override
  State<MerchantsView> createState() => _MerchantsViewState();
}

class _MerchantsViewState extends State<MerchantsView> {
  final _hScroll = ScrollController();
  _Col _col = _Col.total;
  bool _asc = false;
  bool _showAll = false;
  late List<MerchantTotal> _rows = _sortedCopy(
    widget.merchants,
    _col,
    _asc,
    widget.tree,
  );

  @override
  void dispose() {
    _hScroll.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(MerchantsView old) {
    super.didUpdateWidget(old);
    // Coluna só do Ultra sai da tabela ao virar Simples: volta para Total.
    if (!widget.ultra && _col.isUltraOnly) {
      _col = _Col.total;
      _asc = false;
    }
    if (old.merchants != widget.merchants ||
        old.tree != widget.tree ||
        old.ultra != widget.ultra) {
      _rows = _sortedCopy(widget.merchants, _col, _asc, widget.tree);
    }
  }

  void _sortBy(_Col col) {
    setState(() {
      _asc = col == _col ? !_asc : col.isText;
      _col = col;
      _rows = _sortedCopy(widget.merchants, _col, _asc, widget.tree);
    });
  }

  @override
  Widget build(BuildContext context) {
    if (widget.merchants.isEmpty) {
      return const EmptyState(
        icon: Icons.storefront_outlined,
        message: 'Sem compras no período com estes filtros.',
      );
    }
    final ultra = widget.ultra;
    final columns = ultra ? _columns : _columns.take(3).toList();
    final extent = ultra ? 36.0 : 44.0;
    final shown = _showAll
        ? _rows.length
        : math.min(_kFirstCount, _rows.length);
    return LayoutBuilder(
      builder: (context, constraints) => Scrollbar(
        controller: _hScroll,
        child: SingleChildScrollView(
          controller: _hScroll,
          scrollDirection: Axis.horizontal,
          child: SizedBox(
            width: math.max(
              constraints.maxWidth,
              ultra ? _kUltraMinWidth : 0.0,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _header(columns),
                Expanded(
                  child: ListView.builder(
                    itemExtent: extent,
                    itemCount: shown + (shown < _rows.length ? 1 : 0),
                    itemBuilder: (context, i) {
                      if (i == shown) {
                        return Center(
                          child: TextButton(
                            key: const Key('merchants-show-all'),
                            onPressed: () => setState(() => _showAll = true),
                            child: Text('Mostrar todos (${_rows.length})'),
                          ),
                        );
                      }
                      return _MerchantRow(
                        merchant: _rows[i],
                        columns: columns,
                        ultra: ultra,
                        tree: widget.tree,
                      );
                    },
                  ),
                ),
                _footer(widget.merchants.length),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _header(List<_Column> columns) {
    final c = context.colors;
    return Container(
      height: _kHeaderHeight,
      padding: const EdgeInsets.symmetric(horizontal: AppSpace.md),
      decoration: BoxDecoration(
        color: c.surface,
        border: Border(bottom: BorderSide(color: c.border)),
      ),
      child: Row(
        children: [
          for (final col in columns)
            _cell(
              col.width,
              col.end,
              SortableHeaderLabel(
                label: col.title,
                active: _col == col.col,
                ascending: _asc,
                alignEnd: col.end,
                onTap: () => _sortBy(col.col),
              ),
            ),
        ],
      ),
    );
  }

  Widget _footer(int n) {
    final c = context.colors;
    return Container(
      height: _kFooterHeight,
      alignment: Alignment.centerLeft,
      padding: const EdgeInsets.symmetric(horizontal: AppSpace.md),
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: c.border)),
      ),
      child: Text(
        '$n estabelecimento${n == 1 ? '' : 's'}',
        style: Theme.of(
          context,
        ).textTheme.bodySmall?.copyWith(color: c.textSecondary),
      ),
    );
  }
}

/// Largura null = coluna que ocupa o resto (estabelecimento).
Widget _cell(double? width, bool end, Widget child) {
  final aligned = Align(
    alignment: end ? Alignment.centerRight : Alignment.centerLeft,
    child: child,
  );
  return width == null
      ? Expanded(child: aligned)
      : SizedBox(width: width, child: aligned);
}

class _MerchantRow extends StatelessWidget {
  const _MerchantRow({
    required this.merchant,
    required this.columns,
    required this.ultra,
    required this.tree,
  });

  final MerchantTotal merchant;
  final List<_Column> columns;
  final bool ultra;
  final CategoryTree tree;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final textTheme = Theme.of(context).textTheme;
    final body = (textTheme.bodyMedium ?? const TextStyle()).copyWith(
      color: c.textPrimary,
    );
    final small = (textTheme.bodySmall ?? const TextStyle()).copyWith(
      color: c.textSecondary,
    );
    return Padding(
      key: ValueKey('merchant-row-${merchant.key}'),
      padding: const EdgeInsets.symmetric(horizontal: AppSpace.md),
      child: Row(
        children: [
          for (final col in columns)
            _cell(col.width, col.end, _content(col.col, body, small)),
        ],
      ),
    );
  }

  Widget _content(_Col col, TextStyle body, TextStyle small) {
    final m = merchant;
    return switch (col) {
      _Col.label => Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            m.label,
            style: body,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          // Apoio só no Ultra e só quando a chave difere do texto exibido.
          if (ultra && m.key != foldText(m.label))
            Text(
              m.key,
              style: small.copyWith(fontSize: 11),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
        ],
      ),
      _Col.total => MoneyText(m.totalCents, style: body),
      _Col.count => Text('${m.purchaseCount}', style: AppText.tabular(body)),
      _Col.average => MoneyText(m.averageCents, style: body),
      _Col.lastDate => Text(formatDate(m.lastDate), style: body),
      _Col.category => Text(
        reportCategoryLabel(m.categoryId, tree),
        style: small,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
    };
  }
}

/// Cópia ordenada. Empate na coluna mantém a ordem recebida (a do domínio).
List<MerchantTotal> _sortedCopy(
  List<MerchantTotal> list,
  _Col col,
  bool asc,
  CategoryTree tree,
) {
  final rank = {for (var i = 0; i < list.length; i++) list[i]: i};
  return [...list]..sort((a, b) {
    final c = _compare(a, b, col, tree);
    final r = asc ? c : -c;
    return r != 0 ? r : rank[a]!.compareTo(rank[b]!);
  });
}

int _compare(MerchantTotal a, MerchantTotal b, _Col col, CategoryTree tree) =>
    switch (col) {
      _Col.label => foldText(a.label).compareTo(foldText(b.label)),
      _Col.total => a.totalCents.compareTo(b.totalCents),
      _Col.count => a.purchaseCount.compareTo(b.purchaseCount),
      _Col.average => a.averageCents.compareTo(b.averageCents),
      _Col.lastDate => a.lastDate.compareTo(b.lastDate),
      _Col.category => foldText(
        reportCategoryLabel(a.categoryId, tree),
      ).compareTo(foldText(reportCategoryLabel(b.categoryId, tree))),
    };
