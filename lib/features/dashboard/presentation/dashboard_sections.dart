import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/widgets.dart';
import '../../accounts/domain/account.dart';
import '../../cards/domain/invoice.dart';
import '../../forecast/domain/invoice_timeline.dart';
import '../../transactions/domain/transaction.dart';
import 'dashboard_summary.dart';

/// Linha de KPIs em `Wrap`: cada tile tem largura fixa, quebra linha no celular.
class DashboardKpiRow extends StatelessWidget {
  const DashboardKpiRow({super.key, required this.summary});

  final DashboardSummary summary;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final balanceTrend = summary.balanceTrend;
    final expenseTrend = summary.expenseTrend;
    return Wrap(
      spacing: AppSpace.md,
      runSpacing: AppSpace.md,
      children: [
        _slot(
          KpiTile(
            label: 'Saldo atual',
            cents: summary.currentCents,
            trend: balanceTrend == null
                ? null
                : _Trend(
                    delta: summary.balanceDelta,
                    values: balanceTrend,
                    higherIsBetter: true,
                  ),
          ),
        ),
        _slot(
          KpiTile(label: 'A pagar em 30 dias', cents: summary.payableCents),
        ),
        _slot(
          KpiTile(label: 'Faturas em aberto', cents: summary.openInvoicesCents),
        ),
        _slot(
          KpiTile(
            label: 'Saldo previsto fim do mês',
            cents: summary.endOfMonthCents,
            color: summary.endOfMonthCents < 0 ? c.danger : null,
          ),
        ),
        if (summary.monthExpenseCents case final spent?)
          _slot(
            KpiTile(
              label: 'Gasto no mês',
              cents: spent,
              caption: 'até hoje',
              trend: expenseTrend == null
                  ? null
                  : _Trend(
                      delta: summary.monthExpenseDelta,
                      values: expenseTrend,
                      higherIsBetter: false,
                    ),
            ),
          ),
      ],
    );
  }

  static Widget _slot(Widget child) => SizedBox(width: 240, child: child);
}

/// Variação vs. mês anterior à esquerda e sparkline de 6 meses à direita (só Ultra).
class _Trend extends StatelessWidget {
  const _Trend({
    required this.delta,
    required this.values,
    required this.higherIsBetter,
  });

  final double? delta;
  final List<int> values;
  final bool higherIsBetter;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        // Badge encolhe em vez de estourar o KPI (200 px úteis no slot de 240).
        Flexible(
          flex: 2,
          child: FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: DeltaBadge(ratio: delta, higherIsBetter: higherIsBetter),
          ),
        ),
        const Spacer(),
        Sparkline(values: values),
      ],
    );
  }
}

/// Alerta de saldo negativo. Ultra lista também as contas afetadas.
class NegativeBalanceBanner extends StatelessWidget {
  const NegativeBalanceBanner({
    super.key,
    required this.date,
    this.accounts = const [],
  });

  final DateTime date;
  final List<NegativeAccount> accounts;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final textTheme = Theme.of(context).textTheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: c.danger.withValues(alpha: 0.1),
        borderRadius: AppRadius.cardBorder,
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpace.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.warning_amber_rounded, color: c.danger),
                const SizedBox(width: AppSpace.sm),
                Expanded(
                  child: Text(
                    'Seu saldo consolidado fica negativo em ${formatDate(date)}',
                    style: textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            for (final account in accounts)
              Padding(
                padding: const EdgeInsets.only(
                  top: AppSpace.sm,
                  left: AppSpace.xxl,
                ),
                child: Text(
                  '${account.name}: negativa em ${formatDate(account.date)}',
                  style: textTheme.bodySmall?.copyWith(color: c.textSecondary),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Faturas atuais de cada cartão de crédito, em ordem de vencimento.
class InvoicesCard extends StatelessWidget {
  const InvoicesCard({super.key, required this.rows, required this.ultra});

  final List<InvoiceRow> rows;
  final bool ultra;

  @override
  Widget build(BuildContext context) {
    return SectionCard(
      title: 'Próximas faturas',
      child: rows.isEmpty
          ? const EmptyState(
              icon: Icons.credit_card_outlined,
              message: 'Nenhuma fatura em aberto.',
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final row in rows) _InvoiceLine(row: row, ultra: ultra),
              ],
            ),
    );
  }
}

class _InvoiceLine extends StatelessWidget {
  const _InvoiceLine({required this.row, required this.ultra});

  final InvoiceRow row;
  final bool ultra;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final textTheme = Theme.of(context).textTheme;
    final invoice = row.invoice;
    final card = invoice.card;
    final (label, color) = switch (row.status) {
      InvoiceStatus.open => ('Aberta', c.primary),
      InvoiceStatus.closed => ('Fechada', c.warning),
      InvoiceStatus.overdue => ('Vencida', c.danger),
      InvoiceStatus.paid => ('Paga', c.success),
    };
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpace.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      card.name,
                      style: textTheme.bodyMedium,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      card.bankName,
                      style: textTheme.bodySmall?.copyWith(
                        color: c.textSecondary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              Text(
                formatShortDate(invoice.dueDate),
                style: textTheme.bodySmall,
              ),
              const SizedBox(width: AppSpace.sm),
              StatusBadge(label: label, color: color),
              const SizedBox(width: AppSpace.sm),
              MoneyText(
                invoice.remainingCents,
                style: textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          if (ultra) ...[
            const SizedBox(height: AppSpace.xs),
            LimitBar(usedCents: row.usedCents, limitCents: card.limitCents),
          ],
        ],
      ),
    );
  }
}

/// Vencimentos provisionados e boletos dos próximos 30 dias.
class UpcomingCard extends StatelessWidget {
  const UpcomingCard({super.key, required this.items});

  final List<Transaction> items;

  @override
  Widget build(BuildContext context) {
    return SectionCard(
      title: 'Próximos vencimentos',
      child: items.isEmpty
          ? const EmptyState(
              icon: Icons.event_available_outlined,
              message: 'Nenhum vencimento nos próximos 30 dias.',
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [for (final t in items) _UpcomingLine(transaction: t)],
            ),
    );
  }
}

class _UpcomingLine extends StatelessWidget {
  const _UpcomingLine({required this.transaction});

  final Transaction transaction;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final textTheme = Theme.of(context).textTheme;
    final t = transaction;
    final planned = t.isPlanned;
    final signed = t.type == TransactionType.income
        ? t.amountCents
        : -t.amountCents;
    final italic = planned ? FontStyle.italic : FontStyle.normal;
    final line = Row(
      children: [
        SizedBox(
          width: 44,
          child: Text(
            formatShortDate(t.date),
            style: textTheme.bodySmall?.copyWith(fontStyle: italic),
          ),
        ),
        if (t.isBoleto) ...[
          Icon(Icons.receipt_long, size: 16, color: c.textSecondary),
          const SizedBox(width: AppSpace.xs),
        ],
        Expanded(
          child: Text(
            t.description,
            style: textTheme.bodyMedium?.copyWith(fontStyle: italic),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        if (planned) ...[
          const PlannedMarker(),
          const SizedBox(width: AppSpace.sm),
        ],
        MoneyText(
          signed,
          signed: true,
          colorBySign: true,
          style: textTheme.bodyMedium?.copyWith(fontStyle: italic),
        ),
      ],
    );
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpace.xs),
      child: planned
          ? DecoratedBox(
              decoration: BoxDecoration(
                color: c.warning.withValues(alpha: 0.08),
                borderRadius: AppRadius.chipBorder,
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpace.sm,
                  vertical: AppSpace.xs,
                ),
                child: line,
              ),
            )
          : line,
    );
  }
}

/// Gastos do mês por categoria. Ultra: barras proporcionais. Simples: lista.
class CategoriesCard extends StatelessWidget {
  const CategoriesCard({super.key, required this.rows, required this.ultra});

  final List<CategoryRow> rows;
  final bool ultra;

  @override
  Widget build(BuildContext context) {
    final maxCents = rows.isEmpty ? 0 : rows.first.cents;
    return SectionCard(
      title: 'Gastos por categoria (mês)',
      child: rows.isEmpty
          ? const EmptyState(
              icon: Icons.pie_chart_outline,
              message: 'Nenhum gasto neste mês.',
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final row in rows)
                  _CategoryLine(
                    row: row,
                    fraction: maxCents <= 0 ? 0 : row.cents / maxCents,
                    ultra: ultra,
                  ),
              ],
            ),
    );
  }
}

class _CategoryLine extends StatelessWidget {
  const _CategoryLine({
    required this.row,
    required this.fraction,
    required this.ultra,
  });

  final CategoryRow row;
  final double fraction;
  final bool ultra;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpace.xs),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  row.name,
                  style: textTheme.bodyMedium,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              MoneyText(row.cents, style: textTheme.bodyMedium),
            ],
          ),
          if (ultra) ...[
            const SizedBox(height: AppSpace.xs),
            _ShareBar(fraction: fraction.clamp(0.0, 1.0).toDouble()),
          ],
        ],
      ),
    );
  }
}

/// Barra horizontal proporcional: trilho `border` + preenchimento `chartBar`.
class _ShareBar extends StatelessWidget {
  const _ShareBar({required this.fraction});

  final double fraction;

  static const _height = 8.0;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        return Stack(
          children: [
            Container(
              height: _height,
              width: width,
              decoration: BoxDecoration(
                color: c.border,
                borderRadius: AppRadius.chipBorder,
              ),
            ),
            Container(
              height: _height,
              width: width * fraction,
              decoration: BoxDecoration(
                color: c.chartBar,
                borderRadius: AppRadius.chipBorder,
              ),
            ),
          ],
        );
      },
    );
  }
}

/// Simples: alerta de faturas sem saldo previsto na conta de pagamento (mostra a mais próxima).
class CoverageBanner extends StatelessWidget {
  const CoverageBanner({super.key, required this.items});

  final List<InvoiceDue> items;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final textTheme = Theme.of(context).textTheme;
    final count = items.length;
    final nearest = items.first;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: c.danger.withValues(alpha: 0.1),
        borderRadius: AppRadius.cardBorder,
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpace.lg),
        child: Row(
          children: [
            Icon(Icons.event_busy_outlined, color: c.danger),
            const SizedBox(width: AppSpace.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    count == 1
                        ? '1 fatura precisa de atenção (sem saldo previsto ou sem conta de pagamento)'
                        : '$count faturas precisam de atenção (sem saldo previsto ou sem conta de pagamento)',
                    style: textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    'Mais próxima: ${nearest.invoice.card.name} em ${formatDate(nearest.date)}',
                    style: textTheme.bodySmall?.copyWith(
                      color: c.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Ultra: uma linha por fatura pendente com data, cartão, conta, valor e saldo após.
class CoverageCard extends StatelessWidget {
  const CoverageCard({super.key, required this.items, required this.accounts});

  final List<InvoiceDue> items;
  final Map<String, Account> accounts;

  @override
  Widget build(BuildContext context) {
    return SectionCard(
      title: 'Cobertura de faturas',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final d in items)
            _CoverageLine(due: d, account: accounts[d.accountId]),
        ],
      ),
    );
  }
}

class _CoverageLine extends StatelessWidget {
  const _CoverageLine({required this.due, required this.account});

  final InvoiceDue due;
  final Account? account;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final textTheme = Theme.of(context).textTheme;
    final balanceAfter = due.accountBalanceAfterCents;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpace.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              SizedBox(
                width: 44,
                child: Text(
                  formatShortDate(due.date),
                  style: textTheme.bodySmall,
                ),
              ),
              Expanded(
                child: Text(
                  due.invoice.card.name,
                  style: textTheme.bodyMedium,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              MoneyText(
                due.amountCents,
                style: textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.only(left: 44),
            child: Wrap(
              spacing: AppSpace.sm,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Text(
                  due.hasAccount
                      ? _accountLabel(account)
                      : 'Sem conta de pagamento',
                  style: textTheme.bodySmall?.copyWith(
                    color: due.hasAccount ? c.textSecondary : c.warning,
                  ),
                ),
                if (balanceAfter != null)
                  Wrap(
                    spacing: AppSpace.xs,
                    children: [
                      Text(
                        'Saldo após',
                        style: textTheme.bodySmall?.copyWith(
                          color: c.textSecondary,
                        ),
                      ),
                      MoneyText(
                        balanceAfter,
                        style: textTheme.bodySmall?.copyWith(
                          color: c.danger,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static String _accountLabel(Account? account) {
    if (account == null) {
      return 'Conta';
    }
    return account.bankName.isEmpty
        ? account.name
        : '${account.name} (${account.bankName})';
  }
}
