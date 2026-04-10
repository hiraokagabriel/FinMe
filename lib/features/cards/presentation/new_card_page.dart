import 'package:flutter/material.dart';

import '../../../core/services/repository_locator.dart';
import '../../../core/theme/app_theme.dart';
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
  int? _closingDay;  // null = usar fallback dueDay - 7
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
      _closingDay = initial.closingDay;
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
    setState(() => _isSaving = true);

    final repo = RepositoryLocator.instance.cards;
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
      closingDay: _closingDay,
    );

    if (_isEdit) {
      await repo.update(card);
    } else {
      await repo.add(card);
    }

    if (!mounted) return;
    setState(() => _isSaving = false);
    Navigator.of(context).pop(true);
  }

  /// Preview exibido abaixo dos campos de dia quando ambos estão definidos.
  Widget _buildClosingPreview() {
    final closing = _closingDay;
    if (_selectedType != CardType.credit) return const SizedBox.shrink();
    final closingLabel = closing != null
        ? 'dia $closing'
        : 'dia ${((_dueDay - 7) % 28).clamp(1, 28)} (automático)';
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.sm),
      child: Text(
        'Fatura fecha no $closingLabel e vence no dia $_dueDay de cada mês',
        style: AppText.secondary,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final showBillingFields = _selectedType == CardType.credit;

    return Scaffold(
      appBar: AppBar(
        title: Text(_isEdit ? 'Editar cartão' : 'Novo cartão'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'Nome do cartão',
                  hintText: 'Ex: Nubank Gold',
                ),
                validator: (v) =>
                    (v ?? '').trim().isEmpty ? 'Informe o nome' : null,
              ),
              const SizedBox(height: AppSpacing.md),
              TextFormField(
                controller: _bankController,
                decoration: const InputDecoration(
                  labelText: 'Banco',
                  hintText: 'Ex: Nubank',
                ),
                validator: (v) =>
                    (v ?? '').trim().isEmpty ? 'Informe o banco' : null,
              ),
              const SizedBox(height: AppSpacing.md),
              DropdownButtonFormField<CardType>(
                value: _selectedType,
                decoration: const InputDecoration(labelText: 'Tipo'),
                items: const [
                  DropdownMenuItem(
                    value: CardType.credit,
                    child: Text('Crédito'),
                  ),
                  DropdownMenuItem(
                    value: CardType.debit,
                    child: Text('Débito'),
                  ),
                ],
                onChanged: (v) {
                  if (v != null) {
                    setState(() {
                      _selectedType = v;
                      // limpa closingDay se não for crédito
                      if (v != CardType.credit) _closingDay = null;
                    });
                  }
                },
              ),
              const SizedBox(height: AppSpacing.md),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _limitController,
                      keyboardType: const TextInputType.numberWithOptions(
                          decimal: true),
                      decoration: const InputDecoration(
                        labelText: 'Limite (opcional)',
                        prefixText: 'R\$ ',
                        hintText: '5000.00',
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: DropdownButtonFormField<int>(
                      value: _dueDay,
                      decoration:
                          const InputDecoration(labelText: 'Vencimento'),
                      items: List.generate(
                        28,
                        (i) => DropdownMenuItem(
                          value: i + 1,
                          child: Text('Dia ${i + 1}'),
                        ),
                      ),
                      onChanged: (v) {
                        if (v != null) setState(() => _dueDay = v);
                      },
                    ),
                  ),
                ],
              ),
              // Campo de fechamento — apenas para cartões de crédito
              if (showBillingFields) ...[
                const SizedBox(height: AppSpacing.md),
                DropdownButtonFormField<int?>(
                  value: _closingDay,
                  decoration: const InputDecoration(
                    labelText: 'Fechamento (opcional)',
                    hintText: 'Automático (venc. − 7 dias)',
                  ),
                  validator: (v) {
                    if (v != null && v == _dueDay) {
                      return 'Fechamento não pode ser igual ao vencimento';
                    }
                    return null;
                  },
                  items: [
                    const DropdownMenuItem<int?>(
                      value: null,
                      child: Text('Automático (venc. − 7 dias)'),
                    ),
                    ...List.generate(
                      28,
                      (i) => DropdownMenuItem<int?>(
                        value: i + 1,
                        child: Text('Dia ${i + 1}'),
                      ),
                    ),
                  ],
                  onChanged: (v) => setState(() => _closingDay = v),
                ),
                _buildClosingPreview(),
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
                          : 'Salvar cartão'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
