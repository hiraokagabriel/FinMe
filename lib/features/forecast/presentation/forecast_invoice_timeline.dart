import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/utils/date_utils.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/widgets.dart';
import '../../accounts/domain/account.dart';
import '../domain/invoice_timeline.dart';

const _listHeight = 420.0;

/// Modo Ultra: faturas dos próximos 60 dias agrupadas por dia, com conta e saldo previsto após o vencimento.
class InvoiceTimelineSection extends StatelessWidget {
  const InvoiceTimelineSection({
    super.key,
    required this.items,
    required this.accounts,
  });

  final List<InvoiceDue> items;
  final Map<String, Account> accounts;

  @override
  Widget build(BuildContext context) {
    return SectionCard(
      title: 'Vencimentos (60 dias)',
      child: items.isEmpty
          ? const EmptyState(
              icon: Icons.event_available,
              message: 'Nenhuma fatura a vencer nos próximos 60 dias',
            )
          : _TimelineList(items: items, accounts: accounts),
    );
  }
}

class _TimelineList extends StatelessWidget {
  const _TimelineList({required this.items, required this.accounts});

  final List<InvoiceDue> items;
  final Map<String, Account> accounts;

  @override
  Widget build(BuildContext context) {
    final rows = _rows(items);
    return SizedBox(
      height: _listHeight,
      child: ListView.builder(
        itemCount: rows.length,
        itemBuilder: (context, i) => switch (rows[i]) {
          final DateTime day => Padding(
            padding: const EdgeInsets.only(
              top: AppSpace.sm,
              bottom: AppSpace.xs,
            ),
            child: Text(
              formatShortDate(day),
              style: Theme.of(context).textTheme.titleSmall,
            ),
          ),
          final InvoiceDue due => _InvoiceRow(due: due, accounts: accounts),
          _ => const SizedBox.shrink(),
        },
      ),
    );
  }
}

/// Intercala cabeçalhos de dia e faturas (já ordenadas por data).
List<Object> _rows(List<InvoiceDue> items) {
  final rows = <Object>[];
  DateTime? current;
  for (final due in items) {
    if (current == null || !isSameDay(current, due.date)) {
      current = due.date;
      rows.add(due.date);
    }
    rows.add(due);
  }
  return rows;
}

class _InvoiceRow extends StatelessWidget {
  const _InvoiceRow({required this.due, required this.accounts});

  final InvoiceDue due;
  final Map<String, Account> accounts;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final textTheme = Theme.of(context).textTheme;
    final account = accounts[due.accountId];
    final balance = due.accountBalanceAfterCents;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpace.xs),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        due.invoice.card.name,
                        overflow: TextOverflow.ellipsis,
                        style: textTheme.bodyMedium,
                      ),
                    ),
                    if (due.overdue) ...[
                      const SizedBox(width: AppSpace.sm),
                      StatusBadge(label: 'Vencida', color: c.danger),
                    ],
                  ],
                ),
                Text(
                  account?.name ?? 'Sem conta',
                  overflow: TextOverflow.ellipsis,
                  style: textTheme.bodySmall?.copyWith(
                    color: account == null ? c.warning : null,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpace.sm),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              MoneyText(
                due.amountCents,
                style: textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              if (balance == null)
                Text('—', style: textTheme.bodySmall)
              else
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('Saldo após ', style: textTheme.bodySmall),
                    MoneyText(
                      balance,
                      style: textTheme.bodySmall?.copyWith(
                        color: balance < 0 ? c.danger : null,
                      ),
                    ),
                  ],
                ),
            ],
          ),
        ],
      ),
    );
  }
}
