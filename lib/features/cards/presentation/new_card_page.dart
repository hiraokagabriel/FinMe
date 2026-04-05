import 'package:flutter/material.dart';

import '../../../core/services/repository_locator.dart';
import '../domain/card_entity.dart';
import '../domain/card_type.dart';

class NewCardPage extends StatefulWidget {
  const NewCardPage({super.key, this.initialCard});

  final CardEntity? initialCard;

  @override
  State<NewCardPage> createState() => _NewCardPageState();
}

class _NewCardPageState extends State<NewCardPage> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _bankController = TextEditingController();
  final _limitController = TextEditingController();
  CardType _selectedType = CardType.credit;
  int _dueDay = 10;
  bool _isSaving = false;

  bool get _isEdit => widget.initialCard != null;

  @override
  void initState() {
    super.initState();
    final initial = widget.initialCard;
    if (initial != null) {
      _nameController.text = initial.name;
      _bankController.text = initial.bankName;
      _selectedType = initial.type;
      _dueDay = initial.dueDay;
      if (initial.limit != null) {
        _limitController.text = initial.limit!.toStringAsFixed(2);
      }
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _bankController.dispose();
    _limitController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isSaving = true;
    });

    final locator = RepositoryLocator.instance;
    final repo = locator.cards;

    final limitText = _limitController.text.trim();
    final limit = limitText.isEmpty
        ? null
        : double.tryParse(limitText.replaceAll(',', '.'));

    final id = widget.initialCard?.id ??
        DateTime.now().microsecondsSinceEpoch.toString();

    final card = CardEntity(
      id: id,
      name: _nameController.text.trim(),
      bankName: _bankController.text.trim(),
      type: _selectedType,
      dueDay: _dueDay,
      limit: limit,
    );

    if (_isEdit) {
      await repo.update(card);
    } else {
      await repo.add(card);
    }

    if (!mounted) return;
    setState(() {
      _isSaving = false;
    });

    Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final title = _isEdit ? 'Editar cartao' : 'Novo cartao';

    return Scaffold(
      appBar: AppBar(
        title: Text(title),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'Nome do cartao',
                  hintText: 'Ex: Nubank Gold',
                ),
                validator: (value) {
                  if ((value ?? '').trim().isEmpty) {
                    return 'Informe o nome do cartao';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _bankController,
                decoration: const InputDecoration(
                  labelText: 'Banco',
                  hintText: 'Ex: Nubank',
                ),
                validator: (value) {
                  if ((value ?? '').trim().isEmpty) {
                    return 'Informe o banco';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<CardType>(
                value: _selectedType,
                decoration: const InputDecoration(
                  labelText: 'Tipo',
                ),
                items: const [
                  DropdownMenuItem(
                    value: CardType.credit,
                    child: Text('Credito'),
                  ),
                  DropdownMenuItem(
                    value: CardType.debit,
                    child: Text('Debito'),
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
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _limitController,
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(
                        labelText: 'Limite (opcional)',
                        prefixText: 'R\$ ',
                        hintText: '5000.00',
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: DropdownButtonFormField<int>(
                      value: _dueDay,
                      decoration: const InputDecoration(
                        labelText: 'Vencimento',
                      ),
                      items: List.generate(
                        28,
                        (index) => DropdownMenuItem(
                          value: index + 1,
                          child: Text('Dia ${index + 1}'),
                        ),
                      ),
                      onChanged: (value) {
                        if (value != null) {
                          setState(() {
                            _dueDay = value;
                          });
                        }
                      },
                    ),
                  ),
                ],
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
                          : 'Salvar cartao'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
