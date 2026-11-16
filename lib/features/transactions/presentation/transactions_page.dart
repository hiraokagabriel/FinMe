import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../app/app_scope.dart';
import '../../../app/app_shortcuts.dart';
import '../../../app/ledger.dart';
import '../../../core/models/app_settings.dart';
import '../../../core/models/year_month.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/utils/id.dart';
import '../../../core/widgets/widgets.dart';
import '../../categories/domain/transaction_category.dart';
import '../../importing/presentation/import_flow.dart';
import '../../rules/domain/rule_engine.dart';
import '../../rules/domain/rule_suggestion.dart';
import '../../rules/presentation/rule_form.dart';
import '../domain/transaction.dart';
import '../domain/transaction_bulk.dart';
import 'bulk_action_bar.dart';
import 'bulk_dialogs.dart';
import 'transaction_filters.dart';
import 'transaction_form.dart';
import 'transaction_row.dart';
import 'transaction_selection.dart';

class TransactionsPage extends StatefulWidget {
  const TransactionsPage({
    super.key,
    this.focusNode,
    this.searchFocusNode,
    this.initialQuery,
  });

  /// Foco da página (atalhos de seleção). Nulo → a página cria e descarta o próprio.
  final FocusNode? focusNode;

  /// Foco do campo de busca da barra de filtros (Ultra); `/` do shell usa este nó.
  final FocusNode? searchFocusNode;

  /// Busca inicial (ex.: vinda da paleta). Só o Ultra mostra a barra de filtros.
  final String? initialQuery;

  @override
  State<TransactionsPage> createState() => _TransactionsPageState();
}

class _TransactionsPageState extends State<TransactionsPage> {
  final FocusNode _ownFocus = FocusNode(debugLabel: 'transactions');
  YearMonth? _month;
  late TransactionFilter _filter;
  TxSort _sort = kDefaultTxSort;
  // Troca a chave da barra de filtros: `initialValue` não reseta sozinho.
  int _filterEpoch = 0;
  TransactionSelection _selection = TransactionSelection.empty;

  FocusNode get _focus => widget.focusNode ?? _ownFocus;

  @override
  void initState() {
    super.initState();
    _filter = TransactionFilter(query: widget.initialQuery ?? '');
  }

  @override
  void dispose() {
    _ownFocus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    return ListenableBuilder(
      listenable: s.ledger,
      builder: (context, _) {
        final ultra = s.settings.value.mode == AppMode.ultra;
        final ledger = s.ledger;
        final month = _month ?? YearMonth.fromDate(ledger.today);
        // Simples: só mês e provisionados ocultos (CLAUDE.md: Provisionados = Ocultos).
        final filter = ultra
            ? _filter
            : const TransactionFilter(showPlanned: false);
        final filtered = visibleTransactions(s.transactions.all, month, filter);
        // Ordenação só no Ultra e só sobre as linhas já filtradas do mês.
        final rows = ultra
            ? sortTransactions(
                filtered,
                _sort,
                originName: (t) => _originText(ledger, t),
                categoryName: (t) =>
                    ledger.categoriesById[t.categoryId]?.name ?? '',
              )
            : filtered;
        // Seleção só no Ultra: ao sair dele zera (já estamos no build, sem setState).
        if (!ultra) {
          _selection = TransactionSelection.empty;
        }
        // Seleção só no Ultra; conta apenas as linhas visíveis (filtro escondido não entra).
        final order = [for (final t in rows) t.id];
        final selected = ultra
            ? [
                for (final t in rows)
                  if (_selection.contains(t.id)) t,
              ]
            : const <Transaction>[];
        final bulkActions = [
          BulkAction(
            label: 'Recategorizar',
            icon: Icons.category_outlined,
            onPressed: () => _recategorize(context, s, selected),
          ),
          BulkAction(
            label: 'Confirmar pagamento',
            icon: Icons.event_available,
            onPressed: selected.any((t) => t.isPlanned)
                ? () => _confirmBulk(context, s, selected)
                : null,
          ),
          BulkAction(
            label: 'Criar regra',
            icon: Icons.rule,
            onPressed: () => _createRule(context, s, selected),
          ),
          BulkAction(
            label: 'Excluir',
            icon: Icons.delete_outline,
            destructive: true,
            onPressed: () => _deleteBulk(context, s, selected),
          ),
        ];
        final newButton = Tooltip(
          message: 'Atalho: N',
          child: FilledButton.icon(
            icon: const Icon(Icons.add),
            label: const Text('Nova transação'),
            onPressed: () => showTransactionForm(context),
          ),
        );
        // Listas do dropdown inline, uma vez por build (categoria de cada `kind`, por nome).
        final expenseOptions = _optionsOf(
          s.categories.all,
          CategoryKind.expense,
        );
        final incomeOptions = _optionsOf(s.categories.all, CategoryKind.income);
        final emptyAction = ultra && _filter.hasCriteria
            ? Wrap(
                alignment: WrapAlignment.center,
                spacing: AppSpace.sm,
                runSpacing: AppSpace.sm,
                children: [
                  newButton,
                  OutlinedButton(
                    onPressed: _clearFilters,
                    child: const Text('Limpar filtros'),
                  ),
                ],
              )
            : newButton;
        final pad = MediaQuery.sizeOf(context).width < 600
            ? AppSpace.lg
            : AppSpace.xl;
        return Shortcuts(
          shortcuts: kSelectionShortcuts,
          child: Actions(
            actions: <Type, Action<Intent>>{
              SelectAllRowsIntent: TypingGuardAction<SelectAllRowsIntent>(
                onInvoke: (_) {
                  if (ultra) {
                    setState(() => _selection = _selection.selectAll(order));
                  }
                  return null;
                },
              ),
              ClearSelectionIntent: TypingGuardAction<ClearSelectionIntent>(
                onInvoke: (_) {
                  if (ultra) {
                    _clearSelection();
                  }
                  return null;
                },
              ),
            },
            child: Focus(
              focusNode: _focus,
              autofocus: true,
              child: Align(
                alignment: Alignment.topCenter,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1200),
                  child: Column(
                    children: [
                      PageHeader(
                        title: 'Transações',
                        actions: [
                          Tooltip(
                            message: 'Atalho: Ctrl+I',
                            child: OutlinedButton.icon(
                              onPressed: () => startImport(context),
                              icon: const Icon(Icons.upload_file),
                              label: const Text('Importar'),
                            ),
                          ),
                          MonthSelector(
                            value: month,
                            // Seleção é por mês: trocar o mês limpa.
                            onChanged: (m) => setState(() {
                              _month = m;
                              _selection = TransactionSelection.empty;
                            }),
                          ),
                        ],
                      ),
                      if (ultra)
                        Padding(
                          padding: EdgeInsets.fromLTRB(
                            pad,
                            0,
                            pad,
                            AppSpace.md,
                          ),
                          child: TransactionFilterBar(
                            key: ValueKey(_filterEpoch),
                            filter: _filter,
                            accounts: [
                              for (final a in s.accounts.all)
                                if (!a.archived) a,
                            ],
                            cards: [
                              for (final c in s.cards.all)
                                if (!c.archived) c,
                            ],
                            categories: s.categories.all,
                            searchFocusNode: widget.searchFocusNode,
                            // Seleção é por filtro: mudar o filtro limpa, como trocar o mês.
                            onChanged: (f) => setState(() {
                              _filter = f;
                              _selection = TransactionSelection.empty;
                            }),
                          ),
                        ),
                      Expanded(
                        child: Padding(
                          padding: EdgeInsets.fromLTRB(
                            pad,
                            0,
                            pad,
                            AppSpace.lg,
                          ),
                          child: Column(
                            children: [
                              if (selected.isNotEmpty)
                                Padding(
                                  padding: const EdgeInsets.only(
                                    bottom: AppSpace.sm,
                                  ),
                                  child: BulkActionBar(
                                    count: selected.length,
                                    actions: bulkActions,
                                    onClear: _clearSelection,
                                  ),
                                ),
                              Expanded(
                                child: _TransactionTable(
                                  rows: rows,
                                  ultra: ultra,
                                  pastBefore: YearMonth.fromDate(
                                    s.ledger.today,
                                  ).firstDay,
                                  services: s,
                                  sort: _sort,
                                  onSort: (c) => setState(
                                    () => _sort = toggleTxSort(_sort, c),
                                  ),
                                  emptyAction: emptyAction,
                                  onAction: (t, a) =>
                                      _onAction(context, s, t, a),
                                  selection: _selection,
                                  allSelected: _selection.allState(order),
                                  onToggleSelect: (id) => _toggleRow(id, order),
                                  onSelectAll: () => _selectAll(order),
                                  expenseOptions: ultra ? expenseOptions : null,
                                  incomeOptions: ultra ? incomeOptions : null,
                                  onCategoryChanged: ultra
                                      ? (t, v) => _saveCategory(s, t, v)
                                      : null,
                                  onAmountChanged:
                                      ultra && !s.settings.value.hideValues
                                      ? (t, v) => _saveAmount(s, t, v)
                                      : null,
                                ),
                              ),
                              _TotalsBar(totals: txTotals(rows), ultra: ultra),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  void _clearFilters() {
    setState(() {
      _filter = const TransactionFilter();
      _selection = TransactionSelection.empty;
      _filterEpoch++;
    });
  }

  /// Shift+clique estende a partir da âncora; clique comum inverte a linha.
  void _toggleRow(String id, List<String> order) {
    final shift = HardwareKeyboard.instance.isShiftPressed;
    setState(() {
      _selection = shift
          ? _selection.extendTo(id, order)
          : _selection.toggle(id);
    });
  }

  /// Cabeçalho: com tudo marcado limpa; senão marca as linhas visíveis.
  void _selectAll(List<String> order) {
    setState(() {
      _selection = _selection.allState(order) == true
          ? TransactionSelection.empty
          : _selection.selectAll(order);
    });
  }

  void _clearSelection() =>
      setState(() => _selection = TransactionSelection.empty);

  /// Edição inline de categoria (Ultra). "Sem categoria" chega como null.
  Future<void> _saveCategory(
    AppServices s,
    Transaction t,
    String? categoryId,
  ) async {
    await s.transactions.upsert(t.copyWith(categoryId: categoryId));
  }

  /// Edição inline de valor (Ultra, sem hideValues). Parcelas não chegam aqui.
  Future<void> _saveAmount(AppServices s, Transaction t, int cents) async {
    await s.transactions.upsert(t.copyWith(amountCents: cents));
  }

  void _notify(BuildContext context, String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _onAction(
    BuildContext context,
    AppServices s,
    Transaction t,
    TransactionAction action,
  ) async {
    switch (action) {
      case TransactionAction.edit:
        await showTransactionForm(context, initial: t);
      case TransactionAction.confirm:
        await _confirmPlanned(context, s, t);
      case TransactionAction.duplicate:
        await s.transactions.upsert(_duplicate(t));
      case TransactionAction.delete:
        await _delete(context, s, t);
    }
  }

  /// Provisionado → pago, com data editável (padrão: hoje).
  Future<void> _confirmPlanned(
    BuildContext context,
    AppServices s,
    Transaction t,
  ) async {
    var date = s.ledger.today;
    var answered = false;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialog) {
          // Duplo clique faria um segundo pop, fechando a rota de baixo.
          void close(bool value) {
            if (!answered) {
              answered = true;
              Navigator.of(ctx).pop(value);
            }
          }

          return AlertDialog(
            title: const Text('Confirmar pagamento'),
            content: DateField(
              value: date,
              label: 'Data do pagamento',
              onChanged: (d) => setDialog(() => date = d),
            ),
            actions: [
              TextButton(
                onPressed: () => close(false),
                child: const Text('Cancelar'),
              ),
              FilledButton(
                onPressed: () => close(true),
                child: const Text('Confirmar'),
              ),
            ],
          );
        },
      ),
    );
    if (ok != true || !context.mounted) {
      return;
    }
    await s.transactions.upsert(
      t.copyWith(status: TransactionStatus.paid, date: date),
    );
  }

  /// Parcela: pergunta se apaga só esta ou o grupo inteiro. Demais: confirmação simples.
  Future<void> _delete(
    BuildContext context,
    AppServices s,
    Transaction t,
  ) async {
    if (t.isInstallment) {
      final group = t.installmentGroupId;
      var answered = false;
      final scope = await showDialog<_DeleteScope>(
        context: context,
        builder: (ctx) {
          // Duplo clique faria um segundo pop, fechando a rota de baixo.
          void close([_DeleteScope? value]) {
            if (!answered) {
              answered = true;
              Navigator.of(ctx).pop(value);
            }
          }

          return AlertDialog(
            title: const Text('Excluir parcela'),
            content: Text(
              '${t.description} · parcela ${t.installmentIndex}/${t.installmentCount}',
            ),
            actions: [
              TextButton(
                onPressed: () => close(),
                child: const Text('Cancelar'),
              ),
              TextButton(
                onPressed: () => close(_DeleteScope.one),
                child: const Text('Só esta parcela'),
              ),
              FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: ctx.colors.danger,
                ),
                onPressed: () => close(_DeleteScope.all),
                child: const Text('Todas as parcelas'),
              ),
            ],
          );
        },
      );
      if (scope == null || !context.mounted) {
        return;
      }
      if (scope == _DeleteScope.one) {
        await s.transactions.delete(t.id);
      } else {
        await s.transactions.deleteWhere((x) => x.installmentGroupId == group);
      }
      return;
    }
    final ok = await confirmDialog(
      context,
      title: 'Excluir transação',
      message: '"${t.description}" será removida.',
      confirmLabel: 'Excluir',
      destructive: true,
    );
    if (!ok || !context.mounted) {
      return;
    }
    await s.transactions.delete(t.id);
  }

  /// Ações em massa (SPEC §6.3). Cada uma grava com um único `upsertAll`/`deleteWhere`.
  Future<void> _recategorize(
    BuildContext context,
    AppServices s,
    List<Transaction> selected,
  ) async {
    final choice = await showBulkCategoryDialog(
      context,
      count: selected.length,
      categories: s.categories.all,
    );
    if (choice == null || !context.mounted) {
      return;
    }
    final result = bulkRecategorize(selected, choice.category);
    await s.transactions.upsertAll(result.changed);
    if (!context.mounted) {
      return;
    }
    final skipped = result.skipped > 0
        ? ' · ${result.skipped} ignoradas (tipo incompatível)'
        : '';
    _notify(
      context,
      '${_countLabel(result.changed.length, 'recategorizada', 'recategorizadas')}$skipped',
    );
  }

  Future<void> _confirmBulk(
    BuildContext context,
    AppServices s,
    List<Transaction> selected,
  ) async {
    final date = await showBulkConfirmDialog(
      context,
      count: selected.length,
      initialDate: s.ledger.today,
    );
    if (date == null || !context.mounted) {
      return;
    }
    final result = bulkConfirmPlanned(selected, date);
    await s.transactions.upsertAll(result.changed);
    if (!context.mounted) {
      return;
    }
    _notify(
      context,
      _countLabel(
        result.changed.length,
        'provisionado confirmado',
        'provisionados confirmados',
      ),
    );
  }

  /// Formulário de regra com o padrão da seleção; a regra salva recategoriza a seleção na hora.
  Future<void> _createRule(
    BuildContext context,
    AppServices s,
    List<Transaction> selected,
  ) async {
    final rule = await showRuleForm(
      context,
      initialPattern: suggestRulePattern([
        for (final t in selected) ruleSubject(t),
      ]),
      initialCategoryId: commonCategoryId(selected),
      sampleDescription: ruleSubject(selected.first),
    );
    if (rule == null || !context.mounted) {
      return;
    }
    final changed = reapplyRules(
      compileRules([rule]),
      selected,
      categoriesById: s.ledger.categoriesById,
      overwriteCategory: true,
    );
    await s.transactions.upsertAll(changed);
    if (!context.mounted) {
      return;
    }
    _notify(
      context,
      'Regra criada · ${_countLabel(changed.length, 'transação atualizada', 'transações atualizadas')}',
    );
  }

  /// Parcelas na seleção pedem o escopo (só as selecionadas ou grupos inteiros).
  Future<void> _deleteBulk(
    BuildContext context,
    AppServices s,
    List<Transaction> selected,
  ) async {
    final groups = installmentGroupsOf(selected).length;
    final wholeGroupsCount = bulkDeleteIds(
      selected,
      s.transactions.all,
      wholeGroups: true,
    ).length;
    final scope = await showBulkDeleteDialog(
      context,
      count: selected.length,
      groups: groups,
      wholeGroupsCount: wholeGroupsCount,
    );
    if (scope == null || !context.mounted) {
      return;
    }
    final ids = bulkDeleteIds(
      selected,
      s.transactions.all,
      wholeGroups: scope == BulkDeleteScope.wholeGroups,
    );
    await s.transactions.deleteWhere((t) => ids.contains(t.id));
    if (!context.mounted) {
      return;
    }
    _clearSelection();
    _notify(
      context,
      _countLabel(ids.length, 'transação excluída', 'transações excluídas'),
    );
  }
}

/// "1 transação" ou "2 transações": singular só para 1.
String _countLabel(int n, String one, String many) =>
    n == 1 ? '1 $one' : '$n $many';

/// Categorias de um `kind`, por nome (opções do dropdown inline).
List<TransactionCategory> _optionsOf(
  List<TransactionCategory> all,
  CategoryKind kind,
) => [
  for (final c in all)
    if (c.kind == kind) c,
]..sort((a, b) => a.name.compareTo(b.name));

enum _DeleteScope { one, all }

/// Cópia avulsa: novo id, sem vínculo de parcela nem de recorrência, mesma data.
Transaction _duplicate(Transaction t) => Transaction.fromMap({
  ...t.toMap(),
  'id': newId(),
  'installmentGroupId': null,
  'installmentIndex': null,
  'installmentCount': null,
  'recurringId': null,
});

/// Conta ou cartão de origem; '—' quando não há vínculo.
String _originName(Ledger ledger, Transaction t) =>
    ledger.accountsById[t.accountId]?.name ??
    ledger.cardsById[t.cardId]?.name ??
    '—';

/// Conta destino (transferência) ou cartão pago (pagamento de fatura).
String? _destinationName(Ledger ledger, Transaction t) => switch (t.type) {
  TransactionType.transfer => ledger.accountsById[t.toAccountId]?.name,
  TransactionType.invoicePayment => ledger.cardsById[t.cardId]?.name,
  _ => null,
};

/// Texto da coluna Conta / Cartão; também é o critério de ordenação dessa coluna.
String _originText(Ledger ledger, Transaction t) {
  final destination = _destinationName(ledger, t);
  final origin = _originName(ledger, t);
  return destination == null ? origin : '$origin → $destination';
}

class _TransactionTable extends StatelessWidget {
  const _TransactionTable({
    required this.rows,
    required this.ultra,
    required this.pastBefore,
    required this.services,
    required this.sort,
    required this.onSort,
    required this.emptyAction,
    required this.onAction,
    required this.selection,
    required this.allSelected,
    required this.onToggleSelect,
    required this.onSelectAll,
    this.expenseOptions,
    this.incomeOptions,
    this.onCategoryChanged,
    this.onAmountChanged,
  });

  final List<Transaction> rows;
  final bool ultra;
  final DateTime pastBefore;
  final AppServices services;
  final TxSort sort;
  final ValueChanged<TxSortColumn> onSort;
  final Widget emptyAction;
  final void Function(Transaction, TransactionAction) onAction;
  final TransactionSelection selection;

  /// Estado do checkbox de cabeçalho (null = parcial).
  final bool? allSelected;
  final ValueChanged<String> onToggleSelect;
  final VoidCallback onSelectAll;

  /// Edição inline (Ultra): opções por `kind` e gravadores; null = célula estática.
  final List<TransactionCategory>? expenseOptions;
  final List<TransactionCategory>? incomeOptions;
  final void Function(Transaction, String?)? onCategoryChanged;
  final void Function(Transaction, int)? onAmountChanged;

  @override
  Widget build(BuildContext context) {
    if (rows.isEmpty) {
      return Card(
        child: EmptyState(
          icon: Icons.receipt_long,
          message: 'Nenhuma transação neste filtro.',
          action: emptyAction,
        ),
      );
    }
    final ledger = services.ledger;
    final list = ListView.builder(
      // Folga para o FAB "Nova transação" não cobrir a última linha.
      padding: const EdgeInsets.only(bottom: 64),
      itemExtent: ultra ? kTxRowExtentUltra : kTxRowExtentSimple,
      itemCount: rows.length,
      itemBuilder: (context, i) {
        final t = rows[i];
        final onCat = onCategoryChanged;
        final onAmount = onAmountChanged;
        return TransactionRow(
          transaction: t,
          ultra: ultra,
          past: t.date.isBefore(pastBefore),
          category: ledger.categoriesById[t.categoryId],
          origin: _originName(ledger, t),
          destination: _destinationName(ledger, t),
          selected: ultra ? selection.contains(t.id) : null,
          onToggleSelect: ultra ? () => onToggleSelect(t.id) : null,
          onAction: (a) => onAction(t, a),
          categoryOptions: t.type == TransactionType.income
              ? incomeOptions
              : expenseOptions,
          onCategoryChanged: onCat == null ? null : (v) => onCat(t, v),
          // Parcela não edita valor inline (ver canEditAmountInline).
          onAmountChanged: onAmount == null || !canEditAmountInline(t)
              ? null
              : (v) => onAmount(t, v),
        );
      },
    );
    if (!ultra) {
      return Card(
        child: Column(
          children: [
            const TransactionTableHeader(ultra: false),
            Expanded(child: list),
          ],
        ),
      );
    }
    // Ultra: tabela rola na horizontal abaixo de kTxUltraMinWidth.
    return Card(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final width = constraints.maxWidth > kTxUltraMinWidth
              ? constraints.maxWidth
              : kTxUltraMinWidth;
          return SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: SizedBox(
              width: width,
              height: constraints.maxHeight,
              child: Column(
                children: [
                  TransactionTableHeader(
                    ultra: true,
                    sort: sort,
                    onSort: onSort,
                    selectable: true,
                    selectAllState: allSelected,
                    onSelectAll: onSelectAll,
                  ),
                  Expanded(child: list),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

/// Rodapé: despesas, provisionado e receitas do filtro ativo.
class _TotalsBar extends StatelessWidget {
  const _TotalsBar({required this.totals, required this.ultra});

  final TxTotals totals;
  // Simples oculta provisionados, então o total provisionado também some.
  final bool ultra;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: AppSpace.md),
    child: Wrap(
      spacing: AppSpace.xl,
      runSpacing: AppSpace.xs,
      children: [
        _Total(label: 'Despesas', cents: totals.expenses),
        if (ultra) _Total(label: 'Provisionado', cents: totals.provisioned),
        _Total(label: 'Receitas', cents: totals.income),
      ],
    ),
  );
}

class _Total extends StatelessWidget {
  const _Total({required this.label, required this.cents});

  final String label;
  final int cents;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Text(
        label,
        style: Theme.of(
          context,
        ).textTheme.bodySmall?.copyWith(color: context.colors.textSecondary),
      ),
      const SizedBox(width: AppSpace.xs),
      MoneyText(cents, style: const TextStyle(fontWeight: FontWeight.w600)),
    ],
  );
}
