import 'package:flutter/material.dart';

import '../../../app/app_scope.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_palettes.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/utils/id.dart';
import '../domain/account.dart';

const _formMaxWidth = 520.0;

String accountTypeLabel(AccountType type) => switch (type) {
  AccountType.checking => 'Conta corrente',
  AccountType.savings => 'Poupança',
  AccountType.cash => 'Dinheiro',
  AccountType.investment => 'Investimento',
  AccountType.wallet => 'Carteira',
};

/// Cria conta (sem [initial]) ou edita a existente. `archived` não muda aqui.
Future<void> showAccountForm(BuildContext context, {Account? initial}) async {
  final services = AppScope.of(context);
  await showDialog<void>(
    context: context,
    builder: (_) => _AccountFormDialog(services: services, initial: initial),
  );
}

class _AccountFormDialog extends StatefulWidget {
  const _AccountFormDialog({required this.services, this.initial});

  final AppServices services;
  final Account? initial;

  @override
  State<_AccountFormDialog> createState() => _AccountFormDialogState();
}

class _AccountFormDialogState extends State<_AccountFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late final _name = TextEditingController(text: widget.initial?.name ?? '');
  late final _bank = TextEditingController(
    text: widget.initial?.bankName ?? '',
  );
  // RawAutocomplete exige focusNode quando recebe textEditingController.
  final _bankFocus = FocusNode();
  late final _balance = TextEditingController(
    text: _plainMoney(widget.initial?.initialBalanceCents ?? 0),
  );
  late final List<String> _bankNames = {
    for (final a in widget.services.accounts.all) a.bankName.trim(),
    for (final c in widget.services.cards.all) c.bankName.trim(),
  }.where((b) => b.isNotEmpty).toList()..sort();
  late AccountType _type = widget.initial?.type ?? AccountType.checking;
  late int _color = widget.initial?.colorValue ?? kEntityColors.first;

  @override
  void dispose() {
    _name.dispose();
    _bank.dispose();
    _bankFocus.dispose();
    _balance.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }
    final balance = parseMoney(_balance.text);
    if (balance == null) {
      return;
    }
    final name = _name.text.trim();
    final bank = _bank.text.trim();
    final initial = widget.initial;
    final account = initial == null
        ? Account(
            id: newId(),
            name: name,
            bankName: bank,
            type: _type,
            initialBalanceCents: balance,
            colorValue: _color,
          )
        : initial.copyWith(
            name: name,
            bankName: bank,
            type: _type,
            initialBalanceCents: balance,
            colorValue: _color,
          );
    await widget.services.accounts.upsert(account);
    if (mounted) {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return AlertDialog(
      scrollable: true,
      title: Text(widget.initial == null ? 'Nova conta' : 'Editar conta'),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: _formMaxWidth),
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
              RawAutocomplete<String>(
                textEditingController: _bank,
                focusNode: _bankFocus,
                optionsBuilder: (value) => _bankNames.where(
                  (b) =>
                      b.toLowerCase().contains(value.text.trim().toLowerCase()),
                ),
                fieldViewBuilder: (ctx, controller, focusNode, onSubmit) =>
                    TextFormField(
                      controller: controller,
                      focusNode: focusNode,
                      decoration: const InputDecoration(
                        labelText: 'Banco',
                        helperText: 'Vazio para dinheiro ou carteira',
                      ),
                      onFieldSubmitted: (_) => onSubmit(),
                    ),
                optionsViewBuilder: (ctx, onSelected, options) => Align(
                  alignment: Alignment.topLeft,
                  child: Material(
                    elevation: 2,
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxHeight: 200),
                      child: ListView.builder(
                        padding: EdgeInsets.zero,
                        shrinkWrap: true,
                        itemCount: options.length,
                        itemBuilder: (_, i) {
                          final option = options.elementAt(i);
                          return ListTile(
                            dense: true,
                            title: Text(option),
                            onTap: () => onSelected(option),
                          );
                        },
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: AppSpace.md),
              DropdownButtonFormField<AccountType>(
                initialValue: _type,
                decoration: const InputDecoration(labelText: 'Tipo'),
                items: [
                  for (final t in AccountType.values)
                    DropdownMenuItem(
                      value: t,
                      child: Text(accountTypeLabel(t)),
                    ),
                ],
                onChanged: (v) {
                  if (v != null) {
                    setState(() => _type = v);
                  }
                },
              ),
              const SizedBox(height: AppSpace.md),
              TextFormField(
                controller: _balance,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                  signed: true,
                ),
                decoration: const InputDecoration(
                  labelText: 'Saldo inicial',
                  helperText: 'Pode ser negativo',
                ),
                validator: (v) => parseMoney(v ?? '') == null
                    ? 'Informe um valor válido'
                    : null,
              ),
              const SizedBox(height: AppSpace.lg),
              Text('Cor', style: textTheme.bodySmall),
              const SizedBox(height: AppSpace.sm),
              Wrap(
                spacing: AppSpace.sm,
                runSpacing: AppSpace.sm,
                children: [
                  for (final value in kEntityColors)
                    _ColorDot(
                      color: Color(value),
                      selected: value == _color,
                      onTap: () => setState(() => _color = value),
                    ),
                ],
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

/// Valor em reais sem prefixo, para o campo de texto: -1234 → "-12,34".
String _plainMoney(int cents) =>
    (cents / 100).toStringAsFixed(2).replaceAll('.', ',');

class _ColorDot extends StatelessWidget {
  const _ColorDot({
    required this.color,
    required this.selected,
    required this.onTap,
  });

  final Color color;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            border: Border.all(
              color: selected ? context.colors.textPrimary : color,
              width: 2,
            ),
          ),
          child: selected
              ? Icon(Icons.check, size: 16, color: context.colors.surface)
              : null,
        ),
      ),
    );
  }
}
