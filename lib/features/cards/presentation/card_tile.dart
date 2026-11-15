import 'package:flutter/material.dart';

import '../../../app/app_scope.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/widgets.dart';
import '../domain/payment_card.dart';
import 'card_detail_page.dart';
import 'card_form.dart';

/// Cartão na lista: faixa com a cor do cartão, fatura atual (crédito) ou conta vinculada (débito).
/// No modo Ultra, mostra limite usado e badge de assinaturas.
class CardTile extends StatelessWidget {
  const CardTile({
    super.key,
    required this.card,
    required this.ultra,
    this.subscriptions = 0,
    this.missingPaymentAccount = false,
  });

  final PaymentCard card;
  final bool ultra;
  final int subscriptions;

  /// Cartão de crédito sem conta de pagamento ativa (badge `warning`).
  final bool missingPaymentAccount;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 280,
      child: Card(
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => CardDetailPage(cardId: card.id),
            ),
          ),
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                ColoredBox(
                  color: Color(card.colorValue),
                  child: const SizedBox(width: 6),
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(AppSpace.lg),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _Header(card: card),
                        const SizedBox(height: AppSpace.sm),
                        _Tags(
                          card: card,
                          ultra: ultra,
                          subscriptions: subscriptions,
                          missingPaymentAccount: missingPaymentAccount,
                        ),
                        const SizedBox(height: AppSpace.md),
                        if (card.kind == CardKind.credit)
                          _CreditInfo(card: card, ultra: ultra)
                        else
                          _DebitInfo(card: card),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.card});

  final PaymentCard card;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                card.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: c.textPrimary,
                ),
              ),
              Text(
                '${cardBrandLabel(card.brand)} •••• ${card.last4}',
                style: TextStyle(fontSize: 12, color: c.textSecondary),
              ),
            ],
          ),
        ),
        _CardMenu(card: card),
      ],
    );
  }
}

class _Tags extends StatelessWidget {
  const _Tags({
    required this.card,
    required this.ultra,
    required this.subscriptions,
    required this.missingPaymentAccount,
  });

  final PaymentCard card;
  final bool ultra;
  final int subscriptions;
  final bool missingPaymentAccount;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Wrap(
      spacing: AppSpace.sm,
      runSpacing: AppSpace.xs,
      children: [
        StatusBadge(
          label: card.kind == CardKind.credit ? 'Crédito' : 'Débito',
          color: c.primary,
        ),
        if (card.archived)
          StatusBadge(label: 'Arquivado', color: c.textSecondary),
        if (missingPaymentAccount)
          StatusBadge(label: 'Sem conta de pagamento', color: c.warning),
        if (ultra && subscriptions > 0)
          StatusBadge(label: '$subscriptions assinaturas', color: c.primary),
      ],
    );
  }
}

class _CreditInfo extends StatelessWidget {
  const _CreditInfo({required this.card, required this.ultra});

  final PaymentCard card;
  final bool ultra;

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final ledger = s.ledger;
    final c = context.colors;
    final secondary = TextStyle(fontSize: 12, color: c.textSecondary);
    final current = ledger.currentInvoiceFor(card.id);
    final used = ledger.usedLimitFor(card.id);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          'Vence dia ${card.dueDay} · fecha dia ${card.closingDay}',
          style: secondary,
        ),
        const SizedBox(height: AppSpace.sm),
        if (current == null)
          Text('Sem fatura em aberto', style: secondary)
        else
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Fatura de ${formatMonth(current.dueMonth)} · vence ${formatShortDate(current.dueDate)}',
                      style: secondary,
                    ),
                    MoneyText(
                      current.remainingCents,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: c.textPrimary,
                      ),
                    ),
                  ],
                ),
              ),
              InvoiceStatusBadge(current.statusOn(ledger.today)),
            ],
          ),
        if (ultra) ...[
          const SizedBox(height: AppSpace.md),
          LimitBar(usedCents: used, limitCents: card.limitCents),
          const SizedBox(height: AppSpace.xs),
          Wrap(
            children: [
              MoneyText(used, style: secondary),
              Text(' de ', style: secondary),
              MoneyText(card.limitCents, style: secondary),
            ],
          ),
        ],
      ],
    );
  }
}

class _DebitInfo extends StatelessWidget {
  const _DebitInfo({required this.card});

  final PaymentCard card;

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final account = s.ledger.accountsById[card.paymentAccountId];
    return Text(
      account == null ? 'Sem conta vinculada' : 'Conta: ${account.name}',
      style: TextStyle(fontSize: 12, color: context.colors.textSecondary),
    );
  }
}

enum _CardAction { edit, archive, delete }

/// Menu de ações. Excluir só com cartão sem lançamentos; senão sugere arquivar.
class _CardMenu extends StatelessWidget {
  const _CardMenu({required this.card});

  final PaymentCard card;

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<_CardAction>(
      tooltip: 'Ações do cartão',
      onSelected: (action) => _run(context, action),
      itemBuilder: (_) => [
        const PopupMenuItem(value: _CardAction.edit, child: Text('Editar')),
        PopupMenuItem(
          value: _CardAction.archive,
          child: Text(card.archived ? 'Desarquivar' : 'Arquivar'),
        ),
        const PopupMenuItem(value: _CardAction.delete, child: Text('Excluir')),
      ],
    );
  }

  Future<void> _run(BuildContext context, _CardAction action) async {
    final s = AppScope.of(context);
    switch (action) {
      case _CardAction.edit:
        await showCardForm(context, initial: card);
      case _CardAction.archive:
        await s.cards.upsert(card.copyWith(archived: !card.archived));
      case _CardAction.delete:
        await _delete(context, s);
    }
  }

  Future<void> _delete(BuildContext context, AppServices s) async {
    final messenger = ScaffoldMessenger.of(context);
    final inUse =
        s.transactions.all.any((t) => t.cardId == card.id) ||
        s.recurring.all.any((r) => r.cardId == card.id);
    if (inUse) {
      messenger.showSnackBar(
        const SnackBar(
          content: Text('Cartão tem lançamentos. Arquive em vez de excluir.'),
        ),
      );
      return;
    }
    final confirmed = await confirmDialog(
      context,
      title: 'Excluir cartão?',
      message: 'O cartão "${card.name}" será removido.',
      confirmLabel: 'Excluir',
      destructive: true,
    );
    if (confirmed) {
      await s.cards.delete(card.id);
    }
  }
}
