import 'package:flutter/material.dart';

import '../../../app/app_scope.dart';
import '../../../core/models/app_settings.dart';
import '../../../core/models/year_month.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/widgets.dart';
import '../domain/account.dart';
import 'account_form.dart';
import 'transfer_dialog.dart';

const _noBank = 'Sem banco';
const _wideBreakpoint = 600.0;
const _balanceWidth = 130.0;
const _forecastWidth = 170.0;
const _menuWidth = 48.0;

enum _AccountAction { edit, archive, delete }

/// Contas agrupadas por banco, com saldo atual e (Ultra) previsto do fim do mês.
class AccountsPage extends StatefulWidget {
  const AccountsPage({super.key});

  @override
  State<AccountsPage> createState() => _AccountsPageState();
}

class _AccountsPageState extends State<AccountsPage> {
  bool _showArchived = false;

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    return ListenableBuilder(
      listenable: s.ledger,
      builder: (context, _) {
        final ultra = s.settings.value.mode == AppMode.ultra;
        final wide = MediaQuery.sizeOf(context).width >= _wideBreakpoint;
        final pad = wide ? AppSpace.xl : AppSpace.lg;
        final balances = s.ledger.accountBalances;
        final active = s.accounts.all.where((a) => !a.archived).toList();
        final showArchived = ultra && _showArchived;
        final shown = [
          for (final a in s.accounts.all)
            if (showArchived || !a.archived) a,
        ]..sort((a, b) => a.name.compareTo(b.name));

        // Previsto do fim do mês: uma passada sobre os eventos, por conta.
        final forecastByAccount = <String, int>{};
        if (ultra) {
          final end = YearMonth.fromDate(s.ledger.today).lastDay;
          for (final e in s.ledger.forecast.events) {
            final id = e.accountId;
            if (id != null && !e.date.isAfter(end)) {
              forecastByAccount[id] =
                  (forecastByAccount[id] ?? 0) + e.amountCents;
            }
          }
        }
        final transferEnabled = active.length >= 2;
        final totalCents = active.fold<int>(
          0,
          (sum, a) => sum + (balances[a.id] ?? 0),
        );

        final items = _groupByBank(shown);
        final showForecastColumn = ultra && wide;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            PageHeader(
              title: 'Contas',
              actions: wide
                  ? [
                      OutlinedButton.icon(
                        onPressed: transferEnabled
                            ? () => showTransferDialog(context)
                            : null,
                        icon: const Icon(Icons.swap_horiz),
                        label: const Text('Transferir'),
                      ),
                      FilledButton.icon(
                        onPressed: () => showAccountForm(context),
                        icon: const Icon(Icons.add),
                        label: const Text('Nova conta'),
                      ),
                    ]
                  // Cabeçalho sem espaço para rótulos no mobile (PageHeader não quebra linha).
                  : [
                      IconButton.outlined(
                        tooltip: 'Transferir',
                        onPressed: transferEnabled
                            ? () => showTransferDialog(context)
                            : null,
                        icon: const Icon(Icons.swap_horiz),
                      ),
                      IconButton.filled(
                        tooltip: 'Nova conta',
                        onPressed: () => showAccountForm(context),
                        icon: const Icon(Icons.add),
                      ),
                    ],
            ),
            Expanded(
              child: Align(
                alignment: Alignment.topCenter,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1200),
                  child: Padding(
                    padding: EdgeInsets.all(pad),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        KpiTile(label: 'Saldo total', cents: totalCents),
                        if (ultra) ...[
                          const SizedBox(height: AppSpace.md),
                          Align(
                            alignment: Alignment.centerLeft,
                            child: FilterChip(
                              label: const Text('Mostrar arquivadas'),
                              selected: _showArchived,
                              onSelected: (v) =>
                                  setState(() => _showArchived = v),
                            ),
                          ),
                        ],
                        const SizedBox(height: AppSpace.lg),
                        if (showForecastColumn) const _ColumnHeader(),
                        Expanded(
                          child: items.isEmpty
                              ? EmptyState(
                                  icon: Icons.account_balance_wallet_outlined,
                                  message: s.accounts.isEmpty
                                      ? 'Nenhuma conta cadastrada.'
                                      : 'Todas as contas estão arquivadas.',
                                  action: FilledButton.icon(
                                    onPressed: () => showAccountForm(context),
                                    icon: const Icon(Icons.add),
                                    label: const Text('Nova conta'),
                                  ),
                                )
                              : ListView.builder(
                                  itemCount: items.length,
                                  itemBuilder: (context, i) =>
                                      switch (items[i]) {
                                        final String bank => _BankHeader(bank),
                                        final Account a => _AccountRow(
                                          account: a,
                                          balanceCents: balances[a.id] ?? 0,
                                          forecastCents: ultra
                                              ? (balances[a.id] ?? 0) +
                                                    (forecastByAccount[a.id] ??
                                                        0)
                                              : null,
                                          showForecastColumn:
                                              showForecastColumn,
                                          onAction: (action) =>
                                              _onAction(context, s, a, action),
                                        ),
                                        _ => const SizedBox.shrink(),
                                      },
                                ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Future<void> _onAction(
    BuildContext context,
    AppServices s,
    Account a,
    _AccountAction action,
  ) async {
    switch (action) {
      case _AccountAction.edit:
        await showAccountForm(context, initial: a);
      case _AccountAction.archive:
        await s.accounts.upsert(a.copyWith(archived: !a.archived));
      case _AccountAction.delete:
        await _delete(context, s, a);
    }
  }

  Future<void> _delete(BuildContext context, AppServices s, Account a) async {
    final inUse =
        s.transactions.all.any(
          (t) => t.accountId == a.id || t.toAccountId == a.id,
        ) ||
        s.cards.all.any((c) => c.paymentAccountId == a.id) ||
        s.recurring.all.any((r) => r.accountId == a.id);
    if (inUse) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Conta usada por lançamentos, cartões ou recorrências. Arquive em vez de excluir.',
          ),
        ),
      );
      return;
    }
    final ok = await confirmDialog(
      context,
      title: 'Excluir conta?',
      message: '"${a.name}" será removida.',
      confirmLabel: 'Excluir',
      destructive: true,
    );
    if (ok) {
      await s.accounts.delete(a.id);
    }
  }
}

/// Lista plana: cada banco (String) seguido das suas contas (Account).
/// Ordena bancos por nome e deixa "Sem banco" por último.
List<Object> _groupByBank(List<Account> accounts) {
  final groups = <String, List<Account>>{};
  for (final a in accounts) {
    final bank = a.bankName.isEmpty ? _noBank : a.bankName;
    groups.putIfAbsent(bank, () => []).add(a);
  }
  final banks = groups.keys.toList()
    ..sort((x, y) {
      if (x == _noBank || y == _noBank) {
        return x == y ? 0 : (x == _noBank ? 1 : -1);
      }
      return x.compareTo(y);
    });
  return [
    for (final bank in banks) ...[bank, ...groups[bank]!],
  ];
}

class _BankHeader extends StatelessWidget {
  const _BankHeader(this.bank);

  final String bank;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: AppSpace.lg, bottom: AppSpace.xs),
    child: Text(
      bank,
      style: Theme.of(
        context,
      ).textTheme.titleSmall?.copyWith(color: context.colors.textSecondary),
    ),
  );
}

class _ColumnHeader extends StatelessWidget {
  const _ColumnHeader();

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(
      context,
    ).textTheme.bodySmall?.copyWith(color: context.colors.textSecondary);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpace.xs),
      child: Row(
        children: [
          Expanded(child: Text('Conta', style: style)),
          SizedBox(
            width: _balanceWidth,
            child: Text('Saldo atual', style: style, textAlign: TextAlign.end),
          ),
          SizedBox(
            width: _forecastWidth,
            child: Text(
              'Previsto fim do mês',
              style: style,
              textAlign: TextAlign.end,
            ),
          ),
          const SizedBox(width: _menuWidth),
        ],
      ),
    );
  }
}

class _AccountRow extends StatelessWidget {
  const _AccountRow({
    required this.account,
    required this.balanceCents,
    required this.forecastCents,
    required this.showForecastColumn,
    required this.onAction,
  });

  final Account account;
  final int balanceCents;

  /// null no modo Simples.
  final int? forecastCents;
  final bool showForecastColumn;
  final ValueChanged<_AccountAction> onAction;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final textTheme = Theme.of(context).textTheme;
    final archived = account.archived;
    final nameColor = archived ? c.textSecondary : c.textPrimary;
    final forecast = forecastCents;
    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: c.border)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpace.sm),
        child: Row(
          children: [
            Container(
              width: 12,
              height: 12,
              decoration: BoxDecoration(
                color: Color(account.colorValue),
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: AppSpace.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          account.name,
                          overflow: TextOverflow.ellipsis,
                          style: textTheme.bodyMedium?.copyWith(
                            color: nameColor,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      if (archived) ...[
                        const SizedBox(width: AppSpace.sm),
                        StatusBadge(label: 'Arquivada', color: c.textSecondary),
                      ],
                    ],
                  ),
                  Text(
                    accountTypeLabel(account.type),
                    style: textTheme.bodySmall,
                  ),
                  if (forecast != null && !showForecastColumn)
                    Wrap(
                      children: [
                        Text(
                          'Previsto fim do mês: ',
                          style: textTheme.bodySmall,
                        ),
                        MoneyText(forecast, style: textTheme.bodySmall),
                      ],
                    ),
                ],
              ),
            ),
            SizedBox(
              width: _balanceWidth,
              child: Align(
                alignment: Alignment.centerRight,
                child: MoneyText(
                  balanceCents,
                  colorBySign: true,
                  style: textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
            if (showForecastColumn)
              SizedBox(
                width: _forecastWidth,
                child: Align(
                  alignment: Alignment.centerRight,
                  child: MoneyText(
                    forecast ?? balanceCents,
                    style: textTheme.bodyMedium,
                  ),
                ),
              ),
            SizedBox(
              width: _menuWidth,
              child: PopupMenuButton<_AccountAction>(
                tooltip: 'Ações da conta',
                onSelected: onAction,
                itemBuilder: (_) => [
                  const PopupMenuItem(
                    value: _AccountAction.edit,
                    child: Text('Editar'),
                  ),
                  PopupMenuItem(
                    value: _AccountAction.archive,
                    child: Text(archived ? 'Desarquivar' : 'Arquivar'),
                  ),
                  const PopupMenuItem(
                    value: _AccountAction.delete,
                    child: Text('Excluir'),
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
