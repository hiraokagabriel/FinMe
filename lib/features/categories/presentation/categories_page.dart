import 'package:flutter/material.dart';

import '../../../app/app_scope.dart';
import '../../../core/models/app_settings.dart';
import '../../../core/models/year_month.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_palettes.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/widgets.dart';
import '../../recurring/domain/recurring_rule.dart';
import '../../transactions/domain/transaction.dart';
import '../domain/category_spending.dart';
import '../domain/transaction_category.dart';
import 'category_form.dart';

/// Linha da lista. `spentCents` null = receitas (sem valor). `category` null = "Sem categoria".
typedef _Line = ({
  TransactionCategory? category,
  int? spentCents,
  BudgetStatus? budget,
});

enum _CategoryAction { edit, delete }

class CategoriesPage extends StatefulWidget {
  const CategoriesPage({super.key});

  @override
  State<CategoriesPage> createState() => _CategoriesPageState();
}

class _CategoriesPageState extends State<CategoriesPage> {
  YearMonth? _month;
  CategoryKind _kind = CategoryKind.expense;

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
        final cats = [
          for (final c in s.categories.all)
            if (c.kind == _kind) c,
        ];
        final statuses = expense
            ? budgetStatuses(cats, spending)
            : const <BudgetStatus>[];
        final budgetById = {for (final b in statuses) b.category.id: b};
        final bySpend = ultra && expense;
        cats.sort((a, b) {
          final spend = bySpend
              ? (spending[b.id] ?? 0).compareTo(spending[a.id] ?? 0)
              : 0;
          return spend != 0 ? spend : a.name.compareTo(b.name);
        });
        final lines = <_Line>[
          for (final c in cats)
            (
              category: c,
              spentCents: expense ? (spending[c.id] ?? 0) : null,
              budget: budgetById[c.id],
            ),
        ];
        final uncategorized = spending[null] ?? 0;
        if (expense && uncategorized > 0) {
          lines.add((category: null, spentCents: uncategorized, budget: null));
        }
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
                                    child: _BudgetSummary(statuses: statuses),
                                  ),
                                ),
                              if (lines.isEmpty)
                                const SliverFillRemaining(
                                  hasScrollBody: false,
                                  child: EmptyState(
                                    icon: Icons.category_outlined,
                                    message: 'Nenhuma categoria aqui ainda.',
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

/// Exclui a categoria, sempre com confirmação. Lançamentos/recorrências que a usam ficam sem categoria.
Future<void> _deleteCategory(
  BuildContext context,
  AppServices s,
  TransactionCategory cat,
) async {
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
      if (t.categoryId == cat.id) _txWithoutCategory(t),
  ]);
  await s.recurring.upsertAll([
    for (final r in s.recurring.all)
      if (r.categoryId == cat.id) _ruleWithoutCategory(r),
  ]);
  await s.categories.delete(cat.id);
}

// copyWith não aceita null para limpar campo; por isso o construtor é usado com categoryId: null.
Transaction _txWithoutCategory(Transaction t) => Transaction(
  id: t.id,
  type: t.type,
  amountCents: t.amountCents,
  date: t.date,
  description: t.description,
  categoryId: null,
  accountId: t.accountId,
  cardId: t.cardId,
  toAccountId: t.toAccountId,
  status: t.status,
  isBoleto: t.isBoleto,
  invoiceKey: t.invoiceKey,
  installmentGroupId: t.installmentGroupId,
  installmentIndex: t.installmentIndex,
  installmentCount: t.installmentCount,
  recurringId: t.recurringId,
  notes: t.notes,
);

RecurringRule _ruleWithoutCategory(RecurringRule r) => RecurringRule(
  id: r.id,
  description: r.description,
  type: r.type,
  amountCents: r.amountCents,
  frequency: r.frequency,
  startDate: r.startDate,
  categoryId: null,
  accountId: r.accountId,
  cardId: r.cardId,
  endDate: r.endDate,
  isSubscription: r.isSubscription,
  isBoleto: r.isBoleto,
  active: r.active,
  materializedUntil: r.materializedUntil,
);

/// Resumo do orçamento do mês (só Ultra, aba Despesas).
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
    this.onEdit,
    this.onDelete,
  });

  final _Line line;
  final bool ultra;
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
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpace.sm),
      child: Row(
        children: [
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
                  case _CategoryAction.delete:
                    onDelete?.call();
                }
              },
              itemBuilder: (_) => [
                const PopupMenuItem(
                  value: _CategoryAction.edit,
                  child: Text('Editar'),
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
