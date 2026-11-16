import 'dart:math' show min;

import 'package:flutter/material.dart';

import '../../../app/app_scope.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/utils/id.dart';
import '../../../core/widgets/widgets.dart';
import '../../accounts/domain/account.dart';
import '../domain/goal.dart';
import '../domain/goal_math.dart';

/// Meta excluída com o diálogo aberto: não grava (o `upsert` a recriaria) e avisa.
bool _goneGoal(BuildContext context, AppServices services, String id) {
  if (services.goals.byId(id) != null) {
    return false;
  }
  ScaffoldMessenger.of(
    context,
  ).showSnackBar(const SnackBar(content: Text('Esta meta foi excluída.')));
  return true;
}

/// Form de meta (nova ou edição). Devolve a meta salva, ou null ao cancelar.
Future<Goal?> showGoalForm(BuildContext context, {Goal? initial}) {
  final services = AppScope.of(context);
  return showDialog<Goal>(
    context: context,
    builder: (_) => _GoalFormDialog(services: services, initial: initial),
  );
}

class _GoalFormDialog extends StatefulWidget {
  const _GoalFormDialog({required this.services, this.initial});

  final AppServices services;
  final Goal? initial;

  @override
  State<_GoalFormDialog> createState() => _GoalFormDialogState();
}

class _GoalFormDialogState extends State<_GoalFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late final _name = TextEditingController(text: widget.initial?.name ?? '');
  late final _target = TextEditingController(
    text: widget.initial == null
        ? ''
        : formatMoneyInput(widget.initial!.targetCents),
  );
  // Conta arquivada só entra se for a da própria meta (senão o dropdown perde o valor).
  late final List<Account> _accounts = [
    for (final a in widget.services.accounts.all)
      if (!a.archived || a.id == widget.initial?.accountId) a,
  ];
  late String? _accountId = _startAccountId();
  late DateTime? _targetDate = widget.initial?.targetDate;
  bool _saving = false;

  String? _startAccountId() {
    final ids = _accounts.map((a) => a.id).toList();
    final wanted = widget.initial?.accountId;
    if (wanted != null && ids.contains(wanted)) {
      return wanted;
    }
    return ids.isEmpty ? null : ids.first;
  }

  @override
  void dispose() {
    _name.dispose();
    _target.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final valid = _formKey.currentState?.validate() ?? false;
    final accountId = _accountId;
    final target = parseMoney(_target.text);
    if (_saving || !valid || accountId == null || target == null) {
      return;
    }
    final initial = widget.initial;
    if (initial != null && _goneGoal(context, widget.services, initial.id)) {
      return;
    }
    setState(() => _saving = true);
    final goal = Goal(
      id: initial?.id ?? newId(),
      name: _name.text.trim(),
      accountId: accountId,
      targetCents: target,
      targetDate: _targetDate,
      movements: initial?.movements ?? const [],
      archived: initial?.archived ?? false,
    );
    try {
      await widget.services.goals.upsert(goal);
      if (mounted) {
        Navigator.of(context).pop(goal);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Erro ao salvar: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Com movimentos, a conta não muda: senão a reserva sairia do saldo de outra conta.
    final locked = widget.initial?.movements.isNotEmpty ?? false;
    return AlertDialog(
      scrollable: true,
      title: Text(widget.initial == null ? 'Nova meta' : 'Editar meta'),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextFormField(
                controller: _name,
                autofocus: true,
                decoration: const InputDecoration(labelText: 'Nome'),
                validator: (v) =>
                    (v ?? '').trim().isEmpty ? 'Informe o nome' : null,
              ),
              const SizedBox(height: AppSpace.md),
              DropdownButtonFormField<String>(
                initialValue: _accountId,
                decoration: InputDecoration(
                  labelText: 'Conta',
                  helperText: locked ? 'Meta com movimentos' : null,
                ),
                items: [
                  for (final a in _accounts)
                    DropdownMenuItem(value: a.id, child: Text(a.name)),
                ],
                validator: (v) => v == null ? 'Escolha a conta' : null,
                onChanged: locked
                    ? null
                    : (v) => setState(() => _accountId = v),
              ),
              const SizedBox(height: AppSpace.md),
              MoneyField(
                controller: _target,
                label: 'Alvo',
                validator: (cents) => cents == null || cents <= 0
                    ? 'Informe um alvo maior que zero'
                    : null,
              ),
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                controlAffinity: ListTileControlAffinity.leading,
                title: const Text('Com data-alvo'),
                value: _targetDate != null,
                onChanged: (v) => setState(
                  () => _targetDate = v == true
                      ? (_targetDate ?? widget.services.ledger.today)
                      : null,
                ),
              ),
              if (_targetDate != null)
                DateField(
                  value: _targetDate!,
                  label: 'Data-alvo',
                  onChanged: (d) => setState(() => _targetDate = d),
                ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: _saving ? null : _save,
          child: const Text('Salvar'),
        ),
      ],
    );
  }
}

/// Aporte (reserva dinheiro da conta) ou retirada (libera reserva). Não cria transação.
Future<void> showGoalMovementDialog(
  BuildContext context,
  Goal goal, {
  bool withdrawal = false,
}) {
  final services = AppScope.of(context);
  return showDialog<void>(
    context: context,
    builder: (_) => _GoalMovementDialog(
      services: services,
      goal: goal,
      withdrawal: withdrawal,
    ),
  );
}

class _GoalMovementDialog extends StatefulWidget {
  const _GoalMovementDialog({
    required this.services,
    required this.goal,
    required this.withdrawal,
  });

  final AppServices services;
  final Goal goal;
  final bool withdrawal;

  @override
  State<_GoalMovementDialog> createState() => _GoalMovementDialogState();
}

class _GoalMovementDialogState extends State<_GoalMovementDialog> {
  final _formKey = GlobalKey<FormState>();
  final _amount = TextEditingController();
  final _note = TextEditingController();
  late bool _withdrawal = widget.withdrawal;
  late DateTime _date = widget.services.ledger.today;
  bool _saving = false;

  /// Versão atual da meta (pode ter mudado com a dialog aberta).
  Goal get _goal => widget.services.goals.byId(widget.goal.id) ?? widget.goal;

  int get _availableCents {
    final accountId = _goal.accountId;
    return availableToReserve(
      accountId: accountId,
      accountBalanceCents:
          widget.services.ledger.accountBalances[accountId] ?? 0,
      goals: widget.services.goals.all,
    );
  }

  String? _amountError(int? cents) {
    if (cents == null) {
      return 'Informe um valor válido';
    }
    return _withdrawal
        ? withdrawalError(amountCents: cents, goal: _goal)
        : contributionError(
            amountCents: cents,
            availableCents: _availableCents,
          );
  }

  @override
  void dispose() {
    _amount.dispose();
    _note.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_saving || !(_formKey.currentState?.validate() ?? false)) {
      return;
    }
    final cents = parseMoney(_amount.text);
    if (cents == null) {
      return;
    }
    if (_goneGoal(context, widget.services, widget.goal.id)) {
      return;
    }
    final note = _note.text.trim();
    setState(() => _saving = true);
    try {
      await widget.services.goals.upsert(
        _goal.withMovement(
          GoalMovement(
            id: newId(),
            date: _date,
            amountCents: _withdrawal ? -cents : cents,
            note: note.isEmpty ? null : note,
          ),
        ),
      );
      if (mounted) {
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Erro ao salvar: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final helper = _withdrawal
        ? 'Reservado nesta meta: ${formatMoney(_goal.reservedCents)}'
        : 'Disponível para reservar nesta conta: '
              '${formatMoney(_availableCents)}';
    return AlertDialog(
      scrollable: true,
      title: Text(widget.goal.name),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SegmentedButton<bool>(
                key: const Key('goal-move-mode'),
                segments: const [
                  ButtonSegment(value: false, label: Text('Aporte')),
                  ButtonSegment(value: true, label: Text('Retirada')),
                ],
                selected: {_withdrawal},
                onSelectionChanged: (sel) =>
                    setState(() => _withdrawal = sel.first),
              ),
              const SizedBox(height: AppSpace.md),
              TextFormField(
                controller: _amount,
                autofocus: true,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: InputDecoration(
                  labelText: 'Valor',
                  prefixText: 'R\$ ',
                  helperText: helper,
                  errorStyle: TextStyle(color: context.colors.danger),
                ),
                validator: (text) => _amountError(parseMoney(text ?? '')),
              ),
              const SizedBox(height: AppSpace.md),
              DateField(
                value: _date,
                onChanged: (d) => setState(() => _date = d),
              ),
              const SizedBox(height: AppSpace.md),
              TextFormField(
                controller: _note,
                decoration: const InputDecoration(labelText: 'Nota (opcional)'),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: _saving ? null : _save,
          child: const Text('Salvar'),
        ),
      ],
    );
  }
}

/// Movimentos da meta, mais recente primeiro. Excluir um aporte que deixaria retiradas
/// acima do reservado é bloqueado (SnackBar com o erro de `removeMovementError`).
Future<void> showGoalHistory(BuildContext context, Goal goal) {
  final services = AppScope.of(context);
  return showDialog<void>(
    context: context,
    builder: (_) => _GoalHistoryDialog(services: services, goal: goal),
  );
}

class _GoalHistoryDialog extends StatelessWidget {
  const _GoalHistoryDialog({required this.services, required this.goal});

  final AppServices services;
  final Goal goal;

  Future<void> _delete(BuildContext context, Goal current, String id) async {
    if (_goneGoal(context, services, goal.id)) {
      return;
    }
    final error = removeMovementError(current, id);
    if (error != null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error)));
      return;
    }
    await services.goals.upsert(current.withoutMovement(id));
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: services.goals,
      builder: (context, _) {
        final current = services.goals.byId(goal.id) ?? goal;
        final rows = current.movements.reversed.toList();
        // Dialog (e não AlertDialog): o IntrinsicWidth do AlertDialog não mede ListView.
        return Dialog(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: Padding(
              padding: const EdgeInsets.all(AppSpace.lg),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Histórico: ${current.name}',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: AppSpace.lg),
                  if (rows.isEmpty)
                    const Text('Nenhum movimento ainda.')
                  else
                    SizedBox(
                      height: min(rows.length * _rowHeight, _maxListHeight),
                      child: ListView.builder(
                        itemCount: rows.length,
                        itemBuilder: (context, i) => _MovementRow(
                          movement: rows[i],
                          onDelete: () => _delete(context, current, rows[i].id),
                        ),
                      ),
                    ),
                  const SizedBox(height: AppSpace.xl),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('Fechar'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Altura de uma linha do histórico (IconButton 48 + padding) e teto da lista com rolagem.
const double _rowHeight = 56;
const double _maxListHeight = 360;

class _MovementRow extends StatelessWidget {
  const _MovementRow({required this.movement, required this.onDelete});

  final GoalMovement movement;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final m = movement;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpace.xs),
      child: Row(
        children: [
          SizedBox(
            width: 88,
            child: Text(
              formatDate(m.date),
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: context.colors.textSecondary,
              ),
            ),
          ),
          Expanded(
            child: Text(
              m.note ?? (m.isContribution ? 'Aporte' : 'Retirada'),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          MoneyText(m.amountCents, signed: true, colorBySign: true),
          IconButton(
            tooltip: 'Excluir movimento',
            icon: const Icon(Icons.delete_outline),
            onPressed: onDelete,
          ),
        ],
      ),
    );
  }
}
