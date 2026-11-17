import 'dart:math' show min;

import 'package:flutter/material.dart';

import '../../../app/app_scope.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/utils/date_utils.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/utils/id.dart';
import '../../../core/utils/text_normalize.dart';
import '../../../core/widgets/widgets.dart';
import '../../accounts/domain/account.dart';
import '../../categories/domain/transaction_category.dart';
import '../domain/debt.dart';
import '../domain/debt_math.dart';

/// Dívida atual, ou null (com SnackBar) se foi excluída com o diálogo aberto: gravar a recriaria.
Debt? _liveDebt(BuildContext context, AppServices services, String id) {
  final debt = services.debts.byId(id);
  if (debt == null) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Esta dívida foi excluída.')));
  }
  return debt;
}

/// Contas não arquivadas, por nome.
List<Account> _activeAccounts(AppServices s) => [
  for (final a in s.accounts.all)
    if (!a.archived) a,
]..sort((a, b) => foldText(a.name).compareTo(foldText(b.name)));

String? _firstAccountId(AppServices s) {
  final accounts = _activeAccounts(s);
  return accounts.isEmpty ? null : accounts.first.id;
}

TextStyle? _hintStyle(BuildContext context) => Theme.of(
  context,
).textTheme.bodySmall?.copyWith(color: context.colors.textSecondary);

TextStyle? _dangerStyle(BuildContext context) => Theme.of(
  context,
).textTheme.bodySmall?.copyWith(color: context.colors.danger);

/// Form de dívida (nova ou edição). Devolve a dívida salva, ou null ao cancelar.
Future<Debt?> showDebtForm(BuildContext context, {Debt? initial}) {
  final services = AppScope.of(context);
  return showDialog<Debt>(
    context: context,
    builder: (_) => _DebtFormDialog(services: services, initial: initial),
  );
}

class _DebtFormDialog extends StatefulWidget {
  const _DebtFormDialog({required this.services, this.initial});

  final AppServices services;
  final Debt? initial;

  @override
  State<_DebtFormDialog> createState() => _DebtFormDialogState();
}

class _DebtFormDialogState extends State<_DebtFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late final _amount = TextEditingController(
    text: widget.initial == null || _hidden
        ? ''
        : formatMoneyInput(widget.initial!.amountCents),
  );
  late final _description = TextEditingController(
    text: widget.initial?.description ?? '',
  );
  // Atualizado por onChanged/onSelected do Autocomplete (o controller é dele).
  late String _person = widget.initial?.person ?? '';
  late DebtDirection _direction =
      widget.initial?.direction ?? DebtDirection.owedToMe;
  late DateTime _date = widget.initial?.date ?? widget.services.ledger.today;
  late DateTime? _dueDate = widget.initial?.dueDate;
  bool _saving = false;

  /// Com pagamentos a direção fica travada: trocar mudaria o sentido de transações já criadas.
  bool get _locked => widget.initial?.payments.isNotEmpty ?? false;

  int get _paidCents => widget.initial?.paidCents ?? 0;

  bool get _hidden => widget.services.settings.value.hideValues;

  String? get _dueError => _dueDate != null && _dueDate!.isBefore(_date)
      ? 'Vencimento antes da data'
      : null;

  /// Data da dívida: não futura e não depois do primeiro pagamento ([payments] vem ordenado).
  String? _dateError(List<DebtPayment> payments) {
    final day = dateOnly(_date);
    if (day.isAfter(dateOnly(widget.services.ledger.today))) {
      return 'A data não pode ser futura';
    }
    if (payments.isNotEmpty && day.isAfter(payments.first.date)) {
      return 'Há pagamento antes desta data';
    }
    return null;
  }

  @override
  void dispose() {
    _amount.dispose();
    _description.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final valid = _formKey.currentState?.validate() ?? false;
    final amount = parseMoney(_amount.text);
    if (_saving || !valid || amount == null || _dueError != null) {
      return;
    }
    final initial = widget.initial;
    // Relê a dívida: pagamentos gravados depois de abrir o form valem na validação e no save.
    final live = initial == null
        ? null
        : _liveDebt(context, widget.services, initial.id);
    if (initial != null && live == null) {
      return;
    }
    if (_dateError(live?.payments ?? const []) != null) {
      return;
    }
    setState(() => _saving = true);
    final debt = Debt(
      id: initial?.id ?? newId(),
      person: _person,
      direction: _direction,
      amountCents: amount,
      date: _date,
      description: _description.text,
      dueDate: _dueDate,
      payments: live?.payments ?? const [],
    );
    try {
      await widget.services.debts.upsert(debt);
      if (mounted) {
        Navigator.of(context).pop(debt);
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
    final services = widget.services;
    final initial = widget.initial;
    final dateError = _dateError(initial?.payments ?? const []);
    return AlertDialog(
      scrollable: true,
      title: Text(initial == null ? 'Nova dívida' : 'Editar dívida'),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SegmentedButton<DebtDirection>(
                key: const Key('debt-direction'),
                segments: const [
                  ButtonSegment(
                    value: DebtDirection.owedToMe,
                    label: Text('Me devem'),
                  ),
                  ButtonSegment(value: DebtDirection.iOwe, label: Text('Devo')),
                ],
                selected: {_direction},
                onSelectionChanged: _locked
                    ? null
                    : (sel) => setState(() => _direction = sel.first),
              ),
              if (_locked) ...[
                const SizedBox(height: AppSpace.xs),
                Text('Dívida com pagamentos', style: _hintStyle(context)),
              ],
              const SizedBox(height: AppSpace.md),
              Autocomplete<String>(
                initialValue: TextEditingValue(text: _person),
                optionsBuilder: (value) {
                  final query = foldText(value.text);
                  return services.ledger.debtPeople
                      .where((p) => foldText(p).contains(query))
                      .take(8);
                },
                onSelected: (v) => _person = v,
                fieldViewBuilder:
                    (
                      context,
                      controller,
                      focusNode,
                      onFieldSubmitted,
                    ) => TextFormField(
                      key: const Key('debt-person'),
                      controller: controller,
                      focusNode: focusNode,
                      autofocus: initial == null,
                      decoration: const InputDecoration(labelText: 'Pessoa'),
                      onChanged: (v) => _person = v,
                      onFieldSubmitted: (_) => onFieldSubmitted(),
                      validator: (v) =>
                          (v ?? '').trim().isEmpty ? 'Informe a pessoa' : null,
                    ),
              ),
              const SizedBox(height: AppSpace.md),
              MoneyField(
                controller: _amount,
                label: 'Valor',
                validator: (cents) {
                  if (cents == null || cents <= 0) {
                    return 'Informe um valor maior que zero';
                  }
                  if (cents < _paidCents) {
                    return 'Já pago: ${formatMoney(_paidCents, hidden: _hidden)}';
                  }
                  return null;
                },
              ),
              const SizedBox(height: AppSpace.md),
              DateField(
                value: _date,
                onChanged: (d) => setState(() => _date = d),
              ),
              if (dateError != null)
                Padding(
                  padding: const EdgeInsets.only(top: AppSpace.xs),
                  child: Text(dateError, style: _dangerStyle(context)),
                ),
              const SizedBox(height: AppSpace.md),
              TextFormField(
                controller: _description,
                decoration: const InputDecoration(
                  labelText: 'Descrição (opcional)',
                ),
              ),
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                controlAffinity: ListTileControlAffinity.leading,
                title: const Text('Com vencimento'),
                value: _dueDate != null,
                onChanged: (v) => setState(
                  () => _dueDate = v == true
                      ? (_dueDate ?? services.ledger.today)
                      : null,
                ),
              ),
              if (_dueDate != null) ...[
                DateField(
                  value: _dueDate!,
                  label: 'Vencimento',
                  onChanged: (d) => setState(() => _dueDate = d),
                ),
                if (_dueError != null)
                  Padding(
                    padding: const EdgeInsets.only(top: AppSpace.xs),
                    child: Text(_dueError!, style: _dangerStyle(context)),
                  ),
              ],
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

/// Quitação (total ou parcial): cria a transação na conta escolhida e registra o pagamento.
Future<void> showSettleDebtDialog(BuildContext context, Debt debt) {
  final services = AppScope.of(context);
  return showDialog<void>(
    context: context,
    builder: (_) => _SettleDebtDialog(services: services, debt: debt),
  );
}

class _SettleDebtDialog extends StatefulWidget {
  const _SettleDebtDialog({required this.services, required this.debt});

  final AppServices services;
  final Debt debt;

  @override
  State<_SettleDebtDialog> createState() => _SettleDebtDialogState();
}

class _SettleDebtDialogState extends State<_SettleDebtDialog> {
  late final _amount = TextEditingController(
    text: _hidden ? '' : formatMoneyInput(widget.debt.remainingCents),
  );
  late String? _accountId = _firstAccountId(widget.services);
  late DateTime _date = widget.services.ledger.today;
  String? _categoryId;
  bool _saving = false;

  bool get _hidden => widget.services.settings.value.hideValues;

  @override
  void dispose() {
    _amount.dispose();
    super.dispose();
  }

  /// Erro de `debtPaymentError` (null = pode quitar). Valor vazio conta como 0.
  String? _error(Debt debt) {
    final amount = parseMoney(_amount.text) ?? 0;
    final error = debtPaymentError(
      debt: debt,
      amountCents: amount,
      date: _date,
      today: widget.services.ledger.today,
    );
    // A mensagem de "acima do restante" traz o valor em claro: com valores ocultos, sai mascarada.
    if (_hidden && amount > debt.remainingCents) {
      return 'Restante: ${formatMoney(debt.remainingCents, hidden: true)}';
    }
    return error;
  }

  /// Conta escolhida se ainda está ativa; senão null (o dropdown exige valor presente nos itens).
  String? _accountIn(List<Account> accounts) =>
      accounts.any((a) => a.id == _accountId) ? _accountId : null;

  Future<void> _save(String accountId) async {
    final services = widget.services;
    // Relê a dívida: um pagamento gravado depois do build não pode ser sobrescrito.
    final debt = _liveDebt(context, services, widget.debt.id);
    final amount = parseMoney(_amount.text);
    if (_saving || debt == null || amount == null || _error(debt) != null) {
      return;
    }
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _saving = true);
    final r = settleDebt(
      debt,
      paymentId: newId(),
      transactionId: newId(),
      amountCents: amount,
      date: _date,
      accountId: accountId,
      categoryId: _categoryId,
    );
    final accountName = services.accounts.byId(accountId)?.name ?? '';
    try {
      await services.transactions.upsert(r.transaction);
    } catch (_) {
      _failed(messenger);
      return;
    }
    try {
      await services.debts.upsert(r.debt);
    } catch (_) {
      // Compensação: sem o pagamento gravado, a transação criada não pode ficar sozinha.
      try {
        await services.transactions.delete(r.transaction.id);
      } catch (_) {
        // Falhou também: a transação órfã aparece na tela de Transações.
      }
      _failed(messenger);
      return;
    }
    if (!mounted) {
      return;
    }
    if (r.debt.settled) {
      Navigator.of(context).pop();
      messenger.showSnackBar(
        SnackBar(
          content: Text('Dívida quitada · transação criada em $accountName'),
        ),
      );
      return;
    }
    // Parcial: o diálogo continua aberto com o novo restante.
    setState(() {
      _saving = false;
      _amount.text = _hidden ? '' : formatMoneyInput(r.debt.remainingCents);
    });
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          'Pagamento registrado · transação criada em $accountName',
        ),
      ),
    );
  }

  void _failed(ScaffoldMessengerState messenger) {
    if (mounted) {
      setState(() => _saving = false);
    }
    messenger.showSnackBar(
      const SnackBar(content: Text('Não foi possível registrar o pagamento.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final services = widget.services;
    return ListenableBuilder(
      listenable: Listenable.merge([
        services.debts,
        services.accounts,
        services.categories,
      ]),
      builder: (context, _) {
        final debt = services.debts.byId(widget.debt.id);
        if (debt == null) {
          return AlertDialog(
            title: const Text('Dívida excluída'),
            content: const Text('Esta dívida foi excluída.'),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Fechar'),
              ),
            ],
          );
        }
        final accounts = _activeAccounts(services);
        final accountValue = _accountIn(accounts);
        final owedToMe = debt.direction == DebtDirection.owedToMe;
        final options = services.ledger.categoryTree.options(
          owedToMe ? CategoryKind.income : CategoryKind.expense,
        );
        final error = _error(debt);
        final canSave = !_saving && accountValue != null && error == null;
        return AlertDialog(
          scrollable: true,
          title: Text(
            owedToMe ? 'Receber de ${debt.person}' : 'Pagar a ${debt.person}',
          ),
          content: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextFormField(
                  key: const Key('settle-amount'),
                  controller: _amount,
                  autofocus: true,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: InputDecoration(
                    labelText: 'Valor',
                    prefixText: 'R\$ ',
                    // Com erro, o restante já vem na mensagem: não repete.
                    helperText: error == null
                        ? 'Restante: ${formatMoney(debt.remainingCents, hidden: _hidden)}'
                        : null,
                    errorText: error,
                    errorStyle: TextStyle(color: context.colors.danger),
                  ),
                  onChanged: (_) => setState(() {}),
                ),
                const SizedBox(height: AppSpace.md),
                DateField(
                  value: _date,
                  onChanged: (d) => setState(() => _date = d),
                ),
                const SizedBox(height: AppSpace.md),
                if (accounts.isEmpty)
                  Text(
                    'Cadastre uma conta para registrar o pagamento.',
                    style: _dangerStyle(context),
                  )
                else
                  DropdownButtonFormField<String>(
                    key: const Key('settle-account'),
                    isExpanded: true,
                    initialValue: accountValue,
                    decoration: const InputDecoration(labelText: 'Conta'),
                    items: [
                      for (final a in accounts)
                        DropdownMenuItem(
                          value: a.id,
                          child: Row(
                            children: [
                              BankAvatar(bankName: a.bankName, size: 20),
                              const SizedBox(width: AppSpace.sm),
                              Flexible(
                                child: Text(
                                  a.name,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                    onChanged: (v) => setState(() => _accountId = v),
                  ),
                const SizedBox(height: AppSpace.md),
                DropdownButtonFormField<String?>(
                  key: const Key('settle-category'),
                  isExpanded: true,
                  initialValue: _categoryId,
                  decoration: InputDecoration(
                    labelText: 'Categoria',
                    helperText: owedToMe
                        ? 'Cria uma receita na conta'
                        : 'Cria uma despesa na conta',
                  ),
                  items: [
                    const DropdownMenuItem<String?>(
                      value: null,
                      child: Text('Sem categoria'),
                    ),
                    for (final c in options)
                      DropdownMenuItem<String?>(
                        value: c.id,
                        child: Text(services.ledger.categoryTree.label(c.id)),
                      ),
                  ],
                  onChanged: (v) => setState(() => _categoryId = v),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: _saving ? null : () => Navigator.of(context).pop(),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: accountValue != null && canSave
                  ? () => _save(accountValue)
                  : null,
              child: const Text('Confirmar'),
            ),
          ],
        );
      },
    );
  }
}

/// Pagamentos da dívida, mais recente primeiro. Desfazer confirma e exclui a transação ligada.
Future<void> showDebtPayments(BuildContext context, Debt debt) {
  final services = AppScope.of(context);
  return showDialog<void>(
    context: context,
    builder: (_) => _DebtPaymentsDialog(services: services, debt: debt),
  );
}

class _DebtPaymentsDialog extends StatelessWidget {
  const _DebtPaymentsDialog({required this.services, required this.debt});

  final AppServices services;
  final Debt debt;

  Future<void> _undo(BuildContext context, DebtPayment payment) async {
    final ok = await confirmDialog(
      context,
      title: 'Desfazer pagamento?',
      message:
          'O pagamento de ${formatMoney(payment.amountCents, hidden: services.settings.value.hideValues)} de '
          '${formatDate(payment.date)} sai do histórico e a transação ligada é excluída.',
      confirmLabel: 'Desfazer',
      destructive: true,
    );
    if (!ok || !context.mounted) {
      return;
    }
    final messenger = ScaffoldMessenger.of(context);
    final current = _liveDebt(context, services, debt.id);
    if (current == null) {
      return;
    }
    final r = undoDebtPayment(current, payment.id);
    final txId = r.transactionId;
    // Dívida primeiro: se apagar a transação falhar, não sobra pagamento apontando para nada.
    try {
      await services.debts.upsert(r.debt);
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text('Erro ao desfazer o pagamento: $e')),
      );
      return;
    }
    if (txId == null || services.transactions.byId(txId) == null) {
      return;
    }
    try {
      await services.transactions.delete(txId);
    } catch (_) {
      messenger.showSnackBar(
        const SnackBar(
          content: Text(
            'Pagamento desfeito, mas a transação não foi apagada; apague-a em Transações.',
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([services.debts, services.transactions]),
      builder: (context, _) {
        final current = services.debts.byId(debt.id) ?? debt;
        final rows = current.payments.reversed.toList();
        return AlertDialog(
          title: Text('Pagamentos · ${current.person}'),
          content: SizedBox(
            width: 520,
            height: rows.isEmpty
                ? null
                : min(rows.length * _rowHeight, _maxListHeight),
            child: rows.isEmpty
                ? const Text('Nenhum pagamento')
                : ListView.builder(
                    itemCount: rows.length,
                    itemBuilder: (context, i) {
                      final payment = rows[i];
                      final txId = payment.transactionId;
                      final tx = txId == null
                          ? null
                          : services.transactions.byId(txId);
                      return _PaymentRow(
                        payment: payment,
                        description: tx?.description,
                        missing: txId != null && tx == null,
                        onUndo: () => _undo(context, payment),
                      );
                    },
                  ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Fechar'),
            ),
          ],
        );
      },
    );
  }
}

/// Altura de uma linha de pagamento (IconButton 48 + padding) e teto da lista com rolagem.
const double _rowHeight = 56;
const double _maxListHeight = 360;

class _PaymentRow extends StatelessWidget {
  const _PaymentRow({
    required this.payment,
    required this.description,
    required this.missing,
    required this.onUndo,
  });

  final DebtPayment payment;
  final String? description;
  final bool missing;
  final VoidCallback onUndo;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final textTheme = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpace.xs),
      child: Row(
        children: [
          SizedBox(
            width: 88,
            child: Text(
              formatDate(payment.date),
              style: textTheme.bodySmall?.copyWith(color: c.textSecondary),
            ),
          ),
          Expanded(
            child: Text(
              missing ? 'Transação excluída' : (description ?? ''),
              overflow: TextOverflow.ellipsis,
              style: missing
                  ? textTheme.bodySmall?.copyWith(color: c.warning)
                  : null,
            ),
          ),
          MoneyText(payment.amountCents),
          IconButton(
            tooltip: 'Desfazer',
            icon: const Icon(Icons.undo),
            onPressed: onUndo,
          ),
        ],
      ),
    );
  }
}
