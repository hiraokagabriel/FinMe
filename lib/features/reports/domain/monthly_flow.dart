import '../../../core/models/year_month.dart';
import '../../categories/domain/category_tree.dart';
import '../../transactions/domain/transaction.dart';
import 'report_filter.dart';

/// Saldo e fluxo de um mês da tendência (SPEC §5.30).
class TrendPoint {
  const TrendPoint({
    required this.month,
    required this.incomeCents,
    required this.expenseCents,
  });

  final YearMonth month;
  final int incomeCents;
  final int expenseCents;

  /// Saldo do mês.
  int get balanceCents => incomeCents - expenseCents;
}

Map<YearMonth, int> _indexOf(List<YearMonth> months) => {
  for (var i = 0; i < months.length; i++) months[i]: i,
};

/// Um ponto por mês de [months] (zeros inclusos). Ignora `f.flow`: sempre receitas e despesas.
/// `f.categoryIds` restringe só o lado de `f.flow`; o outro lado segue sem categoria.
List<TrendPoint> monthlyTrend(
  Iterable<Transaction> txs,
  ReportFilter f, {
  required List<YearMonth> months,
  required CategoryTree tree,
  required DateTime today,
}) {
  final index = _indexOf(months);
  final income = List<int>.filled(months.length, 0);
  final expense = List<int>.filled(months.length, 0);
  final otherSide = f.withoutCategories;
  for (final t in txs) {
    final i = index[YearMonth.fromDate(t.date)];
    final flow = reportFlowOf(t);
    if (i == null || flow == null || isFutureUnplanned(t, today)) {
      continue;
    }
    final scope = flow == f.flow ? f : otherSide;
    if (!matchesReportScope(t, scope, tree)) {
      continue;
    }
    if (flow == ReportFlow.income) {
      income[i] += t.amountCents;
    } else {
      expense[i] += t.amountCents;
    }
  }
  return [
    for (var i = 0; i < months.length; i++)
      TrendPoint(
        month: months[i],
        incomeCents: income[i],
        expenseCents: expense[i],
      ),
  ];
}

/// Média móvel de [window] valores (arredondada). Os primeiros `window - 1` são null.
List<int?> movingAverage(List<int> values, {int window = 3}) {
  assert(window > 0, 'window deve ser > 0');
  final out = List<int?>.filled(values.length, null);
  var sum = 0;
  for (var i = 0; i < values.length; i++) {
    sum += values[i];
    if (i >= window) {
      sum -= values[i - window];
    }
    if (i >= window - 1) {
      out[i] = roundDiv(sum, window);
    }
  }
  return out;
}

/// Despesas de um mês separadas em fixo (recorrente + parcela) e variável.
class FixedVariableMonth {
  const FixedVariableMonth({
    required this.month,
    required this.recurringCents,
    required this.installmentCents,
    required this.variableCents,
  });

  final YearMonth month;
  final int recurringCents;
  final int installmentCents;
  final int variableCents;

  int get fixedCents => recurringCents + installmentCents;
  int get totalCents => fixedCents + variableCents;

  /// Fração fixa do total; null sem despesas no mês.
  double? get fixedRatio => totalCents == 0 ? null : fixedCents / totalCents;
}

/// Um item por mês de [months]. Só despesas (`reportFlowOf == expense`); ignora `f.flow`
/// (com receita no filtro, `f.categoryIds` também é ignorado).
/// `recurringId` → recorrente; senão `installmentGroupId` → parcela; senão variável.
List<FixedVariableMonth> fixedVariableByMonth(
  Iterable<Transaction> txs,
  ReportFilter f, {
  required List<YearMonth> months,
  required CategoryTree tree,
  required DateTime today,
}) {
  final index = _indexOf(months);
  final recurring = List<int>.filled(months.length, 0);
  final installment = List<int>.filled(months.length, 0);
  final variable = List<int>.filled(months.length, 0);
  final scope = f.flow == ReportFlow.income ? f.withoutCategories : f;
  for (final t in txs) {
    final i = index[YearMonth.fromDate(t.date)];
    if (i == null ||
        reportFlowOf(t) != ReportFlow.expense ||
        isFutureUnplanned(t, today) ||
        !matchesReportScope(t, scope, tree)) {
      continue;
    }
    if (t.recurringId != null) {
      recurring[i] += t.amountCents;
    } else if (t.isInstallment) {
      installment[i] += t.amountCents;
    } else {
      variable[i] += t.amountCents;
    }
  }
  return [
    for (var i = 0; i < months.length; i++)
      FixedVariableMonth(
        month: months[i],
        recurringCents: recurring[i],
        installmentCents: installment[i],
        variableCents: variable[i],
      ),
  ];
}
