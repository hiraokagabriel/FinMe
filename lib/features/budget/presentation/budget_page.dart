import 'package:flutter/material.dart';

import '../../../core/services/repository_locator.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_empty_state.dart';
import '../../categories/domain/category_entity.dart';
import '../../transactions/domain/transaction_entity.dart';
import '../../transactions/domain/transaction_type.dart';
import '../domain/budget_entity.dart';

class BudgetPage extends StatefulWidget {
  const BudgetPage({super.key});

  @override
  State<BudgetPage> createState() => _BudgetPageState();
}

class _BudgetPageState extends State<BudgetPage> {
  late DateTime _currentMonth;
  List<BudgetEntity> _budgets = const [];
  List<CategoryEntity> _categories = const [];
  List<TransactionEntity> _transactions = const [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _currentMonth = DateTime(now.year, now.month);
    _load();
  }

  Future<void> _load() async {
    final locator = RepositoryLocator.instance;
    final budgets = locator.budgets.getByMonth(_currentMonth);
    final categories = await locator.categories.getAll();
    final transactions = await locator.transactions.getAll();
    if (!mounted) return;
    setState(() {
      _budgets = budgets;
      _categories = categories;
      _transactions = transactions;
      _isLoading = false;
    });
  }

  void _prevMonth() {
    setState(() {
      _currentMonth =
          DateTime(_currentMonth.year, _currentMonth.month - 1);
      _isLoading = true;
    });
    _load();
  }

  void _nextMonth() {
    setState(() {
      _currentMonth =
          DateTime(_currentMonth.year, _currentMonth.month + 1);
      _isLoading = true;
    });
    _load();
  }

  double _spentForCategory(String categoryId) {
    return _transactions
        .where((tx) =>
            !tx.isProvisioned &&
            tx.type == TransactionType.expense &&
            tx.categoryId == categoryId &&
            tx.date.year == _currentMonth.year &&
            tx.date.month == _currentMonth.month)
        .fold(0.0, (acc, tx) => acc + tx.amount.amount);
  }

  // ── Totais ────────────────────────────────────────────────────────────────

  double get _totalLimit =>
      _budgets.fold(0.0, (s, b) => s + b.limitAmount);

  double get _totalSpent => _budgets.fold(
      0.0, (s, b) => s + _spentForCategory(b.categoryId));

  // ── Form ──────────────────────────────────────────────────────────────────

  Future<void> _openForm({BudgetEntity? initial}) async {
    await showDialog(
      context: context,
      builder: (ctx) => _BudgetFormDialog(
        initial: initial,
        currentMonth: _currentMonth,
        categories: _categories,
        existingCategoryIds: _budgets
            .where((b) => b.id != initial?.id)
            .map((b) => b.categoryId)
            .toSet(),
        onSave: (budget) async {
          await RepositoryLocator.instance.budgets.save(budget);
          await _load();
        },
      ),
    );
  }

  Future<void> _confirmDelete(BudgetEntity budget) async {
    final cat = _categories
        .where((c) => c.id == budget.categoryId)
        .firstOrNull;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Excluir orçamento'),
        content: Text(
            'Excluir orçamento de "${cat?.name ?? budget.categoryId}"?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('Cancelar')),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text('Excluir',
                style: TextStyle(color: AppColors.danger)),
          ),
        ],
      ),
    );
    if (ok == true) {
      await RepositoryLocator.instance.budgets.remove(budget.id);
      await _load();
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Orçamento excluído')));
    }
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  String get _monthLabel {
    const months = [
      'Janeiro', 'Fevereiro', 'Março', 'Abril', 'Maio', 'Junho',
      'Julho', 'Agosto', 'Setembro', 'Outubro', 'Novembro', 'Dezembro'
    ];
    return '${months[_currentMonth.month - 1]} ${_currentMonth.year}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Orçamento'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            tooltip: 'Novo orçamento',
            onPressed: _isLoading ? null : () => _openForm(),
          ),
        ],
      ),
      body: Column(
        children: [
          _MonthNavigator(
            label: _monthLabel,
            onPrev: _prevMonth,
            onNext: _nextMonth,
          ),
          if (!_isLoading && _budgets.isNotEmpty)
            _SummaryBar(
                totalSpent: _totalSpent, totalLimit: _totalLimit),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _budgets.isEmpty
                    ? AppEmptyState(
                        icon: Icons.account_balance_wallet_outlined,
                        title: 'Nenhum orçamento para este mês',
                        message:
                            'Defina limites por categoria para controlar seus gastos mês a mês.',
                        actionLabel: 'Criar orçamento',
                        onAction: () => _openForm(),
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.fromLTRB(
                            AppSpacing.lg,
                            AppSpacing.md,
                            AppSpacing.lg,
                            AppSpacing.lg),
                        itemCount: _budgets.length,
                        separatorBuilder: (_, __) =>
                            const SizedBox(height: AppSpacing.md),
                        itemBuilder: (_, i) {
                          final b = _budgets[i];
                          final cat = _categories
                              .where((c) => c.id == b.categoryId)
                              .firstOrNull;
                          final spent = _spentForCategory(b.categoryId);
                          return _BudgetCard(
                            budget: b,
                            category: cat,
                            spent: spent,
                            onEdit: () => _openForm(initial: b),
                            onDelete: () => _confirmDelete(b),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
}

// ─── Month Navigator ─────────────────────────────────────────────────────────

class _MonthNavigator extends StatelessWidget {
  const _MonthNavigator({
    required this.label,
    required this.onPrev,
    required this.onNext,
  });

  final String label;
  final VoidCallback onPrev;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg, vertical: AppSpacing.sm),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
            icon: const Icon(Icons.chevron_left),
            onPressed: onPrev,
            tooltip: 'Mês anterior',
          ),
          Text(label,
              style: AppText.sectionLabel.copyWith(fontSize: 15)),
          IconButton(
            icon: const Icon(Icons.chevron_right),
            onPressed: onNext,
            tooltip: 'Próximo mês',
          ),
        ],
      ),
    );
  }
}

// ─── Summary Bar ─────────────────────────────────────────────────────────────

class _SummaryBar extends StatelessWidget {
  const _SummaryBar({
    required this.totalSpent,
    required this.totalLimit,
  });

  final double totalSpent;
  final double totalLimit;

  @override
  Widget build(BuildContext context) {
    final ratio =
        totalLimit <= 0 ? 0.0 : (totalSpent / totalLimit).clamp(0.0, 1.0);
    final isOver = totalSpent > totalLimit && totalLimit > 0;
    final barColor = isOver
        ? AppColors.danger
        : ratio >= 0.8
            ? AppColors.warning
            : AppColors.success;

    return Padding(
      padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg, 0, AppSpacing.lg, AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Total gasto',
                  style: AppText.secondary
                      .copyWith(fontWeight: FontWeight.w600)),
              Text(
                'R\$ ${totalSpent.toStringAsFixed(2)} / R\$ ${totalLimit.toStringAsFixed(2)}',
                style: AppText.secondary.copyWith(
                    color: barColor, fontWeight: FontWeight.w600),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          ClipRRect(
            borderRadius: BorderRadius.circular(AppRadius.chip),
            child: LinearProgressIndicator(
              value: ratio,
              minHeight: 6,
              backgroundColor: AppColors.limitTrack,
              valueColor: AlwaysStoppedAnimation<Color>(barColor),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Budget Card ─────────────────────────────────────────────────────────────

class _BudgetCard extends StatelessWidget {
  const _BudgetCard({
    required this.budget,
    required this.category,
    required this.spent,
    required this.onEdit,
    required this.onDelete,
  });

  final BudgetEntity budget;
  final CategoryEntity? category;
  final double spent;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final limit = budget.limitAmount;
    final ratio = limit <= 0 ? 0.0 : (spent / limit);
    final progress = ratio.clamp(0.0, 1.0);
    final isOver = ratio > 1.0;
    final isNear = ratio >= 0.8 && !isOver;

    final barColor = isOver
        ? AppColors.danger
        : isNear
            ? AppColors.warning
            : AppColors.limitLow;

    final catColor = category?.colorValue != null
        ? Color(category!.colorValue!)
        : AppColors.textSecondary;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 16,
                  backgroundColor: catColor.withOpacity(0.18),
                  child: category?.iconCodePoint != null
                      ? Icon(
                          IconData(category!.iconCodePoint!,
                              fontFamily: 'MaterialIcons'),
                          color: catColor,
                          size: 16,
                        )
                      : Text(
                          category != null && category!.name.isNotEmpty
                              ? category!.name[0].toUpperCase()
                              : '?',
                          style: TextStyle(
                              color: catColor,
                              fontWeight: FontWeight.bold,
                              fontSize: 12),
                        ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Text(
                    category?.name ?? budget.categoryId,
                    style: AppText.sectionLabel,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (isOver)
                  _Badge(label: 'Estourado', color: AppColors.danger)
                else if (isNear)
                  _Badge(
                      label:
                          '${(ratio * 100).toStringAsFixed(0)}%',
                      color: AppColors.warning),
                const SizedBox(width: AppSpacing.xs),
                IconButton(
                  icon: const Icon(Icons.edit_outlined, size: 18),
                  color: AppColors.textSecondary,
                  tooltip: 'Editar',
                  onPressed: onEdit,
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline, size: 18),
                  color: AppColors.danger,
                  tooltip: 'Excluir',
                  onPressed: onDelete,
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            ClipRRect(
              borderRadius: BorderRadius.circular(AppRadius.chip),
              child: LinearProgressIndicator(
                value: progress,
                minHeight: 7,
                backgroundColor: AppColors.limitTrack,
                valueColor: AlwaysStoppedAnimation<Color>(barColor),
              ),
            ),
            const SizedBox(height: AppSpacing.xs + 2),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'R\$ ${spent.toStringAsFixed(2)} gastos',
                  style: AppText.secondary.copyWith(
                      color: barColor, fontWeight: FontWeight.w600),
                ),
                Text(
                  'limite R\$ ${limit.toStringAsFixed(2)}',
                  style: AppText.secondary,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Badge ────────────────────────────────────────────────────────────────────

class _Badge extends StatelessWidget {
  const _Badge({required this.label, required this.color});
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.sm, vertical: AppSpacing.xs - 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(AppRadius.chip),
      ),
      child: Text(
        label,
        style: AppText.badge
            .copyWith(color: color, fontWeight: FontWeight.w700),
      ),
    );
  }
}

// ─── Form Dialog ──────────────────────────────────────────────────────────────

class _BudgetFormDialog extends StatefulWidget {
  const _BudgetFormDialog({
    this.initial,
    required this.currentMonth,
    required this.categories,
    required this.existingCategoryIds,
    required this.onSave,
  });

  final BudgetEntity? initial;
  final DateTime currentMonth;
  final List<CategoryEntity> categories;
  final Set<String> existingCategoryIds;
  final Future<void> Function(BudgetEntity) onSave;

  @override
  State<_BudgetFormDialog> createState() => _BudgetFormDialogState();
}

class _BudgetFormDialogState extends State<_BudgetFormDialog> {
  final _limitController = TextEditingController();
  String? _selectedCategoryId;
  bool _saving = false;

  late final List<CategoryEntity> _availableCategories;

  @override
  void initState() {
    super.initState();
    _availableCategories = widget.categories.where((c) {
      if (c.kind.index != 0) return false;
      if (widget.existingCategoryIds.contains(c.id)) return false;
      return true;
    }).toList();

    final initial = widget.initial;
    if (initial != null) {
      final cat = widget.categories
          .where((c) => c.id == initial.categoryId)
          .firstOrNull;
      if (cat != null && !_availableCategories.contains(cat)) {
        _availableCategories.insert(0, cat);
      }
      _selectedCategoryId = initial.categoryId;
      _limitController.text = initial.limitAmount.toStringAsFixed(2);
    } else {
      _selectedCategoryId = _availableCategories.isNotEmpty
          ? _availableCategories.first.id
          : null;
    }
  }

  @override
  void dispose() {
    _limitController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_selectedCategoryId == null) return;
    final limit = double.tryParse(
        _limitController.text.replaceAll(',', '.').trim());
    if (limit == null || limit <= 0) return;

    setState(() => _saving = true);
    await widget.onSave(BudgetEntity(
      id: widget.initial?.id ??
          'budget_${DateTime.now().microsecondsSinceEpoch}',
      categoryId: _selectedCategoryId!,
      limitAmount: limit,
      month: widget.currentMonth,
    ));
    if (!mounted) return;
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final isNew = widget.initial == null;
    return AlertDialog(
      title: Text(isNew ? 'Novo orçamento' : 'Editar orçamento'),
      content: SizedBox(
        width: 340,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (_availableCategories.isEmpty && isNew)
              const Text(
                'Todas as categorias de despesa já têm orçamento este mês.',
              )
            else ...[
              DropdownButtonFormField<String>(
                value: _selectedCategoryId,
                decoration:
                    const InputDecoration(labelText: 'Categoria'),
                items: _availableCategories
                    .map((c) => DropdownMenuItem(
                          value: c.id,
                          child: Text(c.name),
                        ))
                    .toList(),
                onChanged: isNew
                    ? (v) => setState(() => _selectedCategoryId = v)
                    : null,
              ),
              const SizedBox(height: AppSpacing.md),
              TextFormField(
                controller: _limitController,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                  labelText: 'Limite (R\$)',
                  prefixText: 'R\$ ',
                  hintText: '0.00',
                ),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancelar')),
        FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
          ),
          onPressed: (_saving ||
                  (_availableCategories.isEmpty && isNew))
              ? null
              : _save,
          child: _saving
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: Colors.white))
              : const Text('Salvar'),
        ),
      ],
    );
  }
}
