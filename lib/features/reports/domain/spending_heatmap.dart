import '../../../core/utils/date_utils.dart';
import '../../categories/domain/category_tree.dart';
import '../../transactions/domain/transaction.dart';
import 'report_filter.dart';

/// Gasto de um dia: soma em centavos e nº de transações.
class DaySpending {
  const DaySpending({
    required this.date,
    required this.cents,
    required this.count,
  });

  final DateTime date;
  final int cents;
  final int count;
}

/// Gasto por dia no período. [days] só tem dias com gasto; [thresholds] são
/// os quartis (t1, t2, t3) dos totais diários, usados para os 4 níveis de cor.
class SpendingHeatmap {
  const SpendingHeatmap({
    required this.from,
    required this.to,
    required this.days,
    required this.thresholds,
  });

  final DateTime from, to;
  final Map<DateTime, DaySpending> days;
  final List<int> thresholds;

  /// 0 = sem gasto; 1..4 pelos limiares. Sem limiares: qualquer gasto vira 4.
  int levelOf(int cents) {
    if (cents <= 0) {
      return 0;
    }
    for (var k = 0; k < thresholds.length; k++) {
      if (cents <= thresholds[k]) {
        return k + 1;
      }
    }
    return 4;
  }

  /// Dia de maior gasto; empate fica com o mais antigo.
  DaySpending? get maxDay {
    DaySpending? best;
    for (final d in days.values) {
      if (best == null ||
          d.cents > best.cents ||
          (d.cents == best.cents && d.date.isBefore(best.date))) {
        best = d;
      }
    }
    return best;
  }

  int get totalCents => days.values.fold(0, (sum, d) => sum + d.cents);

  int get activeDays => days.length;
}

/// Despesas (`reportFlowOf` == expense; `f.flow` ignorado) no escopo de [f] com
/// data em [from]..[to] inclusive. Hora da transação é descartada.
/// Com receita no filtro, `f.categoryIds` também é ignorado.
SpendingHeatmap spendingHeatmap(
  Iterable<Transaction> txs,
  ReportFilter f, {
  required DateTime from,
  required DateTime to,
  required CategoryTree tree,
}) {
  final start = dateOnly(from);
  final end = dateOnly(to);
  final acc = <DateTime, DaySpending>{};
  final scope = f.flow == ReportFlow.income ? f.withoutCategories : f;
  for (final t in txs) {
    if (reportFlowOf(t) != ReportFlow.expense ||
        !matchesReportScope(t, scope, tree)) {
      continue;
    }
    // Transaction já guarda a data em meia-noite; dateOnly por linha custa caro.
    final day = t.date;
    if (day.isBefore(start) || day.isAfter(end)) {
      continue;
    }
    final prev = acc[day];
    acc[day] = DaySpending(
      date: day,
      cents: (prev?.cents ?? 0) + t.amountCents,
      count: (prev?.count ?? 0) + 1,
    );
  }
  final sorted = [for (final d in acc.values) d.cents]..sort();
  final n = sorted.length;
  final thresholds = n == 0
      ? const <int>[]
      : [for (var k = 1; k <= 3; k++) sorted[((n - 1) * k) ~/ 4]];
  return SpendingHeatmap(
    from: start,
    to: end,
    days: Map.unmodifiable(acc),
    thresholds: List.unmodifiable(thresholds),
  );
}
