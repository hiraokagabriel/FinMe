import 'package:flutter/material.dart';

import '../../../core/theme/app_spacing.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/inputs.dart';
import '../../accounts/domain/account.dart';
import '../../cards/domain/payment_card.dart';
import '../../categories/domain/category_tree.dart';
import '../../categories/domain/transaction_category.dart';
import '../../transactions/domain/tags.dart';
import '../domain/report_filter.dart';

/// Barra de filtros dos relatórios (SPEC §7.3). Simples: só período. Ultra: todos os filtros.
class ReportFilterBar extends StatelessWidget {
  const ReportFilterBar({
    super.key,
    required this.filter,
    required this.range,
    required this.ultra,
    required this.onChanged,
    required this.accounts,
    required this.cards,
    required this.categoryTree,
    required this.tags,
  });

  final ReportFilter filter;
  final ReportRange range;
  final bool ultra;
  final ValueChanged<ReportFilter> onChanged;
  final List<Account> accounts;
  final List<PaymentCard> cards;
  final CategoryTree categoryTree;

  /// Tags como digitadas (`ledger.allTags`); o filtro guarda `tagKey`.
  final List<String> tags;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: AppSpace.sm,
      runSpacing: AppSpace.sm,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        _periodDropdown(),
        if (filter.preset == ReportPeriodPreset.custom) _customMonths(),
        Text(
          '${formatMonth(range.from)} – ${formatMonth(range.to)}',
          key: const Key('report-range'),
          style: Theme.of(context).textTheme.bodySmall,
        ),
        if (ultra) ..._ultraControls(context),
      ],
    );
  }

  Widget _periodDropdown() => SizedBox(
    width: 160,
    // shortcut: initialValue não acompanha mudança externa do preset; hoje só esta barra o altera.
    child: DropdownButtonFormField<ReportPeriodPreset>(
      key: const Key('report-period'),
      initialValue: filter.preset,
      isExpanded: true,
      items: [
        for (final p in ReportPeriodPreset.values)
          DropdownMenuItem(value: p, child: Text(reportPeriodLabel(p))),
      ],
      onChanged: (p) {
        if (p == null) {
          return;
        }
        onChanged(
          p == ReportPeriodPreset.custom
              ? filter.copyWith(
                  preset: p,
                  customFrom: range.from,
                  customTo: range.to,
                )
              : filter.copyWith(preset: p, customFrom: null, customTo: null),
        );
      },
    ),
  );

  Widget _customMonths() => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      const Text('De'),
      MonthSelector(
        key: const Key('report-from'),
        value: range.from,
        onChanged: (m) => onChanged(filter.copyWith(customFrom: m)),
      ),
      const Text('Até'),
      MonthSelector(
        key: const Key('report-to'),
        value: range.to,
        onChanged: (m) => onChanged(filter.copyWith(customTo: m)),
      ),
    ],
  );

  List<Widget> _ultraControls(BuildContext context) {
    final accountCount = filter.accountIds.length + filter.cardIds.length;
    return [
      OutlinedButton(
        key: const Key('report-filter-accounts'),
        onPressed: () => _pickAccounts(context),
        child: Text(
          'Contas e cartões: ${accountCount == 0 ? 'Todos' : accountCount}',
        ),
      ),
      OutlinedButton(
        key: const Key('report-filter-categories'),
        onPressed: () => _pickCategories(context),
        child: Text(
          'Categorias: ${filter.categoryIds.isEmpty ? 'Todas' : filter.categoryIds.length}',
        ),
      ),
      OutlinedButton(
        key: const Key('report-filter-tags'),
        onPressed: tags.isEmpty ? null : () => _pickTags(context),
        child: Text(
          'Tags: ${filter.tagKeys.isEmpty ? 'Todas' : filter.tagKeys.length}',
        ),
      ),
      SegmentedButton<ReportFlow>(
        key: const Key('report-flow'),
        segments: const [
          ButtonSegment(value: ReportFlow.expense, label: Text('Despesas')),
          ButtonSegment(value: ReportFlow.income, label: Text('Receitas')),
        ],
        selected: {filter.flow},
        onSelectionChanged: (s) => onChanged(
          filter.copyWith(flow: s.first, categoryIds: const <String>{}),
        ),
      ),
      FilterChip(
        key: const Key('report-planned'),
        label: const Text('Incluir provisionados'),
        selected: filter.includePlanned,
        onSelected: (v) => onChanged(filter.copyWith(includePlanned: v)),
      ),
      if (filter.hasScopeFilters)
        TextButton(
          key: const Key('report-clear'),
          onPressed: () => onChanged(filter.periodOnly),
          child: const Text('Limpar filtros'),
        ),
    ];
  }

  Future<void> _pickAccounts(BuildContext context) async {
    final accountIds = {for (final a in accounts) a.id};
    final cardIds = {for (final c in cards) c.id};
    final picked = await showReportMultiSelect(
      context,
      title: 'Contas e cartões',
      options: [
        for (final a in accounts)
          (
            id: a.id,
            label: a.archived ? '${a.name} (arquivada)' : a.name,
            indent: false,
          ),
        for (final c in cards)
          (
            id: c.id,
            label: c.archived ? '${c.name} (arquivado)' : c.name,
            indent: false,
          ),
      ],
      selected: {...filter.accountIds, ...filter.cardIds},
    );
    if (picked == null || !context.mounted) {
      return;
    }
    onChanged(
      filter.copyWith(
        accountIds: picked.intersection(accountIds),
        cardIds: picked.intersection(cardIds),
      ),
    );
  }

  Future<void> _pickCategories(BuildContext context) async {
    final kind = filter.flow == ReportFlow.expense
        ? CategoryKind.expense
        : CategoryKind.income;
    final picked = await showReportMultiSelect(
      context,
      title: 'Categorias',
      options: [
        for (final c in categoryTree.options(kind))
          (
            id: c.id,
            label: categoryTree.label(c.id),
            indent: categoryTree.parentOf(c.id) != null,
          ),
      ],
      selected: filter.categoryIds,
    );
    if (picked == null || !context.mounted) {
      return;
    }
    onChanged(filter.copyWith(categoryIds: picked));
  }

  Future<void> _pickTags(BuildContext context) async {
    final picked = await showReportMultiSelect(
      context,
      title: 'Tags',
      options: [for (final t in tags) (id: tagKey(t), label: t, indent: false)],
      selected: filter.tagKeys,
    );
    if (picked == null || !context.mounted) {
      return;
    }
    onChanged(filter.copyWith(tagKeys: picked));
  }
}

/// Diálogo de múltipla escolha. Devolve a seleção ao aplicar, `{}` ao limpar, `null` ao cancelar ou fechar.
Future<Set<String>?> showReportMultiSelect(
  BuildContext context, {
  required String title,
  required List<({String id, String label, bool indent})> options,
  required Set<String> selected,
}) => showDialog<Set<String>>(
  context: context,
  builder: (_) =>
      _MultiSelectDialog(title: title, options: options, selected: selected),
);

class _MultiSelectDialog extends StatefulWidget {
  const _MultiSelectDialog({
    required this.title,
    required this.options,
    required this.selected,
  });

  final String title;
  final List<({String id, String label, bool indent})> options;
  final Set<String> selected;

  @override
  State<_MultiSelectDialog> createState() => _MultiSelectDialogState();
}

class _MultiSelectDialogState extends State<_MultiSelectDialog> {
  late final Set<String> _picked = {...widget.selected};
  bool _closed = false;

  /// Fecha uma só vez: toque duplo não pode fazer pop na página atrás do diálogo.
  void _close([Set<String>? value]) {
    if (_closed) {
      return;
    }
    _closed = true;
    Navigator.of(context).pop(value);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: SizedBox(
        width: 420,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxHeight: 480),
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: widget.options.length,
            itemBuilder: (_, i) {
              final o = widget.options[i];
              return CheckboxListTile(
                dense: true,
                controlAffinity: ListTileControlAffinity.leading,
                contentPadding: EdgeInsets.only(
                  left: o.indent ? AppSpace.xl : AppSpace.sm,
                ),
                title: Text(o.label),
                value: _picked.contains(o.id),
                onChanged: (v) => setState(() {
                  if (v == true) {
                    _picked.add(o.id);
                  } else {
                    _picked.remove(o.id);
                  }
                }),
              );
            },
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => _close(<String>{}),
          child: const Text('Limpar'),
        ),
        TextButton(onPressed: () => _close(), child: const Text('Cancelar')),
        FilledButton(
          onPressed: () => _close(_picked),
          child: const Text('Aplicar'),
        ),
      ],
    );
  }
}
