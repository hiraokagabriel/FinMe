import 'package:flutter/material.dart';

import '../../../app/app_scope.dart';
import '../../../core/models/app_settings.dart';
import '../../../core/models/year_month.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/widgets.dart';
import '../../transactions/domain/transaction.dart';
import '../domain/invoice.dart';
import '../domain/payment_card.dart';
import 'pay_invoice_dialog.dart';

/// Detalhe do cartão: faturas com itens (crédito) ou lançamentos do mês (débito).
class CardDetailPage extends StatefulWidget {
  const CardDetailPage({super.key, required this.cardId});

  final String cardId;

  @override
  State<CardDetailPage> createState() => _CardDetailPageState();
}

class _CardDetailPageState extends State<CardDetailPage> {
  /// Mês de vencimento da fatura (crédito) ou mês (débito). Null = fatura atual / mês de hoje.
  YearMonth? _selected;

  void _select(YearMonth month) => setState(() => _selected = month);

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    return ListenableBuilder(
      listenable: s.ledger,
      builder: (context, _) {
        final card = s.ledger.cardsById[widget.cardId];
        return Scaffold(
          appBar: AppBar(title: Text(card?.name ?? 'Cartão')),
          body: _body(card),
        );
      },
    );
  }

  Widget _body(PaymentCard? card) {
    if (card == null) {
      return const EmptyState(
        icon: Icons.credit_card_off,
        message: 'Cartão não encontrado.',
      );
    }
    if (card.kind == CardKind.credit) {
      return _CreditBody(card: card, selected: _selected, onSelect: _select);
    }
    return _DebitBody(card: card, selected: _selected, onSelect: _select);
  }
}

/// Status da fatura como badge colorido.
class InvoiceStatusBadge extends StatelessWidget {
  const InvoiceStatusBadge(this.status, {super.key});

  final InvoiceStatus status;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final (label, color) = switch (status) {
      InvoiceStatus.open => ('Aberta', c.primary),
      InvoiceStatus.closed => ('Fechada', c.warning),
      InvoiceStatus.overdue => ('Vencida', c.danger),
      InvoiceStatus.paid => ('Paga', c.success),
    };
    return StatusBadge(label: label, color: color);
  }
}

class _CreditBody extends StatelessWidget {
  const _CreditBody({
    required this.card,
    required this.selected,
    required this.onSelect,
  });

  final PaymentCard card;
  final YearMonth? selected;
  final ValueChanged<YearMonth> onSelect;

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final ledger = s.ledger;
    final invoices = ledger.invoicesFor(card.id);
    if (invoices.isEmpty) {
      return const EmptyState(
        icon: Icons.receipt_long,
        message: 'Nenhuma fatura ainda.',
      );
    }
    final invoice = _pick(
      invoices,
      selected,
      ledger.currentInvoiceFor(card.id),
    );
    final ultra = s.settings.value.mode == AppMode.ultra;
    final c = context.colors;
    return _TransactionList(
      items: invoice.items,
      header: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            height: 44,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: invoices.length,
              separatorBuilder: (context, index) =>
                  const SizedBox(width: AppSpace.sm),
              itemBuilder: (context, i) {
                final month = invoices[i].dueMonth;
                return ChoiceChip(
                  label: Text(formatMonth(month)),
                  selected: month == invoice.dueMonth,
                  onSelected: (_) => onSelect(month),
                );
              },
            ),
          ),
          const SizedBox(height: AppSpace.md),
          _InvoiceSummary(
            invoice: invoice,
            today: ledger.today,
            ultra: ultra,
            usedCents: ledger.usedLimitFor(card.id),
          ),
          const SizedBox(height: AppSpace.lg),
          Text(
            'Lançamentos',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: c.textPrimary,
            ),
          ),
          const SizedBox(height: AppSpace.sm),
        ],
      ),
    );
  }
}

/// Fatura escolhida, ou a atual (ou a mais recente se todas quitadas).
Invoice _pick(List<Invoice> invoices, YearMonth? selected, Invoice? current) {
  for (final invoice in invoices) {
    if (invoice.dueMonth == selected) {
      return invoice;
    }
  }
  return current ?? invoices.last;
}

class _InvoiceSummary extends StatelessWidget {
  const _InvoiceSummary({
    required this.invoice,
    required this.today,
    required this.ultra,
    required this.usedCents,
  });

  final Invoice invoice;
  final DateTime today;
  final bool ultra;
  final int usedCents;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final card = invoice.card;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpace.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Fatura de ${formatMonthLong(invoice.dueMonth)}',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: c.textPrimary,
                    ),
                  ),
                ),
                InvoiceStatusBadge(invoice.statusOn(today)),
              ],
            ),
            const SizedBox(height: AppSpace.xs),
            Text(
              'Fechamento ${formatDate(invoice.closingDate)} · '
              'Vencimento ${formatDate(invoice.dueDate)}',
              style: TextStyle(fontSize: 12, color: c.textSecondary),
            ),
            const SizedBox(height: AppSpace.lg),
            Wrap(
              spacing: AppSpace.xl,
              runSpacing: AppSpace.md,
              children: [
                _Figure(label: 'Total', cents: invoice.totalCents),
                _Figure(label: 'Pago', cents: invoice.paidCents),
                _Figure(label: 'Restante', cents: invoice.remainingCents),
              ],
            ),
            if (ultra && card.limitCents > 0) ...[
              const SizedBox(height: AppSpace.md),
              LimitBar(usedCents: usedCents, limitCents: card.limitCents),
            ],
            if (invoice.remainingCents > 0) ...[
              const SizedBox(height: AppSpace.md),
              Align(
                alignment: Alignment.centerRight,
                child: FilledButton.icon(
                  onPressed: () => showPayInvoiceDialog(context, invoice),
                  icon: const Icon(Icons.payments_outlined),
                  label: const Text('Pagar fatura'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _Figure extends StatelessWidget {
  const _Figure({required this.label, required this.cents});

  final String label;
  final int cents;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(fontSize: 12, color: context.colors.textSecondary),
        ),
        MoneyText(
          cents,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: context.colors.textPrimary,
          ),
        ),
      ],
    );
  }
}

class _DebitBody extends StatelessWidget {
  const _DebitBody({
    required this.card,
    required this.selected,
    required this.onSelect,
  });

  final PaymentCard card;
  final YearMonth? selected;
  final ValueChanged<YearMonth> onSelect;

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final month = selected ?? YearMonth.fromDate(s.ledger.today);
    final items = [
      for (final t in s.transactions.all)
        if (t.cardId == card.id && month.contains(t.date)) t,
    ]..sort((a, b) => a.date.compareTo(b.date));
    final net = items.fold<int>(
      0,
      (sum, t) =>
          sum +
          (t.type == TransactionType.income ? -t.amountCents : t.amountCents),
    );
    return _TransactionList(
      items: items,
      header: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: MonthSelector(value: month, onChanged: onSelect),
          ),
          const SizedBox(height: AppSpace.sm),
          _Figure(label: 'Total do mês', cents: net),
          const SizedBox(height: AppSpace.lg),
        ],
      ),
    );
  }
}

/// Cabeçalho rolável + lista de lançamentos (ListView virtualizado via SliverList).
class _TransactionList extends StatelessWidget {
  const _TransactionList({required this.header, required this.items});

  final Widget header;
  final List<Transaction> items;

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final categories = s.ledger.categoriesById;
    final inset = MediaQuery.sizeOf(context).width < 600
        ? AppSpace.lg
        : AppSpace.xl;
    return CustomScrollView(
      slivers: [
        SliverPadding(
          padding: EdgeInsets.fromLTRB(inset, inset, inset, 0),
          sliver: SliverToBoxAdapter(child: header),
        ),
        if (items.isEmpty)
          SliverPadding(
            padding: EdgeInsets.symmetric(horizontal: inset),
            sliver: SliverToBoxAdapter(
              child: Text(
                'Sem lançamentos.',
                style: TextStyle(
                  fontSize: 13,
                  color: context.colors.textSecondary,
                ),
              ),
            ),
          )
        else
          SliverPadding(
            padding: EdgeInsets.symmetric(horizontal: inset),
            sliver: SliverList.builder(
              itemCount: items.length,
              itemBuilder: (context, i) {
                final t = items[i];
                return _ItemRow(
                  item: t,
                  categoryName: categories[t.categoryId]?.name,
                  planned: _isPlanned(t, s),
                );
              },
            ),
          ),
        const SliverToBoxAdapter(child: SizedBox(height: AppSpace.xl)),
      ],
    );
  }
}

/// Provisionado: ainda não lançado, ou projeção de recorrência de cartão (não gravada).
bool _isPlanned(Transaction t, AppServices s) {
  if (t.isPlanned) {
    return true;
  }
  final recurringId = t.recurringId;
  return recurringId != null &&
      t.id.contains(recurringId) &&
      s.transactions.byId(t.id) == null;
}

class _ItemRow extends StatelessWidget {
  const _ItemRow({
    required this.item,
    required this.categoryName,
    required this.planned,
  });

  final Transaction item;
  final String? categoryName;
  final bool planned;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final refund = item.type == TransactionType.income;
    final installment = item.installmentIndex == null
        ? null
        : '${item.installmentIndex}/${item.installmentCount ?? '?'}';
    final subtitle = [?categoryName, ?installment].join(' · ');
    final fontStyle = planned ? FontStyle.italic : FontStyle.normal;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: planned ? c.warning.withValues(alpha: 0.08) : null,
        borderRadius: AppRadius.chipBorder,
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpace.sm,
          vertical: AppSpace.sm,
        ),
        child: Row(
          children: [
            SizedBox(
              width: 48,
              child: Text(
                formatShortDate(item.date),
                style: TextStyle(fontSize: 12, color: c.textSecondary),
              ),
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          item.description,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 13,
                            fontStyle: fontStyle,
                            color: c.textPrimary,
                          ),
                        ),
                      ),
                      if (planned) ...[
                        const SizedBox(width: AppSpace.xs),
                        const PlannedMarker(),
                      ],
                    ],
                  ),
                  if (subtitle.isNotEmpty)
                    Text(
                      subtitle,
                      style: TextStyle(fontSize: 12, color: c.textSecondary),
                    ),
                ],
              ),
            ),
            const SizedBox(width: AppSpace.sm),
            // Estorno (income no cartão) sai como negativo, em success.
            Flexible(
              child: MoneyText(
                refund ? -item.amountCents : item.amountCents,
                style: TextStyle(
                  fontSize: 13,
                  fontStyle: fontStyle,
                  color: refund ? c.success : c.textPrimary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
