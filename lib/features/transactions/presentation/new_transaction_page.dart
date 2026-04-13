import 'package:flutter/material.dart';

import '../../../core/services/repository_locator.dart';
import '../../../core/models/money.dart';
import '../../../core/models/app_mode.dart';
import '../../../core/services/app_mode_controller.dart';
import '../../../core/theme/app_theme.dart';
import '../../cards/domain/card_entity.dart';
import '../../categories/domain/category_entity.dart';
import '../domain/payment_method.dart';
import '../domain/recurrence_rule.dart';
import '../domain/transaction_entity.dart';
import '../domain/transaction_type.dart';

class NewTransactionPage extends StatefulWidget {
  const NewTransactionPage({super.key, this.initialTransaction});

  final TransactionEntity? initialTransaction;

  @override
  State<NewTransactionPage> createState() => _NewTransactionPageState();
}

class _NewTransactionPageState extends State<NewTransactionPage> {
  final _formKey               = GlobalKey<FormState>();
  final _descriptionController = TextEditingController();
  final _amountController      = TextEditingController();
  final _installmentController = TextEditingController();
  late DateTime        _selectedDate;
  late TransactionType _selectedType;
  late PaymentMethod   _selectedPaymentMethod;
  String?          _selectedCategoryId;
  String?          _selectedCardId;
  bool             _isProvisioned   = false;
  DateTime?        _provisionedDueDate;
  RecurrenceRule   _recurrenceRule  = RecurrenceRule.none;
  bool             _isSaving        = false;

  late final Future<List<dynamic>> _loadFuture;

  bool get _isEdit => widget.initialTransaction != null;

  @override
  void initState() {
    super.initState();
    final initial = widget.initialTransaction;
    if (initial != null) {
      _descriptionController.text = initial.description ?? '';
      _amountController.text      = initial.amount.amount.toStringAsFixed(2);
      _selectedDate               = initial.date;
      _selectedType               = initial.type;
      _selectedPaymentMethod      = initial.paymentMethod;
      _selectedCategoryId         = initial.categoryId;
      _selectedCardId             = initial.cardId;
      _isProvisioned              = initial.isProvisioned;
      _provisionedDueDate         = initial.provisionedDueDate;
      _recurrenceRule             = initial.recurrenceRule;
      if (initial.installmentCount != null) {
        _installmentController.text = initial.installmentCount.toString();
      }
    } else {
      _selectedDate          = DateTime.now();
      _selectedType          = TransactionType.expense;
      _selectedPaymentMethod = PaymentMethod.creditCard;
    }

    _loadFuture = Future.wait([
      RepositoryLocator.instance.categories.getAll(),
      RepositoryLocator.instance.cards.getAll(),
    ]).then((results) {
      final rawCategories = List<CategoryEntity>.from(results[0] as List);
      final seen          = <String>{};
      final categories =
          rawCategories.where((c) => seen.add(c.id)).toList(growable: false);
      if (_selectedCategoryId == null && categories.isNotEmpty) {
        setState(() => _selectedCategoryId = categories.first.id);
      }
      return [categories, results[1]];
    });
  }

  @override
  void dispose() {
    _descriptionController.dispose();
    _amountController.dispose();
    _installmentController.dispose();
    super.dispose();
  }

  Future<void> _pickDate({
    required DateTime initial,
    required void Function(DateTime) onPick,
    DateTime? firstDate,
    DateTime? lastDate,
  }) async {
    final now    = DateTime.now();
    final result = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: firstDate ?? DateTime(now.year - 1),
      lastDate:  lastDate  ?? DateTime(now.year + 3),
    );
    if (result != null) onPick(result);
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedCategoryId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Selecione uma categoria')),
      );
      return;
    }

    setState(() => _isSaving = true);

    final locator = RepositoryLocator.instance;
    final amount  = double.tryParse(
          _amountController.text.replaceAll(',', '.').trim(),
        ) ?? 0;
    final baseId  = widget.initialTransaction?.id ??
        DateTime.now().microsecondsSinceEpoch.toString();

    final isUltra       = AppModeController.instance.mode == AppMode.ultra;
    final effectiveCard = isUltra ? _selectedCardId : null;
    final installments  = isUltra
        ? int.tryParse(_installmentController.text.trim())
        : null;

    final tx = TransactionEntity(
      id:                 baseId,
      amount:             Money(amount),
      date:               _selectedDate,
      type:               _selectedType,
      paymentMethod:      _selectedPaymentMethod,
      description:        _descriptionController.text.isEmpty
          ? null
          : _descriptionController.text,
      categoryId:         _selectedCategoryId,
      cardId:             effectiveCard,
      isBoleto:           false,
      isProvisioned:      isUltra ? _isProvisioned : false,
      provisionedDueDate: (isUltra && _isProvisioned)
          ? _provisionedDueDate
          : null,
      installmentCount:   installments,
      recurrenceRule:     _recurrenceRule,
      recurrenceSourceId: null,
    );

    if (_isEdit) {
      await locator.transactions.update(tx);
    } else {
      await locator.transactions.add(tx);
    }

    if (!mounted) return;
    setState(() => _isSaving = false);
    Navigator.of(context).pop(true);
  }

  String _formatDate(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}'
      '/${d.month.toString().padLeft(2, '0')}'
      '/${d.year}';

  @override
  Widget build(BuildContext context) {
    final isUltra = AppModeController.instance.mode == AppMode.ultra;

    return Scaffold(
      appBar: AppBar(
        title: Text(_isEdit ? 'Editar transação' : 'Nova transação'),
      ),
      body: FutureBuilder<List<dynamic>>(
        future: _loadFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }

          final categories = snapshot.data != null
              ? List<CategoryEntity>.from(snapshot.data![0] as List)
              : <CategoryEntity>[];
          final cards = snapshot.data != null
              ? List<CardEntity>.from(snapshot.data![1] as List)
              : <CardEntity>[];

          // Guards: garante que o value dos dropdowns só é usado
          // quando o item correspondente já está na lista.
          final safeCategoryId = categories.any((c) => c.id == _selectedCategoryId)
              ? _selectedCategoryId
              : (categories.isNotEmpty ? categories.first.id : null);
          final safeCardId = cards.any((c) => c.id == _selectedCardId)
              ? _selectedCardId
              : null;

          // Sincroniza estado se necessário (ex: categoria resolvida pelo guard)
          if (safeCategoryId != _selectedCategoryId) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) setState(() => _selectedCategoryId = safeCategoryId);
            });
          }

          return Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Form(
              key: _formKey,
              child: ListView(
                children: [
                  TextFormField(
                    controller: _descriptionController,
                    decoration: const InputDecoration(
                      labelText: 'Descrição (opcional)',
                      hintText: 'Ex: Mercado, Cinema...',
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),

                  TextFormField(
                    controller: _amountController,
                    keyboardType: const TextInputType.numberWithOptions(
                        decimal: true),
                    decoration: const InputDecoration(
                      labelText: 'Valor',
                      prefixText: 'R\$ ',
                      hintText: '0.00',
                    ),
                    validator: (v) {
                      final text = v?.trim() ?? '';
                      if (text.isEmpty) return 'Informe um valor';
                      final parsed =
                          double.tryParse(text.replaceAll(',', '.'));
                      if (parsed == null || parsed <= 0) {
                        return 'Informe um valor válido';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: AppSpacing.md),

                  Row(
                    children: [
                      Expanded(
                        child: DropdownButtonFormField<TransactionType>(
                          value: _selectedType,
                          decoration:
                              const InputDecoration(labelText: 'Tipo'),
                          items: const [
                            DropdownMenuItem(
                              value: TransactionType.expense,
                              child: Text('Despesa'),
                            ),
                            DropdownMenuItem(
                              value: TransactionType.income,
                              child: Text('Receita'),
                            ),
                          ],
                          onChanged: (v) {
                            if (v != null)
                              setState(() => _selectedType = v);
                          },
                        ),
                      ),
                      const SizedBox(width: AppSpacing.md),
                      Expanded(
                        child: DropdownButtonFormField<PaymentMethod>(
                          value: _selectedPaymentMethod,
                          decoration: const InputDecoration(
                              labelText: 'Pagamento'),
                          items: const [
                            DropdownMenuItem(
                                value: PaymentMethod.creditCard,
                                child: Text('Crédito')),
                            DropdownMenuItem(
                                value: PaymentMethod.debitCard,
                                child: Text('Débito')),
                            DropdownMenuItem(
                                value: PaymentMethod.boleto,
                                child: Text('Boleto')),
                            DropdownMenuItem(
                                value: PaymentMethod.pix,
                                child: Text('Pix')),
                            DropdownMenuItem(
                                value: PaymentMethod.cash,
                                child: Text('Dinheiro')),
                            DropdownMenuItem(
                                value: PaymentMethod.other,
                                child: Text('Outro')),
                          ],
                          onChanged: (v) {
                            if (v != null)
                              setState(
                                  () => _selectedPaymentMethod = v);
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.md),

                  DropdownButtonFormField<String>(
                    value: safeCategoryId,
                    decoration:
                        const InputDecoration(labelText: 'Categoria'),
                    items: categories
                        .map((c) => DropdownMenuItem<String>(
                              value: c.id,
                              child: Text(c.name),
                            ))
                        .toList(),
                    onChanged: (v) =>
                        setState(() => _selectedCategoryId = v),
                  ),
                  const SizedBox(height: AppSpacing.xs),

                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Data da transação'),
                    subtitle: Text(_formatDate(_selectedDate)),
                    trailing: TextButton(
                      onPressed: () => _pickDate(
                        initial: _selectedDate,
                        onPick: (d) =>
                            setState(() => _selectedDate = d),
                      ),
                      child: const Text('Alterar'),
                    ),
                  ),

                  DropdownButtonFormField<RecurrenceRule>(
                    value: _recurrenceRule,
                    decoration: const InputDecoration(
                      labelText: 'Repetir',
                      prefixIcon: Icon(Icons.repeat_outlined),
                    ),
                    items: RecurrenceRule.values
                        .map((r) => DropdownMenuItem(
                              value: r,
                              child: Text(r.label),
                            ))
                        .toList(),
                    onChanged: (v) {
                      if (v != null)
                        setState(() => _recurrenceRule = v);
                    },
                  ),
                  if (_recurrenceRule != RecurrenceRule.none)
                    Padding(
                      padding: const EdgeInsets.only(
                          top: AppSpacing.xs,
                          left: AppSpacing.xs),
                      child: Row(
                        children: [
                          Icon(Icons.info_outline,
                              size: 14,
                              color: AppColors.primary),
                          const SizedBox(width: AppSpacing.xs),
                          Flexible(
                            child: Text(
                              'Ocorrências futuras serão criadas automaticamente ao abrir o app.',
                              style: AppText.secondary,
                            ),
                          ),
                        ],
                      ),
                    ),

                  if (isUltra) ...[
                    const Divider(height: AppSpacing.xxl),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.md,
                          vertical: AppSpacing.xs),
                      decoration: BoxDecoration(
                        color: AppColors.primarySubtle,
                        borderRadius:
                            BorderRadius.circular(AppRadius.full),
                      ),
                      child: Text(
                        'Modo Ultra',
                        style: AppText.badge
                            .copyWith(color: AppColors.primary),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.md),

                    DropdownButtonFormField<String>(
                      value: safeCardId,
                      decoration: const InputDecoration(
                          labelText: 'Cartão (opcional)'),
                      items: [
                        const DropdownMenuItem<String>(
                            value: null,
                            child: Text('Sem cartão')),
                        ...cards.map(
                          (c) => DropdownMenuItem<String>(
                            value: c.id,
                            child: Text(
                                '${c.name} — ${c.bankName}'),
                          ),
                        ),
                      ],
                      onChanged: (v) =>
                          setState(() => _selectedCardId = v),
                    ),
                    const SizedBox(height: AppSpacing.md),

                    TextFormField(
                      controller: _installmentController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Parcelas (opcional)',
                        hintText: 'Ex: 3 para 3×',
                        prefixIcon:
                            Icon(Icons.credit_card_outlined),
                      ),
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) return null;
                        final p = int.tryParse(v.trim());
                        if (p == null || p <= 0) {
                          return 'Número de parcelas inválido';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: AppSpacing.xs),

                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      value: _isProvisioned,
                      onChanged: (v) => setState(() {
                        _isProvisioned = v;
                        if (!v) _provisionedDueDate = null;
                      }),
                      title:
                          const Text('Provisionar (ainda não pago)'),
                      subtitle: const Text(
                        'Contabiliza o gasto mas indica que ainda não saiu da conta.',
                      ),
                    ),

                    if (_isProvisioned)
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: Icon(
                          Icons.event_outlined,
                          color: _provisionedDueDate == null
                              ? AppColors.warning
                              : AppColors.textSecondary,
                        ),
                        title: const Text('Vencimento'),
                        subtitle: Text(
                          _provisionedDueDate != null
                              ? _formatDate(_provisionedDueDate!)
                              : 'Toque para definir',
                          style: TextStyle(
                            color: _provisionedDueDate == null
                                ? AppColors.warning
                                : null,
                          ),
                        ),
                        trailing: TextButton(
                          onPressed: () => _pickDate(
                            initial: _provisionedDueDate ??
                                DateTime.now()
                                    .add(const Duration(days: 7)),
                            firstDate: DateTime.now(),
                            lastDate: DateTime.now().add(
                                const Duration(days: 365 * 2)),
                            onPick: (d) => setState(
                                () => _provisionedDueDate = d),
                          ),
                          child: const Text('Definir'),
                        ),
                      ),
                  ],

                  const SizedBox(height: AppSpacing.xxl),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _isSaving ? null : _save,
                      child: _isSaving
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : Text(_isEdit
                              ? 'Salvar alterações'
                              : 'Salvar transação'),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
