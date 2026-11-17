import 'package:flutter/material.dart';

import '../../../app/app_scope.dart';
import '../../../app/bootstrap.dart';
import '../../../core/models/app_settings.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/utils/date_utils.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/utils/id.dart';
import '../../../core/widgets/widgets.dart';
import '../../categories/domain/transaction_category.dart';
import '../../transactions/domain/transaction.dart';
import '../../transactions/presentation/tag_widgets.dart';
import '../domain/recurring_rule.dart';

const _accountPrefix = 'acc:';
const _cardPrefix = 'card:';

/// Rótulo da frequência na UI.
String frequencyLabel(Frequency f) => switch (f) {
  Frequency.weekly => 'Semanal',
  Frequency.monthly => 'Mensal',
  Frequency.yearly => 'Anual',
};

/// Abre o formulário de recorrência; [initial] preenche para edição.
Future<void> showRecurringForm(BuildContext context, {RecurringRule? initial}) {
  final services = AppScope.of(context);
  return showDialog<void>(
    context: context,
    builder: (_) => _RecurringDialog(services: services, initial: initial),
  );
}

class _RecurringDialog extends StatefulWidget {
  const _RecurringDialog({required this.services, this.initial});

  final AppServices services;
  final RecurringRule? initial;

  @override
  State<_RecurringDialog> createState() => _RecurringDialogState();
}

class _RecurringDialogState extends State<_RecurringDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _description;
  late final TextEditingController _amount;
  late TransactionType _type;
  late Frequency _frequency;
  late DateTime _start;
  late DateTime _end;
  late bool _hasEnd;
  late bool _subscription;
  late bool _boleto;
  // Origem como 'acc:<id>' ou 'card:<id>'; null até o usuário escolher.
  String? _originKey;
  String? _categoryId;
  late List<String> _tags;
  String? _endError;
  late final String _id;
  bool _saving = false;

  bool get _isExpense => _type == TransactionType.expense;
  bool get _ultra => widget.services.settings.value.mode == AppMode.ultra;
  bool get _isAccount => _originKey?.startsWith(_accountPrefix) ?? false;
  String get _originId => _originKey!.split(':').last;
  CategoryKind get _kind =>
      _isExpense ? CategoryKind.expense : CategoryKind.income;

  @override
  void initState() {
    super.initState();
    final r = widget.initial;
    _id = r?.id ?? newId();
    _description = TextEditingController(text: r?.description);
    _amount = TextEditingController(
      text: r == null
          ? null
          : (r.amountCents / 100).toStringAsFixed(2).replaceAll('.', ','),
    );
    _type = r?.type ?? TransactionType.expense;
    _frequency = r?.frequency ?? Frequency.monthly;
    _start = r?.startDate ?? widget.services.ledger.today;
    _hasEnd = r?.endDate != null;
    _end = r?.endDate ?? addMonthsClamped(_start, 12);
    _subscription = r?.isSubscription ?? false;
    _boleto = r?.isBoleto ?? false;
    _originKey = r == null ? null : _keyOf(r);
    _categoryId = _validCategory(r?.categoryId);
    _tags = r?.tags ?? const [];
  }

  @override
  void dispose() {
    _description.dispose();
    _amount.dispose();
    super.dispose();
  }

  static String? _keyOf(RecurringRule r) {
    if (r.accountId != null) {
      return '$_accountPrefix${r.accountId}';
    }
    if (r.cardId != null) {
      return '$_cardPrefix${r.cardId}';
    }
    return null;
  }

  /// Categoria só vale se existe e é do mesmo tipo (evita valor fora dos itens do dropdown).
  String? _validCategory(String? id) {
    final c = id == null ? null : widget.services.categories.byId(id);
    return c != null && c.kind == _kind ? id : null;
  }

  void _setType(TransactionType type) {
    setState(() {
      _type = type;
      _categoryId = _validCategory(_categoryId);
      if (!_isExpense) {
        _subscription = false;
        _boleto = false;
      }
    });
  }

  List<DropdownMenuItem<String>> _originItems() {
    final s = widget.services;
    // Arquivados saem da lista, exceto a origem atual (senão o dropdown quebra na edição).
    return [
      for (final a in s.accounts.all)
        if (!a.archived || '$_accountPrefix${a.id}' == _originKey)
          DropdownMenuItem(
            value: '$_accountPrefix${a.id}',
            child: Text('${a.bankName} · ${a.name}'),
          ),
      for (final c in s.cards.all)
        if (!c.archived || '$_cardPrefix${c.id}' == _originKey)
          DropdownMenuItem(
            value: '$_cardPrefix${c.id}',
            child: Text('${c.bankName} · ${c.name}'),
          ),
    ];
  }

  Future<void> _save() async {
    if (_saving) {
      return;
    }
    final endError = _hasEnd && _end.isBefore(_start)
        ? 'A data de término é anterior ao início.'
        : null;
    setState(() => _endError = endError);
    if (endError != null || !(_formKey.currentState?.validate() ?? false)) {
      return;
    }
    final s = widget.services;
    final initial = widget.initial;
    final rule = RecurringRule(
      id: _id,
      description: _description.text.trim(),
      type: _type,
      amountCents: parseMoney(_amount.text)!,
      categoryId: _categoryId,
      // No Simples o campo some, mas as tags da regra seguem para o save.
      tags: _tags,
      accountId: _isAccount ? _originId : null,
      cardId: _isAccount ? null : _originId,
      frequency: _frequency,
      startDate: _start,
      endDate: _hasEnd ? _end : null,
      isSubscription: _isExpense && _subscription,
      isBoleto: _isExpense && _isAccount && _boleto,
      active: initial?.active ?? true,
      materializedUntil: initial?.materializedUntil,
    );
    setState(() => _saving = true);
    try {
      // Início antecipado: as ocorrências entre o novo e o antigo início nunca foram geradas.
      // Ids determinísticos (regra + data) impedem duplicar as já existentes.
      if (initial != null && rule.startDate.isBefore(initial.startDate)) {
        final start = rule.startDate;
        await s.recurring.upsert(
          rule.copyWith(
            materializedUntil: DateTime(start.year, start.month, start.day - 1),
          ),
        );
        await materializeRecurring(s);
      } else {
        await s.recurring.upsert(rule);
        // Regra nova com início no passado: gera já as ocorrências vencidas.
        if (initial == null && !rule.startDate.isAfter(s.ledger.today)) {
          await materializeRecurring(s);
        }
      }
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
    final tree = widget.services.ledger.categoryTree;
    final c = context.colors;
    return AlertDialog(
      title: Text(
        widget.initial == null ? 'Nova recorrência' : 'Editar recorrência',
      ),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            spacing: AppSpace.md,
            children: [
              TextFormField(
                controller: _description,
                decoration: const InputDecoration(labelText: 'Descrição'),
                validator: (v) => (v == null || v.trim().isEmpty)
                    ? 'Informe a descrição'
                    : null,
              ),
              SegmentedButton<TransactionType>(
                segments: const [
                  ButtonSegment(
                    value: TransactionType.expense,
                    label: Text('Despesa'),
                  ),
                  ButtonSegment(
                    value: TransactionType.income,
                    label: Text('Receita'),
                  ),
                ],
                selected: {_type},
                onSelectionChanged: (sel) => _setType(sel.first),
              ),
              MoneyField(controller: _amount),
              DropdownButtonFormField<String>(
                initialValue: _originKey,
                decoration: const InputDecoration(labelText: 'Origem'),
                hint: const Text('Selecione a conta ou cartão'),
                items: _originItems(),
                validator: (v) => v == null ? 'Selecione a origem' : null,
                onChanged: (v) => setState(() {
                  _originKey = v;
                  if (!_isAccount) {
                    _boleto = false;
                  }
                }),
              ),
              DropdownButtonFormField<String?>(
                key: ValueKey(_type),
                initialValue: _categoryId,
                decoration: const InputDecoration(labelText: 'Categoria'),
                items: [
                  const DropdownMenuItem<String?>(
                    value: null,
                    child: Text('Sem categoria'),
                  ),
                  for (final cat in tree.options(_kind))
                    DropdownMenuItem<String?>(
                      value: cat.id,
                      child: Text(tree.label(cat.id)),
                    ),
                ],
                onChanged: (v) => setState(() => _categoryId = v),
              ),
              if (_ultra)
                TagField(
                  tags: _tags,
                  suggestions: widget.services.ledger.allTags,
                  onChanged: (v) => setState(() => _tags = v),
                ),
              DropdownButtonFormField<Frequency>(
                initialValue: _frequency,
                decoration: const InputDecoration(labelText: 'Frequência'),
                items: [
                  for (final f in Frequency.values)
                    DropdownMenuItem(value: f, child: Text(frequencyLabel(f))),
                ],
                onChanged: (v) {
                  if (v != null) {
                    setState(() => _frequency = v);
                  }
                },
              ),
              DateField(
                label: 'Data de início',
                value: _start,
                onChanged: (d) => setState(() => _start = d),
              ),
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                controlAffinity: ListTileControlAffinity.leading,
                title: const Text('Tem data de término'),
                value: _hasEnd,
                onChanged: (v) => setState(() => _hasEnd = v ?? false),
              ),
              if (_hasEnd)
                DateField(
                  label: 'Data de término',
                  value: _end,
                  onChanged: (d) => setState(() {
                    _end = d;
                    _endError = null;
                  }),
                ),
              if (_endError != null)
                Text(_endError!, style: TextStyle(color: c.danger)),
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                controlAffinity: ListTileControlAffinity.leading,
                title: const Text('Assinatura'),
                value: _isExpense && _subscription,
                onChanged: _isExpense
                    ? (v) => setState(() => _subscription = v ?? false)
                    : null,
              ),
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                controlAffinity: ListTileControlAffinity.leading,
                title: const Text('Boleto'),
                subtitle: _isAccount
                    ? null
                    : const Text('Disponível só para conta'),
                value: _isExpense && _isAccount && _boleto,
                onChanged: _isExpense && _isAccount
                    ? (v) => setState(() => _boleto = v ?? false)
                    : null,
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
          onPressed: _saving ? null : _save,
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
}
