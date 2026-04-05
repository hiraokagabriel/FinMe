import 'package:flutter/material.dart';

import '../data/categories_repository.dart';
import '../domain/category_entity.dart';
import '../domain/category_kind.dart';
import '../../../core/services/repository_locator.dart';

class CategoriesPage extends StatefulWidget {
  const CategoriesPage({super.key});

  @override
  State<CategoriesPage> createState() => _CategoriesPageState();
}

class _CategoriesPageState extends State<CategoriesPage> {
  late final CategoriesRepository _repo;
  List<CategoryEntity> _categories = const [];
  bool _isLoading = true;

  static const List<_CategoryPreset> _presets = [
    _CategoryPreset('Alimentacao', 0xFFF44336),
    _CategoryPreset('Transporte', 0xFF2196F3),
    _CategoryPreset('Saude', 0xFF4CAF50),
    _CategoryPreset('Lazer', 0xFFFF9800),
    _CategoryPreset('Moradia', 0xFF9C27B0),
    _CategoryPreset('Educacao', 0xFF00BCD4),
    _CategoryPreset('Roupas', 0xFFE91E63),
    _CategoryPreset('Assinaturas', 0xFF607D8B),
    _CategoryPreset('Salario', 0xFF43A047),
    _CategoryPreset('Freelance', 0xFF1E88E5),
    _CategoryPreset('Investimentos', 0xFF8BC34A),
    _CategoryPreset('Outros', 0xFF9E9E9E),
  ];

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
      _isLoading = false;
    });
  }

  Color _colorOf(CategoryEntity cat) {
    if (cat.colorValue != null) return Color(cat.colorValue!);
    return Colors.blueGrey;
  }

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
        content: Text('Deseja excluir a categoria "${cat.name}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Excluir'),
          ),
        ],
      ),
    );
    if (ok == true) {
      await _repo.remove(cat.id);
      await _load();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Categoria excluida')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final expenses = _categories.where((c) => c.kind == CategoryKind.expense).toList();
    final incomes = _categories.where((c) => c.kind == CategoryKind.income).toList();

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
              ? const Center(child: Text('Nenhuma categoria cadastrada.'))
              : ListView(
                  padding: const EdgeInsets.only(bottom: 88),
                  children: [
                    if (expenses.isNotEmpty) ...[
                      _SectionHeader(label: 'Despesas (${expenses.length})'),
                      ...expenses.map((cat) => _CategoryTile(
                            category: cat,
                            color: _colorOf(cat),
                            onEdit: () => _openForm(initial: cat),
                            onDelete: () => _confirmDelete(cat),
                          )),
                    ],
                    if (incomes.isNotEmpty) ...[
                      _SectionHeader(label: 'Receitas (${incomes.length})'),
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
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
      child: Text(
        label,
        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
      ),
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
  final Color color;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: CircleAvatar(
        backgroundColor: color.withOpacity(0.18),
        child: Text(
          category.name.isNotEmpty ? category.name[0].toUpperCase() : '?',
          style: TextStyle(color: color, fontWeight: FontWeight.bold),
        ),
      ),
      title: Text(category.name),
      subtitle: Text(
        category.kind == CategoryKind.expense ? 'Despesa' : 'Receita',
        style: TextStyle(fontSize: 12, color: Colors.grey[600]),
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            icon: const Icon(Icons.edit_outlined, size: 20),
            tooltip: 'Editar',
            onPressed: onEdit,
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline, size: 20),
            tooltip: 'Excluir',
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
      _kind = widget.initial!.kind;
      _colorValue = widget.initial!.colorValue ?? _palette.first;
    } else {
      _kind = CategoryKind.expense;
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
      id: widget.initial?.id ??
          'cat_${DateTime.now().microsecondsSinceEpoch}',
      name: name,
      kind: _kind,
      colorValue: _colorValue,
    );

    await widget.onSave(entity);
    if (!mounted) return;
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final title = widget.initial == null ? 'Nova categoria' : 'Editar categoria';
    return AlertDialog(
      title: Text(title),
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
                hintText: 'Ex: Alimentacao, Salario...',
              ),
              textCapitalization: TextCapitalization.sentences,
              autofocus: true,
            ),
            const SizedBox(height: 16),
            const Text('Tipo', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
            const SizedBox(height: 4),
            SegmentedButton<CategoryKind>(
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
              onSelectionChanged: (s) => setState(() => _kind = s.first),
            ),
            const SizedBox(height: 16),
            const Text('Cor', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
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
                        color: selected ? Colors.black87 : Colors.transparent,
                        width: 2.5,
                      ),
                    ),
                    child: selected
                        ? const Icon(Icons.check, size: 14, color: Colors.white)
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
          onPressed: _saving ? null : _save,
          child: _saving
              ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
              : const Text('Salvar'),
        ),
      ],
    );
  }
}

class _CategoryPreset {
  const _CategoryPreset(this.name, this.color);
  final String name;
  final int color;
}
