import 'package:flutter/material.dart';

import '../../../app/app_scope.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/utils/id.dart';
import '../../categories/domain/transaction_category.dart';
import '../../transactions/domain/tags.dart';
import '../../transactions/presentation/tag_widgets.dart';
import '../domain/rule_engine.dart';
import '../domain/transaction_rule.dart';

String ruleMatchLabel(RuleMatchType type) => switch (type) {
  RuleMatchType.contains => 'Contém',
  RuleMatchType.startsWith => 'Começa com',
  RuleMatchType.regex => 'Regex',
};

/// Formulário de regra (nova ou edição). Devolve a regra salva, ou null ao cancelar.
/// [initialPattern], [initialCategoryId] e [sampleDescription] vêm da prévia de importação.
Future<TransactionRule?> showRuleForm(
  BuildContext context, {
  TransactionRule? initial,
  String? initialPattern,
  String? initialCategoryId,
  String? sampleDescription,
}) {
  final services = AppScope.of(context);
  return showDialog<TransactionRule>(
    context: context,
    builder: (_) => _RuleFormDialog(
      services: services,
      initial: initial,
      initialPattern: initialPattern,
      initialCategoryId: initialCategoryId,
      sampleDescription: sampleDescription,
    ),
  );
}

typedef _TestResult = ({int count, List<String> samples, bool? sampleMatch});

class _RuleFormDialog extends StatefulWidget {
  const _RuleFormDialog({
    required this.services,
    this.initial,
    this.initialPattern,
    this.initialCategoryId,
    this.sampleDescription,
  });

  final AppServices services;
  final TransactionRule? initial;
  final String? initialPattern;
  final String? initialCategoryId;
  final String? sampleDescription;

  @override
  State<_RuleFormDialog> createState() => _RuleFormDialogState();
}

class _RuleFormDialogState extends State<_RuleFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late final _pattern = TextEditingController(
    text: widget.initial?.pattern ?? widget.initialPattern ?? '',
  );
  late final _renameTo = TextEditingController(
    text: widget.initial?.renameTo ?? '',
  );
  late RuleMatchType _type =
      widget.initial?.matchType ?? RuleMatchType.contains;
  late String? _categoryId = _existingCategory(
    widget.initial?.categoryId ?? widget.initialCategoryId,
  );
  late bool _active = widget.initial?.active ?? true;
  late List<String> _tags = [...?widget.initial?.tags];
  bool _noTarget = false;
  bool _saving = false;
  _TestResult? _result;

  @override
  void dispose() {
    _pattern.dispose();
    _renameTo.dispose();
    super.dispose();
  }

  /// Categoria removida não pode entrar no dropdown (o valor precisa existir nos itens).
  String? _existingCategory(String? id) =>
      id != null && widget.services.categories.byId(id) != null ? id : null;

  /// Despesas primeiro, depois receitas; cada raiz seguida das filhas (ordem da árvore).
  List<TransactionCategory> get _categoryOptions {
    final tree = widget.services.ledger.categoryTree;
    return [
      ...tree.options(CategoryKind.expense),
      ...tree.options(CategoryKind.income),
    ];
  }

  int _nextPriority() =>
      widget.services.rules.all.fold<int>(
        -1,
        (max, r) => r.priority > max ? r.priority : max,
      ) +
      1;

  void _edited() => setState(() => _result = null);

  void _test() {
    if (!(_formKey.currentState?.validate() ?? false)) {
      _edited();
      return;
    }
    final draft = TransactionRule(
      id: '',
      pattern: _pattern.text.trim(),
      matchType: _type,
    );
    final matches = matchingTransactions(
      draft,
      widget.services.transactions.all,
    );
    final sample = widget.sampleDescription;
    setState(() {
      _result = (
        count: matches.length,
        samples: [for (final t in matches.take(5)) ruleSubject(t)],
        sampleMatch: sample == null
            ? null
            : CompiledRule(draft).matches(sample),
      );
    });
  }

  Future<void> _save() async {
    final valid = _formKey.currentState?.validate() ?? false;
    final renameTo = _renameTo.text.trim();
    final hasTarget =
        _categoryId != null || renameTo.isNotEmpty || _tags.isNotEmpty;
    setState(() => _noTarget = !hasTarget);
    if (_saving || !valid || !hasTarget) {
      return;
    }
    setState(() => _saving = true);
    final rule = TransactionRule(
      id: widget.initial?.id ?? newId(),
      pattern: _pattern.text.trim(),
      matchType: _type,
      categoryId: _categoryId,
      renameTo: renameTo.isEmpty ? null : renameTo,
      priority: widget.initial?.priority ?? _nextPriority(),
      active: _active,
      tags: normalizeTags(_tags),
    );
    await widget.services.rules.upsert(rule);
    if (mounted) {
      Navigator.of(context).pop(rule);
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
                  widget.initial == null ? 'Nova regra' : 'Editar regra',
                  style: textTheme.titleLarge,
                ),
                const SizedBox(height: AppSpace.lg),
                TextFormField(
                  controller: _pattern,
                  autofocus: true,
                  decoration: const InputDecoration(labelText: 'Padrão'),
                  validator: (text) => isValidRulePattern(text ?? '', _type)
                      ? null
                      : 'Padrão inválido',
                  onChanged: (_) => _edited(),
                ),
                const SizedBox(height: AppSpace.md),
                SegmentedButton<RuleMatchType>(
                  segments: [
                    for (final t in RuleMatchType.values)
                      ButtonSegment(value: t, label: Text(ruleMatchLabel(t))),
                  ],
                  selected: {_type},
                  onSelectionChanged: (sel) {
                    _type = sel.first;
                    _edited();
                  },
                ),
                const SizedBox(height: AppSpace.md),
                DropdownButtonFormField<String?>(
                  initialValue: _categoryId,
                  decoration: const InputDecoration(labelText: 'Categoria'),
                  items: [
                    const DropdownMenuItem<String?>(
                      value: null,
                      child: Text('Sem categoria'),
                    ),
                    for (final cat in _categoryOptions)
                      DropdownMenuItem<String?>(
                        value: cat.id,
                        child: Text(
                          widget.services.ledger.categoryTree.label(cat.id),
                        ),
                      ),
                  ],
                  onChanged: (v) => setState(() => _categoryId = v),
                ),
                const SizedBox(height: AppSpace.md),
                TextFormField(
                  controller: _renameTo,
                  decoration: const InputDecoration(
                    labelText: 'Renomear para (opcional)',
                  ),
                ),
                const SizedBox(height: AppSpace.md),
                TagField(
                  tags: _tags,
                  label: 'Adicionar tags',
                  suggestions: widget.services.ledger.allTags,
                  onChanged: (v) {
                    _tags = v;
                    _edited();
                  },
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Ativa'),
                  value: _active,
                  onChanged: (v) => setState(() => _active = v),
                ),
                if (_noTarget)
                  Text(
                    'Defina categoria, renomeação ou tags',
                    style: textTheme.bodySmall?.copyWith(color: c.danger),
                  ),
                const SizedBox(height: AppSpace.md),
                Align(
                  alignment: Alignment.centerLeft,
                  child: OutlinedButton(
                    onPressed: _test,
                    child: const Text('Testar padrão'),
                  ),
                ),
                if (_result != null) _TestResultView(result: _result!),
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

class _TestResultView extends StatelessWidget {
  const _TestResultView({required this.result});

  final _TestResult result;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final textTheme = Theme.of(context).textTheme;
    final sampleMatch = result.sampleMatch;
    return Padding(
      padding: const EdgeInsets.only(top: AppSpace.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            result.count == 1
                ? '1 transação casa'
                : '${result.count} transações casam',
            style: textTheme.bodyMedium,
          ),
          for (final s in result.samples)
            Text(
              s,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: textTheme.bodySmall?.copyWith(color: c.textSecondary),
            ),
          if (sampleMatch != null)
            Padding(
              padding: const EdgeInsets.only(top: AppSpace.xs),
              child: Text(
                sampleMatch ? 'Casa com a linha' : 'Não casa com a linha',
                style: textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: sampleMatch ? c.success : c.textSecondary,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
