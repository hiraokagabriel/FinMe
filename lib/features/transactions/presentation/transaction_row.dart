import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_palettes.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/widgets.dart';
import '../../categories/domain/transaction_category.dart';
import '../domain/transaction.dart';
import 'transaction_filters.dart';

/// Ações da linha. Tocar na linha equivale a [TransactionAction.edit].
enum TransactionAction { edit, confirm, duplicate, delete }

/// Larguras fixas das colunas; cabeçalho e linhas compartilham.
const kTxDateWidth = 136.0;

/// Simples: data curta (dd/MM) cabe em coluna estreita no celular.
const kTxDateWidthSimple = 72.0;
const kTxOriginWidth = 160.0;
const kTxCategoryWidth = 140.0;
const kTxValueWidth = 120.0;
const kTxMenuWidth = 40.0;

/// Abaixo disso a tabela Ultra rola na horizontal (360px sem overflow).
const kTxUltraMinWidth = 760.0;

/// Alturas fixas para `ListView.builder(itemExtent)`.
const kTxRowExtentUltra = 40.0;
const kTxRowExtentSimple = 56.0;

/// Linha de transação. Simples: data, descrição (+ categoria), valor.
/// Ultra: acrescenta conta/cartão e categoria em colunas.
class TransactionRow extends StatelessWidget {
  const TransactionRow({
    super.key,
    required this.transaction,
    required this.ultra,
    required this.past,
    required this.onAction,
    this.category,
    this.origin = '',
    this.destination,
  });

  final Transaction transaction;
  final bool ultra;

  /// Data anterior ao início do mês atual: texto em `textSecondary`.
  final bool past;
  final TransactionCategory? category;
  final String origin;

  /// Conta destino (transferência) ou cartão pago (pagamento de fatura).
  final String? destination;
  final ValueChanged<TransactionAction> onAction;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final t = transaction;
    final provisioned = isProvisioned(t);
    final textTheme = Theme.of(context).textTheme;
    final italic = provisioned ? FontStyle.italic : FontStyle.normal;
    final body = (textTheme.bodyMedium ?? const TextStyle()).copyWith(
      color: past ? c.textSecondary : c.textPrimary,
      fontStyle: italic,
    );
    final small = (textTheme.bodySmall ?? const TextStyle()).copyWith(
      color: c.textSecondary,
      fontStyle: italic,
    );
    final colorBySign = ultra && !past;
    final installment = t.isInstallment
        ? ' ${t.installmentIndex}/${t.installmentCount}'
        : '';
    final title = '${t.description}$installment';
    final arrow = destination == null ? null : '→ $destination';
    final cat = category;
    final subtitle = [if (cat != null) cat.name, ?arrow].join(' · ');

    final Widget description = ultra
        ? Row(
            children: [
              Icon(
                cat == null
                    ? Icons.label_outline
                    : categoryIcon(cat.iconCodePoint),
                size: 16,
                color: cat == null ? c.textSecondary : Color(cat.colorValue),
              ),
              const SizedBox(width: AppSpace.sm),
              Expanded(
                child: Text(
                  title,
                  style: body,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          )
        : Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: body,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              if (subtitle.isNotEmpty)
                Text(
                  subtitle,
                  style: small,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
            ],
          );

    final value = switch (t.type) {
      TransactionType.expense || TransactionType.invoicePayment => MoneyText(
        -t.amountCents,
        signed: true,
        colorBySign: colorBySign,
        style: body,
      ),
      TransactionType.income => MoneyText(
        t.amountCents,
        signed: true,
        colorBySign: colorBySign,
        style: body,
      ),
      TransactionType.transfer => MoneyText(t.amountCents, style: body),
    };

    return DecoratedBox(
      decoration: BoxDecoration(
        color: provisioned ? c.warning.withValues(alpha: 0.08) : null,
        border: Border(bottom: BorderSide(color: c.border)),
      ),
      child: InkWell(
        onTap: () => onAction(TransactionAction.edit),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpace.sm),
          child: TransactionColumns(
            ultra: ultra,
            date: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (provisioned) ...[
                  const PlannedMarker(),
                  const SizedBox(width: AppSpace.xs),
                ],
                Text(
                  ultra ? formatDate(t.date) : formatShortDate(t.date),
                  style: body,
                ),
              ],
            ),
            description: description,
            origin: ultra
                ? Text(
                    arrow == null ? origin : '$origin → $destination',
                    style: small,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  )
                : const SizedBox.shrink(),
            category: ultra
                ? Text(
                    cat?.name ?? '—',
                    style: small,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  )
                : const SizedBox.shrink(),
            value: value,
            menu: PopupMenuButton<TransactionAction>(
              tooltip: 'Ações',
              padding: EdgeInsets.zero,
              icon: Icon(Icons.more_vert, size: 18, color: c.textSecondary),
              onSelected: onAction,
              itemBuilder: (_) => [
                const PopupMenuItem(
                  value: TransactionAction.edit,
                  child: Text('Editar'),
                ),
                if (provisioned)
                  const PopupMenuItem(
                    value: TransactionAction.confirm,
                    child: Text('Confirmar'),
                  ),
                const PopupMenuItem(
                  value: TransactionAction.duplicate,
                  child: Text('Duplicar'),
                ),
                const PopupMenuItem(
                  value: TransactionAction.delete,
                  child: Text('Excluir'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Disposição em colunas usada por linhas e cabeçalho.
class TransactionColumns extends StatelessWidget {
  const TransactionColumns({
    super.key,
    required this.ultra,
    required this.date,
    required this.description,
    required this.value,
    required this.menu,
    this.origin = const SizedBox.shrink(),
    this.category = const SizedBox.shrink(),
  });

  final bool ultra;
  final Widget date;
  final Widget description;
  final Widget origin;
  final Widget category;
  final Widget value;
  final Widget menu;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      SizedBox(
        width: ultra ? kTxDateWidth : kTxDateWidthSimple,
        child: Align(
          alignment: Alignment.centerLeft,
          // Encolhe em vez de estourar quando a fonte é larga (ex.: Ahem nos testes).
          child: FittedBox(fit: BoxFit.scaleDown, child: date),
        ),
      ),
      Expanded(child: description),
      if (ultra) ...[
        SizedBox(width: kTxOriginWidth, child: origin),
        SizedBox(width: kTxCategoryWidth, child: category),
      ],
      SizedBox(
        width: kTxValueWidth,
        child: Align(
          alignment: Alignment.centerRight,
          child: FittedBox(fit: BoxFit.scaleDown, child: value),
        ),
      ),
      SizedBox(width: kTxMenuWidth, child: menu),
    ],
  );
}

/// Cabeçalho fixo da tabela. Rótulos ordenáveis só quando [onSort] é dado (Ultra).
class TransactionTableHeader extends StatelessWidget {
  const TransactionTableHeader({
    super.key,
    required this.ultra,
    this.sort,
    this.onSort,
  });

  final bool ultra;
  final TxSort? sort;
  final ValueChanged<TxSortColumn>? onSort;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final sortCallback = onSort;
    Widget label(String text, TxSortColumn column, {bool alignEnd = false}) =>
        SortableHeaderLabel(
          label: text,
          active: sort?.column == column,
          ascending: sort?.ascending ?? false,
          onTap: sortCallback == null ? null : () => sortCallback(column),
          alignEnd: alignEnd,
        );
    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: c.border)),
      ),
      child: SizedBox(
        height: 32,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpace.sm),
          child: TransactionColumns(
            ultra: ultra,
            date: label('Data', TxSortColumn.date),
            description: label('Descrição', TxSortColumn.description),
            origin: ultra
                ? label('Conta / Cartão', TxSortColumn.origin)
                : const SizedBox.shrink(),
            category: ultra
                ? label('Categoria', TxSortColumn.category)
                : const SizedBox.shrink(),
            value: label('Valor', TxSortColumn.value, alignEnd: true),
            menu: const SizedBox.shrink(),
          ),
        ),
      ),
    );
  }
}
