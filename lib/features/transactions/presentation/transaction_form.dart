import 'package:flutter/material.dart';

import '../../../app/app_scope.dart';
import '../../../core/models/app_settings.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/utils/id.dart';
import '../../../core/widgets/widgets.dart';
import '../../cards/domain/payment_card.dart';
import '../../categories/domain/transaction_category.dart';
import '../../importing/domain/categorizer.dart';
import '../domain/installments.dart';
import '../domain/transaction.dart';
import 'tag_widgets.dart';
import 'transaction_filters.dart';

const _maxInstallments = 48;

String _suggestionLabel(SuggestionSource source) => switch (source) {
  SuggestionSource.rule => 'Sugerida por regra',
  SuggestionSource.bank => 'Sugerida pelo banco',
  SuggestionSource.history => 'Sugerida pelo histórico',
  SuggestionSource.dictionary => 'Sugerida pelo dicionário',
};

/// Abre o formulário de transação (nova ou edição).
/// Transferência e pagamento de fatura editados mantêm o tipo travado.
Future<void> showTransactionForm(BuildContext context, {Transaction? initial}) {
  final services = AppScope.of(context);
  return showDialog<void>(
    context: context,
    builder: (_) =>
        _TransactionFormDialog(services: services, initial: initial),
  );
}

CategoryKind _kindOf(TransactionType type) =>
    type == TransactionType.income ? CategoryKind.income : CategoryKind.expense;

class _TransactionFormDialog extends StatefulWidget {
  const _TransactionFormDialog({required this.services, this.initial});

  final AppServices services;
  final Transaction? initial;

  @override
  State<_TransactionFormDialog> createState() => _TransactionFormDialogState();
}

class _TransactionFormDialogState extends State<_TransactionFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _amount;
  late final TextEditingController _description;
  late final TextEditingController _notes;
  late final TextEditingController _installments;
  // Ids gerados uma vez: duplo clique regrava o mesmo registro, não cria outro.
  late final String _id;
  late final String _groupId;
  late TransactionType _type;
  late DateTime _date;
  String? _categoryId;
  // Usuário escolheu (ou já tinha) categoria: a descrição não sobrescreve mais.
  late bool _categoryTouched;
  CategorizationResult? _suggestion;
  // Tags só aparecem no Ultra; no Simples são preservadas ao salvar.
  late List<String> _tags;
  // Usuário mexeu nas tags: a regra não sobrescreve mais.
  bool _tagsTouched = false;
  // Tags vieram da regra (helper 'Tags da regra').
  bool _tagsFromRule = false;
  // renameTo da regra, só em lançamento novo e só se difere do texto digitado.
  String? _rename;
  // Usuário tocou 'Manter como digitado': a descrição não é trocada até mudar de novo.
  bool _renameKept = false;
  String? _accountId;
  String? _cardId;
  late bool _planned;
  late bool _boleto;
  bool _saving = false;

  bool get _isNew => widget.initial == null;

  bool get _ultra => widget.services.settings.value.mode == AppMode.ultra;

  bool get _locked {
    final type = widget.initial?.type;
    return type == TransactionType.transfer ||
        type == TransactionType.invoicePayment;
  }

  /// Parcela existente: só valor, descrição, categoria e notas são editáveis.
  bool get _fixed => widget.initial?.isInstallment ?? false;

  PaymentCard? get _card =>
      _cardId == null ? null : widget.services.ledger.cardsById[_cardId];

  /// Parcelamento só para despesa nova em cartão de crédito.
  bool get _installmentsEnabled =>
      _isNew &&
      _type == TransactionType.expense &&
      _card?.kind == CardKind.credit;

  String? get _originKey => _cardId != null
      ? 'card:$_cardId'
      : (_accountId != null ? 'acc:$_accountId' : null);

  @override
  void initState() {
    super.initState();
    final init = widget.initial;
    final s = widget.services;
    _id = init?.id ?? newId();
    _groupId = newId();
    _type = init?.type ?? TransactionType.expense;
    _date = init?.date ?? s.ledger.today;
    _amount = TextEditingController(
      text: init == null
          ? ''
          : formatMoney(init.amountCents).replaceFirst('R\$ ', ''),
    );
    _description = TextEditingController(text: init?.description ?? '');
    _notes = TextEditingController(text: init?.notes ?? '');
    _installments = TextEditingController(text: '1');
    // Referências órfãs (conta/cartão/categoria apagados) viram null: evita assert do Dropdown.
    _categoryId = _validCategory(init?.categoryId);
    _categoryTouched = init?.categoryId != null;
    _tags = init?.tags ?? const [];
    final accountId = init?.accountId;
    _accountId = accountId != null && s.accounts.byId(accountId) != null
        ? accountId
        : null;
    final cardId = init?.cardId;
    _cardId = cardId != null && s.cards.byId(cardId) != null ? cardId : null;
    _planned = init?.isPlanned ?? false;
    _boleto = init?.isBoleto ?? false;
  }

  @override
  void dispose() {
    _amount.dispose();
    _description.dispose();
    _notes.dispose();
    _installments.dispose();
    super.dispose();
  }

  /// Categoria só vale se existe e é do tipo da transação.
  String? _validCategory(String? id) {
    final c = id == null ? null : widget.services.categories.byId(id);
    return c != null && c.kind == _kindOf(_type) ? id : null;
  }

  /// Ordem de dropdown da árvore: cada principal seguida das subcategorias.
  List<TransactionCategory> _categoriesFor(AppServices s) =>
      s.ledger.categoryTree.options(_kindOf(_type));

  void _setType(TransactionType type) {
    setState(() {
      _type = type;
      _categoryId = _validCategory(_categoryId);
      // Sugestão era do tipo anterior: sem ela, o helper não some junto com a categoria limpa.
      _suggestion = null;
    });
  }

  /// Sugere categoria e tags (Ultra) pela descrição, só enquanto o usuário não escolheu cada uma.
  void _suggestCategory(String text) {
    if (_locked) {
      return;
    }
    final s = widget.services;
    final r = s.ledger.categorizer.categorize(
      text,
      isIncome: _type == TransactionType.income,
    );
    final id = r.categoryId;
    final valid = id != null && _categoriesFor(s).any((cat) => cat.id == id);
    final rename = r.renamedDescription?.trim();
    setState(() {
      _renameKept = false;
      _rename =
          _isNew && rename != null && rename.isNotEmpty && rename != text.trim()
          ? rename
          : null;
      if (!_categoryTouched) {
        if (valid) {
          _categoryId = id;
          _suggestion = r;
        } else {
          // Categoria veio da sugestão que sumiu (o usuário não escolheu): limpa junto.
          if (_suggestion != null) {
            _categoryId = null;
          }
          _suggestion = null;
        }
      }
      // No Simples o campo de tags some, mas a regra ainda vale ao salvar.
      if (_isNew && !_tagsTouched) {
        _tags = r.tags;
        _tagsFromRule = r.tags.isNotEmpty;
      }
    });
  }

  /// Aviso de rename da regra, com a saída 'Manter como digitado'.
  Widget _renameHint(BuildContext context, String renamed) => Row(
    children: [
      Expanded(
        child: Text(
          'Será salvo como "$renamed" (regra)',
          key: const ValueKey('form-rename-hint'),
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ),
      TextButton(
        key: const ValueKey('form-rename-keep'),
        onPressed: () => setState(() => _renameKept = true),
        child: const Text('Manter como digitado'),
      ),
    ],
  );

  void _setOrigin(String? key) {
    setState(() {
      _accountId = key != null && key.startsWith('acc:')
          ? key.substring(4)
          : null;
      _cardId = key != null && key.startsWith('card:')
          ? key.substring(5)
          : null;
    });
  }

  List<DropdownMenuItem<String>> _originItems(AppServices s) => [
    for (final a in s.accounts.all)
      if (!a.archived || a.id == _accountId)
        DropdownMenuItem(
          value: 'acc:${a.id}',
          child: Text(accountOptionLabel(a)),
        ),
    for (final c in s.cards.all)
      if (!c.archived || c.id == _cardId)
        DropdownMenuItem(
          value: 'card:${c.id}',
          child: Text(cardOptionLabel(c)),
        ),
  ];

  String? _validateInstallments(String? text) {
    final n = int.tryParse(text?.trim() ?? '');
    if (n == null || n < 1 || n > _maxInstallments) {
      return 'Entre 1 e $_maxInstallments';
    }
    final cents = parseMoney(_amount.text) ?? 0;
    return n > cents ? 'Valor insuficiente para $n parcelas' : null;
  }

  Future<void> _save() async {
    if (_saving || !(_formKey.currentState?.validate() ?? false)) {
      return;
    }
    final cents = parseMoney(_amount.text);
    if (cents == null) {
      return;
    }
    final s = widget.services;
    final init = widget.initial;
    final notes = _notes.text.trim();
    final hasAccount = _accountId != null;
    final typed = _description.text.trim();
    final rename = _renameKept ? null : _rename;
    final tx = Transaction(
      id: _id,
      type: _type,
      amountCents: cents,
      date: _date,
      description: rename ?? typed,
      categoryId: _categoryId,
      accountId: _accountId,
      cardId: _cardId,
      toAccountId: init?.toAccountId,
      status: _planned && hasAccount
          ? TransactionStatus.planned
          : TransactionStatus.paid,
      isBoleto: _boleto && hasAccount,
      invoiceKey: init?.invoiceKey,
      installmentGroupId: init?.installmentGroupId,
      installmentIndex: init?.installmentIndex,
      installmentCount: init?.installmentCount,
      recurringId: init?.recurringId,
      notes: notes.isEmpty ? null : notes,
      externalId: init?.externalId,
      importedDescription: rename != null ? typed : init?.importedDescription,
      tags: _tags,
    );
    setState(() => _saving = true);
    try {
      final count = _installmentsEnabled
          ? int.parse(_installments.text.trim())
          : 1;
      if (count > 1) {
        await s.transactions.upsertAll(
          buildInstallments(base: tx, count: count, groupId: _groupId),
        );
      } else {
        await s.transactions.upsert(tx);
      }
      if (!mounted) {
        return;
      }
      Navigator.of(context).pop();
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
    final s = widget.services;
    final init = widget.initial;
    final locked = _locked;
    final fixed = _fixed;
    final source = _suggestion?.source;
    final c = context.colors;
    final narrow = MediaQuery.sizeOf(context).width < 600;
    return Dialog(
      insetPadding: narrow ? const EdgeInsets.all(AppSpace.lg) : null,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(AppSpace.xl),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  _isNew ? 'Nova transação' : 'Editar transação',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: AppSpace.lg),
                if (locked)
                  Text(
                    _type == TransactionType.transfer
                        ? 'Transferência'
                        : 'Pagamento de fatura',
                    style: Theme.of(context).textTheme.titleMedium,
                  )
                else
                  Align(
                    alignment: Alignment.centerLeft,
                    child: SegmentedButton<TransactionType>(
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
                      onSelectionChanged: fixed
                          ? null
                          : (sel) => _setType(sel.first),
                    ),
                  ),
                const SizedBox(height: AppSpace.md),
                MoneyField(controller: _amount),
                const SizedBox(height: AppSpace.md),
                TextFormField(
                  controller: _description,
                  decoration: const InputDecoration(labelText: 'Descrição'),
                  onChanged: _suggestCategory,
                  validator: (v) =>
                      (v ?? '').trim().isEmpty ? 'Informe a descrição' : null,
                ),
                if (_rename != null && !_renameKept)
                  _renameHint(context, _rename!),
                const SizedBox(height: AppSpace.md),
                AbsorbPointer(
                  absorbing: fixed,
                  child: DateField(
                    value: _date,
                    onChanged: (d) => setState(() => _date = d),
                  ),
                ),
                if (!locked) ...[
                  const SizedBox(height: AppSpace.md),
                  DropdownButtonFormField<String>(
                    key: const ValueKey('form-origem'),
                    isExpanded: true,
                    initialValue: _originKey,
                    decoration: const InputDecoration(
                      labelText: 'Conta ou cartão',
                    ),
                    items: _originItems(s),
                    onChanged: fixed ? null : _setOrigin,
                    validator: (v) =>
                        v == null ? 'Escolha a conta ou cartão' : null,
                  ),
                  const SizedBox(height: AppSpace.md),
                  DropdownButtonFormField<String?>(
                    // Chave com a categoria: recria o campo quando a sugestão troca o valor.
                    key: ValueKey('form-categoria-${_type.name}-$_categoryId'),
                    isExpanded: true,
                    initialValue: _categoryId,
                    decoration: InputDecoration(
                      labelText: 'Categoria',
                      helperText: source == null
                          ? null
                          : _suggestionLabel(source),
                    ),
                    items: [
                      const DropdownMenuItem<String?>(
                        value: null,
                        child: Text('Sem categoria'),
                      ),
                      for (final cat in _categoriesFor(s))
                        DropdownMenuItem<String?>(
                          value: cat.id,
                          child: Text(s.ledger.categoryTree.label(cat.id)),
                        ),
                    ],
                    onChanged: (v) => setState(() {
                      _categoryId = v;
                      _categoryTouched = true;
                      _suggestion = null;
                    }),
                  ),
                ],
                if (!locked && _ultra) ...[
                  const SizedBox(height: AppSpace.md),
                  TagField(
                    tags: _tags,
                    suggestions: s.ledger.allTags,
                    helperText: _tagsFromRule ? 'Tags da regra' : null,
                    onChanged: (v) => setState(() {
                      _tags = v;
                      _tagsTouched = true;
                      _tagsFromRule = false;
                    }),
                  ),
                ],
                if (_installmentsEnabled) ...[
                  const SizedBox(height: AppSpace.md),
                  TextFormField(
                    controller: _installments,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Parcelas',
                      helperText: 'Uma transação mensal por parcela (1 a 48)',
                    ),
                    validator: _validateInstallments,
                  ),
                ],
                if (init != null && init.isInstallment) ...[
                  const SizedBox(height: AppSpace.md),
                  Text(
                    'Parcela ${init.installmentIndex}/${init.installmentCount}'
                    ' — data e cartão seguem a compra original.',
                    style: Theme.of(
                      context,
                    ).textTheme.bodySmall?.copyWith(color: c.textSecondary),
                  ),
                ],
                if (!locked && _accountId != null) ...[
                  CheckboxListTile(
                    value: _planned,
                    onChanged: fixed
                        ? null
                        : (v) => setState(() => _planned = v ?? false),
                    title: const Text('Provisionado (ainda não pago)'),
                    controlAffinity: ListTileControlAffinity.leading,
                    contentPadding: EdgeInsets.zero,
                    dense: true,
                  ),
                  CheckboxListTile(
                    value: _boleto,
                    onChanged: fixed
                        ? null
                        : (v) => setState(() => _boleto = v ?? false),
                    title: const Text('Boleto'),
                    controlAffinity: ListTileControlAffinity.leading,
                    contentPadding: EdgeInsets.zero,
                    dense: true,
                  ),
                ],
                const SizedBox(height: AppSpace.md),
                TextFormField(
                  controller: _notes,
                  maxLines: 2,
                  decoration: const InputDecoration(
                    labelText: 'Notas (opcional)',
                  ),
                ),
                const SizedBox(height: AppSpace.xl),
                Wrap(
                  alignment: WrapAlignment.end,
                  spacing: AppSpace.sm,
                  runSpacing: AppSpace.sm,
                  children: [
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
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
