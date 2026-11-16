import 'package:flutter/material.dart';

import '../../../app/app_scope.dart';
import '../../../core/models/app_settings.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/utils/text_normalize.dart';
import '../../../core/widgets/widgets.dart';
import '../domain/debt.dart';
import '../domain/debt_math.dart';
import 'debt_dialogs.dart';

enum _DebtAction { settle, payments, edit, delete }

/// Seção "Devo / me devem" da página Patrimônio. Simples: totais e dívidas em aberto com 'Quitar'.
/// Ultra: 'Por pessoa', filtros, quitadas, data, pagamentos e menu completo.
class DebtsSection extends StatefulWidget {
  const DebtsSection({super.key});

  @override
  State<DebtsSection> createState() => _DebtsSectionState();
}

class _DebtsSectionState extends State<DebtsSection> {
  DebtDirection? _direction;

  /// Chave de `foldText` da pessoa filtrada.
  String? _person;
  bool _showSettled = false;

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    return ListenableBuilder(
      listenable: Listenable.merge([s.debts, s.settings, s.ledger]),
      builder: (context, _) {
        final ledger = s.ledger;
        final ultra = s.settings.value.mode == AppMode.ultra;
        final today = ledger.today;
        // Filtros e quitadas só existem no Ultra; no Simples o estado antigo é ignorado.
        final direction = ultra ? _direction : null;
        final person = ultra ? _person : null;
        final showSettled = ultra && _showSettled;
        final all = s.debts.all;
        final filtered = direction != null || person != null || showSettled;
        final debts = [
          for (final d in all)
            if ((showSettled || !d.settled) &&
                (direction == null || d.direction == direction) &&
                (person == null || foldText(d.person) == person))
              d,
        ]..sort(_byDue);
        final people = ultra ? ledger.debtPeople : const <String>[];
        final summaries = ultra
            ? ledger.debtsByPerson
            : const <PersonDebtSummary>[];
        final last = ledger.netWorthHistory.last;

        final body = debts.isEmpty
            ? EmptyState(
                icon: Icons.handshake_outlined,
                message: all.isEmpty
                    ? 'Nada pendente. Registre o que você deve ou o que te '
                          'devem para acompanhar e quitar com um clique.'
                    : filtered
                    ? 'Nenhuma dívida com esses filtros.'
                    : 'Nada pendente.',
                action: all.isEmpty ? _newDebtButton(context) : null,
              )
            : Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (final d in debts)
                    _DebtRow(
                      key: ValueKey(d.id),
                      debt: d,
                      ultra: ultra,
                      today: today,
                      onAction: (action) => _onAction(context, s, d, action),
                    ),
                ],
              );

        return SectionCard(
          title: 'Devo / me devem',
          trailing: _newDebtButton(context),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _TotalsLine(
                receivableCents: last.receivableCents,
                payableCents: last.payableCents,
              ),
              if (ultra) ...[
                const SizedBox(height: AppSpace.lg),
                if (summaries.isNotEmpty)
                  _PersonTable(
                    people: summaries,
                    selected: person,
                    onTap: (key) =>
                        setState(() => _person = _person == key ? null : key),
                  ),
                const SizedBox(height: AppSpace.md),
                _DebtFilters(
                  direction: _direction,
                  person: people.any((p) => foldText(p) == _person)
                      ? _person
                      : null,
                  people: people,
                  showSettled: _showSettled,
                  onDirection: (v) => setState(() => _direction = v),
                  onPerson: (v) => setState(() => _person = v),
                  onShowSettled: (v) => setState(() => _showSettled = v),
                ),
              ],
              const SizedBox(height: AppSpace.md),
              body,
            ],
          ),
        );
      },
    );
  }

  Widget _newDebtButton(BuildContext context) => TextButton.icon(
    onPressed: () => showDebtForm(context),
    icon: const Icon(Icons.add),
    label: const Text('Nova dívida'),
  );

  Future<void> _onAction(
    BuildContext context,
    AppServices s,
    Debt d,
    _DebtAction action,
  ) async {
    // Lê o repositório: o diálogo recebe a dívida atual (pagamentos e restante já atualizados).
    final current = s.debts.byId(d.id);
    if (current == null) {
      return;
    }
    switch (action) {
      case _DebtAction.settle:
        await showSettleDebtDialog(context, current);
      case _DebtAction.payments:
        await showDebtPayments(context, current);
      case _DebtAction.edit:
        await showDebtForm(context, initial: current);
      case _DebtAction.delete:
        if (current.payments.isNotEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Desfaça os pagamentos antes de excluir'),
            ),
          );
          return;
        }
        final ok = await confirmDialog(
          context,
          title: 'Excluir dívida?',
          message: 'A dívida some do patrimônio e da previsão.',
          confirmLabel: 'Excluir',
          destructive: true,
        );
        if (ok) {
          await s.debts.delete(current.id);
        }
    }
  }
}

/// Ordem: vencimento asc (sem vencimento por último), depois data asc e id.
int _byDue(Debt a, Debt b) {
  final da = a.dueDate;
  final db = b.dueDate;
  if (da == null || db == null) {
    if (da == null && db == null) {
      return _byDate(a, b);
    }
    return da == null ? 1 : -1;
  }
  final byDue = da.compareTo(db);
  return byDue != 0 ? byDue : _byDate(a, b);
}

int _byDate(Debt a, Debt b) {
  final byDate = a.date.compareTo(b.date);
  return byDate != 0 ? byDate : a.id.compareTo(b.id);
}

/// Primeira linha: 'Me devem R$ X · Devo R$ Y'.
class _TotalsLine extends StatelessWidget {
  const _TotalsLine({
    required this.receivableCents,
    required this.payableCents,
  });

  final int receivableCents;
  final int payableCents;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final style = Theme.of(context).textTheme.bodyMedium;
    return Wrap(
      key: const Key('debt-totals'),
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        Text('Me devem ', style: style),
        MoneyText(receivableCents, style: style?.copyWith(color: c.success)),
        Text(' · Devo ', style: style),
        MoneyText(payableCents, style: style?.copyWith(color: c.danger)),
      ],
    );
  }
}

/// Ultra: uma linha por pessoa com dívida em aberto. Tocar filtra; tocar de novo limpa.
class _PersonTable extends StatelessWidget {
  const _PersonTable({
    required this.people,
    required this.selected,
    required this.onTap,
  });

  final List<PersonDebtSummary> people;

  /// Chave de `foldText` da pessoa filtrada.
  final String? selected;
  final ValueChanged<String> onTap;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final header = textTheme.bodySmall;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Por pessoa',
          style: textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: AppSpace.xs),
        Row(
          children: [
            Expanded(flex: 3, child: Text('Pessoa', style: header)),
            Expanded(
              flex: 2,
              child: Text('Me deve', style: header, textAlign: TextAlign.end),
            ),
            Expanded(
              flex: 2,
              child: Text('Devo', style: header, textAlign: TextAlign.end),
            ),
            Expanded(
              flex: 2,
              child: Text('Líquido', style: header, textAlign: TextAlign.end),
            ),
          ],
        ),
        for (var i = 0; i < people.length; i++)
          _PersonRow(
            key: Key('debt-person-$i'),
            summary: people[i],
            selected: selected == foldText(people[i].person),
            onTap: () => onTap(foldText(people[i].person)),
          ),
      ],
    );
  }
}

class _PersonRow extends StatelessWidget {
  const _PersonRow({
    super.key,
    required this.summary,
    required this.selected,
    required this.onTap,
  });

  final PersonDebtSummary summary;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final textTheme = Theme.of(context).textTheme;
    final s = summary;
    return InkWell(
      borderRadius: AppRadius.cardBorder,
      onTap: onTap,
      child: Container(
        color: selected ? c.primarySubtle : null,
        padding: const EdgeInsets.symmetric(vertical: AppSpace.sm),
        child: Row(
          children: [
            Expanded(
              flex: 3,
              child: Text(
                s.person,
                overflow: TextOverflow.ellipsis,
                style: textTheme.bodyMedium,
              ),
            ),
            Expanded(flex: 2, child: _AlignEnd(MoneyText(s.receivableCents))),
            Expanded(flex: 2, child: _AlignEnd(MoneyText(s.payableCents))),
            Expanded(
              flex: 2,
              child: _AlignEnd(
                MoneyText(s.netCents, signed: true, colorBySign: true),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AlignEnd extends StatelessWidget {
  const _AlignEnd(this.child);

  final Widget child;

  @override
  Widget build(BuildContext context) =>
      Align(alignment: Alignment.centerRight, child: child);
}

/// Filtros Ultra: direção, pessoa e quitadas. `person` já vem validado contra `people`.
class _DebtFilters extends StatelessWidget {
  const _DebtFilters({
    required this.direction,
    required this.person,
    required this.people,
    required this.showSettled,
    required this.onDirection,
    required this.onPerson,
    required this.onShowSettled,
  });

  final DebtDirection? direction;
  final String? person;
  final List<String> people;
  final bool showSettled;
  final ValueChanged<DebtDirection?> onDirection;
  final ValueChanged<String?> onPerson;
  final ValueChanged<bool> onShowSettled;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: AppSpace.md,
      runSpacing: AppSpace.sm,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        SegmentedButton<DebtDirection?>(
          key: const Key('debt-filter-direction'),
          segments: const <ButtonSegment<DebtDirection?>>[
            ButtonSegment(value: null, label: Text('Todas')),
            ButtonSegment(
              value: DebtDirection.owedToMe,
              label: Text('Me devem'),
            ),
            ButtonSegment(value: DebtDirection.iOwe, label: Text('Devo')),
          ],
          selected: {direction},
          onSelectionChanged: (v) => onDirection(v.first),
        ),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Pessoa', style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(width: AppSpace.sm),
            DropdownButton<String?>(
              key: const Key('debt-filter-person'),
              value: person,
              items: [
                const DropdownMenuItem<String?>(
                  value: null,
                  child: Text('Todas'),
                ),
                for (final p in people)
                  DropdownMenuItem<String?>(value: foldText(p), child: Text(p)),
              ],
              onChanged: onPerson,
            ),
          ],
        ),
        FilterChip(
          key: const Key('debt-show-settled'),
          label: const Text('Mostrar quitadas'),
          selected: showSettled,
          onSelected: onShowSettled,
        ),
      ],
    );
  }
}

/// Uma dívida. Quitada (só Ultra): texto em `textSecondary` com badge 'Quitada'.
class _DebtRow extends StatelessWidget {
  const _DebtRow({
    super.key,
    required this.debt,
    required this.ultra,
    required this.today,
    required this.onAction,
  });

  final Debt debt;
  final bool ultra;
  final DateTime today;
  final ValueChanged<_DebtAction> onAction;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final textTheme = Theme.of(context).textTheme;
    final d = debt;
    final settled = d.settled;
    final owedToMe = d.direction == DebtDirection.owedToMe;
    final nameStyle = textTheme.bodyMedium?.copyWith(
      fontWeight: FontWeight.w600,
      color: settled ? c.textSecondary : c.textPrimary,
    );
    final due = d.dueDate;

    final Widget? status;
    if (settled) {
      status = StatusBadge(label: 'Quitada', color: c.textSecondary);
    } else if (isDebtOverdue(d, today)) {
      status = StatusBadge(label: 'Vencida', color: c.danger);
    } else if (due != null) {
      status = Text(
        'vence ${formatShortDate(due)}',
        style: textTheme.bodySmall,
      );
    } else {
      status = null;
    }

    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: c.border)),
      ),
      child: Padding(
        key: Key('debt-${d.id}'),
        padding: const EdgeInsets.symmetric(vertical: AppSpace.sm),
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
                          d.person,
                          overflow: TextOverflow.ellipsis,
                          style: nameStyle,
                        ),
                      ),
                      const SizedBox(width: AppSpace.sm),
                      StatusBadge(
                        label: owedToMe ? 'Me deve' : 'Devo',
                        color: owedToMe ? c.success : c.warning,
                      ),
                    ],
                  ),
                  if (ultra && d.description != null)
                    Text(d.description!, style: textTheme.bodySmall),
                  if (ultra)
                    Text(
                      'desde ${formatDate(d.date)}',
                      style: textTheme.bodySmall,
                    ),
                  if (ultra && d.payments.isNotEmpty)
                    Wrap(
                      children: [
                        MoneyText(d.paidCents, style: textTheme.bodySmall),
                        Text(' pago de ', style: textTheme.bodySmall),
                        MoneyText(d.amountCents, style: textTheme.bodySmall),
                      ],
                    ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                MoneyText(d.remainingCents, style: nameStyle),
                ?status,
              ],
            ),
            if (!settled)
              TextButton(
                key: Key('debt-settle-${d.id}'),
                onPressed: () => onAction(_DebtAction.settle),
                child: const Text('Quitar'),
              ),
            if (ultra)
              PopupMenuButton<_DebtAction>(
                key: Key('debt-menu-${d.id}'),
                tooltip: 'Ações da dívida',
                onSelected: onAction,
                itemBuilder: (_) => [
                  PopupMenuItem(
                    value: _DebtAction.settle,
                    enabled: !settled,
                    child: const Text('Quitar'),
                  ),
                  const PopupMenuItem(
                    value: _DebtAction.payments,
                    child: Text('Pagamentos'),
                  ),
                  const PopupMenuItem(
                    value: _DebtAction.edit,
                    child: Text('Editar'),
                  ),
                  const PopupMenuItem(
                    value: _DebtAction.delete,
                    child: Text('Excluir'),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}
