import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../domain/card_entity.dart';
import '../domain/statement_cycle.dart';
import '../domain/statement_service.dart';
import '../../../core/services/repository_locator.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_empty_state.dart';
import '../../transactions/domain/transaction_entity.dart';
import '../../categories/domain/category_entity.dart';

class CardStatementsPage extends StatefulWidget {
  const CardStatementsPage({super.key, required this.card});
  final CardEntity card;

  @override
  State<CardStatementsPage> createState() => _CardStatementsPageState();
}

class _CardStatementsPageState extends State<CardStatementsPage> {
  final _service = StatementService.instance;

  List<StatementCycle> _cycles = [];
  List<CategoryEntity> _categories = [];
  int _selectedIndex = 0;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final locator = RepositoryLocator.instance;
    final transactions = await locator.transactions.getAll();
    final categories = await locator.categories.getAll();
    final cycles = await _service.cyclesForCard(
      widget.card,
      transactions,
      count: 6,
    );
    setState(() {
      _cycles = cycles;
      _categories = categories;
      _selectedIndex = 0;
      _isLoading = false;
    });
  }

  StatementCycle get _current => _cycles[_selectedIndex];

  Future<void> _togglePaid() async {
    final cycle = _current;
    final newPaid = !cycle.isPaid;
    await _service.markPaid(
      widget.card.id,
      cycle.cycleEnd.year,
      cycle.cycleEnd.month,
      paid: newPaid,
    );
    final locator = RepositoryLocator.instance;
    final transactions = await locator.transactions.getAll();
    final updated = await _service.cyclesForCard(
      widget.card,
      transactions,
      count: 6,
    );
    setState(() {
      _cycles = updated;
    });
    if (!mounted) return;
    final label = DateFormat('MMM/yyyy', 'pt_BR').format(cycle.cycleEnd);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          newPaid
              ? 'Fatura de $label marcada como paga'
              : 'Fatura de $label desmarcada',
        ),
      ),
    );
  }

  CategoryEntity? _categoryOf(TransactionEntity tx) {
    if (tx.categoryId == null) return null;
    try {
      return _categories.firstWhere((c) => c.id == tx.categoryId);
    } catch (_) {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('${widget.card.name} — Faturas'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _cycles.isEmpty
              ? const AppEmptyState(
                  icon: Icons.receipt_long_outlined,
                  title: 'Sem faturas',
                  message: 'Ainda não há ciclos de fatura para este cartão.',
                )
              : Column(
                  children: [
                    _CyclePicker(
                      cycles: _cycles,
                      selectedIndex: _selectedIndex,
                      onChanged: (i) => setState(() => _selectedIndex = i),
                    ),
                    const Divider(height: 1),
                    _CycleHeader(cycle: _current),
                    const Divider(height: 1),
                    Expanded(
                      child: _current.transactions.isEmpty
                          ? const AppEmptyState(
                              icon: Icons.receipt_long_outlined,
                              title: 'Nenhuma transação',
                              message: 'Nenhuma despesa neste período.',
                            )
                          : ListView.separated(
                              padding: const EdgeInsets.only(
                                  bottom: 100, top: AppSpacing.xs),
                              itemCount: _current.transactions.length,
                              separatorBuilder: (_, __) =>
                                  const Divider(height: 1),
                              itemBuilder: (context, i) {
                                final tx = _current.transactions[i];
                                return _TransactionTile(
                                  tx: tx,
                                  category: _categoryOf(tx),
                                );
                              },
                            ),
                    ),
                    _CycleFooter(
                      cycle: _current,
                      onTogglePaid: _togglePaid,
                    ),
                  ],
                ),
    );
  }
}

// ── _CyclePicker ──────────────────────────────────────────────────────────

class _CyclePicker extends StatelessWidget {
  const _CyclePicker({
    required this.cycles,
    required this.selectedIndex,
    required this.onChanged,
  });

  final List<StatementCycle> cycles;
  final int selectedIndex;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final cycle = cycles[selectedIndex];
    final label = DateFormat('MMM yyyy', 'pt_BR').format(cycle.cycleEnd);
    final canGoBack = selectedIndex < cycles.length - 1;
    final canGoForward = selectedIndex > 0;

    return Padding(
      padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.sm, vertical: AppSpacing.xs),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
            icon: const Icon(Icons.chevron_left),
            onPressed: canGoBack ? () => onChanged(selectedIndex + 1) : null,
          ),
          Text(
            label,
            style: AppText.sectionLabel.copyWith(
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
          IconButton(
            icon: const Icon(Icons.chevron_right),
            onPressed:
                canGoForward ? () => onChanged(selectedIndex - 1) : null,
          ),
        ],
      ),
    );
  }
}

// ── _CycleHeader ──────────────────────────────────────────────────────────

class _CycleHeader extends StatelessWidget {
  const _CycleHeader({required this.cycle});
  final StatementCycle cycle;

  @override
  Widget build(BuildContext context) {
    final fmt = DateFormat('dd/MMM', 'pt_BR');
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final dueDay =
        DateTime(cycle.dueDate.year, cycle.dueDate.month, cycle.dueDate.day);
    final isOverdue = !cycle.isPaid && dueDay.isBefore(today);

    final (badgeLabel, badgeColor) = switch (true) {
      _ when cycle.isPaid        => ('Paga', AppColors.limitLow),
      _ when isOverdue           => ('Vencida', AppColors.danger),
      _ when cycle.isClosingToday => ('Fecha hoje', AppColors.warning),
      _ when cycle.isOpen        => ('Aberta', AppColors.primary),
      _                          => ('Pendente', AppColors.warning),
    };

    return Padding(
      padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg, vertical: AppSpacing.md),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${fmt.format(cycle.cycleStart)} → ${fmt.format(cycle.cycleEnd)}',
                  style: AppText.body.copyWith(
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Venc. ${fmt.format(cycle.dueDate)}',
                  style: AppText.secondary.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.sm, vertical: AppSpacing.xs),
            decoration: BoxDecoration(
              color: badgeColor.withOpacity(0.12),
              borderRadius: BorderRadius.circular(AppRadius.chip),
            ),
            child: Text(
              badgeLabel,
              style: AppText.badge.copyWith(color: badgeColor),
            ),
          ),
        ],
      ),
    );
  }
}

// ── _TransactionTile ───────────────────────────────────────────────────────

class _TransactionTile extends StatelessWidget {
  const _TransactionTile({required this.tx, this.category});
  final TransactionEntity tx;
  final CategoryEntity? category;

  @override
  Widget build(BuildContext context) {
    final fmt = DateFormat('dd/MM', 'pt_BR');
    final isProvisioned = tx.isProvisioned;
    final iconWidget = category != null
        ? Text(
            String.fromCharCode(category!.iconCodePoint),
            style: const TextStyle(fontSize: 20),
          )
        : const Icon(Icons.label_outline, size: 20);

    return Padding(
      padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg, vertical: AppSpacing.sm),
      child: Row(
        children: [
          iconWidget,
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  tx.description,
                  style: AppText.body.copyWith(
                    color: Theme.of(context).colorScheme.onSurface,
                    fontStyle: isProvisioned
                        ? FontStyle.italic
                        : FontStyle.normal,
                  ),
                ),
                Text(
                  fmt.format(tx.date),
                  style: AppText.secondary.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          if (isProvisioned)
            Padding(
              padding: const EdgeInsets.only(right: AppSpacing.xs),
              child: Icon(
                Icons.schedule_outlined,
                size: 14,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          Text(
            'R\$ ${tx.amount.amount.toStringAsFixed(2)}',
            style: AppText.amount.copyWith(
              color: AppColors.danger,
              fontStyle:
                  isProvisioned ? FontStyle.italic : FontStyle.normal,
            ),
          ),
        ],
      ),
    );
  }
}

// ── _CycleFooter ────────────────────────────────────────────────────────

class _CycleFooter extends StatelessWidget {
  const _CycleFooter({
    required this.cycle,
    required this.onTogglePaid,
  });

  final StatementCycle cycle;
  final VoidCallback onTogglePaid;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final endDay = DateTime(
        cycle.cycleEnd.year, cycle.cycleEnd.month, cycle.cycleEnd.day);
    final isPartial = endDay.isAfter(today) || endDay == today;
    final cs = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg, AppSpacing.md, AppSpacing.lg, AppSpacing.lg),
      decoration: BoxDecoration(
        color: cs.surface,
        border: Border(
          top: BorderSide(
            color:
                Theme.of(context).dividerTheme.color ?? AppColors.divider,
          ),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                isPartial ? 'Total parcial' : 'Total da fatura',
                style: AppText.sectionLabel.copyWith(color: cs.onSurface),
              ),
              Text(
                'R\$ ${cycle.total.toStringAsFixed(2)}',
                style: AppText.amount.copyWith(color: AppColors.danger),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          SizedBox(
            width: double.infinity,
            child: cycle.isPaid
                ? OutlinedButton.icon(
                    onPressed: onTogglePaid,
                    icon: const Icon(Icons.undo, size: 16),
                    label: const Text('Desmarcar como paga'),
                  )
                : ElevatedButton.icon(
                    onPressed: onTogglePaid,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.limitLow,
                      foregroundColor: Colors.white,
                    ),
                    icon: const Icon(Icons.check_circle_outline, size: 16),
                    label: const Text('Marcar como paga'),
                  ),
          ),
        ],
      ),
    );
  }
}
