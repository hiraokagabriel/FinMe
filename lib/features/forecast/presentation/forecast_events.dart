import 'package:flutter/material.dart';

import '../../../core/models/year_month.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/widgets.dart';
import '../../accounts/domain/account.dart';
import '../domain/forecast.dart';

/// Nome da conta do evento, ou '—' para evento só consolidado.
String accountNameOf(Map<String, Account> accounts, String? accountId) =>
    accounts[accountId]?.name ?? '—';

String _kindLabel(ForecastEventKind kind) => switch (kind) {
  ForecastEventKind.income => 'Receita',
  ForecastEventKind.expense => 'Despesa',
  ForecastEventKind.boleto => 'Boleto',
  ForecastEventKind.invoice => 'Fatura',
  ForecastEventKind.transfer => 'Transferência',
};

IconData _kindIcon(ForecastEventKind kind) => switch (kind) {
  ForecastEventKind.income => Icons.arrow_downward,
  ForecastEventKind.expense => Icons.arrow_upward,
  ForecastEventKind.boleto => Icons.receipt_long,
  ForecastEventKind.invoice => Icons.credit_card,
  ForecastEventKind.transfer => Icons.swap_horiz,
};

/// Linha de evento: data, ícone do tipo, descrição, conta e valor com sinal.
class ForecastEventRow extends StatelessWidget {
  const ForecastEventRow({
    super.key,
    required this.event,
    required this.accountName,
  });

  final ForecastEvent event;
  final String accountName;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final textTheme = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpace.xs),
      child: Row(
        children: [
          SizedBox(
            width: 44,
            child: Text(
              formatShortDate(event.date),
              style: textTheme.bodySmall,
            ),
          ),
          Icon(_kindIcon(event.kind), size: 16, color: c.textSecondary),
          const SizedBox(width: AppSpace.sm),
          Expanded(
            child: Text(
              event.description,
              overflow: TextOverflow.ellipsis,
              style: event.isProjected
                  ? textTheme.bodyMedium?.copyWith(fontStyle: FontStyle.italic)
                  : textTheme.bodyMedium,
            ),
          ),
          Flexible(
            child: Text(
              accountName,
              overflow: TextOverflow.ellipsis,
              style: textTheme.bodySmall,
            ),
          ),
          const SizedBox(width: AppSpace.sm),
          if (event.isProjected) ...[
            const PlannedMarker(),
            const SizedBox(width: AppSpace.xs),
          ],
          MoneyText(
            event.amountCents,
            signed: true,
            colorBySign: true,
            style: textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}

/// Eventos do modo Ultra: filtros por conta e tipo, lista agrupada por mês.
/// Estado dos filtros fica aqui; o build calcula as linhas uma vez por mudança.
class ForecastEventsFilter extends StatefulWidget {
  const ForecastEventsFilter({
    super.key,
    required this.events,
    required this.accounts,
  });

  final List<ForecastEvent> events;
  final Map<String, Account> accounts;

  @override
  State<ForecastEventsFilter> createState() => _ForecastEventsFilterState();
}

class _ForecastEventsFilterState extends State<ForecastEventsFilter> {
  static const _listHeight = 420.0;

  String? _accountId;
  final _kinds = {...ForecastEventKind.values};

  @override
  Widget build(BuildContext context) {
    final activeAccounts =
        widget.accounts.values.where((a) => !a.archived).toList()
          ..sort((a, b) => a.name.compareTo(b.name));
    // Conta selecionada que foi arquivada/removida volta para "todas".
    final accountId = activeAccounts.any((a) => a.id == _accountId)
        ? _accountId
        : null;
    final rows = _rows(widget.events, accountId, _kinds);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: AppSpace.sm,
          runSpacing: AppSpace.sm,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            SizedBox(
              width: 220,
              child: DropdownButtonFormField<String?>(
                key: ValueKey(accountId),
                initialValue: accountId,
                isDense: true,
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'Conta'),
                items: [
                  const DropdownMenuItem<String?>(
                    value: null,
                    child: Text('Todas as contas'),
                  ),
                  for (final a in activeAccounts)
                    DropdownMenuItem<String?>(
                      value: a.id,
                      child: Text(a.name, overflow: TextOverflow.ellipsis),
                    ),
                ],
                onChanged: (value) => setState(() => _accountId = value),
              ),
            ),
            for (final kind in ForecastEventKind.values)
              FilterChip(
                label: Text(_kindLabel(kind)),
                selected: _kinds.contains(kind),
                onSelected: (on) => setState(() {
                  if (on) {
                    _kinds.add(kind);
                  } else {
                    _kinds.remove(kind);
                  }
                }),
              ),
          ],
        ),
        const SizedBox(height: AppSpace.md),
        SizedBox(
          height: _listHeight,
          child: rows.isEmpty
              ? const EmptyState(
                  icon: Icons.event_busy,
                  message: 'Nenhum evento com esses filtros',
                )
              : ListView.builder(
                  itemCount: rows.length,
                  itemBuilder: (context, i) => switch (rows[i]) {
                    final YearMonth m => Padding(
                      padding: const EdgeInsets.only(
                        top: AppSpace.sm,
                        bottom: AppSpace.xs,
                      ),
                      child: Text(
                        formatMonthLong(m),
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    ),
                    final ForecastEvent e => ForecastEventRow(
                      event: e,
                      accountName: accountNameOf(widget.accounts, e.accountId),
                    ),
                    _ => const SizedBox.shrink(),
                  },
                ),
        ),
      ],
    );
  }
}

/// Intercala cabeçalhos de [YearMonth] e eventos já filtrados (eventos vêm ordenados por data).
List<Object> _rows(
  List<ForecastEvent> events,
  String? accountId,
  Set<ForecastEventKind> kinds,
) {
  final rows = <Object>[];
  YearMonth? current;
  for (final e in events) {
    if (accountId != null && e.accountId != accountId) {
      continue;
    }
    if (!kinds.contains(e.kind)) {
      continue;
    }
    final month = YearMonth.fromDate(e.date);
    if (month != current) {
      current = month;
      rows.add(month);
    }
    rows.add(e);
  }
  return rows;
}
