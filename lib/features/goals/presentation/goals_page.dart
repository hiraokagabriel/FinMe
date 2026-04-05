import 'package:flutter/material.dart';

import '../../../core/services/repository_locator.dart';
import '../../../core/services/app_mode_controller.dart';
import '../../../core/models/app_mode.dart';
import '../../../core/theme/app_theme.dart';
import '../../categories/domain/category_entity.dart';
import '../../transactions/domain/transaction_entity.dart';
import '../../transactions/domain/transaction_type.dart';
import '../domain/goal_entity.dart';

class GoalsPage extends StatefulWidget {
  const GoalsPage({super.key});

  @override
  State<GoalsPage> createState() => _GoalsPageState();
}

class _GoalsPageState extends State<GoalsPage> {
  List<GoalEntity> _goals = const [];
  List<CategoryEntity> _categories = const [];
  List<TransactionEntity> _transactions = const [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _load();
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

  /// Gasto da categoria no mês atual.
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

  Future<void> _openForm({GoalEntity? initial}) async {
    await showDialog(
      context: context,
      builder: (ctx) => _GoalFormDialog(
        initial: initial,
        categories: _categories,
        onSave: (goal) async {
          await RepositoryLocator.instance.goals.save(goal);
          await _load();
        },
      ),
    );
  }

  Future<void> _confirmDelete(GoalEntity goal) async {
    final cat = _categories
        .where((c) => c.id == goal.categoryId)
        .firstOrNull;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Excluir meta'),
        content: Text(
            'Deseja excluir a meta de "${cat?.name ?? goal.categoryId}"?'),
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
          .showSnackBar(const SnackBar(content: Text('Meta excluída')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final isUltra =
        AppModeController.instance.mode == AppMode.ultra;

    return Scaffold(
      appBar: AppBar(title: const Text('Metas')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openForm(),
        icon: const Icon(Icons.add),
        label: const Text('Nova meta'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _goals.isEmpty
              ? _buildEmpty()
              : ListView(
                  padding: const EdgeInsets.only(
                      bottom: 88,
                      top: AppSpacing.md,
                      left: AppSpacing.lg,
                      right: AppSpacing.lg),
                  children: [
                    if (isUltra)
                      Padding(
                        padding: const EdgeInsets.only(
                            bottom: AppSpacing.md),
                        child: Text(
                          'Limite mensal por categoria',
                          style: AppText.sectionLabel,
                        ),
                      ),
                    ..._goals.map((goal) {
                      final cat = _categories
                          .where((c) => c.id == goal.categoryId)
                          .firstOrNull;
                      final spent = _spentForCategory(goal.categoryId);
                      return Padding(
                        padding: const EdgeInsets.only(
                            bottom: AppSpacing.md),
                        child: _GoalCard(
                          goal: goal,
                          category: cat,
                          spent: spent,
                          onEdit: () => _openForm(initial: goal),
                          onDelete: () => _confirmDelete(goal),
                        ),
                      );
                    }),
                  ],
                ),
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.flag_outlined,
              size: 48, color: AppColors.textSecondary),
          const SizedBox(height: AppSpacing.md),
          Text('Nenhuma meta cadastrada', style: AppText.sectionLabel),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'Defina limites de gasto por categoria\ne acompanhe seu progresso mensalmente.',
            textAlign: TextAlign.center,
            style: AppText.secondary,
          ),
        ],
      ),
    );
  }
}

// ── Card de meta ───────────────────────────────────────────────────────────

class _GoalCard extends StatelessWidget {
  const _GoalCard({
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
    final ratio =
        goal.limitAmount <= 0 ? 0.0 : (spent / goal.limitAmount);
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
                // Ícone de categoria
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
                      Text(
                        category?.name ?? goal.categoryId,
                        style: AppText.sectionLabel,
                      ),
                      Text(
                        goal.month == null
                            ? 'Recorrente (todos os meses)'
                            : 'Mês: ${goal.month!.month.toString().padLeft(2, '0')}/${goal.month!.year}',
                        style: AppText.secondary,
                      ),
                    ],
                  ),
                ),
                // Badge de alerta
                if (isOver)
                  _AlertBadge(
                    label: 'Estourada',
                    color: AppColors.danger,
                  )
                else if (isNear)
                  _AlertBadge(
                    label: '${(ratio * 100).toStringAsFixed(0)}%',
                    color: AppColors.warning,
                  ),
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
                minHeight: 7,
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
                  'R\$ ${spent.toStringAsFixed(2)} gastos',
                  style: AppText.secondary.copyWith(
                      color: barColor, fontWeight: FontWeight.w600),
                ),
                Text(
                  'limite R\$ ${goal.limitAmount.toStringAsFixed(2)}',
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

class _AlertBadge extends StatelessWidget {
  const _AlertBadge({required this.label, required this.color});
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

// ── Diálogo de cadastro / edição ──────────────────────────────────────────

class _GoalFormDialog extends StatefulWidget {
  const _GoalFormDialog({
    this.initial,
    required this.categories,
    required this.onSave,
  });

  final GoalEntity? initial;
  final List<CategoryEntity> categories;
  final Future<void> Function(GoalEntity) onSave;

  @override
  State<_GoalFormDialog> createState() => _GoalFormDialogState();
}

class _GoalFormDialogState extends State<_GoalFormDialog> {
  final _limitController = TextEditingController();
  String? _selectedCategoryId;
  bool _isRecurrent = true;
  DateTime? _selectedMonth;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    if (widget.initial != null) {
      final g = widget.initial!;
      _limitController.text = g.limitAmount.toStringAsFixed(2);
      _selectedCategoryId = g.categoryId;
      _isRecurrent = g.month == null;
      _selectedMonth = g.month;
    } else {
      if (widget.categories.isNotEmpty) {
        _selectedCategoryId = widget.categories.first.id;
      }
    }
  }

  @override
  void dispose() {
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
      setState(() =>
          _selectedMonth = DateTime(result.year, result.month));
    }
  }

  Future<void> _save() async {
    if (_selectedCategoryId == null) return;
    final limit =
        double.tryParse(_limitController.text.replaceAll(',', '.').trim());
    if (limit == null || limit <= 0) return;

    setState(() => _saving = true);
    final goal = GoalEntity(
      id: widget.initial?.id ??
          'goal_${DateTime.now().microsecondsSinceEpoch}',
      categoryId: _selectedCategoryId!,
      limitAmount: limit,
      month: _isRecurrent ? null : _selectedMonth,
    );
    await widget.onSave(goal);
    if (!mounted) return;
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final title = widget.initial == null ? 'Nova meta' : 'Editar meta';
    final expenseCategories = widget.categories
        .where((c) =>
            c.kind.index == 0) // CategoryKind.expense
        .toList();

    return AlertDialog(
      title: Text(title),
      content: SizedBox(
        width: 360,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Categoria
            DropdownButtonFormField<String>(
              value: _selectedCategoryId,
              decoration:
                  const InputDecoration(labelText: 'Categoria'),
              items: expenseCategories
                  .map((c) => DropdownMenuItem(
                        value: c.id,
                        child: Text(c.name),
                      ))
                  .toList(),
              onChanged: (v) =>
                  setState(() => _selectedCategoryId = v),
            ),
            const SizedBox(height: AppSpacing.md),

            // Valor limite
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

            // Recorrente ou mês específico
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              value: _isRecurrent,
              onChanged: (v) => setState(() {
                _isRecurrent = v;
                if (v) _selectedMonth = null;
              }),
              title: const Text('Recorrente (todos os meses)'),
            ),

            if (!_isRecurrent) ...[
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
