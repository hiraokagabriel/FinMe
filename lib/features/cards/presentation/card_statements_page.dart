import 'package:flutter/material.dart';

import '../domain/card_entity.dart';
import '../domain/statement_cycle.dart';
import '../domain/statement_service.dart';
import '../../../core/services/repository_locator.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_empty_state.dart';
import '../../transactions/domain/transaction_entity.dart';
import '../../transactions/presentation/new_transaction_page.dart';
import '../../categories/domain/category_entity.dart';

const _months = [
  'jan', 'fev', 'mar', 'abr', 'mai', 'jun',
  'jul', 'ago', 'set', 'out', 'nov', 'dez',
];

String _fmtDayMonth(DateTime d) =>
    '${d.day.toString().padLeft(2, '0')}/${_months[d.month - 1]}';

String _fmtDayMonthNum(DateTime d) =>
    '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}';

String _fmtMonthYear(DateTime d) {
  final m = _months[d.month - 1];
  return '${m[0].toUpperCase()}${m.substring(1)} ${d.year}';
}

String _fmtMonthYearShort(DateTime d) =>
    '${_months[d.month - 1]}/${d.year}';

class CardStatementsPage extends StatefulWidget {
  const CardStatementsPage({super.key, required this.card});
  final CardEntity card;

  @override
  State<CardStatementsPage> createState() => _CardStatementsPageState();
}

class _CardStatementsPageState extends State<CardStatementsPage> {
  final _service = StatementService.instance;

  List<StatementCycle> _cycles     = [];
  List<CategoryEntity> _categories = [];
  int  _selectedIndex = 0;
  bool _isLoading     = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() { _isLoading = true; _error = null; });
    try {
      final locator      = RepositoryLocator.instance;
      final transactions = await locator.transactions.getAll();
      final categories   = await locator.categories.getAll();
      final cycles       = await _service.cyclesForCard(
        widget.card,
        transactions,
        count: 6,
      );
      if (!mounted) return;
      setState(() {
        _cycles        = cycles;
        _categories    = categories;
        _selectedIndex = 0;
        _isLoading     = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _error     = e.toString();
      });
    }
  }

  StatementCycle get _current => _cycles[_selectedIndex];

  Future<void> _togglePaid() async {
    try {
      final cycle   = _current;
      final newPaid = !cycle.isPaid;
      await _service.markPaid(
        widget.card.id,
        cycle.cycleEnd.year,
        cycle.cycleEnd.month,
        paid:     newPaid,
        amount:   newPaid ? cycle.total : null,
        cardName: newPaid ? widget.card.name : null,
      );
      await _loadData();
      if (!mounted) return;
      final label = _fmtMonthYearShort(cycle.cycleEnd);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            newPaid
                ? 'Fatura de $label marcada como paga'
                : 'Fatura de $label desmarcada',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erro ao salvar: $e')),
      );
    }
  }

  Future<void> _openEdit(TransactionEntity tx) async {
    final ok = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => NewTransactionPage(initialTransaction: tx),
      ),
    );
    if (ok == true) await _loadData();
  }

  Future<void> _confirmAndDelete(TransactionEntity tx) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Excluir lançamento'),
        content: Text(
          'Deseja excluir "${tx.description ?? 'Sem descrição'}"?\n'
          'Esta ação não pode ser desfeita.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text('Excluir',
                style: TextStyle(color: AppColors.danger)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await RepositoryLocator.instance.transactions.remove(tx.id);
    await _loadData();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Lançamento excluído')),
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
    if (_error != null) {
      return Scaffold(
        appBar: AppBar(title: Text('${widget.card.name} — Faturas')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.error_outline, size: 48, color: AppColors.danger),
                const SizedBox(height: AppSpacing.md),
                Text('Erro ao carregar faturas', style: AppText.sectionLabel),
                const SizedBox(height: AppSpacing.xs),
                Text(_error!, style: AppText.secondary, textAlign: TextAlign.center),
                const SizedBox(height: AppSpacing.md),
                ElevatedButton(
                  onPressed: _loadData,
                  child: const Text('Tentar novamente'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(title: Text('${widget.card.name} — Faturas')),
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
                      cycles:        _cycles,
                      selectedIndex: _selectedIndex,
                      onChanged:     (i) => setState(() => _selectedIndex = i),
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
                                return Dismissible(
                                  key: ValueKey('stmt_${tx.id}'),
                                  direction: DismissDirection.endToStart,
                                  confirmDismiss: (_) async {
                                    final ok = await showDialog<bool>(
                                      context: context,
                                      builder: (ctx) => AlertDialog(
                                        title: const Text('Excluir lançamento'),
                                        content: Text(
                                          'Deseja excluir "${tx.description ?? 'Sem descrição'}"?',
                                        ),
                                        actions: [
                                          TextButton(
                                            onPressed: () => Navigator.of(ctx).pop(false),
                                            child: const Text('Cancelar'),
                                          ),
                                          TextButton(
                                            onPressed: () => Navigator.of(ctx).pop(true),
                                            child: Text('Excluir',
                                                style: TextStyle(color: AppColors.danger)),
                                          ),
                                        ],
                                      ),
                                    );
                                    return ok ?? false;
                                  },
                                  onDismissed: (_) async {
                                    await RepositoryLocator.instance.transactions.remove(tx.id);
                                    await _loadData();
                                    if (!mounted) return;
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(content: Text('Lançamento excluído')),
                                    );
                                  },
                                  background: Container(
                                    color: AppColors.danger,
                                    alignment: Alignment.centerRight,
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: AppSpacing.lg),
                                    child: const Icon(Icons.delete_outline,
                                        color: Colors.white),
                                  ),
                                  child: _TransactionTile(
                                    tx:       tx,
                                    category: _categoryOf(tx),
                                    onTap:    () => _openEdit(tx),
                                  ),
                                );
                              },
                            ),
                    ),
                    _CycleFooter(
                      cycle:        _current,
                      onTogglePaid: _togglePaid,
                    ),
                  ],
                ),
    );
  }
}

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
    final label       = _fmtMonthYear(cycles[selectedIndex].cycleEnd);
    final canGoBack   = selectedIndex < cycles.length - 1;
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
            onPressed: canGoForward ? () => onChanged(selectedIndex - 1) : null,
          ),
        ],
      ),
    );
  }
}

class _CycleHeader extends StatelessWidget {
  const _CycleHeader({required this.cycle});
  final StatementCycle cycle;

  @override
  Widget build(BuildContext context) {
    final now     = DateTime.now();
    final today   = DateTime(now.year, now.month, now.day);
    final dueDay  = DateTime(
        cycle.dueDate.year, cycle.dueDate.month, cycle.dueDate.day);
    final isOverdue = !cycle.isPaid && dueDay.isBefore(today);

    final (badgeLabel, badgeColor) = switch (true) {
      _ when cycle.isPaid         => ('Paga',       AppColors.limitLow),
      _ when isOverdue            => ('Vencida',    AppColors.danger),
      _ when cycle.isClosingToday => ('Fecha hoje', AppColors.warning),
      _ when cycle.isOpen         => ('Aberta',     AppColors.primary),
      _                           => ('Pendente',   AppColors.warning),
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
                  '${_fmtDayMonth(cycle.cycleStart)} → ${_fmtDayMonth(cycle.cycleEnd)}',
                  style: AppText.body.copyWith(
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Venc. ${_fmtDayMonth(cycle.dueDate)}',
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

class _TransactionTile extends StatelessWidget {
  const _TransactionTile({
    required this.tx,
    required this.onTap,
    this.category,
  });
  final TransactionEntity tx;
  final CategoryEntity?   category;
  final VoidCallback      onTap;

  @override
  Widget build(BuildContext context) {
    final isProvisioned = tx.isProvisioned;
    final cp            = category?.iconCodePoint;
    final iconWidget    = cp != null
        ? Text(String.fromCharCode(cp), style: const TextStyle(fontSize: 20))
        : const Icon(Icons.label_outline, size: 20);

    return ListTile(
      onTap: onTap,
      leading: iconWidget,
      title: Text(
        tx.description ?? 'Sem descrição',
        style: TextStyle(
          color: Theme.of(context).colorScheme.onSurface,
          fontStyle: isProvisioned ? FontStyle.italic : FontStyle.normal,
        ),
      ),
      subtitle: Text(
        _fmtDayMonthNum(tx.date),
        style: TextStyle(
          color: Theme.of(context).colorScheme.onSurfaceVariant,
          fontSize: 12,
        ),
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
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
            style: TextStyle(
              color: AppColors.danger,
              fontStyle: isProvisioned ? FontStyle.italic : FontStyle.normal,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(width: AppSpacing.xs),
          Icon(
            Icons.chevron_right,
            size: 16,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ],
      ),
    );
  }
}

class _CycleFooter extends StatelessWidget {
  const _CycleFooter({
    required this.cycle,
    required this.onTogglePaid,
  });

  final StatementCycle cycle;
  final VoidCallback   onTogglePaid;

  @override
  Widget build(BuildContext context) {
    final now      = DateTime.now();
    final today    = DateTime(now.year, now.month, now.day);
    final endDay   = DateTime(
        cycle.cycleEnd.year, cycle.cycleEnd.month, cycle.cycleEnd.day);
    final isPartial = !endDay.isBefore(today);
    final cs = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg, AppSpacing.md, AppSpacing.lg, AppSpacing.lg),
      decoration: BoxDecoration(
        color: cs.surface,
        border: Border(
          top: BorderSide(
            color: Theme.of(context).dividerTheme.color ?? AppColors.divider,
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
