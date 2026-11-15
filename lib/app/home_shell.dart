import 'package:flutter/material.dart';

import '../core/models/app_settings.dart';
import '../core/theme/app_colors.dart';
import '../core/theme/app_spacing.dart';
import '../features/accounts/presentation/accounts_page.dart';
import '../features/cards/domain/invoice.dart';
import '../features/cards/domain/payment_card.dart';
import '../features/cards/presentation/cards_page.dart';
import '../features/categories/presentation/categories_page.dart';
import '../features/dashboard/presentation/dashboard_page.dart';
import '../features/forecast/presentation/forecast_page.dart';
import '../features/recurring/presentation/recurring_page.dart';
import '../features/settings/presentation/settings_page.dart';
import '../features/transactions/presentation/transaction_form.dart';
import '../features/transactions/presentation/transactions_page.dart';
import 'app_scope.dart';

const _wideBreakpoint = 900.0;
const _sidebarWidth = 220.0;

const _navItems = <({String label, IconData icon})>[
  (label: 'Painel', icon: Icons.dashboard_outlined),
  (label: 'Previsão', icon: Icons.show_chart),
  (label: 'Cartões', icon: Icons.credit_card),
  (label: 'Contas', icon: Icons.account_balance_wallet_outlined),
  (label: 'Transações', icon: Icons.receipt_long),
  (label: 'Recorrentes', icon: Icons.autorenew),
  (label: 'Categorias', icon: Icons.category_outlined),
  (label: 'Ajustes', icon: Icons.settings_outlined),
];

/// Casca do app: sidebar fixa em telas largas, `Drawer` em telas estreitas.
/// Só a página ativa é construída.
class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _index = 0;
  final _scaffoldKey = GlobalKey<ScaffoldState>();

  @override
  Widget build(BuildContext context) {
    final services = AppScope.of(context);
    return ListenableBuilder(
      listenable: services.ledger,
      builder: (context, _) {
        final ultra = services.settings.value.mode == AppMode.ultra;
        final wide = MediaQuery.sizeOf(context).width >= _wideBreakpoint;
        final sidebar = _Sidebar(
          index: _index,
          badges: _badges(services, ultra),
          ultra: ultra,
          onSelect: (i) {
            _scaffoldKey.currentState?.closeDrawer();
            setState(() => _index = i);
          },
          onToggleMode: (on) => services.settings.update(
            (s) => s.copyWith(mode: on ? AppMode.ultra : AppMode.simple),
          ),
        );
        return Scaffold(
          key: _scaffoldKey,
          appBar: wide ? null : AppBar(title: Text(_navItems[_index].label)),
          drawer: wide
              ? null
              : Drawer(
                  backgroundColor: context.colors.sidebar,
                  child: SafeArea(child: sidebar),
                ),
          body: wide
              ? Row(
                  children: [
                    SizedBox(
                      width: _sidebarWidth,
                      child: ColoredBox(
                        color: context.colors.sidebar,
                        child: sidebar,
                      ),
                    ),
                    Expanded(child: _pageFor(_index)),
                  ],
                )
              : _pageFor(_index),
          floatingActionButton: FloatingActionButton.extended(
            onPressed: () => showTransactionForm(context),
            icon: const Icon(Icons.add),
            label: const Text('Nova transação'),
          ),
        );
      },
    );
  }

  Widget _pageFor(int index) => switch (index) {
    1 => const ForecastPage(),
    2 => const CardsPage(),
    3 => const AccountsPage(),
    4 => const TransactionsPage(),
    5 => const RecurringPage(),
    6 => const CategoriesPage(),
    7 => const SettingsPage(),
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
  counts[4] = s.transactions.all
      .where((t) => t.isPlanned && t.date.isBefore(today))
      .length;
  return counts;
}

class _Sidebar extends StatelessWidget {
  const _Sidebar({
    required this.index,
    required this.badges,
    required this.ultra,
    required this.onSelect,
    required this.onToggleMode,
  });

  final int index;
  final List<int> badges;
  final bool ultra;
  final ValueChanged<int> onSelect;
  final ValueChanged<bool> onToggleMode;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.all(AppSpace.lg),
          child: Text('FinMe', style: textTheme.titleLarge),
        ),
        Expanded(
          child: ListView.builder(
            itemCount: _navItems.length,
            itemBuilder: (context, i) => _NavTile(
              label: _navItems[i].label,
              icon: _navItems[i].icon,
              selected: i == index,
              badge: badges[i],
              onTap: () => onSelect(i),
            ),
          ),
        ),
        const Divider(height: 1),
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

class _NavTile extends StatelessWidget {
  const _NavTile({
    required this.label,
    required this.icon,
    required this.selected,
    required this.badge,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final int badge;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final textTheme = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpace.sm, vertical: 2),
      child: InkWell(
        borderRadius: AppRadius.cardBorder,
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
            color: selected ? colors.primarySubtle : null,
            borderRadius: AppRadius.cardBorder,
          ),
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpace.md,
            vertical: AppSpace.sm,
          ),
          child: Row(
            children: [
              Icon(
                icon,
                size: 20,
                color: selected ? colors.primary : colors.textSecondary,
              ),
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
          ),
        ),
      ),
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
