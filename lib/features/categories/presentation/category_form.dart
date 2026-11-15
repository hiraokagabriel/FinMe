import 'package:flutter/material.dart';

import '../../../app/app_scope.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_palettes.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/utils/id.dart';
import '../../../core/widgets/widgets.dart';
import '../domain/transaction_category.dart';

/// Abre o formulário de categoria (nova ou edição). Orçamento só existe para despesa.
Future<void> showCategoryForm(
  BuildContext context, {
  TransactionCategory? initial,
  CategoryKind kind = CategoryKind.expense,
}) {
  final services = AppScope.of(context);
  return showDialog<void>(
    context: context,
    builder: (_) => _CategoryFormDialog(
      services: services,
      initial: initial,
      kind: initial?.kind ?? kind,
    ),
  );
}

class _CategoryFormDialog extends StatefulWidget {
  const _CategoryFormDialog({
    required this.services,
    required this.initial,
    required this.kind,
  });

  final AppServices services;
  final TransactionCategory? initial;
  final CategoryKind kind;

  @override
  State<_CategoryFormDialog> createState() => _CategoryFormDialogState();
}

class _CategoryFormDialogState extends State<_CategoryFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late final _name = TextEditingController(text: widget.initial?.name ?? '');
  late final _budget = TextEditingController(text: _initialBudgetText());
  late CategoryKind _kind = widget.kind;
  late int _icon = widget.initial?.iconCodePoint ?? kCategoryIcons.first;
  late int _color = widget.initial?.colorValue ?? kEntityColors.first;

  @override
  void dispose() {
    _name.dispose();
    _budget.dispose();
    super.dispose();
  }

  String _initialBudgetText() {
    final cents = widget.initial?.monthlyBudgetCents;
    return cents == null
        ? ''
        : (cents / 100).toStringAsFixed(2).replaceAll('.', ',');
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }
    final budget = parseMoney(_budget.text);
    final category = TransactionCategory(
      id: widget.initial?.id ?? newId(),
      name: _name.text.trim(),
      kind: _kind,
      iconCodePoint: _icon,
      colorValue: _color,
      monthlyBudgetCents:
          _kind == CategoryKind.expense && budget != null && budget > 0
          ? budget
          : null,
    );
    await widget.services.categories.upsert(category);
    if (mounted) {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final textTheme = Theme.of(context).textTheme;
    return Dialog(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(AppSpace.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  widget.initial == null
                      ? 'Nova categoria'
                      : 'Editar categoria',
                  style: textTheme.titleLarge,
                ),
                const SizedBox(height: AppSpace.lg),
                TextFormField(
                  controller: _name,
                  autofocus: true,
                  decoration: const InputDecoration(labelText: 'Nome'),
                  validator: (text) =>
                      (text ?? '').trim().isEmpty ? 'Informe o nome' : null,
                ),
                const SizedBox(height: AppSpace.md),
                SegmentedButton<CategoryKind>(
                  segments: const [
                    ButtonSegment(
                      value: CategoryKind.expense,
                      label: Text('Despesa'),
                    ),
                    ButtonSegment(
                      value: CategoryKind.income,
                      label: Text('Receita'),
                    ),
                  ],
                  selected: {_kind},
                  onSelectionChanged: (sel) =>
                      setState(() => _kind = sel.first),
                ),
                if (_kind == CategoryKind.expense) ...[
                  const SizedBox(height: AppSpace.md),
                  MoneyField(
                    controller: _budget,
                    label: 'Orçamento mensal (opcional)',
                    // Vazio ou válido passa; só texto inválido ou negativo falha.
                    validator: (cents) =>
                        _budget.text.trim().isEmpty ||
                            (cents != null && cents >= 0)
                        ? null
                        : 'Informe um valor válido',
                  ),
                ],
                const SizedBox(height: AppSpace.lg),
                Text('Ícone', style: textTheme.labelLarge),
                const SizedBox(height: AppSpace.sm),
                GridView.count(
                  crossAxisCount: 8,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  mainAxisSpacing: AppSpace.xs,
                  crossAxisSpacing: AppSpace.xs,
                  children: [
                    for (final cp in kCategoryIcons)
                      _IconChoice(
                        codePoint: cp,
                        selected: cp == _icon,
                        onTap: () => setState(() => _icon = cp),
                      ),
                  ],
                ),
                const SizedBox(height: AppSpace.lg),
                Text('Cor', style: textTheme.labelLarge),
                const SizedBox(height: AppSpace.sm),
                Wrap(
                  spacing: AppSpace.sm,
                  runSpacing: AppSpace.sm,
                  children: [
                    for (final value in kEntityColors)
                      _ColorChoice(
                        color: Color(value),
                        selected: value == _color,
                        borderColor: c.textPrimary,
                        onTap: () => setState(() => _color = value),
                      ),
                  ],
                ),
                const SizedBox(height: AppSpace.xl),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('Cancelar'),
                    ),
                    const SizedBox(width: AppSpace.sm),
                    FilledButton(onPressed: _save, child: const Text('Salvar')),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _IconChoice extends StatelessWidget {
  const _IconChoice({
    required this.codePoint,
    required this.selected,
    required this.onTap,
  });

  final int codePoint;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return InkWell(
      borderRadius: AppRadius.chipBorder,
      onTap: onTap,
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: AppRadius.chipBorder,
          border: selected ? Border.all(color: c.primary, width: 2) : null,
        ),
        child: Icon(
          IconData(codePoint, fontFamily: 'MaterialIcons'),
          size: 20,
          color: c.textPrimary,
        ),
      ),
    );
  }
}

class _ColorChoice extends StatelessWidget {
  const _ColorChoice({
    required this.color,
    required this.selected,
    required this.borderColor,
    required this.onTap,
  });

  final Color color;
  final bool selected;
  final Color borderColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      customBorder: const CircleBorder(),
      onTap: onTap,
      child: Container(
        width: 28,
        height: 28,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          border: selected ? Border.all(color: borderColor, width: 2) : null,
        ),
      ),
    );
  }
}
