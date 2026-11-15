import 'package:flutter/material.dart';

import '../../../app/app_scope.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text.dart';
import '../../../core/utils/id.dart';
import '../../../core/utils/text_normalize.dart';
import '../../../core/widgets/widgets.dart';
import '../../categories/domain/transaction_category.dart';
import '../domain/merchant_dictionary.dart';

/// Seção "Dicionário de estabelecimentos" (SPEC §7.3, Fase 8): padrão → categoria.
class DictionarySection extends StatelessWidget {
  const DictionarySection({super.key});

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    return ListenableBuilder(
      listenable: Listenable.merge([s.dictionary, s.categories]),
      builder: (context, _) {
        final categories = s.categories.all;
        final entries = [...s.dictionary.all]
          ..sort((a, b) {
            final byCategory = a.categoryName.compareTo(b.categoryName);
            return byCategory != 0
                ? byCategory
                : a.pattern.compareTo(b.pattern);
          });
        return SectionCard(
          title: 'Dicionário de estabelecimentos',
          trailing: Wrap(
            spacing: AppSpace.sm,
            children: [
              TextButton(
                onPressed: () => _restore(context),
                child: const Text('Restaurar padrão'),
              ),
              FilledButton.icon(
                onPressed: () => showDictionaryEntryForm(context),
                icon: const Icon(Icons.add),
                label: const Text('Novo padrão'),
              ),
            ],
          ),
          child: entries.isEmpty
              ? const EmptyState(
                  icon: Icons.storefront_outlined,
                  message: 'Nenhum padrão no dicionário.',
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (final e in entries)
                      _EntryRow(
                        entry: e,
                        resolved:
                            resolveCategoryByName(e.categoryName, categories) !=
                            null,
                        onEdit: () =>
                            showDictionaryEntryForm(context, initial: e),
                        onDelete: () => _guarded(
                          context,
                          () => s.dictionary.delete(e.id),
                          'Não foi possível excluir o padrão.',
                        ),
                      ),
                  ],
                ),
        );
      },
    );
  }

  Future<void> _restore(BuildContext context) async {
    final ok = await confirmDialog(
      context,
      title: 'Restaurar padrão?',
      message:
          'O dicionário volta às entradas originais. Padrões criados ou '
          'editados serão perdidos.',
      confirmLabel: 'Restaurar',
      destructive: true,
    );
    if (!ok || !context.mounted) {
      return;
    }
    final dictionary = AppScope.of(context).dictionary;
    await _guarded(
      context,
      () => dictionary.replaceAll(defaultDictionary()),
      'Não foi possível restaurar o dicionário.',
    );
  }
}

/// Novo padrão (sem [initial]) ou edição. Grava o padrão em foldText e o nome da categoria.
Future<void> showDictionaryEntryForm(
  BuildContext context, {
  DictionaryEntry? initial,
}) {
  final services = AppScope.of(context);
  return showDialog<void>(
    context: context,
    builder: (_) =>
        _DictionaryEntryDialog(services: services, initial: initial),
  );
}

/// Roda [action] e avisa com SnackBar se falhar (erro de gravação não some em silêncio).
Future<void> _guarded(
  BuildContext context,
  Future<void> Function() action,
  String error,
) async {
  try {
    await action();
  } catch (_) {
    if (context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error)));
    }
  }
}

class _EntryRow extends StatelessWidget {
  const _EntryRow({
    required this.entry,
    required this.resolved,
    required this.onEdit,
    required this.onDelete,
  });

  final DictionaryEntry entry;
  final bool resolved;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final body = Theme.of(context).textTheme.bodyMedium;
    return SizedBox(
      height: 32,
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: Text(
              entry.pattern,
              overflow: TextOverflow.ellipsis,
              style: body,
            ),
          ),
          Icon(Icons.arrow_forward, size: 14, color: c.textSecondary),
          const SizedBox(width: AppSpace.sm),
          Expanded(
            flex: 2,
            child: Text(
              entry.categoryName,
              overflow: TextOverflow.ellipsis,
              style: body?.copyWith(color: c.textSecondary),
            ),
          ),
          if (!resolved) ...[
            const SizedBox(width: AppSpace.sm),
            StatusBadge(label: 'Categoria não encontrada', color: c.warning),
          ],
          _compactIcon(context, Icons.edit_outlined, 'Editar padrão', onEdit),
          _compactIcon(
            context,
            Icons.delete_outline,
            'Excluir padrão',
            onDelete,
          ),
        ],
      ),
    );
  }

  Widget _compactIcon(
    BuildContext context,
    IconData icon,
    String tooltip,
    VoidCallback onPressed,
  ) {
    return IconButton(
      tooltip: tooltip,
      icon: Icon(icon, size: 16, color: context.colors.textSecondary),
      onPressed: onPressed,
      padding: EdgeInsets.zero,
      visualDensity: VisualDensity.compact,
      constraints: const BoxConstraints.tightFor(width: 28, height: 28),
    );
  }
}

class _DictionaryEntryDialog extends StatefulWidget {
  const _DictionaryEntryDialog({required this.services, required this.initial});

  final AppServices services;
  final DictionaryEntry? initial;

  @override
  State<_DictionaryEntryDialog> createState() => _DictionaryEntryDialogState();
}

class _DictionaryEntryDialogState extends State<_DictionaryEntryDialog> {
  final _formKey = GlobalKey<FormState>();
  late final _pattern = TextEditingController(
    text: widget.initial?.pattern ?? '',
  );
  late final List<TransactionCategory> _categories = _sortedCategories();
  late String? _category = _initialCategoryName();
  bool _saving = false;

  @override
  void dispose() {
    _pattern.dispose();
    super.dispose();
  }

  List<TransactionCategory> _sortedCategories() =>
      [...widget.services.categories.all]
        ..sort((a, b) => a.name.compareTo(b.name));

  /// Nome da categoria que o padrão resolve hoje (inclui fallback); null se não resolve.
  String? _initialCategoryName() {
    final initial = widget.initial;
    if (initial == null) {
      return null;
    }
    final id = resolveCategoryByName(
      initial.categoryName,
      widget.services.categories.all,
    );
    return id == null ? null : widget.services.categories.byId(id)?.name;
  }

  Future<void> _save() async {
    final valid = _formKey.currentState?.validate() ?? false;
    final category = _category;
    if (_saving || !valid || category == null) {
      return;
    }
    setState(() => _saving = true);
    try {
      await widget.services.dictionary.upsert(
        DictionaryEntry(
          id: widget.initial?.id ?? 'dict_${newId()}',
          pattern: foldText(_pattern.text.trim()),
          categoryName: category,
        ),
      );
      if (mounted) {
        Navigator.of(context).pop();
      }
    } catch (_) {
      if (mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Não foi possível salvar o padrão.')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
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
                  widget.initial == null ? 'Novo padrão' : 'Editar padrão',
                  style: AppText.screenTitle(context),
                ),
                const SizedBox(height: AppSpace.lg),
                TextFormField(
                  controller: _pattern,
                  autofocus: true,
                  decoration: const InputDecoration(
                    labelText: 'Padrão',
                    helperText:
                        'Como aparece na descrição do banco. Caixa e acentos não importam.',
                  ),
                  validator: (text) =>
                      (text ?? '').trim().isEmpty ? 'Informe o padrão' : null,
                ),
                const SizedBox(height: AppSpace.md),
                DropdownButtonFormField<String>(
                  initialValue: _category,
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: 'Categoria'),
                  items: [
                    for (final c in _categories)
                      DropdownMenuItem(value: c.name, child: Text(c.name)),
                  ],
                  onChanged: (value) => setState(() => _category = value),
                  validator: (value) =>
                      value == null ? 'Escolha a categoria' : null,
                ),
                const SizedBox(height: AppSpace.xl),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: _saving
                          ? null
                          : () => Navigator.of(context).pop(),
                      child: const Text('Cancelar'),
                    ),
                    const SizedBox(width: AppSpace.sm),
                    FilledButton(
                      onPressed: _saving ? null : _save,
                      child: const Text('Salvar'),
                    ),
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
