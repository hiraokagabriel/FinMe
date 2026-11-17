import 'package:flutter/material.dart';

import '../core/models/app_settings.dart';
import '../core/theme/app_colors.dart';
import '../core/theme/app_spacing.dart';
import '../core/widgets/bank_avatar.dart';
import '../features/accounts/presentation/accounts_page.dart';
import '../features/cards/domain/invoice.dart';
import '../features/cards/domain/payment_card.dart';
import '../features/cards/presentation/cards_page.dart';
import '../features/categories/presentation/categories_page.dart';
import '../features/dashboard/presentation/dashboard_page.dart';
import '../features/debts/domain/debt.dart';
import '../features/debts/domain/debt_math.dart';
import '../features/debts/presentation/debt_dialogs.dart';
import '../features/forecast/presentation/forecast_page.dart';
import '../features/net_worth/presentation/asset_dialogs.dart';
import '../features/net_worth/presentation/net_worth_page.dart';
import '../features/reports/presentation/reports_controller.dart';
import '../features/reports/presentation/reports_page.dart';
import '../features/importing/presentation/import_flow.dart';
import '../features/importing/presentation/import_page.dart';
import '../features/recurring/presentation/recurring_form.dart';
import '../features/recurring/presentation/recurring_page.dart';
import '../features/settings/presentation/settings_page.dart';
import '../features/transactions/domain/transaction_search.dart';
import '../features/transactions/presentation/transaction_filters.dart';
import '../features/transactions/presentation/transaction_form.dart';
import '../features/transactions/presentation/transactions_page.dart';
import 'app_commands.dart';
import 'app_scope.dart';
import 'app_shortcuts.dart';
import 'command_palette.dart';
import 'profile_registry.dart';

const _collapseBreakpoint = 900.0;
const _sidebarWidth = 220.0;
const _railWidth = 64.0;
const _transactionsIndex = 4;
const _netWorthIndex = 9;
const _reportsIndex = 10;

const _navItems = <({String label, IconData icon})>[
  (label: 'Painel', icon: Icons.dashboard_outlined),
  (label: 'Previsão', icon: Icons.show_chart),
  (label: 'Cartões', icon: Icons.credit_card),
  (label: 'Contas', icon: Icons.account_balance_wallet_outlined),
  (label: 'Transações', icon: Icons.receipt_long),
  (label: 'Importar', icon: Icons.upload_file),
  (label: 'Recorrentes', icon: Icons.autorenew),
  (label: 'Categorias', icon: Icons.category_outlined),
  (label: 'Ajustes', icon: Icons.settings_outlined),
  // Sem atalho numérico: '1'..'9' seguem nas 9 primeiras páginas (SPEC §7.3 Fase 11).
  (label: 'Patrimônio', icon: Icons.account_balance_outlined),
  // Relatórios também sem atalho numérico (SPEC §7.3 Fase 12).
  (label: 'Relatórios', icon: Icons.insights_outlined),
];

/// Ordem da sidebar (índices de `_navItems`): Patrimônio logo depois de Contas; Relatórios entre Categorias e Ajustes.
const _sidebarOrder = [
  0,
  1,
  2,
  3,
  _netWorthIndex,
  4,
  5,
  6,
  7,
  _reportsIndex,
  8,
];

/// Casca do app: sidebar sempre visível, 220 px com rótulos ou 64 px só com ícones
/// (abaixo de 900 px de largura). Só a página ativa é construída.
/// Atalhos globais e foco: docs/SPEC.md §7.3 "Produtividade (Fase 9)".
class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _index = 0;
  // Troca a chave da página de Transações: a busca vinda da paleta reabre a página com `initialQuery`.
  int _txEpoch = 0;
  String _txQuery = '';
  bool _paletteOpen = false;
  final _shellFocus = FocusNode(debugLabel: 'shell');
  final _txFocus = FocusNode(debugLabel: 'transactions');
  final _txSearchFocus = FocusNode(debugLabel: 'tx-search');
  // Criado no primeiro acesso à página ou a um comando de relatório; filtro e relatório escolhido sobrevivem à troca de página.
  ReportsController? _reportsCtl;

  ReportsController get _reports =>
      _reportsCtl ??= ReportsController(AppScope.of(context));

  @override
  void initState() {
    super.initState();
    FocusManager.instance.addListener(_reclaimFocus);
    WidgetsBinding.instance.addPostFrameCallback((_) => _announceRecovery());
  }

  /// Aviso único de import de backup restaurado no boot (SPEC §9.13): zera a flag para não repetir.
  void _announceRecovery() {
    final services = AppScope.of(context);
    if (!mounted || !services.restoredFromJournal) {
      return;
    }
    services.restoredFromJournal = false;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'A última importação de backup não terminou. Os dados anteriores foram restaurados.',
        ),
      ),
    );
  }

  @override
  void dispose() {
    FocusManager.instance.removeListener(_reclaimFocus);
    _shellFocus.dispose();
    _txFocus.dispose();
    _txSearchFocus.dispose();
    _reportsCtl?.dispose();
    super.dispose();
  }

  /// Troca de página limpa a busca vinda da paleta e devolve o foco ao shell.
  void _select(int i) {
    setState(() {
      _index = i;
      _txQuery = '';
    });
    _reclaimFocus();
  }

  /// Foco some (linha excluída, clique fora): pede foco pós-frame, sem rota por cima.
  void _reclaimFocus() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !(ModalRoute.of(context)?.isCurrent ?? false)) {
        return;
      }
      final primary = FocusManager.instance.primaryFocus;
      if (primary != null && primary is! FocusScopeNode) {
        return;
      }
      (_index == _transactionsIndex ? _txFocus : _shellFocus).requestFocus();
    });
  }

  bool get _onUltraTransactions =>
      _index == _transactionsIndex &&
      AppScope.of(context).settings.value.mode == AppMode.ultra;

  /// Atalhos sem modificador (N, /, 1–9) são desligados com digitação; Ctrl+K e Ctrl+I valem sempre.
  Map<Type, Action<Intent>> _actions() => {
    OpenPaletteIntent: CallbackAction<OpenPaletteIntent>(
      onInvoke: (_) => _openPalette(),
    ),
    ImportFileIntent: CallbackAction<ImportFileIntent>(
      onInvoke: (_) => startImport(context),
    ),
    NewTransactionIntent: TypingGuardAction<NewTransactionIntent>(
      onInvoke: (_) => showTransactionForm(context),
    ),
    FocusSearchIntent: TypingGuardAction<FocusSearchIntent>(
      onInvoke: (_) {
        if (_onUltraTransactions) {
          _txSearchFocus.requestFocus();
          return null;
        }
        return _openPalette();
      },
    ),
    GoToPageIntent: TypingGuardAction<GoToPageIntent>(
      onInvoke: (intent) {
        _select(intent.index);
        return null;
      },
    ),
  };

  /// Abre a paleta com índice de transações construído uma vez (Simples exclui provisionados de conta).
  Future<void> _openPalette() async {
    if (_paletteOpen) {
      return;
    }
    final s = AppScope.of(context);
    final ultra = s.settings.value.mode == AppMode.ultra;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final all = s.transactions.all;
    final index = TransactionSearchIndex(
      ultra ? all : all.where((t) => !isProvisioned(t)),
      // Com valores ocultos, digitar um valor não pode revelar a transação pelo casamento exato.
      matchAmounts: !s.settings.value.hideValues,
    );
    _paletteOpen = true;
    try {
      await showCommandPalette(
        context,
        commands: buildAppCommands(
          settings: s.settings.value,
          pages: _navItems,
          onGoTo: _select,
          onNewTransaction: () => showTransactionForm(context),
          onImport: () => startImport(context),
          onNewRecurring: () => showRecurringForm(context),
          onNewAsset: () => showAssetForm(context),
          onNewDebt: () => showDebtForm(context),
          onOpenReport: (k) {
            _reports.selected = k;
            _select(_reportsIndex);
          },
          onToggleMode: () => s.settings.update(
            (c) => c.copyWith(mode: ultra ? AppMode.simple : AppMode.ultra),
          ),
          onToggleTheme: () => s.settings.update(
            (c) => c.copyWith(
              theme: dark ? ThemePreference.light : ThemePreference.dark,
            ),
          ),
          onToggleHideValues: () =>
              s.settings.update((c) => c.copyWith(hideValues: !c.hideValues)),
        ),
        search: (q) => q.length < 2
            ? const <PaletteEntry>[]
            : [
                if (ultra)
                  filterTransactionsEntry(
                    q,
                    onRun: () => _filterTransactions(q),
                  ),
                ...transactionEntries(
                  index.search(q, limit: 20),
                  ledger: s.ledger,
                  onOpen: (t) => showTransactionForm(context, initial: t),
                ),
              ],
      );
    } finally {
      _paletteOpen = false;
    }
  }

  void _filterTransactions(String query) {
    setState(() {
      _txQuery = query;
      _txEpoch++;
      _index = _transactionsIndex;
    });
  }

  @override
  Widget build(BuildContext context) {
    final services = AppScope.of(context);
    return ListenableBuilder(
      listenable: services.ledger,
      builder: (context, _) {
        final ultra = services.settings.value.mode == AppMode.ultra;
        final collapsed =
            MediaQuery.sizeOf(context).width < _collapseBreakpoint;
        final width = collapsed ? _railWidth : _sidebarWidth;
        return Shortcuts(
          shortcuts: kAppShortcuts,
          child: Actions(
            actions: _actions(),
            child: Focus(
              focusNode: _shellFocus,
              autofocus: true,
              child: Scaffold(
                body: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    AnimatedContainer(
                      width: width,
                      duration: AppMotion.normal,
                      curve: AppMotion.curve,
                      color: context.colors.sidebar,
                      // Conteúdo já em largura final; o ClipRect corta enquanto a sidebar anima.
                      child: ClipRect(
                        child: OverflowBox(
                          alignment: Alignment.topLeft,
                          minWidth: width,
                          maxWidth: width,
                          child: _Sidebar(
                            index: _index,
                            badges: _badges(services, ultra),
                            ultra: ultra,
                            collapsed: collapsed,
                            onSelect: _select,
                            onSearch: _openPalette,
                            onToggleMode: (on) => services.settings.update(
                              (s) => s.copyWith(
                                mode: on ? AppMode.ultra : AppMode.simple,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    Expanded(child: _pageFor(_index)),
                  ],
                ),
                floatingActionButton: FloatingActionButton.extended(
                  tooltip: 'Atalho: N',
                  onPressed: () => showTransactionForm(context),
                  icon: const Icon(Icons.add),
                  label: const Text('Nova transação'),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _pageFor(int index) => switch (index) {
    1 => const ForecastPage(),
    2 => const CardsPage(),
    3 => const AccountsPage(),
    _transactionsIndex => TransactionsPage(
      key: ValueKey('tx-$_txEpoch'),
      focusNode: _txFocus,
      searchFocusNode: _txSearchFocus,
      initialQuery: _txQuery,
    ),
    5 => const ImportPage(),
    6 => const RecurringPage(),
    7 => const CategoriesPage(),
    8 => const SettingsPage(),
    _netWorthIndex => const NetWorthPage(),
    _reportsIndex => ReportsPage(controller: _reports),
    _ => const DashboardPage(),
  };
}

/// Contagens do modo Ultra: faturas vencidas (Cartões) e provisionados atrasados (Transações).
List<int> _badges(AppServices s, bool ultra) {
  final counts = List<int>.filled(_navItems.length, 0);
  if (!ultra) {
    return counts;
  }
  final today = s.ledger.today;
  var overdue = 0;
  for (final card in s.cards.all) {
    if (card.kind != CardKind.credit) {
      continue;
    }
    overdue += s.ledger
        .invoicesFor(card.id)
        .where((i) => i.statusOn(today) == InvoiceStatus.overdue)
        .length;
  }
  counts[2] = overdue;
  counts[_transactionsIndex] = s.transactions.all
      .where((t) => t.isPlanned && t.date.isBefore(today))
      .length;
  // Patrimônio: dívidas "devo" vencidas (SPEC §7.3 Fase 11).
  counts[_netWorthIndex] = s.debts.all
      .where(
        (d) => d.direction == DebtDirection.iOwe && isDebtOverdue(d, today),
      )
      .length;
  return counts;
}

class _Sidebar extends StatelessWidget {
  const _Sidebar({
    required this.index,
    required this.badges,
    required this.ultra,
    required this.collapsed,
    required this.onSelect,
    required this.onSearch,
    required this.onToggleMode,
  });

  final int index;
  final List<int> badges;
  final bool ultra;
  final bool collapsed;
  final ValueChanged<int> onSelect;
  final VoidCallback onSearch;
  final ValueChanged<bool> onToggleMode;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _ProfileHeader(collapsed: collapsed),
        _SearchEntry(collapsed: collapsed, onTap: onSearch),
        Expanded(
          child: ListView.builder(
            itemCount: _sidebarOrder.length,
            itemBuilder: (context, k) {
              final i = _sidebarOrder[k];
              return _NavTile(
                label: _navItems[i].label,
                icon: _navItems[i].icon,
                number: i < 9 ? i + 1 : null,
                selected: i == index,
                badge: badges[i],
                collapsed: collapsed,
                onTap: () => onSelect(i),
              );
            },
          ),
        ),
        const Divider(height: 1),
        if (collapsed)
          Center(
            child: IconButton(
              tooltip: ultra ? 'Modo: Ultra' : 'Modo: Simples',
              icon: Icon(ultra ? Icons.bolt : Icons.bolt_outlined),
              onPressed: () => onToggleMode(!ultra),
            ),
          )
        else
          SwitchListTile(
            dense: true,
            value: ultra,
            onChanged: onToggleMode,
            contentPadding: const EdgeInsets.symmetric(horizontal: AppSpace.lg),
            title: Text(
              ultra ? 'Modo: Ultra' : 'Modo: Simples',
              style: textTheme.bodyMedium,
            ),
          ),
      ],
    );
  }
}

/// Topo da sidebar: perfil aberto e "Trocar perfil" (SPEC §10.5). Sem `ProfileScope` (testes), só o nome do app.
class _ProfileHeader extends StatelessWidget {
  const _ProfileHeader({required this.collapsed});

  final bool collapsed;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final scope = ProfileScope.maybeOf(context);
    if (scope == null) {
      return Padding(
        padding: const EdgeInsets.all(AppSpace.lg),
        child: collapsed
            ? Center(child: Text('F', style: textTheme.titleLarge))
            : Text('FinMe', style: textTheme.titleLarge),
      );
    }
    return ListenableBuilder(
      listenable: scope.registry,
      builder: (context, _) {
        final name = scope.registry.byId(scope.activeId)?.name ?? 'FinMe';
        return Padding(
          padding: const EdgeInsets.all(AppSpace.sm),
          child: PopupMenuButton<void>(
            key: const ValueKey('sidebar-profile'),
            tooltip: collapsed ? 'Perfil: $name' : 'Perfil',
            position: PopupMenuPosition.under,
            itemBuilder: (_) => [
              PopupMenuItem(
                onTap: scope.switchProfile,
                child: const ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(Icons.swap_horiz),
                  title: Text('Trocar perfil'),
                ),
              ),
            ],
            child: Padding(
              padding: const EdgeInsets.all(AppSpace.sm),
              child: Row(
                mainAxisAlignment: collapsed
                    ? MainAxisAlignment.center
                    : MainAxisAlignment.start,
                children: [
                  BankAvatar(bankName: name, size: 28),
                  if (!collapsed) ...[
                    const SizedBox(width: AppSpace.sm),
                    Expanded(
                      child: Text(
                        name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: textTheme.titleSmall,
                      ),
                    ),
                    Icon(
                      Icons.unfold_more,
                      size: 16,
                      color: context.colors.textSecondary,
                    ),
                  ],
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Entrada de busca da sidebar: abre a paleta (Ctrl+K). Colapsada, vira só ícone.
class _SearchEntry extends StatelessWidget {
  const _SearchEntry({required this.collapsed, required this.onTap});

  final bool collapsed;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    if (collapsed) {
      return Center(
        child: IconButton(
          icon: const Icon(Icons.search, size: 20),
          tooltip: 'Buscar (Ctrl+K)',
          onPressed: onTap,
        ),
      );
    }
    final colors = context.colors;
    final textTheme = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpace.sm, vertical: 2),
      child: InkWell(
        key: const ValueKey('sidebar-search'),
        borderRadius: AppRadius.cardBorder,
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpace.md,
            vertical: AppSpace.sm,
          ),
          child: Row(
            children: [
              Icon(Icons.search, size: 20, color: colors.textSecondary),
              const SizedBox(width: AppSpace.md),
              Expanded(child: Text('Buscar', style: textTheme.bodyMedium)),
              Text(
                'Ctrl+K',
                style: textTheme.labelSmall?.copyWith(
                  color: colors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NavTile extends StatelessWidget {
  const _NavTile({
    required this.label,
    required this.icon,
    required this.number,
    required this.selected,
    required this.badge,
    required this.collapsed,
    required this.onTap,
  });

  final String label;
  final IconData icon;

  /// Número do atalho (1..9) da página; null = sem atalho numérico (Patrimônio).
  final int? number;
  final bool selected;
  final int badge;
  final bool collapsed;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final textTheme = Theme.of(context).textTheme;
    final iconWidget = Icon(
      icon,
      size: 20,
      color: selected ? colors.primary : colors.textSecondary,
    );
    final content = collapsed
        ? Center(
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                iconWidget,
                if (badge > 0)
                  Positioned(
                    top: 0,
                    right: 0,
                    child: Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: colors.danger,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
              ],
            ),
          )
        : Row(
            children: [
              iconWidget,
              const SizedBox(width: AppSpace.md),
              Expanded(
                child: Text(
                  label,
                  style: textTheme.bodyMedium?.copyWith(
                    fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                  ),
                ),
              ),
              if (badge > 0) _CountBadge(count: badge),
            ],
          );
    Widget tile = InkWell(
      borderRadius: AppRadius.cardBorder,
      onTap: onTap,
      child: AnimatedContainer(
        duration: AppMotion.fast,
        decoration: BoxDecoration(
          color: selected ? colors.primarySubtle : null,
          borderRadius: AppRadius.cardBorder,
        ),
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpace.md,
          vertical: AppSpace.sm,
        ),
        child: content,
      ),
    );
    final n = number;
    if (collapsed) {
      tile = Tooltip(message: n == null ? label : '$label · $n', child: tile);
    } else if (n != null) {
      tile = Tooltip(message: 'Atalho: $n', child: tile);
    }
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpace.sm, vertical: 2),
      child: tile,
    );
  }
}

class _CountBadge extends StatelessWidget {
  const _CountBadge({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppSpace.xs),
      decoration: BoxDecoration(
        color: colors.danger,
        borderRadius: AppRadius.chipBorder,
      ),
      child: Text(
        '$count',
        style: Theme.of(
          context,
        ).textTheme.labelSmall?.copyWith(color: colors.surface),
      ),
    );
  }
}
