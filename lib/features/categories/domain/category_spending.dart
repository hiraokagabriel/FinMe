import '../../../core/models/year_month.dart';
import '../../transactions/domain/transaction.dart';
import 'transaction_category.dart';

/// Gasto por categoria no mês (só despesas; cartão incluso). Chave null = sem categoria.
/// Estornos (income em cartão) não abatem. shortcut: modo simples, subtrair estornos se o painel pedir.
Map<String?, int> spendingByCategory(
  Iterable<Transaction> txs,
  YearMonth month, {
  bool includePlanned = false,
}) {
  final totals = <String?, int>{};
  for (final t in txs) {
    if (t.type != TransactionType.expense) {
      continue;
    }
    if (t.isPlanned && !includePlanned) {
      continue;
    }
    if (!month.contains(t.date)) {
      continue;
    }
    totals[t.categoryId] = (totals[t.categoryId] ?? 0) + t.amountCents;
  }
  return totals;
}

class BudgetStatus {
  const BudgetStatus({
    required this.category,
    required this.spentCents,
    required this.budgetCents,
  });

  final TransactionCategory category;
  final int spentCents;
  final int budgetCents;

  double get ratio => spentCents / budgetCents;

  bool get exceeded => spentCents > budgetCents;
}

/// Orçamentos das categorias com `monthlyBudgetCents > 0`, do maior ratio ao menor.
List<BudgetStatus> budgetStatuses(
  Iterable<TransactionCategory> cats,
  Map<String?, int> spending,
) {
  final statuses = [
    for (final c in cats)
      if (c.monthlyBudgetCents case final budget? when budget > 0)
        BudgetStatus(
          category: c,
          spentCents: spending[c.id] ?? 0,
          budgetCents: budget,
        ),
  ];
  statuses.sort((a, b) => b.ratio.compareTo(a.ratio));
  return statuses;
}
