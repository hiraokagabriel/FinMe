import 'package:flutter/material.dart';

import '../../../app/app_scope.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/utils/id.dart';
import '../../../core/widgets/widgets.dart';
import '../../transactions/domain/transaction.dart';
import '../domain/account.dart';

/// Transferência entre duas contas ativas. Cria uma única `Transaction` de tipo transfer.
Future<void> showTransferDialog(BuildContext context) async {
  final services = AppScope.of(context);
  final active = services.accounts.all.where((a) => !a.archived).toList();
  if (active.length < 2) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Cadastre ao menos duas contas ativas para transferir.'),
      ),
    );
    return;
  }
  await showDialog<void>(
    context: context,
    builder: (_) => _TransferDialog(services: services, accounts: active),
  );
}

class _TransferDialog extends StatefulWidget {
  const _TransferDialog({required this.services, required this.accounts});

  final AppServices services;
  final List<Account> accounts;

  @override
  State<_TransferDialog> createState() => _TransferDialogState();
}

class _TransferDialogState extends State<_TransferDialog> {
  final _formKey = GlobalKey<FormState>();
  final _amount = TextEditingController();
  final _description = TextEditingController(text: 'Transferência');
  late String _from = widget.accounts[0].id;
  late String _to = widget.accounts[1].id;
  late DateTime _date = widget.services.ledger.today;
  bool _planned = false;

  @override
  void dispose() {
    _amount.dispose();
    _description.dispose();
    super.dispose();
  }

  List<DropdownMenuItem<String>> get _items => [
    for (final a in widget.accounts)
      DropdownMenuItem(value: a.id, child: Text(_label(a))),
  ];

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }
    final amount = parseMoney(_amount.text);
    if (amount == null) {
      return;
    }
    await widget.services.transactions.upsert(
      Transaction(
        id: newId(),
        type: TransactionType.transfer,
        amountCents: amount,
        date: _date,
        description: _description.text.trim(),
        accountId: _from,
        toAccountId: _to,
        status: _planned ? TransactionStatus.planned : TransactionStatus.paid,
      ),
    );
    if (mounted) {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      scrollable: true,
      title: const Text('Transferir entre contas'),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              DropdownButtonFormField<String>(
                initialValue: _from,
                decoration: const InputDecoration(labelText: 'Origem'),
                items: _items,
                onChanged: (v) {
                  if (v != null) {
                    setState(() => _from = v);
                  }
                },
              ),
              const SizedBox(height: AppSpace.md),
              DropdownButtonFormField<String>(
                initialValue: _to,
                decoration: const InputDecoration(labelText: 'Destino'),
                items: _items,
                validator: (v) =>
                    v == _from ? 'Escolha uma conta diferente da origem' : null,
                onChanged: (v) {
                  if (v != null) {
                    setState(() => _to = v);
                  }
                },
              ),
              const SizedBox(height: AppSpace.md),
              MoneyField(controller: _amount, label: 'Valor'),
              const SizedBox(height: AppSpace.md),
              DateField(
                value: _date,
                onChanged: (d) => setState(() => _date = d),
              ),
              const SizedBox(height: AppSpace.md),
              TextFormField(
                controller: _description,
                decoration: const InputDecoration(labelText: 'Descrição'),
                validator: (v) =>
                    (v ?? '').trim().isEmpty ? 'Informe a descrição' : null,
              ),
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                controlAffinity: ListTileControlAffinity.leading,
                value: _planned,
                title: const Text('Provisionar (ainda não feita)'),
                onChanged: (v) => setState(() => _planned = v ?? false),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
        FilledButton(onPressed: _save, child: const Text('Salvar')),
      ],
    );
  }
}

String _label(Account a) =>
    a.bankName.isEmpty ? a.name : '${a.name} · ${a.bankName}';
