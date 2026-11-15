import 'package:flutter/material.dart';

import '../../../app/app_scope.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/widgets.dart';
import '../../categories/domain/transaction_category.dart';
import '../../transactions/domain/transaction.dart';
import '../domain/rule_engine.dart';
import '../domain/transaction_rule.dart';
import 'rule_form.dart';

/// Seção "Regras" da página Importar. A ordem da lista é a prioridade (arrastar reordena).
class RulesSection extends StatelessWidget {
  const RulesSection({super.key});

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    return ListenableBuilder(
      // Ledger entra no merge: nome da categoria muda sem a regra mudar.
      listenable: Listenable.merge([s.rules, s.ledger]),
      builder: (context, _) {
        final rules = [...s.rules.all]..sort(_byPriority);
        final categories = s.ledger.categoriesById;
        return SectionCard(
          title: 'Regras',
          trailing: Wrap(
            spacing: AppSpace.sm,
            runSpacing: AppSpace.sm,
            children: [
              OutlinedButton(
                onPressed: () => showReapplyRulesDialog(context),
                child: const Text('Reaplicar às transações'),
              ),
              FilledButton.icon(
                onPressed: () => showRuleForm(context),
                icon: const Icon(Icons.add),
                label: const Text('Nova regra'),
              ),
            ],
          ),
          child: rules.isEmpty
              ? EmptyState(
                  icon: Icons.rule,
                  message:
                      'Nenhuma regra. Crie regras para categorizar e renomear lançamentos automaticamente.',
                  action: FilledButton(
                    onPressed: () => showRuleForm(context),
                    child: const Text('Nova regra'),
                  ),
                )
              : ReorderableListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  buildDefaultDragHandles: false,
                  itemCount: rules.length,
                  onReorder: (oldIndex, newIndex) =>
                      _reorder(s, rules, oldIndex, newIndex),
                  itemBuilder: (context, i) {
                    final rule = rules[i];
                    final catId = rule.categoryId;
                    return _RuleRow(
                      key: ValueKey(rule.id),
                      index: i,
                      rule: rule,
                      category: catId == null ? null : categories[catId],
                    );
                  },
                ),
        );
      },
    );
  }
}

int _byPriority(TransactionRule a, TransactionRule b) =>
    a.priority != b.priority
    ? a.priority.compareTo(b.priority)
    : a.id.compareTo(b.id);

void _reorder(
  AppServices s,
  List<TransactionRule> rules,
  int oldIndex,
  int newIndex,
) {
  final list = [...rules];
  final moved = list.removeAt(oldIndex);
  list.insert(newIndex > oldIndex ? newIndex - 1 : newIndex, moved);
  s.rules.upsertAll(reorderRules(list));
}

class _RuleRow extends StatelessWidget {
  const _RuleRow({
    super.key,
    required this.index,
    required this.rule,
    required this.category,
  });

  final int index;
  final TransactionRule rule;

  /// null = sem categoria (ou a categoria foi removida; ver `missing`).
  final TransactionCategory? category;

  bool get _missing => rule.categoryId != null && category == null;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final textTheme = Theme.of(context).textTheme;
    final s = AppScope.of(context);
    final cat = category;
    final catLabel = rule.categoryId == null
        ? '—'
        : cat == null
        ? 'Categoria removida'
        : '→ ${cat.name}';
    final rename = (rule.renameTo ?? '').trim();
    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: c.border)),
      ),
      child: Row(
        children: [
          ReorderableDragStartListener(
            index: index,
            child: Padding(
              padding: const EdgeInsets.all(AppSpace.xs),
              child: Icon(
                Icons.drag_indicator,
                size: 18,
                color: c.textSecondary,
              ),
            ),
          ),
          Expanded(
            child: Row(
              children: [
                Flexible(
                  child: Text(
                    rule.pattern,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: textTheme.bodyMedium?.copyWith(
                      color: rule.active ? c.textPrimary : c.textSecondary,
                    ),
                  ),
                ),
                const SizedBox(width: AppSpace.sm),
                StatusBadge(
                  label: ruleMatchLabel(rule.matchType),
                  color: c.textSecondary,
                ),
                const SizedBox(width: AppSpace.sm),
                Flexible(
                  child: Text(
                    catLabel,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: textTheme.bodySmall?.copyWith(
                      color: _missing ? c.warning : c.textSecondary,
                    ),
                  ),
                ),
                if (rename.isNotEmpty) ...[
                  const SizedBox(width: AppSpace.sm),
                  Flexible(
                    child: Text(
                      'renomeia para "$rename"',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: textTheme.bodySmall?.copyWith(
                        color: c.textSecondary,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          Switch(
            value: rule.active,
            onChanged: (v) => s.rules.upsert(rule.copyWith(active: v)),
          ),
          IconButton(
            tooltip: 'Editar regra',
            visualDensity: VisualDensity.compact,
            icon: const Icon(Icons.edit_outlined, size: 18),
            onPressed: () => showRuleForm(context, initial: rule),
          ),
          IconButton(
            tooltip: 'Excluir regra',
            visualDensity: VisualDensity.compact,
            icon: const Icon(Icons.delete_outline, size: 18),
            onPressed: () => _delete(context, s),
          ),
        ],
      ),
    );
  }

  Future<void> _delete(BuildContext context, AppServices s) async {
    final ok = await confirmDialog(
      context,
      title: 'Excluir regra?',
      message:
          'A regra "${rule.pattern}" será removida. Transações já categorizadas não mudam.',
      confirmLabel: 'Excluir',
      destructive: true,
    );
    if (ok && context.mounted) {
      await s.rules.delete(rule.id);
    }
  }
}

/// Reaplica as regras às transações já lançadas. Grava só as que mudam.
Future<void> showReapplyRulesDialog(BuildContext context) {
  final services = AppScope.of(context);
  return showDialog<void>(
    context: context,
    builder: (_) => _ReapplyDialog(services: services),
  );
}

class _ReapplyDialog extends StatefulWidget {
  const _ReapplyDialog({required this.services});

  final AppServices services;

  @override
  State<_ReapplyDialog> createState() => _ReapplyDialogState();
}

class _ReapplyDialogState extends State<_ReapplyDialog> {
  bool _overwrite = false;
  late List<Transaction> _changes;
  int _categoryCount = 0;
  int _descriptionCount = 0;

  @override
  void initState() {
    super.initState();
    _recalc();
  }

  /// Recalcula ao abrir e ao mudar a opção; `build` só lê o resultado.
  void _recalc() {
    final services = widget.services;
    final before = {for (final t in services.transactions.all) t.id: t};
    final changes = reapplyRules(
      compileRules(services.rules.all),
      before.values,
      categoriesById: services.ledger.categoriesById,
      overwriteCategory: _overwrite,
    );
    _changes = changes;
    _categoryCount = changes
        .where((t) => t.categoryId != before[t.id]!.categoryId)
        .length;
    _descriptionCount = changes
        .where((t) => t.description != before[t.id]!.description)
        .length;
  }

  Future<void> _apply() async {
    try {
      await widget.services.transactions.upsertAll(_changes);
    } catch (e) {
      // Diálogo continua aberto: o usuário pode tentar de novo.
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Erro ao reaplicar regras: $e')));
      }
      return;
    }
    if (mounted) {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final n = _changes.length;
    final noun = n == 1 ? 'transação vai mudar' : 'transações vão mudar';
    return AlertDialog(
      title: const Text('Reaplicar regras'),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              '$n $noun ($_categoryCount de categoria, $_descriptionCount de descrição)',
            ),
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              controlAffinity: ListTileControlAffinity.leading,
              title: const Text('Sobrescrever categorias já definidas'),
              value: _overwrite,
              onChanged: (v) => setState(() {
                _overwrite = v ?? false;
                _recalc();
              }),
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
          onPressed: n == 0 ? null : _apply,
          child: const Text('Aplicar'),
        ),
      ],
    );
  }
}
