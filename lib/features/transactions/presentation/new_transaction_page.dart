import 'package:flutter/material.dart';

import '../../../core/services/repository_locator.dart';
import '../../../core/models/money.dart';
import '../../../core/models/app_mode.dart';
import '../../../core/services/app_mode_controller.dart';
import '../../cards/domain/card_entity.dart';
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
  late DateTime _selectedDate;
  late TransactionType _selectedType;
  late PaymentMethod _selectedPaymentMethod;
  String? _selectedCategoryId;
  String? _selectedCardId;

  bool _isSaving = false;

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
    } else {
      _selectedDate = DateTime.now();
      _selectedType = TransactionType.expense;
      _selectedPaymentMethod = PaymentMethod.creditCard;
    }
    _loadInitialCategory();
  }

  @override
  void dispose() {
    _descriptionController.dispose();
    _amountController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final result = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 1),
    );
    if (result != null) {
      setState(() {
        _selectedDate = result;
      });
    }
  }

  Future<void> _loadInitialCategory() async {
    if (_selectedCategoryId != null) return;
    final categories = await RepositoryLocator.instance.categories.getAll();
    if (categories.isNotEmpty) {
      setState(() {
        _selectedCategoryId = categories.first.id;
      });
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedCategoryId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Selecione uma categoria')),
      );
      return;
    }

    setState(() {
      _isSaving = true;
    });

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
    );

    if (_isEdit) {
      await locator.transactions.update(tx);
    } else {
      await locator.transactions.add(tx);
    }

    if (!mounted) return;
    setState(() {
      _isSaving = false;
    });

    Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final mode = AppModeController.instance.mode;
    final isUltra = mode == AppMode.ultra;
    final title = _isEdit ? 'Editar transacao' : 'Nova transacao';

    return Scaffold(
      appBar: AppBar(
        title: Text(title),
      ),
      body: FutureBuilder<List<dynamic>>(
        future: Future.wait([
          RepositoryLocator.instance.categories.getAll(),
          RepositoryLocator.instance.cards.getAll(),
        ]),
        builder: (context, snapshot) {
          final categories = snapshot.data != null
              ? List.from(snapshot.data![0])
              : <dynamic>[];
          final cards = snapshot.data != null
              ? List<CardEntity>.from(snapshot.data![1] as List)
              : <CardEntity>[];

          return Padding(
            padding: const EdgeInsets.all(16),
            child: Form(
              key: _formKey,
              child: ListView(
                children: [
                  TextFormField(
                    controller: _descriptionController,
                    decoration: const InputDecoration(
                      labelText: 'Descricao (opcional)',
                      hintText: 'Ex: Mercado, Cinema...',
                    ),
                  ),
                  const SizedBox(height: 12),
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
                  Row(
                    children: [
                      Expanded(
                        child: DropdownButtonFormField<TransactionType>(
                          value: _selectedType,
                          decoration: const InputDecoration(
                            labelText: 'Tipo',
                          ),
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
                              setState(() {
                                _selectedType = value;
                              });
                            }
                          },
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: DropdownButtonFormField<PaymentMethod>(
                          value: _selectedPaymentMethod,
                          decoration: const InputDecoration(
                            labelText: 'Pagamento',
                          ),
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
                              setState(() {
                                _selectedPaymentMethod = value;
                              });
                            }
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    value: _selectedCategoryId,
                    decoration: const InputDecoration(
                      labelText: 'Categoria',
                    ),
                    items: categories
                        .map(
                          (c) => DropdownMenuItem<String>(
                            value: c.id as String,
                            child: Text(c.name as String),
                          ),
                        )
                        .toList(),
                    onChanged: (value) {
                      setState(() {
                        _selectedCategoryId = value;
                      });
                    },
                  ),
                  if (isUltra) ...[
                    const SizedBox(height: 12),
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
                            child: Text('${c.name} - ${c.bankName}'),
                          ),
                        ),
                      ],
                      onChanged: (value) {
                        setState(() {
                          _selectedCardId = value;
                        });
                      },
                    ),
                  ],
                  const SizedBox(height: 12),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Data'),
                    subtitle: Text(
                      '${_selectedDate.day.toString().padLeft(2, '0')}/${_selectedDate.month.toString().padLeft(2, '0')}/${_selectedDate.year}',
                    ),
                    trailing: TextButton(
                      onPressed: _pickDate,
                      child: const Text('Alterar'),
                    ),
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _isSaving ? null : _save,
                      child: _isSaving
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
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
