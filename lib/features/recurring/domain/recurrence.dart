import '../../../core/models/year_month.dart';
import '../../../core/utils/date_utils.dart';
import '../../transactions/domain/transaction.dart';
import 'recurring_rule.dart';

/// Datas de ocorrência de [r] entre [from] e [to] (inclusivos, por dia).
/// Regra inativa → []. Começa no 1º candidato ≥ max(from, startDate), não em startDate.
List<DateTime> occurrencesBetween(RecurringRule r, DateTime from, DateTime to) {
  final start = dateOnly(r.startDate);
  final lo = dateOnly(from);
  final hi = dateOnly(to);
  final end = r.endDate == null ? null : dateOnly(r.endDate!);
  if (!r.active || hi.isBefore(lo) || hi.isBefore(start)) {
    return const [];
  }
  final lowerBound = lo.isAfter(start) ? lo : start;
  return switch (r.frequency) {
    Frequency.weekly => _weekly(start, lowerBound, hi, end),
    Frequency.monthly => _monthly(start, lowerBound, hi, end),
    Frequency.yearly => _yearly(start, lowerBound, hi, end),
  };
}

List<DateTime> _weekly(
  DateTime start,
  DateTime lo,
  DateTime hi,
  DateTime? end,
) {
  final days = _dayNumber(lo) - _dayNumber(start);
  final out = <DateTime>[];
  for (var k = days <= 0 ? 0 : (days + 6) ~/ 7; ; k++) {
    final d = DateTime(start.year, start.month, start.day + 7 * k);
    if (d.isAfter(hi) || (end != null && d.isAfter(end))) {
      break;
    }
    out.add(d);
  }
  return out;
}

/// Dia do mês original de [start] em cada mês (sem deslizar 31→28→28).
List<DateTime> _monthly(
  DateTime start,
  DateTime lo,
  DateTime hi,
  DateTime? end,
) {
  final out = <DateTime>[];
  final last = YearMonth.fromDate(hi);
  for (var ym = YearMonth.fromDate(lo); ym <= last; ym = ym.next()) {
    final d = ym.dateAt(start.day);
    if (end != null && d.isAfter(end)) {
      break;
    }
    if (!d.isBefore(lo) && !d.isAfter(hi)) {
      out.add(d);
    }
  }
  return out;
}

/// Mês e dia de [start] em cada ano, dia limitado (29/02 → 28/02 em não-bissexto).
List<DateTime> _yearly(
  DateTime start,
  DateTime lo,
  DateTime hi,
  DateTime? end,
) {
  final out = <DateTime>[];
  for (var y = lo.year; y <= hi.year; y++) {
    final d = YearMonth(y, start.month).dateAt(start.day);
    if (end != null && d.isAfter(end)) {
      break;
    }
    if (!d.isBefore(lo) && !d.isAfter(hi)) {
      out.add(d);
    }
  }
  return out;
}

/// Número de dias desde a época, em UTC: diferença exata, sem efeito de horário de verão.
int _dayNumber(DateTime d) =>
    DateTime.utc(d.year, d.month, d.day).millisecondsSinceEpoch ~/
    Duration.millisecondsPerDay;

String occurrenceId(RecurringRule r, DateTime date) =>
    '${r.id}_${dateKey(date)}';

/// Transações geradas por [r] em [from]..[to], pulando ids em [existingIds].
/// Status (SPEC §5.4): cartão → paid. Conta com [forProjection] → planned.
/// Conta na materialização → paid só se o dia é antes de [to] e não é boleto
/// (boleto exige confirmação; ocorrência de [to] fica provisionada).
List<Transaction> occurrenceTransactions(
  RecurringRule r,
  DateTime from,
  DateTime to,
  Set<String> existingIds, {
  required bool forProjection,
}) {
  return [
    for (final d in occurrencesBetween(r, from, to))
      if (!existingIds.contains(occurrenceId(r, d)))
        Transaction(
          id: occurrenceId(r, d),
          type: r.type,
          amountCents: r.amountCents,
          date: d,
          description: r.description,
          categoryId: r.categoryId,
          accountId: r.accountId,
          cardId: r.cardId,
          status: _occurrenceStatus(r, d, to, forProjection: forProjection),
          isBoleto: r.isBoleto,
          recurringId: r.id,
          tags: r.tags,
        ),
  ];
}

TransactionStatus _occurrenceStatus(
  RecurringRule r,
  DateTime d,
  DateTime to, {
  required bool forProjection,
}) {
  if (r.cardId != null) {
    return TransactionStatus.paid;
  }
  if (forProjection) {
    return TransactionStatus.planned;
  }
  final settled = dateOnly(d).isBefore(dateOnly(to)) && !r.isBoleto;
  return settled ? TransactionStatus.paid : TransactionStatus.planned;
}
