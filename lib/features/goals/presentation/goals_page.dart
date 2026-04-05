import 'package:flutter/material.dart';

import '../../../core/services/repository_locator.dart';
import '../../../core/theme/app_theme.dart';
import '../../categories/domain/category_entity.dart';
import '../../transactions/domain/transaction_entity.dart';
import '../../transactions/domain/transaction_type.dart';
import '../domain/goal_entity.dart';
import '../domain/goal_type.dart';

class GoalsPage extends StatefulWidget {
  const GoalsPage({super.key});

  @override
  State<GoalsPage> createState() => _GoalsPageState();
}

class _GoalsPageState extends State<GoalsPage>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  List<GoalEntity> _goals = const [];
  List<CategoryEntity> _categories = const [];
  List<TransactionEntity> _transactions = const [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _load();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final locator = RepositoryLocator.instance;
    final goals = locator.goals.getAll();
    final categories = await locator.categories.getAll();
    final transactions = await locator.transactions.getAll();
    if (!mounted) return;
    setState(() {
      _goals = goals;
      _categories = categories;
      _transactions = transactions;
      _isLoading = false;
    });
  }

  // ── Helpers ──────────────────────────────────────────────────────────────

  List<GoalEntity> get _savingsGoals =>
      _goals.where((g) => g.type == GoalType.savingsGoal).toList();

  List<GoalEntity> get _ceilings =>
      _goals.where((g) => g.type == GoalType.spendingCeiling).toList();

  double _spentForCategory(String categoryId) {
    final now = DateTime.now();
    return _transactions
        .where((tx) =>
            !tx.isProvisioned &&
            tx.type == TransactionType.expense &&
            tx.categoryId == categoryId &&
            tx.date.year == now.year &&
            tx.date.month == now.month)
        .fold(0.0, (acc, tx) => acc + tx.amount.amount);
  }

  // ── Form ─────────────────────────────────────────────────────────────────

  Future<void> _openForm({GoalEntity? initial, GoalType? forceType}) async {
    await showDialog(
      context: context,
      builder: (ctx) => _GoalFormDialog(
        initial: initial,
        forceType: forceType,
        categories: _categories,
        onSave: (goal) async {
          await RepositoryLocator.instance.goals.save(goal);
          await _load();
        },
      ),
    );
  }

  Future<void> _confirmDelete(GoalEntity goal) async {
    final label = goal.type == GoalType.savingsGoal
        ? goal.title
        : (_categories
                .where((c) => c.id == goal.categoryId)
                .firstOrNull
                ?.name ??
            goal.title);

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(goal.type == GoalType.savingsGoal
            ? 'Excluir meta'
            : 'Excluir teto de gastos'),
        content: Text('Deseja excluir "$label"?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('Cancelar')),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child:
                Text('Excluir', style: TextStyle(color: AppColors.danger)),
          ),
        ],
      ),
    );
    if (ok == true) {
      await RepositoryLocator.instance.goals.remove(goal.id);
      await _load();
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Item excluído')));
    }
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Metas & Limites'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(icon: Icon(Icons.savings_outlined), text: 'Metas'),
            Tab(icon: Icon(Icons.price_check_outlined), text: 'Teto de Gastos'),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          final isCeilingTab = _tabController.index == 1;
          _openForm(
            forceType: isCeilingTab
                ? GoalType.spendingCeiling
                : GoalType.savingsGoal,
          );
        },
        icon: const Icon(Icons.add),
        label: AnimatedBuilder(
          animation: _tabController,
          builder: (_, __) => Text(
            _tabController.index == 1 ? 'Novo teto' : 'Nova meta',
          ),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabController,
              children: [
                _SavingsTab(
                  goals: _savingsGoals,
                  onEdit: (g) => _openForm(initial: g),
                  onDelete: _confirmDelete,
                ),
                _CeilingTab(
                  goals: _ceilings,
                  categories: _categories,
                  spentFor: _spentForCategory,
                  onEdit: (g) => _openForm(initial: g),
                  onDelete: _confirmDelete,
                ),
              ],
            ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// ABA 1 — Metas de Economia
// ═══════════════════════════════════════════════════════════════════════════

class _SavingsTab extends StatelessWidget {
  const _SavingsTab({
    required this.goals,
    required this.onEdit,
    required this.onDelete,
  });

  final List<GoalEntity> goals;
  final void Function(GoalEntity) onEdit;
  final void Function(GoalEntity) onDelete;

  @override
  Widget build(BuildContext context) {
    if (goals.isEmpty) {
      return _EmptyState(
        icon: Icons.savings_outlined,
        title: 'Nenhuma meta cadastrada',
        subtitle:
            'Crie metas de economia para acompanhar\nseu progresso rumo a um objetivo.',
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg, AppSpacing.md, AppSpacing.lg, 96),
      itemCount: goals.length,
      separatorBuilder: (_, __) =>
          const SizedBox(height: AppSpacing.md),
      itemBuilder: (_, i) => _SavingsCard(
        goal: goals[i],
        onEdit: () => onEdit(goals[i]),
        onDelete: () => onDelete(goals[i]),
      ),
    );
  }
}

class _SavingsCard extends StatelessWidget {
  const _SavingsCard({
    required this.goal,
    required this.onEdit,
    required this.onDelete,
  });

  final GoalEntity goal;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final target = goal.targetAmount ?? 0.0;
    final current = goal.currentAmount ?? 0.0;
    final ratio = target <= 0 ? 0.0 : (current / target);
    final progress = ratio.clamp(0.0, 1.0);
    final isDone = ratio >= 1.0;
    final isNear = ratio >= 0.8 && !isDone;

    final barColor = isDone
        ? AppColors.success
        : isNear
            ? AppColors.primary
            : AppColors.limitLow;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                CircleAvatar(
                  radius: 18,
                  backgroundColor: AppColors.primary.withOpacity(0.12),
                  child: Icon(Icons.savings_outlined,
                      color: AppColors.primary, size: 18),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Text(goal.title,
                      style: AppText.sectionLabel,
                      overflow: TextOverflow.ellipsis),
                ),
                if (isDone)
                  _Badge(
                      label: '🎉 Concluída', color: AppColors.success)
                else if (isNear)
                  _Badge(
                      label:
                          '${(ratio * 100).toStringAsFixed(0)}%',
                      color: AppColors.primary),
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
            // Barra de progresso
            ClipRRect(
              borderRadius: BorderRadius.circular(AppRadius.chip),
              child: LinearProgressIndicator(
                value: progress,
                minHeight: 8,
                backgroundColor: AppColors.limitTrack,
                valueColor: AlwaysStoppedAnimation<Color>(barColor),
              ),
            ),
            const SizedBox(height: AppSpacing.xs + 2),
            // Valores
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'R\$ ${current.toStringAsFixed(2)} guardados',
                  style: AppText.secondary.copyWith(
                      color: barColor, fontWeight: FontWeight.w600),
                ),
                Text(
                  'meta R\$ ${target.toStringAsFixed(2)}',
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

// ═══════════════════════════════════════════════════════════════════════════
// ABA 2 — Teto de Gastos
// ═══════════════════════════════════════════════════════════════════════════

class _CeilingTab extends StatelessWidget {
  const _CeilingTab({
    required this.goals,
    required this.categories,
    required this.spentFor,
    required this.onEdit,
    required this.onDelete,
  });

  final List<GoalEntity> goals;
  final List<CategoryEntity> categories;
  final double Function(String) spentFor;
  final void Function(GoalEntity) onEdit;
  final void Function(GoalEntity) onDelete;

  @override
  Widget build(BuildContext context) {
    if (goals.isEmpty) {
      return _EmptyState(
        icon: Icons.price_check_outlined,
        title: 'Nenhum teto cadastrado',
        subtitle:
            'Defina limites de gasto por categoria\ne receba alertas quando se aproximar do limite.',
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg, AppSpacing.md, AppSpacing.lg, 96),
      itemCount: goals.length,
      separatorBuilder: (_, __) =>
          const SizedBox(height: AppSpacing.md),
      itemBuilder: (_, i) {
        final goal = goals[i];
        final cat = categories
            .where((c) => c.id == goal.categoryId)
            .firstOrNull;
        final spent =
            goal.categoryId != null ? spentFor(goal.categoryId!) : 0.0;
        return _CeilingCard(
          goal: goal,
          category: cat,
          spent: spent,
          onEdit: () => onEdit(goal),
          onDelete: () => onDelete(goal),
        );
      },
    );
  }
}

class _CeilingCard extends StatelessWidget {
  const _CeilingCard({
    required this.goal,
    required this.category,
    required this.spent,
    required this.onEdit,
    required this.onDelete,
  });

  final GoalEntity goal;
  final CategoryEntity? category;
  final double spent;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final limit = goal.limitAmount ?? 0.0;
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
                  child: Text(
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
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(goal.title.isNotEmpty
                          ? goal.title
                          : (category?.name ?? 'Sem categoria'),
                          style: AppText.sectionLabel),
                      Text(
                        goal.month == null
                            ? 'Recorrente'
                            : '${goal.month!.month.toString().padLeft(2, '0')}/${goal.month!.year}',
                        style: AppText.secondary,
                      ),
                    ],
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

// ═══════════════════════════════════════════════════════════════════════════
// Widgets utilitários
// ═══════════════════════════════════════════════════════════════════════════

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

class _EmptyState extends StatelessWidget {
  const _EmptyState({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 48, color: AppColors.textSecondary),
            const SizedBox(height: AppSpacing.md),
            Text(title, style: AppText.sectionLabel),
            const SizedBox(height: AppSpacing.sm),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: AppText.secondary,
            ),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// Formulário unificado
// ═══════════════════════════════════════════════════════════════════════════

class _GoalFormDialog extends StatefulWidget {
  const _GoalFormDialog({
    this.initial,
    this.forceType,
    required this.categories,
    required this.onSave,
  });

  final GoalEntity? initial;
  final GoalType? forceType;
  final List<CategoryEntity> categories;
  final Future<void> Function(GoalEntity) onSave;

  @override
  State<_GoalFormDialog> createState() => _GoalFormDialogState();
}

class _GoalFormDialogState extends State<_GoalFormDialog> {
  final _titleController = TextEditingController();
  final _targetController = TextEditingController();
  final _currentController = TextEditingController();
  final _limitController = TextEditingController();

  late GoalType _type;
  String? _selectedCategoryId;
  bool _isRecurrent = true;
  DateTime? _selectedMonth;
  bool _saving = false;

  late final List<CategoryEntity> _expenseCategories;

  @override
  void initState() {
    super.initState();
    _expenseCategories = widget.categories
        .where((c) => c.kind.index == 0)
        .toList();

    final g = widget.initial;
    _type = g?.type ?? widget.forceType ?? GoalType.savingsGoal;

    if (g != null) {
      _titleController.text = g.title;
      _targetController.text =
          g.targetAmount?.toStringAsFixed(2) ?? '';
      _currentController.text =
          g.currentAmount?.toStringAsFixed(2) ?? '';
      _limitController.text =
          g.limitAmount?.toStringAsFixed(2) ?? '';
      _isRecurrent = g.month == null;
      _selectedMonth = g.month;
      final existsInList =
          _expenseCategories.any((c) => c.id == g.categoryId);
      _selectedCategoryId = existsInList
          ? g.categoryId
          : (_expenseCategories.isNotEmpty
              ? _expenseCategories.first.id
              : null);
    } else {
      _selectedCategoryId = _expenseCategories.isNotEmpty
          ? _expenseCategories.first.id
          : null;
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _targetController.dispose();
    _currentController.dispose();
    _limitController.dispose();
    super.dispose();
  }

  String _monthLabel(DateTime d) =>
      '${d.month.toString().padLeft(2, '0')}/${d.year}';

  Future<void> _pickMonth() async {
    final now = DateTime.now();
    final result = await showDatePicker(
      context: context,
      initialDate: _selectedMonth ?? now,
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 2),
      helpText: 'Selecione o mês de referência',
    );
    if (result != null) {
      setState(
          () => _selectedMonth = DateTime(result.year, result.month));
    }
  }

  Future<void> _save() async {
    final title = _titleController.text.trim();

    if (_type == GoalType.savingsGoal) {
      final target = double.tryParse(
          _targetController.text.replaceAll(',', '.').trim());
      final current = double.tryParse(
          _currentController.text.replaceAll(',', '.').trim());
      if (title.isEmpty || target == null || target <= 0) return;
      setState(() => _saving = true);
      await widget.onSave(GoalEntity(
        id: widget.initial?.id ??
            'goal_${DateTime.now().microsecondsSinceEpoch}',
        type: GoalType.savingsGoal,
        title: title,
        targetAmount: target,
        currentAmount: current ?? 0.0,
      ));
    } else {
      if (_selectedCategoryId == null) return;
      final limit = double.tryParse(
          _limitController.text.replaceAll(',', '.').trim());
      if (limit == null || limit <= 0) return;
      setState(() => _saving = true);
      await widget.onSave(GoalEntity(
        id: widget.initial?.id ??
            'goal_${DateTime.now().microsecondsSinceEpoch}',
        type: GoalType.spendingCeiling,
        title: title.isNotEmpty
            ? title
            : (_expenseCategories
                    .where((c) => c.id == _selectedCategoryId)
                    .firstOrNull
                    ?.name ??
                ''),
        categoryId: _selectedCategoryId,
        limitAmount: limit,
        month: _isRecurrent ? null : _selectedMonth,
      ));
    }

    if (!mounted) return;
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final isNew = widget.initial == null;
    final title = _type == GoalType.savingsGoal
        ? (isNew ? 'Nova meta' : 'Editar meta')
        : (isNew ? 'Novo teto de gastos' : 'Editar teto de gastos');

    return AlertDialog(
      title: Text(title),
      content: SizedBox(
        width: 360,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Seletor de tipo (apenas para criação sem forceType)
              if (isNew && widget.forceType == null) ...[
                SegmentedButton<GoalType>(
                  segments: const [
                    ButtonSegment(
                      value: GoalType.savingsGoal,
                      label: Text('Meta'),
                      icon: Icon(Icons.savings_outlined),
                    ),
                    ButtonSegment(
                      value: GoalType.spendingCeiling,
                      label: Text('Teto'),
                      icon: Icon(Icons.price_check_outlined),
                    ),
                  ],
                  selected: {_type},
                  onSelectionChanged: (s) =>
                      setState(() => _type = s.first),
                ),
                const SizedBox(height: AppSpacing.md),
              ],

              // ── Campos de Meta de Economia ──────────────────────────────
              if (_type == GoalType.savingsGoal) ...[
                TextFormField(
                  controller: _titleController,
                  decoration: const InputDecoration(
                    labelText: 'Nome da meta',
                    hintText: 'Ex: Viagem para Europa',
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                TextFormField(
                  controller: _targetController,
                  keyboardType: const TextInputType.numberWithOptions(
                      decimal: true),
                  decoration: const InputDecoration(
                    labelText: 'Valor alvo (R\$)',
                    prefixText: 'R\$ ',
                    hintText: '0.00',
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                TextFormField(
                  controller: _currentController,
                  keyboardType: const TextInputType.numberWithOptions(
                      decimal: true),
                  decoration: const InputDecoration(
                    labelText: 'Valor já guardado (R\$)',
                    prefixText: 'R\$ ',
                    hintText: '0.00',
                  ),
                ),
              ],

              // ── Campos de Teto de Gastos ──────────────────────────────
              if (_type == GoalType.spendingCeiling) ...[
                if (_expenseCategories.isEmpty)
                  const Text(
                    'Nenhuma categoria de despesa encontrada.\nCadastre uma categoria de despesa antes de criar um teto.',
                    style: TextStyle(color: Colors.red),
                  )
                else ...[
                  DropdownButtonFormField<String>(
                    value: _selectedCategoryId,
                    decoration:
                        const InputDecoration(labelText: 'Categoria'),
                    items: _expenseCategories
                        .map((c) => DropdownMenuItem(
                              value: c.id,
                              child: Text(c.name),
                            ))
                        .toList(),
                    onChanged: (v) =>
                        setState(() => _selectedCategoryId = v),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  TextFormField(
                    controller: _titleController,
                    decoration: const InputDecoration(
                      labelText: 'Rótulo (opcional)',
                      hintText: 'Ex: Alimentação outubro',
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  TextFormField(
                    controller: _limitController,
                    keyboardType: const TextInputType.numberWithOptions(
                        decimal: true),
                    decoration: const InputDecoration(
                      labelText: 'Limite (R\$)',
                      prefixText: 'R\$ ',
                      hintText: '0.00',
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    value: _isRecurrent,
                    onChanged: (v) => setState(() {
                      _isRecurrent = v;
                      if (v) _selectedMonth = null;
                    }),
                    title: const Text('Recorrente (todos os meses)'),
                  ),
                  if (!_isRecurrent)
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Mês de referência'),
                      subtitle: Text(
                        _selectedMonth != null
                            ? _monthLabel(_selectedMonth!)
                            : 'Toque para selecionar',
                        style: TextStyle(
                          color: _selectedMonth == null
                              ? AppColors.warning
                              : AppColors.textPrimary,
                        ),
                      ),
                      trailing: TextButton(
                        onPressed: _pickMonth,
                        child: const Text('Selecionar'),
                      ),
                    ),
                ],
              ],
            ],
          ),
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
          onPressed: _saving ? null : _save,
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
