import 'package:flutter/material.dart';

import '../../../app/app_scope.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/utils/id.dart';
import '../../../core/widgets/widgets.dart';
import '../../transactions/domain/transaction.dart';
import '../domain/invoice.dart';
import 'card_form.dart';

/// Registra o pagamento de [invoice] como lançamento `invoicePayment` (SPEC §6.3).
Future<void> showPayInvoiceDialog(BuildContext context, Invoice invoice) {
  return showDialog<void>(
    context: context,
    builder: (_) => _PayInvoiceDialog(invoice: invoice),
  );
}

class _PayInvoiceDialog extends StatefulWidget {
  const _PayInvoiceDialog({required this.invoice});

  final Invoice invoice;

  @override
  State<_PayInvoiceDialog> createState() => _PayInvoiceDialogState();
}

class _PayInvoiceDialogState extends State<_PayInvoiceDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _amount;
  late String? _accountId;
  DateTime? _date;

  @override
  void initState() {
    super.initState();
    final invoice = widget.invoice;
    _amount = TextEditingController(
      text: formatMoney(invoice.remainingCents).replaceFirst('R\$ ', ''),
    );
    _accountId = invoice.card.paymentAccountId;
  }

  @override
  void dispose() {
    _amount.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final card = widget.invoice.card;
    return ListenableBuilder(
      listenable: s.ledger,
      builder: (context, _) {
        final date = _date ?? s.ledger.today;
        final accounts = s.accounts.all
            .where((a) => !a.archived || a.id == _accountId)
            .toList();
        final accountValue = accounts.any((a) => a.id == _accountId)
            ? _accountId
            : null;
        return AlertDialog(
          title: const Text('Pagar fatura'),
          content: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    '${card.name} · vence em ${formatDate(widget.invoice.dueDate)}',
                    style: TextStyle(
                      fontSize: 12,
                      color: context.colors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: AppSpace.lg),
                  DropdownButtonFormField<String>(
                    initialValue: accountValue,
                    decoration: const InputDecoration(
                      labelText: 'Conta de pagamento',
                    ),
                    items: [
                      for (final a in accounts)
                        DropdownMenuItem(
                          value: a.id,
                          child: Text(accountOptionLabel(a)),
                        ),
                    ],
                    onChanged: (v) => setState(() => _accountId = v),
                    validator: (v) => v == null ? 'Escolha a conta' : null,
                  ),
                  const SizedBox(height: AppSpace.md),
                  MoneyField(controller: _amount, label: 'Valor pago'),
                  const SizedBox(height: AppSpace.md),
                  DateField(
                    value: date,
                    label: 'Data do pagamento',
                    onChanged: (d) => setState(() => _date = d),
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
              onPressed: () => _save(s),
              child: const Text('Salvar'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _save(AppServices s) async {
    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }
    final invoice = widget.invoice;
    await s.transactions.upsert(
      Transaction(
        id: newId(),
        type: TransactionType.invoicePayment,
        // MoneyField já rejeita vazio e <= 0; após validate() o valor existe.
        amountCents: parseMoney(_amount.text)!,
        date: _date ?? s.ledger.today,
        description: 'Pagamento fatura ${invoice.card.name}',
        accountId: _accountId,
        cardId: invoice.card.id,
        invoiceKey: invoice.dueMonth.key,
        status: TransactionStatus.paid,
      ),
    );
    if (mounted) {
      Navigator.of(context).pop();
    }
  }
}
