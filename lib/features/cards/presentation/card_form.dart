import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../app/app_scope.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_palettes.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/utils/id.dart';
import '../../../core/widgets/widgets.dart';
import '../../accounts/domain/account.dart';
import '../domain/payment_card.dart';

/// Abre o formulário de cartão: novo, ou editando [initial].
Future<void> showCardForm(BuildContext context, {PaymentCard? initial}) {
  return showDialog<void>(
    context: context,
    builder: (_) => _CardForm(initial: initial),
  );
}

String cardBrandLabel(CardBrand brand) => switch (brand) {
  CardBrand.visa => 'Visa',
  CardBrand.mastercard => 'Mastercard',
  CardBrand.elo => 'Elo',
  CardBrand.amex => 'Amex',
  CardBrand.hipercard => 'Hipercard',
  CardBrand.other => 'Outro',
};

/// Rótulo de conta em listas de seleção: "Conta corrente · Banco Alfa".
String accountOptionLabel(Account a) =>
    a.bankName.isEmpty ? a.name : '${a.name} · ${a.bankName}';

class _CardForm extends StatefulWidget {
  const _CardForm({this.initial});

  final PaymentCard? initial;

  @override
  State<_CardForm> createState() => _CardFormState();
}

class _CardFormState extends State<_CardForm> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _name;
  late final TextEditingController _bank;
  late final TextEditingController _last4;
  late final TextEditingController _limit;
  late final TextEditingController _closing;
  late final TextEditingController _due;
  late CardBrand _brand;
  late CardKind _kind;
  late String? _accountId;
  late int _color;
  late final String _id;
  bool _saving = false;

  /// Cartão com transações: tipo travado e troca de dias reorganiza faturas.
  bool _hasTransactions(AppServices s) {
    final id = widget.initial?.id;
    return id != null && s.transactions.all.any((t) => t.cardId == id);
  }

  bool _reorganizes(AppServices s) {
    final old = widget.initial;
    return old != null &&
        _kind == CardKind.credit &&
        old.kind == CardKind.credit &&
        _hasTransactions(s) &&
        (int.tryParse(_closing.text.trim()) != old.closingDay ||
            int.tryParse(_due.text.trim()) != old.dueDay);
  }

  @override
  void initState() {
    super.initState();
    final initial = widget.initial;
    _id = initial?.id ?? newId();
    final credit = initial?.kind == CardKind.credit;
    _name = TextEditingController(text: initial?.name ?? '');
    _bank = TextEditingController(text: initial?.bankName ?? '');
    _last4 = TextEditingController(text: initial?.last4 ?? '');
    _limit = TextEditingController(
      text: initial == null || initial.limitCents == 0
          ? ''
          : formatMoney(initial.limitCents).replaceFirst('R\$ ', ''),
    );
    _closing = TextEditingController(
      text: credit ? '${initial!.closingDay}' : '',
    );
    _due = TextEditingController(text: credit ? '${initial!.dueDay}' : '');
    _brand = initial?.brand ?? CardBrand.other;
    _kind = initial?.kind ?? CardKind.credit;
    _accountId = initial?.paymentAccountId;
    _color = initial?.colorValue ?? kEntityColors.first;
  }

  @override
  void dispose() {
    for (final c in [_name, _bank, _last4, _limit, _closing, _due]) {
      c.dispose();
    }
    super.dispose();
  }

  String? _limitValidator(int? cents) {
    final empty = _limit.text.trim().isEmpty;
    return empty || (cents != null && cents >= 0)
        ? null
        : 'Informe um valor válido';
  }

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final isCredit = _kind == CardKind.credit;
    final bankNames = {
      for (final c in s.cards.all) c.bankName.trim(),
      for (final a in s.accounts.all) a.bankName.trim(),
    }.where((b) => b.isNotEmpty).toList()..sort();
    final accounts = s.accounts.all
        .where((a) => !a.archived || a.id == _accountId)
        .toList();
    final accountValue = accounts.any((a) => a.id == _accountId)
        ? _accountId
        : null;
    final kindLocked = _hasTransactions(s);
    return AlertDialog(
      title: Text(widget.initial == null ? 'Novo cartão' : 'Editar cartão'),
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
                decoration: const InputDecoration(labelText: 'Nome do cartão'),
                validator: (v) =>
                    (v ?? '').trim().isEmpty ? 'Campo obrigatório' : null,
              ),
              const SizedBox(height: AppSpace.md),
              Autocomplete<String>(
                textEditingController: _bank,
                optionsBuilder: (value) => _bankOptions(value.text, bankNames),
                fieldViewBuilder: (context, controller, focusNode, onSubmit) =>
                    TextFormField(
                      controller: controller,
                      focusNode: focusNode,
                      decoration: const InputDecoration(
                        labelText: 'Banco (opcional)',
                      ),
                      onFieldSubmitted: (_) => onSubmit(),
                    ),
              ),
              const SizedBox(height: AppSpace.md),
              DropdownButtonFormField<CardBrand>(
                initialValue: _brand,
                decoration: const InputDecoration(labelText: 'Bandeira'),
                items: [
                  for (final b in CardBrand.values)
                    DropdownMenuItem(value: b, child: Text(cardBrandLabel(b))),
                ],
                onChanged: (v) => setState(() => _brand = v ?? _brand),
              ),
              const SizedBox(height: AppSpace.md),
              SegmentedButton<CardKind>(
                segments: const [
                  ButtonSegment(value: CardKind.credit, label: Text('Crédito')),
                  ButtonSegment(value: CardKind.debit, label: Text('Débito')),
                ],
                selected: {_kind},
                onSelectionChanged: kindLocked
                    ? null
                    : (sel) => setState(() => _kind = sel.first),
              ),
              const SizedBox(height: AppSpace.md),
              TextFormField(
                controller: _last4,
                keyboardType: TextInputType.number,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(4),
                ],
                decoration: const InputDecoration(
                  labelText: 'Últimos 4 dígitos',
                ),
                validator: (v) => RegExp(r'^\d{4}$').hasMatch(v?.trim() ?? '')
                    ? null
                    : 'Informe os 4 dígitos',
              ),
              if (isCredit) ...[
                const SizedBox(height: AppSpace.md),
                MoneyField(
                  controller: _limit,
                  label: 'Limite',
                  validator: _limitValidator,
                ),
                const SizedBox(height: AppSpace.md),
                Row(
                  children: [
                    Expanded(child: _dayField(_closing, 'Dia de fechamento')),
                    const SizedBox(width: AppSpace.md),
                    Expanded(child: _dayField(_due, 'Dia de vencimento')),
                  ],
                ),
                if (_reorganizes(s)) ...[
                  const SizedBox(height: AppSpace.sm),
                  Text(
                    'Mudar fechamento/vencimento reorganiza as faturas passadas deste cartão.',
                    style: TextStyle(
                      fontSize: 12,
                      color: context.colors.warning,
                    ),
                  ),
                ],
              ],
              const SizedBox(height: AppSpace.md),
              DropdownButtonFormField<String?>(
                initialValue: accountValue,
                decoration: InputDecoration(
                  labelText: isCredit
                      ? 'Conta que paga a fatura (opcional)'
                      : 'Conta debitada',
                ),
                items: [
                  const DropdownMenuItem<String?>(
                    value: null,
                    child: Text('Nenhuma'),
                  ),
                  for (final a in accounts)
                    DropdownMenuItem<String?>(
                      value: a.id,
                      child: Text(accountOptionLabel(a)),
                    ),
                ],
                onChanged: (v) => setState(() => _accountId = v),
                validator: (v) =>
                    !isCredit && v == null ? 'Escolha a conta debitada' : null,
              ),
              const SizedBox(height: AppSpace.lg),
              Text(
                'Cor',
                style: TextStyle(
                  fontSize: 12,
                  color: context.colors.textSecondary,
                ),
              ),
              const SizedBox(height: AppSpace.sm),
              Wrap(
                spacing: AppSpace.sm,
                runSpacing: AppSpace.sm,
                children: [
                  for (final color in kEntityColors)
                    _ColorDot(
                      color: color,
                      selected: color == _color,
                      onTap: () => setState(() => _color = color),
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
        FilledButton(
          onPressed: _saving ? null : () => _save(s),
          child: _saving
              ? const SizedBox.square(
                  dimension: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Salvar'),
        ),
      ],
    );
  }

  Widget _dayField(TextEditingController controller, String label) {
    return TextFormField(
      controller: controller,
      onChanged: (_) => setState(() {}),
      keyboardType: TextInputType.number,
      inputFormatters: [
        FilteringTextInputFormatter.digitsOnly,
        LengthLimitingTextInputFormatter(2),
      ],
      decoration: InputDecoration(labelText: label),
      validator: (v) {
        final day = int.tryParse(v ?? '');
        return day != null && day >= 1 && day <= 31 ? null : 'De 1 a 31';
      },
    );
  }

  Future<void> _save(AppServices s) async {
    if (_saving || !(_formKey.currentState?.validate() ?? false)) {
      return;
    }
    setState(() => _saving = true);
    try {
      if (_reorganizes(s)) {
        final ok = await confirmDialog(
          context,
          title: 'Reorganizar faturas?',
          message:
              'Mudar fechamento/vencimento reorganiza as faturas passadas deste cartão.',
          confirmLabel: 'Salvar',
        );
        if (!mounted) {
          return;
        }
        if (!ok) {
          setState(() => _saving = false);
          return;
        }
      }
      final credit = _kind == CardKind.credit;
      final old = widget.initial;
      await s.cards.upsert(
        PaymentCard(
          id: _id,
          name: _name.text.trim(),
          bankName: _bank.text.trim(),
          brand: _brand,
          kind: _kind,
          last4: _last4.text.trim(),
          // Em débito, limite e dias de fatura são ignorados (SPEC §4.2).
          limitCents: credit ? (parseMoney(_limit.text) ?? 0) : 0,
          closingDay: credit ? int.parse(_closing.text.trim()) : 1,
          dueDay: credit ? int.parse(_due.text.trim()) : 1,
          paymentAccountId: _accountId,
          colorValue: _color,
          archived: old?.archived ?? false,
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
}

Iterable<String> _bankOptions(String text, List<String> names) {
  final query = text.trim().toLowerCase();
  if (query.isEmpty) {
    return names;
  }
  return names.where((n) => n.toLowerCase().contains(query));
}

class _ColorDot extends StatelessWidget {
  const _ColorDot({
    required this.color,
    required this.selected,
    required this.onTap,
  });

  final int color;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      customBorder: const CircleBorder(),
      onTap: onTap,
      child: Container(
        width: 28,
        height: 28,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Color(color),
          border: selected
              ? Border.all(width: 3, color: context.colors.textPrimary)
              : null,
        ),
      ),
    );
  }
}
