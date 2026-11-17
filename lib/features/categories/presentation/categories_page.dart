import 'package:flutter/material.dart';

import '../../../app/app_scope.dart';
import '../../../core/models/app_settings.dart';
import '../../../core/models/year_month.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_palettes.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/utils/text_normalize.dart';
import '../../../core/widgets/widgets.dart';
import '../domain/category_spending.dart';
import '../domain/category_tree.dart';
import '../domain/transaction_category.dart';
import 'category_form.dart';

/// Linha da lista. `spentCents` null = receitas (sem valor). `category` null = "Sem categoria".
/// `child` = subcategoria (recuada). `expanded` null = sem chevron; senão raiz com filhas (Ultra).
typedef _Line = ({
  TransactionCategory? category,
  int? spentCents,
  BudgetStatus? budget,
  bool child,
  bool? expanded,
});

enum _CategoryAction { edit, addChild, delete }

class CategoriesPage extends StatefulWidget {
  const CategoriesPage({super.key});

  @override
  State<CategoriesPage> createState() => _CategoriesPageState();
}

class _CategoriesPageState extends State<CategoriesPage> {
  YearMonth? _month;
  CategoryKind _kind = CategoryKind.expense;
  final Set<String> _expanded = {};

  void _toggle(String id) => setState(() {
    if (!_expanded.remove(id)) {
      _expanded.add(id);
    }
  });

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    return ListenableBuilder(
      listenable: s.ledger,
      builder: (context, _) {
        final ultra = s.settings.value.mode == AppMode.ultra;
        final expense = _kind == CategoryKind.expense;
        final month = _month ?? YearMonth.fromDate(s.ledger.today);
        final spending = s.ledger.spendingFor(month);
        final tree = s.ledger.categoryTree;
        final cats = [
          for (final c in s.categories.all)
            if (c.kind == _kind) c,
        ];
        final statuses = expense
            ? budgetStatuses(cats, spending, tree: tree)
            : const <BudgetStatus>[];
        final budgetById = {for (final b in statuses) b.category.id: b};
        final lines = _treeLines(
          tree: tree,
          kind: _kind,
          ultra: ultra,
          expanded: _expanded,
          spending: spending,
          rolled: s.ledger.rolledSpendingFor(month),
          budgetById: budgetById,
        );
        final uncategorized = spending[null] ?? 0;
        if (expense && uncategorized > 0) {
          lines.add((
            category: null,
            spentCents: uncategorized,
            budget: null,
            child: false,
            expanded: null,
          ));
        }
        // Resumo só com raízes: o gasto de uma raiz já inclui o das filhas.
        final rootStatuses = [
          for (final b in statuses)
            if (tree.isRoot(b.category.id)) b,
        ];
        final narrow = MediaQuery.sizeOf(context).width < 600;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            PageHeader(
              title: 'Categorias',
              actions: [
                FilledButton.icon(
                  onPressed: () => showCategoryForm(context, kind: _kind),
                  icon: const Icon(Icons.add),
                  label: const Text('Nova categoria'),
                ),
              ],
            ),
            Expanded(
              child: Align(
                alignment: Alignment.topCenter,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1200),
                  child: Padding(
                    padding: EdgeInsets.symmetric(
                      horizontal: narrow ? AppSpace.lg : AppSpace.xl,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Wrap(
                          spacing: AppSpace.md,
                          runSpacing: AppSpace.sm,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            MonthSelector(
                              value: month,
                              onChanged: (m) => setState(() => _month = m),
                            ),
                            SegmentedButton<CategoryKind>(
                              segments: const [
                                ButtonSegment(
                                  value: CategoryKind.expense,
                                  label: Text('Despesas'),
                                ),
                                ButtonSegment(
                                  value: CategoryKind.income,
                                  label: Text('Receitas'),
                                ),
                              ],
                              selected: {_kind},
                              onSelectionChanged: (sel) =>
                                  setState(() => _kind = sel.first),
                            ),
                          ],
                        ),
                        const SizedBox(height: AppSpace.md),
                        Expanded(
                          child: CustomScrollView(
                            slivers: [
                              if (expense && ultra)
                                SliverToBoxAdapter(
                                  child: Padding(
                                    padding: const EdgeInsets.only(
                                      bottom: AppSpace.md,
                                    ),
                                    child: _BudgetSummary(
                                      statuses: rootStatuses,
                                    ),
                                  ),
                                ),
                              if (lines.isEmpty)
                                SliverFillRemaining(
                                  hasScrollBody: false,
                                  child: EmptyState(
                                    icon: Icons.category_outlined,
                                    message: 'Nenhuma categoria aqui ainda.',
                                    action: FilledButton.icon(
                                      onPressed: () => showCategoryForm(
                                        context,
                                        kind: _kind,
                                      ),
                                      icon: const Icon(Icons.add),
                                      label: const Text('Nova categoria'),
                                    ),
                                  ),
                                )
                              else
                                SliverList.builder(
                                  itemCount: lines.length,
                                  itemBuilder: (context, i) {
                                    final line = lines[i];
                                    final cat = line.category;
                                    return Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        _CategoryRow(
                                          key: cat == null
                                              ? null
                                              : ValueKey('cat-${cat.id}'),
                                          line: line,
                                          ultra: ultra,
                                          onToggle: cat == null
                                              ? null
                                              : () => _toggle(cat.id),
                                          onAddChild: cat == null || line.child
                                              ? null
                                              : () => showCategoryForm(
                                                  context,
                                                  kind: cat.kind,
                                                  parentId: cat.id,
                                                ),
                                          onEdit: cat == null
                                              ? null
                                              : () => showCategoryForm(
                                                  context,
                                                  initial: cat,
                                                  kind: cat.kind,
                                                ),
                                          onDelete: cat == null
                                              ? null
                                              : () => _deleteCategory(
                                                  context,
                                                  s,
                                                  cat,
                                                ),
                                        ),
                                        const Divider(height: 1),
                                      ],
                                    );
                                  },
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

/// Linhas da árvore: cada raiz seguida das filhas. Gasto da raiz agregado (`rolled`); da filha, o próprio.
/// Ultra: raiz com filhas começa recolhida; filhas só aparecem depois de expandir.
List<_Line> _treeLines({
  required CategoryTree tree,
  required CategoryKind kind,
  required bool ultra,
  required Set<String> expanded,
  required Map<String?, int> spending,
  required Map<String?, int> rolled,
  required Map<String, BudgetStatus> budgetById,
}) {
  final expense = kind == CategoryKind.expense;
  final bySpend = ultra && expense;
  int spentOf(TransactionCategory c) =>
      tree.isRoot(c.id) ? rolled[c.id] ?? 0 : spending[c.id] ?? 0;
  int byValue(TransactionCategory a, TransactionCategory b) {
    final spend = bySpend ? spentOf(b).compareTo(spentOf(a)) : 0;
    return spend != 0 ? spend : foldText(a.name).compareTo(foldText(b.name));
  }

  final roots = bySpend
      ? ([...tree.roots(kind)]..sort(byValue))
      : tree.roots(kind);
  final lines = <_Line>[];
  for (final root in roots) {
    final kids = [...tree.childrenOf(root.id)];
    if (bySpend) {
      kids.sort(byValue);
    }
    final open = expanded.contains(root.id);
    lines.add((
      category: root,
      spentCents: expense ? spentOf(root) : null,
      budget: budgetById[root.id],
      child: false,
      expanded: ultra && kids.isNotEmpty ? open : null,
    ));
    if (ultra && !open) {
      continue;
    }
    for (final kid in kids) {
      lines.add((
        category: kid,
        spentCents: expense ? spentOf(kid) : null,
        budget: budgetById[kid.id],
        child: true,
        expanded: null,
      ));
    }
  }
  return lines;
}

/// Exclui a categoria, sempre com confirmação. Lançamentos/recorrências que a usam ficam sem categoria.
Future<void> _deleteCategory(
  BuildContext context,
  AppServices s,
  TransactionCategory cat,
) async {
  if (s.categories.all.any((c) => c.parentId == cat.id)) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Mova ou exclua as subcategorias antes')),
    );
    return;
  }
  final txCount = s.transactions.all
      .where((t) => t.categoryId == cat.id)
      .length;
  final ruleCount = s.recurring.all.where((r) => r.categoryId == cat.id).length;
  final ok = await confirmDialog(
    context,
    title: 'Excluir "${cat.name}"?',
    message: txCount + ruleCount == 0
        ? 'A categoria não está em uso.'
        : '$txCount lançamento(s) e $ruleCount recorrência(s) ficarão sem categoria.',
    confirmLabel: 'Excluir',
    destructive: true,
  );
  if (!ok || !context.mounted) {
    return;
  }
  // Atualiza os dependentes antes de apagar a categoria: falha no meio não deixa referência quebrada.
  await s.transactions.upsertAll([
    for (final t in s.transactions.all)
      if (t.categoryId == cat.id) t.copyWith(categoryId: null),
  ]);
  await s.recurring.upsertAll([
    for (final r in s.recurring.all)
      if (r.categoryId == cat.id) r.copyWith(categoryId: null),
  ]);
  await s.categories.delete(cat.id);
}

/// Resumo do orçamento do mês (só Ultra, aba Despesas). Recebe só as raízes.
class _BudgetSummary extends StatelessWidget {
  const _BudgetSummary({required this.statuses});

  final List<BudgetStatus> statuses;

  @override
  Widget build(BuildContext context) {
    final exceeded = statuses.where((b) => b.exceeded).length;
    final budget = statuses.fold<int>(0, (sum, b) => sum + b.budgetCents);
    final spent = statuses.fold<int>(0, (sum, b) => sum + b.spentCents);
    final muted = Theme.of(
      context,
    ).textTheme.bodyMedium?.copyWith(color: context.colors.textSecondary);
    return SectionCard(
      title: 'Orçamentos',
      trailing: exceeded == 0
          ? null
          : StatusBadge(
              label: '$exceeded estourada${exceeded > 1 ? 's' : ''}',
              color: context.colors.danger,
            ),
      child: statuses.isEmpty
          ? Text('Nenhum orçamento definido', style: muted)
          : Wrap(
              spacing: AppSpace.xs,
              runSpacing: AppSpace.xs,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Text('Gasto', style: muted),
                MoneyText(spent, style: muted),
                Text('de', style: muted),
                MoneyText(budget, style: muted),
                Text('em ${statuses.length} categoria(s)', style: muted),
              ],
            ),
    );
  }
}

class _CategoryRow extends StatelessWidget {
  const _CategoryRow({
    super.key,
    required this.line,
    required this.ultra,
    this.onToggle,
    this.onAddChild,
    this.onEdit,
    this.onDelete,
  });

  final _Line line;
  final bool ultra;
  final VoidCallback? onToggle;
  final VoidCallback? onAddChild;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final textTheme = Theme.of(context).textTheme;
    final muted = textTheme.bodySmall?.copyWith(color: c.textSecondary);
    final cat = line.category;
    final color = cat == null ? c.textSecondary : Color(cat.colorValue);
    final icon = cat == null
        ? Icons.help_outline
        : categoryIcon(cat.iconCodePoint);
    final budget = line.budget;
    final spent = line.spentCents;
    final expanded = line.expanded;
    return Padding(
      key: cat == null ? null : ValueKey('category-line-${cat.id}'),
      padding: EdgeInsets.fromLTRB(
        line.child ? AppSpace.lg : 0,
        AppSpace.sm,
        0,
        AppSpace.sm,
      ),
      child: Row(
        children: [
          if (ultra)
            SizedBox(
              width: 28,
              child: expanded == null || cat == null
                  ? null
                  : IconButton(
                      key: ValueKey('category-toggle-${cat.id}'),
                      tooltip: expanded ? 'Recolher' : 'Expandir',
                      visualDensity: VisualDensity.compact,
                      padding: EdgeInsets.zero,
                      onPressed: onToggle,
                      icon: AnimatedRotation(
                        turns: expanded ? 0.25 : 0,
                        duration: AppMotion.fast,
                        child: const Icon(Icons.chevron_right, size: 20),
                      ),
                    ),
            ),
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 18, color: color),
          ),
          const SizedBox(width: AppSpace.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(cat?.name ?? 'Sem categoria', style: textTheme.bodyMedium),
                if (ultra && budget != null) ...[
                  const SizedBox(height: AppSpace.xs),
                  LimitBar(
                    usedCents: budget.spentCents,
                    limitCents: budget.budgetCents,
                  ),
                  const SizedBox(height: AppSpace.xs),
                  Wrap(
                    spacing: AppSpace.xs,
                    runSpacing: AppSpace.xs,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      MoneyText(budget.spentCents, style: muted),
                      Text('de', style: muted),
                      MoneyText(budget.budgetCents, style: muted),
                      if (budget.exceeded)
                        StatusBadge(label: 'Estourado', color: c.danger),
                    ],
                  ),
                ],
              ],
            ),
          ),
          // Com orçamento no Ultra, o gasto já aparece na linha de orçamento.
          if (spent != null && !(ultra && budget != null))
            MoneyText(spent, style: textTheme.bodyMedium),
          if (onEdit != null)
            PopupMenuButton<_CategoryAction>(
              tooltip: 'Ações',
              onSelected: (action) {
                switch (action) {
                  case _CategoryAction.edit:
                    onEdit?.call();
                  case _CategoryAction.addChild:
                    onAddChild?.call();
                  case _CategoryAction.delete:
                    onDelete?.call();
                }
              },
              itemBuilder: (_) => [
                const PopupMenuItem(
                  value: _CategoryAction.edit,
                  child: Text('Editar'),
                ),
                if (onAddChild != null)
                  const PopupMenuItem(
                    value: _CategoryAction.addChild,
                    child: Text('Nova subcategoria'),
                  ),
                PopupMenuItem(
                  value: _CategoryAction.delete,
                  child: Text('Excluir', style: TextStyle(color: c.danger)),
                ),
              ],
            ),
        ],
      ),
    );
  }
}
