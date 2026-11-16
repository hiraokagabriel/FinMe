import 'package:flutter/material.dart';

import '../../../app/app_scope.dart';
import '../../../core/models/app_settings.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/widgets.dart';
import '../../accounts/domain/account.dart';
import '../domain/goal.dart';
import '../domain/goal_math.dart';
import 'goal_dialogs.dart';

enum _GoalAction { deposit, withdraw, history, edit, archive, delete }

/// Seção "Metas" da página Contas. Simples: progresso e aporte. Ultra: conta, datas, menu.
class GoalsSection extends StatefulWidget {
  const GoalsSection({super.key});

  @override
  State<GoalsSection> createState() => _GoalsSectionState();
}

class _GoalsSectionState extends State<GoalsSection> {
  bool _showArchived = false;

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    return ListenableBuilder(
      listenable: Listenable.merge([s.ledger, s.settings]),
      builder: (context, _) {
        final settings = s.settings.value;
        final ultra = settings.mode == AppMode.ultra;
        final all = s.goals.all;
        final goals = [
          for (final g in all)
            if ((ultra && _showArchived) || !g.archived) g,
        ]..sort((a, b) => a.name.compareTo(b.name));
        final balances = s.ledger.accountBalances;
        final reserved = s.ledger.reservedByAccount;
        final canCreate = s.accounts.all.any((a) => !a.archived);
        final hasArchived = all.any((g) => g.archived);

        final Widget body;
        if (goals.isEmpty) {
          body = EmptyState(
            icon: Icons.savings_outlined,
            message: all.isEmpty
                ? 'Nenhuma meta. Reserve parte do saldo de uma conta para um '
                      'objetivo; o valor reservado sai do "posso gastar".'
                : 'Todas as metas estão arquivadas.',
            action: _newGoalButton(context, enabled: canCreate),
          );
        } else {
          body = Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (final g in goals)
                _GoalRow(
                  goal: g,
                  ultra: ultra,
                  today: s.ledger.today,
                  hidden: settings.hideValues,
                  account: s.accounts.byId(g.accountId),
                  accountBalanceCents: balances[g.accountId] ?? 0,
                  accountReservedCents: reserved[g.accountId] ?? 0,
                  onAction: (action) => _onAction(context, s, g, action),
                ),
            ],
          );
        }

        return SectionCard(
          title: 'Metas',
          trailing: _newGoalButton(context, enabled: canCreate),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (ultra && hasArchived) ...[
                Align(
                  alignment: Alignment.centerLeft,
                  child: FilterChip(
                    label: const Text('Mostrar arquivadas'),
                    selected: _showArchived,
                    onSelected: (v) => setState(() => _showArchived = v),
                  ),
                ),
                const SizedBox(height: AppSpace.sm),
              ],
              body,
            ],
          ),
        );
      },
    );
  }

  Widget _newGoalButton(BuildContext context, {required bool enabled}) =>
      FilledButton.icon(
        onPressed: enabled ? () => showGoalForm(context) : null,
        icon: const Icon(Icons.add),
        label: const Text('Nova meta'),
      );

  Future<void> _onAction(
    BuildContext context,
    AppServices s,
    Goal g,
    _GoalAction action,
  ) async {
    switch (action) {
      case _GoalAction.deposit:
        await showGoalMovementDialog(context, g);
      case _GoalAction.withdraw:
        await showGoalMovementDialog(context, g, withdrawal: true);
      case _GoalAction.history:
        await showGoalHistory(context, g);
      case _GoalAction.edit:
        await showGoalForm(context, initial: g);
      case _GoalAction.archive:
        final unarchiving = g.archived;
        await s.goals.upsert(g.copyWith(archived: !g.archived));
        if (unarchiving && context.mounted) {
          final over = overReservedCents(
            accountBalanceCents: s.ledger.accountBalances[g.accountId] ?? 0,
            reservedCents: s.ledger.reservedByAccount[g.accountId] ?? 0,
          );
          if (over > 0) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  overReservedText(over, hidden: s.settings.value.hideValues),
                ),
              ),
            );
          }
        }
      case _GoalAction.delete:
        final ok = await confirmDialog(
          context,
          title: 'Excluir meta?',
          message:
              'A reserva de ${formatMoney(g.reservedCents, hidden: s.settings.value.hideValues)} '
              'volta a ficar livre.',
          confirmLabel: 'Excluir',
          destructive: true,
        );
        if (ok) {
          await s.goals.delete(g.id);
        }
    }
  }
}

/// Aviso de reserva acima do saldo (SPEC §5.22 regra 2), usado no badge e no SnackBar de desarquivar.
String overReservedText(int over, {required bool hidden}) =>
    'Reserva maior que o saldo da conta: faltam '
    '${formatMoney(over, hidden: hidden)}';

/// Uma meta. Simples: nome, progresso e aporte. Ultra: conta, datas, avisos e menu.
class _GoalRow extends StatelessWidget {
  const _GoalRow({
    required this.goal,
    required this.ultra,
    required this.today,
    required this.hidden,
    required this.account,
    required this.accountBalanceCents,
    required this.accountReservedCents,
    required this.onAction,
  });

  final Goal goal;
  final bool ultra;
  final DateTime today;
  final bool hidden;
  final Account? account;
  final int accountBalanceCents;
  final int accountReservedCents;
  final ValueChanged<_GoalAction> onAction;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final textTheme = Theme.of(context).textTheme;
    final g = goal;
    final target = g.targetDate;
    final monthly = monthlyContributionNeeded(g, today);
    final over = overReservedCents(
      accountBalanceCents: accountBalanceCents,
      reservedCents: accountReservedCents,
    );
    final acc = account;

    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: c.border)),
      ),
      child: Padding(
        key: Key('goal-${g.id}'),
        padding: const EdgeInsets.symmetric(vertical: AppSpace.sm),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    g.name,
                    overflow: TextOverflow.ellipsis,
                    style: textTheme.bodyMedium?.copyWith(
                      color: g.archived ? c.textSecondary : c.textPrimary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                // Meta arquivada não recebe aporte: a reserva foi liberada.
                if (!g.archived)
                  IconButton(
                    tooltip: 'Aportar',
                    icon: const Icon(Icons.add_circle_outline),
                    onPressed: () => onAction(_GoalAction.deposit),
                  ),
                if (ultra)
                  PopupMenuButton<_GoalAction>(
                    tooltip: 'Ações da meta',
                    onSelected: onAction,
                    itemBuilder: (_) => [
                      if (!g.archived)
                        const PopupMenuItem(
                          value: _GoalAction.deposit,
                          child: Text('Aportar'),
                        ),
                      const PopupMenuItem(
                        value: _GoalAction.withdraw,
                        child: Text('Retirar'),
                      ),
                      const PopupMenuItem(
                        value: _GoalAction.history,
                        child: Text('Histórico'),
                      ),
                      const PopupMenuItem(
                        value: _GoalAction.edit,
                        child: Text('Editar'),
                      ),
                      PopupMenuItem(
                        value: _GoalAction.archive,
                        child: Text(g.archived ? 'Desarquivar' : 'Arquivar'),
                      ),
                      const PopupMenuItem(
                        value: _GoalAction.delete,
                        child: Text('Excluir'),
                      ),
                    ],
                  ),
              ],
            ),
            const SizedBox(height: AppSpace.xs),
            TweenAnimationBuilder<double>(
              tween: Tween(end: g.progress),
              duration: AppMotion.normal,
              curve: AppMotion.curve,
              builder: (context, value, _) => LinearProgressIndicator(
                value: value,
                minHeight: 6,
                color: g.reached ? c.success : c.primary,
                backgroundColor: c.border,
              ),
            ),
            const SizedBox(height: AppSpace.xs),
            Row(
              children: [
                MoneyText(g.reservedCents, style: textTheme.bodySmall),
                Text(' de ', style: textTheme.bodySmall),
                MoneyText(g.targetCents, style: textTheme.bodySmall),
                const Spacer(),
                Text(
                  formatPercent(g.progress),
                  style: textTheme.bodySmall?.copyWith(color: c.textSecondary),
                ),
              ],
            ),
            if (ultra) ...[
              if (acc != null)
                Padding(
                  padding: const EdgeInsets.only(top: AppSpace.xs),
                  child: Row(
                    children: [
                      BankAvatar(bankName: acc.bankName, size: 16),
                      const SizedBox(width: AppSpace.sm),
                      Flexible(
                        child: Text(
                          acc.name,
                          overflow: TextOverflow.ellipsis,
                          style: textTheme.bodySmall,
                        ),
                      ),
                      if (acc.archived) ...[
                        const SizedBox(width: AppSpace.sm),
                        Text(
                          'Conta arquivada',
                          style: textTheme.bodySmall?.copyWith(
                            color: c.warning,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              if (target != null)
                Text(
                  'até ${formatDate(target)}',
                  style: textTheme.bodySmall?.copyWith(color: c.textSecondary),
                ),
              if (!g.reached && monthly != null)
                Text(
                  'Aporte mensal necessário: '
                  '${formatMoney(monthly, hidden: hidden)}',
                  style: textTheme.bodySmall,
                ),
              if (g.reached)
                Text(
                  'Meta atingida',
                  style: textTheme.bodySmall?.copyWith(color: c.success),
                )
              else if (isGoalOverdue(g, today))
                Text(
                  'Data-alvo passou',
                  style: textTheme.bodySmall?.copyWith(color: c.warning),
                ),
              if (over > 0)
                Padding(
                  padding: const EdgeInsets.only(top: AppSpace.xs),
                  child: StatusBadge(
                    label: overReservedText(over, hidden: hidden),
                    color: c.warning,
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }
}
