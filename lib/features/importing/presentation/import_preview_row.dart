// Cabeçalho e linha da tabela da prévia de importação. Contrato: docs/SPEC.md §7.3 (Fase 8).

import 'package:flutter/material.dart';

import '../../../app/app_scope.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/indicators.dart';
import '../../../core/widgets/money.dart';
import '../../../core/widgets/sortable_header.dart';
import '../../categories/domain/transaction_category.dart';
import '../../transactions/domain/transaction.dart';
import '../domain/categorizer.dart';
import '../domain/import_matcher.dart';
import '../domain/import_session.dart';
import '../domain/invoice_payment_match.dart';

// Larguras das colunas: cabeçalho e linha usam as mesmas.
const double _wCheck = 40;
const double _wDate = 56;
const double _wOrigin = 150;
const double _wValue = 116;
const double _wCategory = 180;
const double _wInstallment = 112;
const double _wFlags = 104;
const double _wMenu = 40;

String suggestionSourceLabel(SuggestionSource s) => switch (s) {
  SuggestionSource.rule => 'Regra',
  SuggestionSource.bank => 'Banco',
  SuggestionSource.history => 'Histórico',
  SuggestionSource.dictionary => 'Dicionário',
};

String _flagLabel(ImportFlag f) => switch (f) {
  ImportFlag.fitidDuplicate => 'Já importada (mesmo identificador do banco)',
  ImportFlag.probableDuplicate => 'Provável duplicata de lançamento existente',
  ImportFlag.existingInstallment => 'Parcela já existe no histórico',
  ImportFlag.sameNameAmount => 'Mesmo nome e valor de outro lançamento',
  ImportFlag.invoicePaymentLike => 'Parece pagamento de fatura',
};

Widget _flagIcon(AppColors c, ImportFlag f) {
  final (icon, color) = switch (f) {
    ImportFlag.fitidDuplicate => (Icons.content_copy, c.danger),
    ImportFlag.probableDuplicate => (Icons.content_copy, c.warning),
    ImportFlag.existingInstallment => (Icons.layers, c.warning),
    ImportFlag.sameNameAmount => (Icons.repeat, c.textSecondary),
    ImportFlag.invoicePaymentLike => (Icons.credit_score, c.warning),
  };
  return Tooltip(
    message: _flagLabel(f),
    child: Icon(icon, size: 16, color: color),
  );
}

Widget _check(bool value, ValueChanged<bool>? onChanged) => Checkbox(
  value: value,
  onChanged: onChanged == null ? null : (v) => onChanged(v ?? false),
  visualDensity: VisualDensity.compact,
  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
);

/// Monta uma linha de tabela com as colunas fixas; a descrição ocupa o resto.
Widget _cells({
  required bool ultra,
  required Widget check,
  required Widget date,
  required Widget description,
  Widget? origin,
  required Widget value,
  required Widget category,
  Widget? installment,
  required Widget flags,
  Widget? menu,
}) => Padding(
  padding: const EdgeInsets.symmetric(horizontal: AppSpace.sm),
  child: Row(
    children: [
      SizedBox(width: _wCheck, child: check),
      SizedBox(width: _wDate, child: date),
      Expanded(child: description),
      if (ultra) SizedBox(width: _wOrigin, child: origin),
      SizedBox(width: _wValue, child: value),
      SizedBox(width: _wCategory, child: category),
      if (ultra) SizedBox(width: _wInstallment, child: installment),
      SizedBox(width: _wFlags, child: flags),
      if (ultra) SizedBox(width: _wMenu, child: menu),
    ],
  ),
);

/// Cabeçalho estático da tabela (sem ordenação na prévia).
class ImportPreviewHeader extends StatelessWidget {
  const ImportPreviewHeader({super.key, required this.ultra});

  final bool ultra;

  @override
  Widget build(BuildContext context) {
    Widget label(String text, {bool end = false}) => SortableHeaderLabel(
      label: text,
      active: false,
      ascending: true,
      onTap: null,
      alignEnd: end,
    );

    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: context.colors.border)),
      ),
      child: SizedBox(
        height: 32,
        child: _cells(
          ultra: ultra,
          check: const SizedBox.shrink(),
          date: label('Data'),
          description: label('Descrição'),
          origin: label('Origem'),
          value: label('Valor', end: true),
          category: label('Categoria'),
          installment: label('Parcela'),
          flags: label('Alertas'),
        ),
      ),
    );
  }
}

/// Uma linha da prévia. Simples: sem origem/confiança, sem parcelas editáveis, sem menu de regra.
class ImportPreviewRow extends StatelessWidget {
  const ImportPreviewRow({
    super.key,
    required this.row,
    required this.index,
    required this.ultra,
    required this.categoryOptions,
    required this.onInclude,
    required this.onCategory,
    this.labelOf,
    this.onCreateInstallments,
    this.onCreateRule,
    this.invoiceCandidates = const [],
    this.onInvoice,
  });

  final ImportRow row;

  /// Posição da linha na sessão (chave `import-invoice-{index}` do menu de fatura).
  final int index;
  final bool ultra;

  /// Já filtradas pelo tipo da linha.
  final List<TransactionCategory> categoryOptions;

  /// Texto do item de categoria; padrão `c.name` (a prévia passa `'Pai › Filha'`).
  final String Function(TransactionCategory c)? labelOf;
  final ValueChanged<bool> onInclude;
  final ValueChanged<String?> onCategory;
  final ValueChanged<bool>? onCreateInstallments;
  final VoidCallback? onCreateRule;

  /// Faturas em aberto da conta (vazio em importação de cartão); sem elas não há menu de fatura.
  final List<InvoiceCandidate> invoiceCandidates;

  /// Marca (`InvoiceCandidate`) ou desfaz (`null`) o pagamento de fatura da linha.
  final ValueChanged<InvoiceCandidate?>? onInvoice;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final textTheme = Theme.of(context).textTheme;
    final body = (textTheme.bodyMedium ?? const TextStyle()).copyWith(
      color: row.include ? c.textPrimary : c.textSecondary,
    );
    final small = (textTheme.bodySmall ?? const TextStyle()).copyWith(
      color: c.textSecondary,
    );
    final line = row.line;
    final mark = row.installment;
    final chip = mark == null
        ? null
        : StatusBadge(label: '${mark.index}/${mark.count}', color: c.primary);
    final onRule = ultra ? onCreateRule : null;
    final onSeries = ultra ? onCreateInstallments : null;
    final planned = row.match.plannedMatch;
    final invoiceOn =
        onInvoice != null &&
        invoiceCandidates.isNotEmpty &&
        row.type == TransactionType.expense &&
        (row.isInvoicePayment ||
            row.match.flags.contains(ImportFlag.invoicePaymentLike));
    final invoiceMenu = invoiceOn
        ? _InvoiceMenu(
            index: index,
            selected: row.invoicePayment,
            choices: invoiceChoicesFor(line.date, invoiceCandidates),
            labelOf: (f) => _invoiceLabel(
              AppScope.of(context).cards.byId(f.cardId)?.name,
              f,
            ),
            onPick: onInvoice!,
            style: body,
          )
        : null;
    // Marcado: o menu ocupa o seletor de categoria. Não marcado: fica na coluna de alertas.
    final invoiceInCategory = row.isInvoicePayment ? invoiceMenu : null;
    final invoiceInFlags = row.isInvoicePayment ? null : invoiceMenu;
    final shownFlags = [
      for (final f in row.match.flags)
        if (!(invoiceOn && f == ImportFlag.invoicePaymentLike)) f,
    ];

    final text = ultra && row.finalDescription != line.description
        ? Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                line.description,
                style: small,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              Text(
                row.finalDescription,
                style: body,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          )
        : Text(
            row.finalDescription,
            style: body,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          );

    final source = row.suggestion.source;
    final origin = source == null
        ? Text('—', style: small)
        : Row(
            children: [
              Flexible(
                child: Text(
                  suggestionSourceLabel(source),
                  style: small,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: AppSpace.xs),
              Text(confidenceLabel(row.suggestion.confidence), style: small),
            ],
          );

    final categoryIds = {for (final cat in categoryOptions) cat.id};
    final category = DropdownButton<String?>(
      value: categoryIds.contains(row.categoryId) ? row.categoryId : null,
      isDense: true,
      isExpanded: true,
      style: body,
      items: [
        const DropdownMenuItem<String?>(
          value: null,
          child: Text('Sem categoria'),
        ),
        for (final cat in categoryOptions)
          DropdownMenuItem<String?>(
            value: cat.id,
            child: Text(
              labelOf?.call(cat) ?? cat.name,
              overflow: TextOverflow.ellipsis,
            ),
          ),
      ],
      onChanged: onCategory,
    );

    final installment = mark == null
        ? null
        : Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              ?chip,
              if (onSeries != null && mark.index < mark.count)
                Tooltip(
                  message: 'criar futuras',
                  child: _check(row.createInstallments, onSeries),
                ),
            ],
          );

    final flags = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (ultra)
          for (final f in shownFlags) _flagIcon(c, f)
        else if (shownFlags.isNotEmpty)
          Tooltip(
            message: _flagLabel(shownFlags.first),
            child: Icon(Icons.error_outline, size: 16, color: c.warning),
          ),
        if (ultra && planned != null)
          Tooltip(
            message:
                'Confirma provisionado ${planned.description} de '
                '${formatShortDate(planned.date)}',
            child: Icon(Icons.event_available, size: 16, color: c.primary),
          ),
        if (invoiceInFlags != null) Flexible(child: invoiceInFlags),
      ],
    );

    final menu = onRule == null
        ? null
        : PopupMenuButton<String>(
            tooltip: 'Ações da linha',
            icon: Icon(Icons.more_vert, size: 18, color: c.textSecondary),
            onSelected: (_) => onRule(),
            itemBuilder: (_) => const [
              PopupMenuItem<String>(
                value: 'rule',
                child: Text('Criar regra a partir desta linha'),
              ),
            ],
          );

    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: c.border)),
      ),
      child: _cells(
        ultra: ultra,
        check: _check(row.include, onInclude),
        date: Text(
          ultra ? formatDate(line.date) : formatShortDate(line.date),
          style: small,
        ),
        description: Row(
          children: [
            Expanded(child: text),
            // Simples: o chip de parcela é só informativo, sem coluna própria.
            if (!ultra && chip != null) ...[
              const SizedBox(width: AppSpace.xs),
              chip,
            ],
          ],
        ),
        origin: origin,
        value: MoneyText(
          line.amountCents,
          signed: true,
          colorBySign: ultra && row.include,
          style: body,
        ),
        category: invoiceInCategory ?? category,
        installment: installment,
        flags: flags,
        menu: menu,
      ),
    );
  }
}

/// Rótulo de fatura: "Fatura {cartão} · venc. dd/mm".
String _invoiceLabel(String? cardName, InvoiceCandidate f) =>
    'Fatura ${cardName ?? 'Cartão'} · venc. ${formatShortDate(f.dueDate)}';

/// Menu de pagamento de fatura: rótulo da fatura marcada ou 'Pagamento de fatura?'.
/// Opções: uma fatura por cartão; 'Não é pagamento de fatura' só quando marcado.
class _InvoiceMenu extends StatelessWidget {
  const _InvoiceMenu({
    required this.index,
    required this.selected,
    required this.choices,
    required this.labelOf,
    required this.onPick,
    required this.style,
  });

  final int index;
  final InvoiceCandidate? selected;
  final List<InvoiceCandidate> choices;
  final String Function(InvoiceCandidate f) labelOf;
  final ValueChanged<InvoiceCandidate?> onPick;
  final TextStyle style;

  @override
  Widget build(BuildContext context) {
    final current = selected;
    return PopupMenuButton<int>(
      key: Key('import-invoice-$index'),
      tooltip: 'Pagamento de fatura',
      // Índice negativo = "Não é pagamento de fatura" (null não serve: o menu trata como cancelado).
      onSelected: (k) => onPick(k < 0 ? null : choices[k]),
      itemBuilder: (_) => [
        for (final (k, f) in choices.indexed)
          PopupMenuItem<int>(value: k, child: Text(labelOf(f))),
        if (current != null)
          const PopupMenuItem<int>(
            value: -1,
            child: Text('Não é pagamento de fatura'),
          ),
      ],
      child: Text(
        current == null ? 'Pagamento de fatura?' : labelOf(current),
        style: style,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }
}
