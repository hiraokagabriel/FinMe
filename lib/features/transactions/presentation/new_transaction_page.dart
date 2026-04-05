import 'package:flutter/material.dart';

import '../../../core/services/repository_locator.dart';
import '../../../core/models/money.dart';
import '../../../core/models/app_mode.dart';
import '../../../core/services/app_mode_controller.dart';
import '../../cards/domain/card_entity.dart';
import '../../categories/domain/category_entity.dart';
import '../domain/payment_method.dart';
import '../domain/transaction_entity.dart';
import '../domain/transaction_type.dart';

class NewTransactionPage extends StatefulWidget {
  const NewTransactionPage({super.key, this.initialTransaction});

  final TransactionEntity? initialTransaction;

  @override
  State<NewTransactionPage> createState() => _NewTransactionPageState();
}

class _NewTransactionPageState extends State<NewTransactionPage> {
  final _formKey = GlobalKey<FormState>();
  final _descriptionController = TextEditingController();
  final _amountController = TextEditingController();
  final _installmentController = TextEditingController();
  late DateTime _selectedDate;
  late TransactionType _selectedType;
  late PaymentMethod _selectedPaymentMethod;
  String? _selectedCategoryId;
  String? _selectedCardId;
  bool _isProvisioned = false;
  DateTime? _provisionedDueDate;
  bool _isSaving = false;

  late final Future<List<dynamic>> _loadFuture;

  bool get _isEdit => widget.initialTransaction != null;

  @override
  void initState() {
    super.initState();
    final initial = widget.initialTransaction;
    if (initial != null) {
      _descriptionController.text = initial.description ?? '';
      _amountController.text = initial.amount.amount.toStringAsFixed(2);
      _selectedDate = initial.date;
      _selectedType = initial.type;
      _selectedPaymentMethod = initial.paymentMethod;
      _selectedCategoryId = initial.categoryId;
      _selectedCardId = initial.cardId;
      _isProvisioned = initial.isProvisioned;
      _provisionedDueDate = initial.provisionedDueDate;
      if (initial.installmentCount != null) {
        _installmentController.text = initial.installmentCount.toString();
      }
    } else {
      _selectedDate = DateTime.now();
      _selectedType = TransactionType.expense;
      _selectedPaymentMethod = PaymentMethod.creditCard;
    }

    _loadFuture = Future.wait([
      RepositoryLocator.instance.categories.getAll(),
      RepositoryLocator.instance.cards.getAll(),
    ]).then((results) {
      final rawCategories = List<CategoryEntity>.from(results[0] as List);
      final seen = <String>{};
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
    final now = DateTime.now();
    final result = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: firstDate ?? DateTime(now.year - 1),
      lastDate: lastDate ?? DateTime(now.year + 3),
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
    final amount = double.tryParse(
          _amountController.text.replaceAll(',', '.').trim(),
        ) ??
        0;
    final baseId = widget.initialTransaction?.id ??
        DateTime.now().microsecondsSinceEpoch.toString();

    final mode = AppModeController.instance.mode;
    final isUltra = mode == AppMode.ultra;
    final effectiveCardId = isUltra ? _selectedCardId : null;

    final installments = isUltra
        ? int.tryParse(_installmentController.text.trim())
        : null;

    final tx = TransactionEntity(
      id: baseId,
      amount: Money(amount),
      date: _selectedDate,
      type: _selectedType,
      paymentMethod: _selectedPaymentMethod,
      description: _descriptionController.text.isEmpty
          ? null
          : _descriptionController.text,
      categoryId: _selectedCategoryId!,
      cardId: effectiveCardId,
      isProvisioned: isUltra ? _isProvisioned : false,
      provisionedDueDate: (isUltra && _isProvisioned) ? _provisionedDueDate : null,
      installmentCount: installments,
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
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

  @override
  Widget build(BuildContext context) {
    final mode = AppModeController.instance.mode;
    final isUltra = mode == AppMode.ultra;
    final title = _isEdit ? 'Editar transacao' : 'Nova transacao';

    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: FutureBuilder<List<dynamic>>(
        future: _loadFuture,
        builder: (context, snapshot) {
          final categories = snapshot.data != null
              ? List<CategoryEntity>.from(snapshot.data![0] as List)
              : <CategoryEntity>[];
          final cards = snapshot.data != null
              ? List<CardEntity>.from(snapshot.data![1] as List)
              : <CardEntity>[];

          return Padding(
            padding: const EdgeInsets.all(16),
            child: Form(
              key: _formKey,
              child: ListView(
                children: [
                  // ---------- Descricao ----------
                  TextFormField(
                    controller: _descriptionController,
                    decoration: const InputDecoration(
                      labelText: 'Descricao (opcional)',
                      hintText: 'Ex: Mercado, Cinema...',
                    ),
                  ),
                  const SizedBox(height: 12),

                  // ---------- Valor ----------
                  TextFormField(
                    controller: _amountController,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(
                      labelText: 'Valor',
                      prefixText: 'R\$ ',
                      hintText: '0.00',
                    ),
                    validator: (value) {
                      final text = value?.trim() ?? '';
                      if (text.isEmpty) return 'Informe um valor';
                      final parsed =
                          double.tryParse(text.replaceAll(',', '.'));
                      if (parsed == null || parsed <= 0) {
                        return 'Informe um valor valido';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 12),

                  // ---------- Tipo + Forma de pagamento ----------
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
                          onChanged: (value) {
                            if (value != null) {
                              setState(() => _selectedType = value);
                            }
                          },
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: DropdownButtonFormField<PaymentMethod>(
                          value: _selectedPaymentMethod,
                          decoration:
                              const InputDecoration(labelText: 'Pagamento'),
                          items: const [
                            DropdownMenuItem(
                              value: PaymentMethod.creditCard,
                              child: Text('Credito'),
                            ),
                            DropdownMenuItem(
                              value: PaymentMethod.debitCard,
                              child: Text('Debito'),
                            ),
                            DropdownMenuItem(
                              value: PaymentMethod.boleto,
                              child: Text('Boleto'),
                            ),
                            DropdownMenuItem(
                              value: PaymentMethod.pix,
                              child: Text('Pix'),
                            ),
                            DropdownMenuItem(
                              value: PaymentMethod.cash,
                              child: Text('Dinheiro'),
                            ),
                            DropdownMenuItem(
                              value: PaymentMethod.other,
                              child: Text('Outro'),
                            ),
                          ],
                          onChanged: (value) {
                            if (value != null) {
                              setState(() => _selectedPaymentMethod = value);
                            }
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // ---------- Categoria ----------
                  DropdownButtonFormField<String>(
                    value: _selectedCategoryId,
                    decoration:
                        const InputDecoration(labelText: 'Categoria'),
                    items: categories
                        .map(
                          (c) => DropdownMenuItem<String>(
                            value: c.id,
                            child: Text(c.name),
                          ),
                        )
                        .toList(),
                    onChanged: (value) {
                      setState(() => _selectedCategoryId = value);
                    },
                  ),

                  // ---------- Data ----------
                  const SizedBox(height: 4),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Data da transacao'),
                    subtitle: Text(_formatDate(_selectedDate)),
                    trailing: TextButton(
                      onPressed: () => _pickDate(
                        initial: _selectedDate,
                        onPick: (d) => setState(() => _selectedDate = d),
                      ),
                      child: const Text('Alterar'),
                    ),
                  ),

                  // ---------- Campos exclusivos do Modo Ultra ----------
                  if (isUltra) ...[
                    const Divider(height: 24),
                    const Text(
                      'Modo Ultra',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Colors.deepPurple,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Cartao
                    DropdownButtonFormField<String>(
                      value: _selectedCardId,
                      decoration: const InputDecoration(
                        labelText: 'Cartao (opcional)',
                      ),
                      items: [
                        const DropdownMenuItem<String>(
                          value: null,
                          child: Text('Sem cartao'),
                        ),
                        ...cards.map(
                          (c) => DropdownMenuItem<String>(
                            value: c.id,
                            child: Text('${c.name} — ${c.bankName}'),
                          ),
                        ),
                      ],
                      onChanged: (value) {
                        setState(() => _selectedCardId = value);
                      },
                    ),
                    const SizedBox(height: 12),

                    // Parcelas
                    TextFormField(
                      controller: _installmentController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Numero de parcelas (opcional)',
                        hintText: 'Ex: 3 para 3x',
                        prefixIcon: Icon(Icons.credit_card_outlined),
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) return null;
                        final parsed = int.tryParse(value.trim());
                        if (parsed == null || parsed <= 0) {
                          return 'Numero de parcelas invalido';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 4),

                    // Provisionamento
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      value: _isProvisioned,
                      onChanged: (v) {
                        setState(() {
                          _isProvisioned = v;
                          if (!v) _provisionedDueDate = null;
                        });
                      },
                      title: const Text('Provisionar (ainda nao pago)'),
                      subtitle: const Text(
                        'Contabiliza o gasto mas indica que ainda nao saiu da conta.',
                      ),
                    ),

                    // Data de vencimento do provisionado
                    if (_isProvisioned)
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: const Icon(Icons.event_outlined),
                        title: const Text('Vencimento'),
                        subtitle: Text(
                          _provisionedDueDate != null
                              ? _formatDate(_provisionedDueDate!)
                              : 'Toque para definir',
                          style: TextStyle(
                            color: _provisionedDueDate == null
                                ? Colors.orange[700]
                                : null,
                          ),
                        ),
                        trailing: TextButton(
                          onPressed: () => _pickDate(
                            initial: _provisionedDueDate ??
                                DateTime.now().add(const Duration(days: 7)),
                            firstDate: DateTime.now(),
                            lastDate: DateTime.now()
                                .add(const Duration(days: 365 * 2)),
                            onPick: (d) =>
                                setState(() => _provisionedDueDate = d),
                          ),
                          child: const Text('Definir'),
                        ),
                      ),
                  ],

                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _isSaving ? null : _save,
                      child: _isSaving
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2),
                            )
                          : Text(_isEdit
                              ? 'Salvar alteracoes'
                              : 'Salvar transacao'),
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
