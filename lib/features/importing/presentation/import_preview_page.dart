// Tela cheia de prévia da importação. Contrato: docs/SPEC.md §5.16 e §7.3 (Fase 8).

import 'package:flutter/material.dart';

import '../../../app/app_scope.dart';
import '../../../core/models/app_settings.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text.dart';
import '../../categories/domain/transaction_category.dart';
import '../../rules/domain/transaction_rule.dart';
import '../../transactions/domain/transaction.dart';
import '../domain/import_matcher.dart';
import '../domain/imported_line.dart';
import '../domain/import_session.dart';
import 'import_preview_row.dart';

/// Largura mínima da tabela no Ultra; abaixo disso rola na horizontal.
const double _kUltraMinWidth = 1100;

/// Espelha `_excludeByDefault` de import_session.dart (privado): "Marcar todas" não remarca essas linhas.
const Set<ImportFlag> _flagsExcludedByDefault = {
  ImportFlag.fitidDuplicate,
  ImportFlag.probableDuplicate,
  ImportFlag.existingInstallment,
  ImportFlag.invoicePaymentLike,
};

/// Marca todas, exceto linhas com flag que exclui por padrão (essas mantêm o estado atual).
ImportSession _markAllSafe(ImportSession session) {
  // setAllIncluded copia a lista inteira uma vez; só as linhas flagadas voltam ao estado anterior.
  var next = session.setAllIncluded(true);
  for (final (i, r) in session.rows.indexed) {
    if (r.match.flags.any(_flagsExcludedByDefault.contains)) {
      next = next.setInclude(i, r.include);
    }
  }
  return next;
}

/// Abre a prévia em tela cheia. Devolve a sessão ao importar; `null` ao fechar/cancelar.
Future<ImportSession?> showImportPreview(
  BuildContext context, {
  required ImportSession session,
  required String sourceLabel,
  List<ImportLineError> errors = const [],
  Map<String, String> bankCategoryMap = const {},
  Future<TransactionRule?> Function(ImportRow row)? onCreateRule,
}) {
  return Navigator.of(context).push<ImportSession>(
    MaterialPageRoute<ImportSession>(
      fullscreenDialog: true,
      builder: (_) => _ImportPreviewPage(
        session: session,
        sourceLabel: sourceLabel,
        errors: errors,
        bankCategoryMap: bankCategoryMap,
        onCreateRule: onCreateRule,
      ),
    ),
  );
}

class _ImportPreviewPage extends StatefulWidget {
  const _ImportPreviewPage({
    required this.session,
    required this.sourceLabel,
    required this.errors,
    required this.bankCategoryMap,
    this.onCreateRule,
  });

  final ImportSession session;
  final String sourceLabel;
  final List<ImportLineError> errors;
  final Map<String, String> bankCategoryMap;
  final Future<TransactionRule?> Function(ImportRow row)? onCreateRule;

  @override
  State<_ImportPreviewPage> createState() => _ImportPreviewPageState();
}

class _ImportPreviewPageState extends State<_ImportPreviewPage> {
  late ImportSession _session;
  bool _onlyUncategorized = false;

  @override
  void initState() {
    super.initState();
    _session = widget.session;
  }

  void _set(ImportSession next) => setState(() => _session = next);

  /// Regra criada: recategoriza só as linhas que não foram editadas à mão.
  Future<void> _createRule(int i) async {
    final onCreate = widget.onCreateRule;
    if (onCreate == null) {
      return;
    }
    final rule = await onCreate(_session.rows[i]);
    if (!mounted || rule == null) {
      return;
    }
    _set(
      _session.recategorize(
        AppScope.of(context).ledger.categorizer,
        bankCategoryMap: widget.bankCategoryMap,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final services = AppScope.of(context);
    final ultra = services.settings.value.mode == AppMode.ultra;
    final session = _session;
    final summary = session.summary;
    final ready = summary.create + summary.confirm + summary.invoicePayments;
    final visible = _onlyUncategorized ? session.uncategorizedIndices() : null;
    final count = visible?.length ?? session.rows.length;

    final tree = services.ledger.categoryTree;
    final expenseOptions = tree.options(CategoryKind.expense);
    final incomeOptions = tree.options(CategoryKind.income);
    final onRule = ultra ? widget.onCreateRule : null;

    final c = context.colors;
    final small = (Theme.of(context).textTheme.bodySmall ?? const TextStyle())
        .copyWith(color: c.textSecondary);

    final errorTip = widget.errors
        .take(10)
        .map((e) => 'Linha ${e.row}: ${e.message}')
        .join('\n');
    final summaryText =
        '${session.rows.length} linhas · ${summary.create} a criar · '
        '${summary.confirm} a confirmar · ${summary.skipped} ignoradas'
        '${ultra ? ' · ${summary.futureInstallments} parcelas futuras' : ''}'
        '${summary.invoicePayments > 0 ? ' · ${summary.invoicePayments} pagamentos de fatura' : ''}';

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpace.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Prévia da importação — ${widget.sourceLabel}',
                      style: AppText.screenTitle(context),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  IconButton(
                    tooltip: 'Fechar',
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              Row(
                children: [
                  Expanded(child: Text(summaryText, style: small)),
                  if (widget.errors.isNotEmpty)
                    Tooltip(
                      message: errorTip,
                      child: Text(
                        '${widget.errors.length} linhas com erro',
                        style: TextStyle(color: c.danger),
                      ),
                    ),
                ],
              ),
              if (ultra)
                Padding(
                  padding: const EdgeInsets.only(top: AppSpace.sm),
                  child: Row(
                    children: [
                      FilterChip(
                        label: const Text('Só sem categoria'),
                        selected: _onlyUncategorized,
                        onSelected: (v) =>
                            setState(() => _onlyUncategorized = v),
                      ),
                      const SizedBox(width: AppSpace.sm),
                      TextButton(
                        onPressed: () => _set(_markAllSafe(_session)),
                        child: const Text('Marcar todas'),
                      ),
                      TextButton(
                        onPressed: () => _set(_session.setAllIncluded(false)),
                        child: const Text('Desmarcar todas'),
                      ),
                    ],
                  ),
                ),
              const SizedBox(height: AppSpace.sm),
              Expanded(
                child: LayoutBuilder(
                  builder: (context, box) {
                    final width = ultra && box.maxWidth < _kUltraMinWidth
                        ? _kUltraMinWidth
                        : box.maxWidth;
                    final table = SizedBox(
                      width: width,
                      child: Column(
                        children: [
                          ImportPreviewHeader(ultra: ultra),
                          Expanded(
                            child: ListView.builder(
                              itemCount: count,
                              itemExtent: ultra ? 40 : 48,
                              itemBuilder: (_, k) {
                                final i = visible?[k] ?? k;
                                final row = session.rows[i];
                                return ImportPreviewRow(
                                  key: ValueKey(i),
                                  row: row,
                                  index: i,
                                  ultra: ultra,
                                  invoiceCandidates: session.invoiceCandidates,
                                  onInvoice: (c) =>
                                      _set(_session.setInvoicePayment(i, c)),
                                  categoryOptions:
                                      row.type == TransactionType.income
                                      ? incomeOptions
                                      : expenseOptions,
                                  labelOf: (c) => tree.label(c.id),
                                  onInclude: (v) =>
                                      _set(_session.setInclude(i, v)),
                                  onCategory: (id) =>
                                      _set(_session.setCategory(i, id)),
                                  onCreateInstallments: ultra
                                      ? (v) => _set(
                                          _session.setCreateInstallments(i, v),
                                        )
                                      : null,
                                  onCreateRule: onRule == null
                                      ? null
                                      : () => _createRule(i),
                                );
                              },
                            ),
                          ),
                        ],
                      ),
                    );
                    return ultra
                        ? SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: table,
                          )
                        : table;
                  },
                ),
              ),
              const Divider(height: AppSpace.lg),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Cancelar'),
                  ),
                  const SizedBox(width: AppSpace.sm),
                  FilledButton(
                    onPressed: ready == 0
                        ? null
                        : () => Navigator.of(context).pop(_session),
                    child: Text('Importar $ready'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
