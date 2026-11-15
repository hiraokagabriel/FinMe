import '../../../core/models/year_month.dart';
import '../../../core/utils/date_utils.dart';
import '../../cards/domain/payment_card.dart';
import '../../categories/domain/category_spending.dart';
import '../../transactions/domain/transaction.dart';
import 'account.dart';
import 'balances.dart';

/// Ponto do histórico mensal (SPEC §5.10). Alimenta delta e sparkline do Painel Ultra.
class MonthSnapshot {
  const MonthSnapshot({
    required this.month,
    required this.endBalanceCents,
    required this.expenseCents,
  });

  final YearMonth month;

  /// Saldo consolidado das contas ativas ao fim do mês.
  final int endBalanceCents;

  /// Despesas pagas do mês (sem provisionados; no mês atual só até hoje).
  final int expenseCents;
}

/// Últimos [months] meses até o mês de [today], em ordem cronológica.
/// Só o último snapshot inclui transações futuras (igual a `Forecast.currentTotalCents`).
List<MonthSnapshot> monthlyHistory({
  required Iterable<Account> accounts,
  required Iterable<PaymentCard> cards,
  required Iterable<Transaction> transactions,
  required DateTime today,
  int months = 6,
}) {
  final activeAccounts = [
    for (final a in accounts)
      if (!a.archived) a,
  ];
  final cardList = cards.toList();
  final txs = transactions.toList();
  final todayOnly = dateOnly(today);
  final paidUntilToday = [
    for (final t in txs)
      if (!t.date.isAfter(todayOnly)) t,
  ];
  final current = YearMonth.fromDate(today);
  final first = current.addMonths(1 - months);

  final snapshots = <MonthSnapshot>[];
  for (var i = 0; i < months; i++) {
    final month = first.addMonths(i);
    // Meses passados fecham no último dia; o atual usa todas as transações.
    final upToEnd = month == current
        ? txs
        : [
            for (final t in txs)
              if (!t.date.isAfter(month.lastDay)) t,
          ];
    final balances = accountBalances(
      accounts: activeAccounts,
      cards: cardList,
      transactions: upToEnd,
    );
    snapshots.add(
      MonthSnapshot(
        month: month,
        endBalanceCents: _sum(balances.values),
        expenseCents: _sum(spendingByCategory(paidUntilToday, month).values),
      ),
    );
  }
  return List.unmodifiable(snapshots);
}

/// Despesas pagas do [month] com data até o dia [day] (clamp no último dia do mês).
int expenseUntilDay(Iterable<Transaction> txs, YearMonth month, int day) {
  final cutoff = month.dateAt(day);
  final until = txs.where((t) => !t.date.isAfter(cutoff));
  return _sum(spendingByCategory(until, month).values);
}

/// Variação relativa `(current - previous) / |previous|`; `null` se `previous == 0`.
double? deltaRatio(int previous, int current) {
  if (previous == 0) {
    return null;
  }
  return (current - previous) / previous.abs();
}

int _sum(Iterable<int> values) => values.fold(0, (a, b) => a + b);
