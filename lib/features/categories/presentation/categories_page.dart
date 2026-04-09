import 'package:flutter/material.dart';

import '../data/categories_repository.dart';
import '../domain/category_entity.dart';
import '../domain/category_kind.dart';
import '../../../core/services/repository_locator.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_empty_state.dart';

// Paleta de ícones disponíveis para seleção
const List<IconData> _kIconOptions = [
  Icons.restaurant_outlined,
  Icons.directions_car_outlined,
  Icons.subscriptions_outlined,
  Icons.account_balance_wallet_outlined,
  Icons.home_outlined,
  Icons.local_hospital_outlined,
  Icons.school_outlined,
  Icons.shopping_bag_outlined,
  Icons.sports_esports_outlined,
  Icons.flight_outlined,
  Icons.pets_outlined,
  Icons.fitness_center_outlined,
  Icons.local_gas_station_outlined,
  Icons.phone_outlined,
  Icons.computer_outlined,
  Icons.coffee_outlined,
  Icons.theaters_outlined,
  Icons.child_care_outlined,
  Icons.savings_outlined,
  Icons.work_outline,
  Icons.attach_money,
  Icons.card_giftcard_outlined,
  Icons.build_outlined,
  Icons.emoji_transportation_outlined,
];

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

  IconData _iconOf(CategoryEntity cat) {
    if (cat.iconCodePoint == null) return Icons.label_outline;
    return IconData(cat.iconCodePoint!, fontFamily: 'MaterialIcons');
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
              ? AppEmptyState(
                  icon: Icons.label_off_outlined,
                  title: 'Nenhuma categoria cadastrada',
                  message:
                      'Crie categorias para organizar suas transações por tipo de gasto ou receita.',
                  actionLabel: 'Nova categoria',
                  onAction: () => _openForm(),
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
                            icon: _iconOf(cat),
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
                            icon: _iconOf(cat),
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
    required this.icon,
    required this.onEdit,
    required this.onDelete,
  });

  final CategoryEntity category;
  final Color          color;
  final IconData       icon;
  final VoidCallback   onEdit;
  final VoidCallback   onDelete;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: CircleAvatar(
        backgroundColor: color.withOpacity(0.18),
        child: Icon(icon, color: color, size: 20),
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
  late IconData _selectedIcon;
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
      _selectedIcon = widget.initial!.iconCodePoint != null
          ? IconData(widget.initial!.iconCodePoint!,
              fontFamily: 'MaterialIcons')
          : _kIconOptions.first;
    } else {
      _kind         = CategoryKind.expense;
      _colorValue   = _palette.first;
      _selectedIcon = _kIconOptions.first;
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
      id:            widget.initial?.id ??
          'cat_${DateTime.now().microsecondsSinceEpoch}',
      name:          name,
      kind:          _kind,
      colorValue:    _colorValue,
      iconCodePoint: _selectedIcon.codePoint,
    );

    await widget.onSave(entity);
    if (!mounted) return;
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final color = Color(_colorValue);

    return AlertDialog(
      title: Text(
          widget.initial == null ? 'Nova categoria' : 'Editar categoria'),
      content: SizedBox(
        width: 360,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Preview
              Center(
                child: CircleAvatar(
                  radius: 28,
                  backgroundColor: color.withOpacity(0.18),
                  child: Icon(_selectedIcon, color: color, size: 26),
                ),
              ),
              const SizedBox(height: AppSpacing.lg),

              // Nome
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

              // Ícone
              Text('Ícone',
                  style: AppText.secondary
                      .copyWith(fontWeight: FontWeight.w500)),
              const SizedBox(height: AppSpacing.sm),
              Wrap(
                spacing: AppSpacing.sm,
                runSpacing: AppSpacing.sm,
                children: _kIconOptions.map((ic) {
                  final selected = ic.codePoint == _selectedIcon.codePoint;
                  return GestureDetector(
                    onTap: () => setState(() => _selectedIcon = ic),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: selected
                            ? color.withOpacity(0.18)
                            : Colors.transparent,
                        borderRadius:
                            BorderRadius.circular(AppRadius.card),
                        border: Border.all(
                          color: selected ? color : Colors.transparent,
                          width: 1.5,
                        ),
                      ),
                      child: Icon(
                        ic,
                        size: 18,
                        color: selected ? color : null,
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: AppSpacing.lg),

              // Tipo de transação
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

              // Cor
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
                              ? Colors.white
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
                      strokeWidth: 2, color: Colors.white))
              : const Text('Salvar'),
        ),
      ],
    );
  }
}
