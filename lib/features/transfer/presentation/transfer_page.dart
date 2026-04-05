import 'package:flutter/material.dart';

import '../../../core/models/money.dart';
import '../../../core/services/repository_locator.dart';
import '../../../core/theme/app_theme.dart';
import '../../accounts/domain/account_entity.dart';
import '../../transactions/domain/payment_method.dart';
import '../../transactions/domain/recurrence_rule.dart';
import '../../transactions/domain/transaction_entity.dart';
import '../../transactions/domain/transaction_type.dart';

class TransferPage extends StatefulWidget {
  const TransferPage({super.key, this.defaultFromAccountId});

  final String? defaultFromAccountId;

  @override
  State<TransferPage> createState() => _TransferPageState();
}

class _TransferPageState extends State<TransferPage> {
  final _formKey    = GlobalKey<FormState>();
  final _amountCtrl = TextEditingController();
  final _descCtrl   = TextEditingController();

  List<AccountEntity> _accounts = [];
  String? _fromId;
  String? _toId;
  DateTime _date = DateTime.now();
  bool _isSaving = false;
  bool _loaded   = false;

  @override
  void initState() {
    super.initState();
    _loadAccounts();
  }

  Future<void> _loadAccounts() async {
    final all = await RepositoryLocator.instance.accounts.getAll();
    setState(() {
      _accounts = List<AccountEntity>.from(all);
      _fromId   = widget.defaultFromAccountId ?? (_accounts.isNotEmpty ? _accounts.first.id : null);
      _toId     = _accounts.length > 1 ? _accounts[1].id : null;
      _loaded   = true;
    });
  }

  String _fmtDate(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_fromId == null || _toId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Selecione as contas de origem e destino')),
      );
      return;
    }
    if (_fromId == _toId) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Origem e destino não podem ser a mesma conta')),
      );
      return;
    }

    setState(() => _isSaving = true);

    final amount  = double.tryParse(_amountCtrl.text.replaceAll(',', '.').trim()) ?? 0;
    final desc    = _descCtrl.text.trim().isEmpty ? 'Transferência' : _descCtrl.text.trim();
    final baseId  = DateTime.now().microsecondsSinceEpoch.toString();
    final locator = RepositoryLocator.instance;

    // Débito na conta origem
    final debit = TransactionEntity(
      id:               '${baseId}_out',
      amount:           Money(amount),
      date:             _date,
      type:             TransactionType.transfer,
      paymentMethod:    PaymentMethod.other,
      description:      desc,
      accountId:        _fromId,
      toAccountId:      _toId,
      isBoleto:         false,
      isProvisioned:    false,
      recurrenceRule:   RecurrenceRule.none,
    );

    // Crédito na conta destino
    final credit = TransactionEntity(
      id:               '${baseId}_in',
      amount:           Money(amount),
      date:             _date,
      type:             TransactionType.transfer,
      paymentMethod:    PaymentMethod.other,
      description:      desc,
      accountId:        _toId,
      toAccountId:      _fromId,
      isBoleto:         false,
      isProvisioned:    false,
      recurrenceRule:   RecurrenceRule.none,
    );

    await locator.transactions.add(debit);
    await locator.transactions.add(credit);

    if (!mounted) return;
    setState(() => _isSaving = false);
    Navigator.of(context).pop(true);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Transferência de R\$ ${amount.toStringAsFixed(2)} realizada com sucesso!',
        ),
        backgroundColor: AppColors.success,
      ),
    );
  }

  @override
  void dispose() {
    _amountCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Transferência entre contas')),
      body: !_loaded
          ? const Center(child: CircularProgressIndicator())
          : _accounts.length < 2
              ? _emptyState()
              : _form(),
    );
  }

  Widget _emptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.account_balance_wallet_outlined,
                size: 56, color: AppColors.textSecondary),
            const SizedBox(height: AppSpacing.md),
            Text(
              'Você precisa de pelo menos 2 contas\npara realizar uma transferência.',
              style: AppText.body.copyWith(color: AppColors.textSecondary),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.lg),
            ElevatedButton.icon(
              onPressed: () => Navigator.of(context)
                  .pushNamed('/accounts')
                  .then((_) => _loadAccounts()),
              icon: const Icon(Icons.add),
              label: const Text('Criar conta'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _form() {
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Form(
        key: _formKey,
        child: ListView(
          children: [
            // ── Valor ────────────────────────────────────────────────────
            TextFormField(
              controller: _amountCtrl,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                labelText: 'Valor',
                prefixText: 'R\$ ',
                hintText: '0.00',
                prefixIcon: Icon(Icons.attach_money_outlined),
              ),
              validator: (v) {
                final text = v?.trim() ?? '';
                if (text.isEmpty) return 'Informe um valor';
                final p = double.tryParse(text.replaceAll(',', '.'));
                if (p == null || p <= 0) return 'Informe um valor válido';
                return null;
              },
            ),
            const SizedBox(height: AppSpacing.md),

            // ── Conta origem ─────────────────────────────────────────────
            DropdownButtonFormField<String>(
              value: _fromId,
              decoration: const InputDecoration(
                labelText: 'Conta de origem',
                prefixIcon: Icon(Icons.arrow_upward_outlined),
              ),
              items: _accounts
                  .map((a) => DropdownMenuItem(
                        value: a.id,
                        child: Text(a.name),
                      ))
                  .toList(),
              onChanged: (v) => setState(() => _fromId = v),
              validator: (v) => v == null ? 'Selecione a conta de origem' : null,
            ),
            const SizedBox(height: AppSpacing.md),

            // ── Conta destino ────────────────────────────────────────────
            DropdownButtonFormField<String>(
              value: _toId,
              decoration: const InputDecoration(
                labelText: 'Conta de destino',
                prefixIcon: Icon(Icons.arrow_downward_outlined),
              ),
              items: _accounts
                  .map((a) => DropdownMenuItem(
                        value: a.id,
                        child: Text(a.name),
                      ))
                  .toList(),
              onChanged: (v) => setState(() => _toId = v),
              validator: (v) => v == null ? 'Selecione a conta de destino' : null,
            ),
            const SizedBox(height: AppSpacing.md),

            // ── Descrição ────────────────────────────────────────────────
            TextFormField(
              controller: _descCtrl,
              decoration: const InputDecoration(
                labelText: 'Descrição (opcional)',
                hintText: 'Ex: Reserva para férias',
                prefixIcon: Icon(Icons.notes_outlined),
              ),
            ),
            const SizedBox(height: AppSpacing.md),

            // ── Data ─────────────────────────────────────────────────────
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.calendar_today_outlined),
              title: const Text('Data da transferência'),
              subtitle: Text(_fmtDate(_date)),
              trailing: TextButton(
                onPressed: () async {
                  final now = DateTime.now();
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: _date,
                    firstDate: DateTime(now.year - 2),
                    lastDate: DateTime(now.year + 1),
                  );
                  if (picked != null) setState(() => _date = picked);
                },
                child: const Text('Alterar'),
              ),
            ),

            const SizedBox(height: AppSpacing.xl),

            // ── Botão salvar ─────────────────────────────────────────────
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _isSaving ? null : _save,
                icon: _isSaving
                    ? const SizedBox(
                        height: 18,
                        width: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.swap_horiz_outlined),
                label: Text(_isSaving ? 'Transferindo...' : 'Realizar transferência'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
