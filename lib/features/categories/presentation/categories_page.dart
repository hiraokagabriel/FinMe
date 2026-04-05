import 'package:flutter/material.dart';

import '../data/categories_repository.dart';
import '../domain/category_entity.dart';
import '../domain/category_kind.dart';
import '../../../core/services/repository_locator.dart';
import '../../../core/theme/app_theme.dart';

class CategoriesPage extends StatefulWidget {
  const CategoriesPage({super.key});

  @override
  State<CategoriesPage> createState() => _CategoriesPageState();
}

class _CategoriesPageState extends State<CategoriesPage> {
  late final CategoriesRepository _repo;
  List<CategoryEntity> _categories = const [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _repo = RepositoryLocator.instance.categories;
    _load();
  }

  Future<void> _load() async {
    final list = await _repo.getAll();
    setState(() {
      _categories = list;
      _isLoading  = false;
    });
  }

  Color _colorOf(CategoryEntity cat) =>
      cat.colorValue != null ? Color(cat.colorValue!) : AppColors.textSecondary;

  Future<void> _openForm({CategoryEntity? initial}) async {
    await showDialog(
      context: context,
      builder: (context) => _CategoryFormDialog(
        initial: initial,
        onSave: (entity) async {
          if (initial == null) {
            await _repo.add(entity);
          } else {
            await _repo.update(entity);
          }
          await _load();
        },
      ),
    );
  }

  Future<void> _confirmDelete(CategoryEntity cat) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Excluir categoria'),
        content: Text('Deseja excluir "${cat.name}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text('Excluir',
                style: TextStyle(color: AppColors.danger)),
          ),
        ],
      ),
    );
    if (ok == true) {
      await _repo.remove(cat.id);
      await _load();
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Categoria excluída')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final expenses =
        _categories.where((c) => c.kind == CategoryKind.expense).toList();
    final incomes =
        _categories.where((c) => c.kind == CategoryKind.income).toList();

    return Scaffold(
      appBar: AppBar(title: const Text('Categorias')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openForm(),
        icon: const Icon(Icons.add),
        label: const Text('Nova categoria'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _categories.isEmpty
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.label_off_outlined,
                          size: 48, color: AppColors.textSecondary),
                      const SizedBox(height: AppSpacing.md),
                      Text('Nenhuma categoria cadastrada',
                          style: AppText.sectionLabel),
                      const SizedBox(height: AppSpacing.sm),
                      Text('Toque em "Nova categoria" para começar.',
                          style: AppText.secondary),
                    ],
                  ),
                )
              : ListView(
                  padding: const EdgeInsets.only(bottom: 88),
                  children: [
                    if (expenses.isNotEmpty) ...[
                      _SectionHeader(
                          label: 'Despesas (${expenses.length})'),
                      ...expenses.map((cat) => _CategoryTile(
                            category: cat,
                            color: _colorOf(cat),
                            onEdit: () => _openForm(initial: cat),
                            onDelete: () => _confirmDelete(cat),
                          )),
                    ],
                    if (incomes.isNotEmpty) ...[
                      _SectionHeader(
                          label: 'Receitas (${incomes.length})'),
                      ...incomes.map((cat) => _CategoryTile(
                            category: cat,
                            color: _colorOf(cat),
                            onEdit: () => _openForm(initial: cat),
                            onDelete: () => _confirmDelete(cat),
                          )),
                    ],
                  ],
                ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg, AppSpacing.lg, AppSpacing.lg, AppSpacing.xs),
      child: Text(label, style: AppText.sectionLabel),
    );
  }
}

class _CategoryTile extends StatelessWidget {
  const _CategoryTile({
    required this.category,
    required this.color,
    required this.onEdit,
    required this.onDelete,
  });

  final CategoryEntity category;
  final Color          color;
  final VoidCallback   onEdit;
  final VoidCallback   onDelete;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: CircleAvatar(
        backgroundColor: color.withOpacity(0.18),
        child: Text(
          category.name.isNotEmpty ? category.name[0].toUpperCase() : '?',
          style: TextStyle(
              color: color, fontWeight: FontWeight.bold),
        ),
      ),
      title: Text(category.name),
      subtitle: Text(
        category.kind == CategoryKind.expense ? 'Despesa' : 'Receita',
        style: AppText.secondary,
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            icon: const Icon(Icons.edit_outlined, size: 20),
            tooltip: 'Editar',
            color: AppColors.textSecondary,
            onPressed: onEdit,
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline, size: 20),
            tooltip: 'Excluir',
            color: AppColors.danger,
            onPressed: onDelete,
          ),
        ],
      ),
    );
  }
}

class _CategoryFormDialog extends StatefulWidget {
  const _CategoryFormDialog({this.initial, required this.onSave});

  final CategoryEntity? initial;
  final Future<void> Function(CategoryEntity) onSave;

  @override
  State<_CategoryFormDialog> createState() => _CategoryFormDialogState();
}

class _CategoryFormDialogState extends State<_CategoryFormDialog> {
  final _nameController = TextEditingController();
  late CategoryKind _kind;
  late int _colorValue;
  bool _saving = false;

  static const List<int> _palette = [
    0xFFF44336, 0xFFE91E63, 0xFF9C27B0, 0xFF673AB7,
    0xFF3F51B5, 0xFF2196F3, 0xFF00BCD4, 0xFF4CAF50,
    0xFF8BC34A, 0xFFFF9800, 0xFFFF5722, 0xFF607D8B,
    0xFF43A047, 0xFF1E88E5, 0xFF9E9E9E, 0xFF795548,
  ];

  @override
  void initState() {
    super.initState();
    if (widget.initial != null) {
      _nameController.text = widget.initial!.name;
      _kind       = widget.initial!.kind;
      _colorValue = widget.initial!.colorValue ?? _palette.first;
    } else {
      _kind       = CategoryKind.expense;
      _colorValue = _palette.first;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) return;
    setState(() => _saving = true);

    final entity = CategoryEntity(
      id:         widget.initial?.id ??
          'cat_${DateTime.now().microsecondsSinceEpoch}',
      name:       name,
      kind:       _kind,
      colorValue: _colorValue,
    );

    await widget.onSave(entity);
    if (!mounted) return;
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(
          widget.initial == null ? 'Nova categoria' : 'Editar categoria'),
      content: SizedBox(
        width: 360,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'Nome da categoria',
                hintText: 'Ex: Alimentação, Salário...',
              ),
              textCapitalization: TextCapitalization.sentences,
              autofocus: true,
            ),
            const SizedBox(height: AppSpacing.lg),
            Text('Tipo',
                style: AppText.secondary
                    .copyWith(fontWeight: FontWeight.w500)),
            const SizedBox(height: AppSpacing.xs),
            SegmentedButton<CategoryKind>(
              style: SegmentedButton.styleFrom(
                selectedBackgroundColor: AppColors.primarySubtle,
                selectedForegroundColor: AppColors.primary,
              ),
              segments: const [
                ButtonSegment(
                  value: CategoryKind.expense,
                  label: Text('Despesa'),
                  icon: Icon(Icons.arrow_downward),
                ),
                ButtonSegment(
                  value: CategoryKind.income,
                  label: Text('Receita'),
                  icon: Icon(Icons.arrow_upward),
                ),
              ],
              selected: {_kind},
              onSelectionChanged: (s) =>
                  setState(() => _kind = s.first),
            ),
            const SizedBox(height: AppSpacing.lg),
            Text('Cor',
                style: AppText.secondary
                    .copyWith(fontWeight: FontWeight.w500)),
            const SizedBox(height: AppSpacing.sm),
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              children: _palette.map((c) {
                final selected = c == _colorValue;
                return GestureDetector(
                  onTap: () => setState(() => _colorValue = c),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      color: Color(c),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: selected
                            ? AppColors.textPrimary
                            : Colors.transparent,
                        width: 2.5,
                      ),
                    ),
                    child: selected
                        ? const Icon(Icons.check,
                            size: 14, color: Colors.white)
                        : null,
                  ),
                );
              }).toList(),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
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
                    strokeWidth: 2,
                    color: Colors.white,
                  ))
              : const Text('Salvar'),
        ),
      ],
    );
  }
}
