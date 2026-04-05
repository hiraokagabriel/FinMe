import 'package:flutter/material.dart';

import '../../../core/services/repository_locator.dart';
import '../../../core/models/money.dart';
import '../domain/payment_method.dart';
import '../domain/transaction_entity.dart';
import '../domain/transaction_type.dart';

class NewTransactionPage extends StatefulWidget {
  const NewTransactionPage({super.key});

  @override
  State<NewTransactionPage> createState() => _NewTransactionPageState();
}

class _NewTransactionPageState extends State<NewTransactionPage> {
  final _formKey = GlobalKey<FormState>();
  final _descriptionController = TextEditingController();
  final _amountController = TextEditingController();
  DateTime _selectedDate = DateTime.now();
  TransactionType _selectedType = TransactionType.expense;
  PaymentMethod _selectedPaymentMethod = PaymentMethod.creditCard;
  String? _selectedCategoryId;

  bool _isSaving = false;

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

  @override
  void initState() {
    super.initState();
    _loadInitialCategory();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }
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

    final tx = TransactionEntity(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      amount: Money(amount),
      date: _selectedDate,
      type: _selectedType,
      paymentMethod: _selectedPaymentMethod,
      description:
          _descriptionController.text.isEmpty ? null : _descriptionController.text,
      categoryId: _selectedCategoryId!,
      cardId: null,
    );

    await locator.transactions.add(tx);

    if (!mounted) return;
    setState(() {
      _isSaving = false;
    });

    Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Nova transacao'),
      ),
      body: FutureBuilder(
        future: RepositoryLocator.instance.categories.getAll(),
        builder: (context, snapshot) {
          final categories = snapshot.data ?? [];

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
                            labelText: 'Forma de pagamento',
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
                          (c) => DropdownMenuItem(
                            value: c.id,
                            child: Text(c.name),
                          ),
                        )
                        .toList(),
                    onChanged: (value) {
                      setState(() {
                        _selectedCategoryId = value;
                      });
                    },
                  ),
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
                          : const Text('Salvar transacao'),
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
