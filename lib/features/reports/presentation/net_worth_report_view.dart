import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/layout.dart';
import '../../net_worth/domain/net_worth.dart';
import '../../net_worth/presentation/net_worth_chart.dart';

const _apoio =
    'Histórico disponível: últimos 24 meses. Filtros de conta, categoria, '
    'tag, tipo e provisionados não se aplicam ao patrimônio. '
    'A pagar e dívida de cartão aparecem negativos aqui e positivos no CSV.';

/// Componentes do patrimônio zerados em todos os meses: não há o que plotar.
bool _allZero(List<NetWorthPoint> points) => points.every(
  (p) =>
      p.accountsCents == 0 &&
      p.assetsCents == 0 &&
      p.receivableCents == 0 &&
      p.payableCents == 0 &&
      p.cardDebtCents == 0,
);

/// Colunas da tabela mês a mês. A primeira é a única de texto (ordena asc ao ser escolhida).
enum _Col { month, accounts, assets, receivable, payable, card, net, variation }

String _colLabel(_Col c) => switch (c) {
  _Col.month => 'Mês',
  _Col.accounts => 'Contas',
  _Col.assets => 'Ativos',
  _Col.receivable => 'A receber',
  _Col.payable => 'A pagar',
  _Col.card => 'Dívida de cartão',
  _Col.net => 'Líquido',
  _Col.variation => 'Variação',
};

/// Linha da tabela: ponto + variação vs. ponto anterior (null no primeiro).
typedef _Row = ({NetWorthPoint p, int? variation});

/// Valor da coluna para ordenar. Passivos entram com o sinal exibido (negativo).
int? _key(_Col col, _Row r) => switch (col) {
  _Col.month => r.p.month.year * 12 + r.p.month.month,
  _Col.accounts => r.p.accountsCents,
  _Col.assets => r.p.assetsCents,
  _Col.receivable => r.p.receivableCents,
  _Col.payable => -r.p.payableCents,
  _Col.card => -r.p.cardDebtCents,
  _Col.net => r.p.netCents,
  _Col.variation => r.variation,
};

/// Evolução do patrimônio (SPEC §7.3 Fase 12): gráfico da série, apoio e tabela mês a mês.
/// Recebe a série já recortada; [hideValues] mascara todos os valores.
class NetWorthReportView extends StatefulWidget {
  const NetWorthReportView({
    super.key,
    required this.points,
    required this.hideValues,
  });

  final List<NetWorthPoint> points;
  final bool hideValues;

  @override
  State<NetWorthReportView> createState() => _NetWorthReportViewState();
}

class _NetWorthReportViewState extends State<NetWorthReportView> {
  _Col _sort = _Col.month;
  bool _ascending = true;

  void _onSort(_Col col) {
    setState(() {
      if (_sort == col) {
        _ascending = !_ascending;
      } else {
        _sort = col;
        _ascending = col == _Col.month;
      }
    });
  }

  List<_Row> _sortedRows() {
    final points = widget.points;
    final rows = <_Row>[
      for (var i = 0; i < points.length; i++)
        (
          p: points[i],
          variation: i == 0
              ? null
              : points[i].netCents - points[i - 1].netCents,
        ),
    ];
    rows.sort((a, b) {
      final ka = _key(_sort, a);
      final kb = _key(_sort, b);
      // Variação ausente (primeiro mês) fica no fim, seja qual for a direção.
      if (ka == null || kb == null) {
        return (ka == null ? 1 : 0) - (kb == null ? 1 : 0);
      }
      final c = ka.compareTo(kb);
      if (c != 0) {
        return _ascending ? c : -c;
      }
      return a.p.month.compareTo(b.p.month);
    });
    return rows;
  }

  @override
  Widget build(BuildContext context) {
    if (_allZero(widget.points)) {
      return const EmptyState(
        icon: Icons.account_balance_outlined,
        message: 'Sem histórico de patrimônio no período.',
      );
    }
    final note = Theme.of(
      context,
    ).textTheme.bodySmall?.copyWith(color: context.colors.textSecondary);
    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpace.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SectionCard(
            title: 'Evolução',
            child: NetWorthChart(
              points: widget.points,
              hideValues: widget.hideValues,
            ),
          ),
          const SizedBox(height: AppSpace.sm),
          Text(_apoio, style: note),
          const SizedBox(height: AppSpace.lg),
          SectionCard(title: 'Mês a mês', child: _table()),
        ],
      ),
    );
  }

  Widget _table() {
    final hidden = widget.hideValues;
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(
        sortColumnIndex: _sort.index,
        sortAscending: _ascending,
        columns: [
          for (final col in _Col.values)
            DataColumn(
              label: Text(_colLabel(col)),
              numeric: col != _Col.month,
              onSort: (_, _) => _onSort(col),
            ),
        ],
        rows: [
          for (final r in _sortedRows())
            DataRow(
              cells: [
                DataCell(Text(formatMonth(r.p.month))),
                DataCell(_Amount(r.p.accountsCents, hidden: hidden)),
                DataCell(_Amount(r.p.assetsCents, hidden: hidden)),
                DataCell(_Amount(r.p.receivableCents, hidden: hidden)),
                DataCell(_Amount(-r.p.payableCents, hidden: hidden)),
                DataCell(_Amount(-r.p.cardDebtCents, hidden: hidden)),
                DataCell(_Amount(r.p.netCents, hidden: hidden)),
                DataCell(
                  r.variation == null
                      ? const Text('–')
                      : _Amount(
                          r.variation!,
                          hidden: hidden,
                          signed: true,
                          colorBySign: true,
                        ),
                ),
              ],
            ),
        ],
      ),
    );
  }
}

/// Valor em centavos com `hideValues` do caller (MoneyText lê as settings, não o parâmetro).
class _Amount extends StatelessWidget {
  const _Amount(
    this.cents, {
    required this.hidden,
    this.signed = false,
    this.colorBySign = false,
  });

  final int cents;
  final bool hidden;
  final bool signed;
  final bool colorBySign;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final color = !colorBySign || cents == 0
        ? null
        : cents > 0
        ? c.success
        : c.danger;
    return Text(
      formatMoney(cents, hidden: hidden, signed: signed),
      style: AppText.tabular(TextStyle(color: color)),
    );
  }
}
