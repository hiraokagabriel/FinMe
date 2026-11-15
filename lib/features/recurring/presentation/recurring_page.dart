import 'package:flutter/material.dart';

import '../../../app/app_scope.dart';
import '../../../app/ledger.dart';
import '../../../core/services/collection_repository.dart';
import '../../../core/models/app_settings.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/widgets.dart';
import '../../transactions/domain/transaction.dart';
import '../domain/recurrence.dart';
import '../domain/recurring_rule.dart';
import 'recurring_form.dart';

/// Horizonte para achar a próxima ocorrência (cobre a recorrência anual).
const _horizonDays = 400;
const _weekdays = ['Seg', 'Ter', 'Qua', 'Qui', 'Sex', 'Sáb', 'Dom'];

/// Custo mensal de [r] em centavos: semanal ×52/12, anual ÷12, arredondado.
int _monthlyCents(RecurringRule r) => switch (r.frequency) {
  Frequency.weekly => (r.amountCents * 52 / 12).round(),
  Frequency.monthly => r.amountCents,
  Frequency.yearly => (r.amountCents / 12).round(),
};

int _sumMonthly(Iterable<RecurringRule> rules) =>
    rules.fold(0, (sum, r) => sum + _monthlyCents(r));

class RecurringPage extends StatelessWidget {
  const RecurringPage({super.key});

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    return ListenableBuilder(
      listenable: s.ledger,
      builder: (context, _) {
        final ultra = s.settings.value.mode == AppMode.ultra;
        final today = s.ledger.today;
        final to = DateTime(today.year, today.month, today.day + _horizonDays);
        final rules = [...s.recurring.all]
          ..sort(
            (a, b) => a.description.toLowerCase().compareTo(
              b.description.toLowerCase(),
            ),
          );
        final active = rules.where((r) => r.active).toList();
        final expenses = active
            .where((r) => r.type == TransactionType.expense)
            .toList();
        final incomes = active
            .where((r) => r.type == TransactionType.income)
            .toList();
        final subsMonthly = _sumMonthly(
          expenses.where((r) => r.isSubscription),
        );
        final kpis = [
          KpiTile(label: 'Custo mensal fixo', cents: _sumMonthly(expenses)),
          KpiTile(
            label: 'Receitas mensais fixas',
            cents: _sumMonthly(incomes),
            color: context.colors.success,
          ),
          if (ultra) ...[
            KpiTile(label: 'Assinaturas/mês', cents: subsMonthly),
            KpiTile(label: 'Assinaturas/ano', cents: subsMonthly * 12),
          ],
        ];
        final items = _items([
          for (final r in rules)
            _RuleItem(
              r,
              occurrencesBetween(r, today, to).firstOrNull,
              _originLabel(s.ledger, r),
            ),
        ], ultra: ultra);
        return _content(context, kpis, items);
      },
    );
  }

  Widget _content(BuildContext context, List<Widget> kpis, List<_Item> items) {
    final pad = MediaQuery.sizeOf(context).width < 600
        ? AppSpace.lg
        : AppSpace.xl;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        PageHeader(
          title: 'Recorrentes',
          actions: [
            FilledButton.icon(
              onPressed: () => showRecurringForm(context),
              icon: const Icon(Icons.add),
              label: const Text('Nova recorrência'),
            ),
          ],
        ),
        Expanded(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1200),
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: pad),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Wrap(
                      spacing: AppSpace.md,
                      runSpacing: AppSpace.md,
                      children: [
                        for (final kpi in kpis)
                          SizedBox(width: 220, child: kpi),
                      ],
                    ),
                    const SizedBox(height: AppSpace.lg),
                    Expanded(
                      child: items.isEmpty
                          ? const EmptyState(
                              icon: Icons.repeat,
                              message: 'Nenhuma recorrência cadastrada.',
                            )
                          : ListView.builder(
                              itemCount: items.length,
                              itemBuilder: (context, i) =>
                                  _itemView(context, items[i], i),
                            ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _itemView(BuildContext context, _Item item, int index) {
    return switch (item) {
      _HeaderItem(:final title) => Padding(
        padding: EdgeInsets.only(
          top: index == 0 ? 0 : AppSpace.lg,
          bottom: AppSpace.sm,
        ),
        child: Text(title, style: Theme.of(context).textTheme.titleSmall),
      ),
      _RuleItem() => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _RecurringRow(item: item),
          const Divider(height: 1),
        ],
      ),
    };
  }
}

/// Seções só no Modo Ultra: assinaturas à parte das contas fixas e receitas.
List<_Item> _items(List<_RuleItem> rules, {required bool ultra}) {
  if (!ultra) {
    return rules;
  }
  final subs = rules.where((r) => r.rule.isSubscription).toList();
  final others = rules.where((r) => !r.rule.isSubscription).toList();
  return [
    if (subs.isNotEmpty) ...[const _HeaderItem('Assinaturas'), ...subs],
    if (others.isNotEmpty) ...[
      const _HeaderItem('Contas fixas e receitas'),
      ...others,
    ],
  ];
}

String _originLabel(Ledger l, RecurringRule r) {
  final account = r.accountId == null ? null : l.accountsById[r.accountId];
  if (account != null) {
    return '${account.bankName} · ${account.name}';
  }
  final card = r.cardId == null ? null : l.cardsById[r.cardId];
  return card == null ? 'Sem origem' : '${card.bankName} · ${card.name}';
}

String _scheduleLabel(RecurringRule r) => switch (r.frequency) {
  Frequency.weekly => _weekdays[r.startDate.weekday - 1],
  Frequency.monthly => 'dia ${r.startDate.day}',
  Frequency.yearly => formatShortDate(r.startDate),
};

sealed class _Item {
  const _Item();
}

class _HeaderItem extends _Item {
  const _HeaderItem(this.title);

  final String title;
}

class _RuleItem extends _Item {
  const _RuleItem(this.rule, this.next, this.origin);

  final RecurringRule rule;

  /// Próxima ocorrência a partir de hoje; null se pausada ou encerrada.
  final DateTime? next;
  final String origin;
}

enum _RowAction { edit, delete }

class _RecurringRow extends StatelessWidget {
  const _RecurringRow({required this.item});

  final _RuleItem item;

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final r = item.rule;
    final c = context.colors;
    final textTheme = Theme.of(context).textTheme;
    final amount = r.type == TransactionType.income
        ? r.amountCents
        : -r.amountCents;
    final next = item.next;
    return Opacity(
      opacity: r.active ? 1 : 0.5,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpace.sm),
        child: Row(
          children: [
            Icon(
              r.isBoleto ? Icons.receipt_long : Icons.repeat,
              color: c.textSecondary,
            ),
            const SizedBox(width: AppSpace.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          r.description,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: textTheme.bodyMedium,
                        ),
                      ),
                      if (!r.active) ...[
                        const SizedBox(width: AppSpace.sm),
                        StatusBadge(label: 'Pausada', color: c.textSecondary),
                      ],
                    ],
                  ),
                  Text(
                    '${frequencyLabel(r.frequency)} · ${_scheduleLabel(r)} · ${item.origin}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: textTheme.bodySmall,
                  ),
                  if (next != null)
                    Text(
                      'Próxima: ${formatDate(next)}',
                      style: textTheme.bodySmall,
                    ),
                ],
              ),
            ),
            MoneyText(
              amount,
              signed: true,
              colorBySign: true,
              style: textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            Switch(
              value: r.active,
              onChanged: (v) => s.recurring.upsert(r.copyWith(active: v)),
            ),
            PopupMenuButton<_RowAction>(
              tooltip: 'Mais opções',
              onSelected: (action) => switch (action) {
                _RowAction.edit => showRecurringForm(context, initial: r),
                _RowAction.delete => _confirmDelete(context, s.recurring, r),
              },
              itemBuilder: (_) => const [
                PopupMenuItem(value: _RowAction.edit, child: Text('Editar')),
                PopupMenuItem(value: _RowAction.delete, child: Text('Excluir')),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// Apaga só a regra: transações já lançadas por ela são mantidas.
  Future<void> _confirmDelete(
    BuildContext context,
    CollectionRepository<RecurringRule> repo,
    RecurringRule r,
  ) async {
    final ok = await confirmDialog(
      context,
      title: 'Excluir recorrência?',
      message:
          '"${r.description}" deixa de gerar lançamentos. '
          'As transações já lançadas são mantidas.',
      confirmLabel: 'Excluir',
      destructive: true,
    );
    if (ok) {
      await repo.delete(r.id);
    }
  }
}
