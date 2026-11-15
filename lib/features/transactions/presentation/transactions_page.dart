import 'package:flutter/material.dart';

import '../../../app/app_scope.dart';
import '../../../app/ledger.dart';
import '../../../core/models/app_settings.dart';
import '../../../core/models/year_month.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/utils/id.dart';
import '../../../core/widgets/widgets.dart';
import '../../importing/presentation/import_flow.dart';
import '../domain/transaction.dart';
import 'transaction_filters.dart';
import 'transaction_form.dart';
import 'transaction_row.dart';

class TransactionsPage extends StatefulWidget {
  const TransactionsPage({super.key});

  @override
  State<TransactionsPage> createState() => _TransactionsPageState();
}

class _TransactionsPageState extends State<TransactionsPage> {
  YearMonth? _month;
  TransactionFilter _filter = const TransactionFilter();
  TxSort _sort = kDefaultTxSort;
  // Troca a chave da barra de filtros: `initialValue` não reseta sozinho.
  int _filterEpoch = 0;

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
        final newButton = FilledButton.icon(
          icon: const Icon(Icons.add),
          label: const Text('Nova transação'),
          onPressed: () => showTransactionForm(context),
        );
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
        return Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1200),
            child: Column(
              children: [
                PageHeader(
                  title: 'Transações',
                  actions: [
                    OutlinedButton.icon(
                      onPressed: () => startImport(context),
                      icon: const Icon(Icons.upload_file),
                      label: const Text('Importar'),
                    ),
                    MonthSelector(
                      value: month,
                      onChanged: (m) => setState(() => _month = m),
                    ),
                  ],
                ),
                if (ultra)
                  Padding(
                    padding: EdgeInsets.fromLTRB(pad, 0, pad, AppSpace.md),
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
                      onChanged: (f) => setState(() => _filter = f),
                    ),
                  ),
                Expanded(
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(pad, 0, pad, AppSpace.lg),
                    child: Column(
                      children: [
                        Expanded(
                          child: _TransactionTable(
                            rows: rows,
                            ultra: ultra,
                            pastBefore: YearMonth.fromDate(
                              s.ledger.today,
                            ).firstDay,
                            services: s,
                            sort: _sort,
                            onSort: (c) =>
                                setState(() => _sort = toggleTxSort(_sort, c)),
                            emptyAction: emptyAction,
                            onAction: (t, a) => _onAction(context, s, t, a),
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
        );
      },
    );
  }

  void _clearFilters() {
    setState(() {
      _filter = const TransactionFilter();
      _filterEpoch++;
    });
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
}

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
  });

  final List<Transaction> rows;
  final bool ultra;
  final DateTime pastBefore;
  final AppServices services;
  final TxSort sort;
  final ValueChanged<TxSortColumn> onSort;
  final Widget emptyAction;
  final void Function(Transaction, TransactionAction) onAction;

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
      itemExtent: ultra ? kTxRowExtentUltra : kTxRowExtentSimple,
      itemCount: rows.length,
      itemBuilder: (context, i) {
        final t = rows[i];
        return TransactionRow(
          transaction: t,
          ultra: ultra,
          past: t.date.isBefore(pastBefore),
          category: ledger.categoriesById[t.categoryId],
          origin: _originName(ledger, t),
          destination: _destinationName(ledger, t),
          onAction: (a) => onAction(t, a),
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
