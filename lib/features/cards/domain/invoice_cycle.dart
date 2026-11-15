import '../../../core/models/year_month.dart';
import '../../../core/utils/date_utils.dart';
import 'payment_card.dart';

/// Fechamento mantido na linha de fechamentos (SPEC §5.1): data, mês e dia de vencimento.
typedef _Closing = ({DateTime closing, YearMonth dueMonth, int dueDay});

/// Mês de fechamento que recebe uma compra em [purchase]. Compra no dia do
/// fechamento (ou depois) vai para o fechamento seguinte.
YearMonth closingMonthFor(DateTime purchase, int closingDay) {
  final month = YearMonth.fromDate(purchase);
  final closing = month.dateAt(closingDay);
  return purchase.day < closing.day ? month : month.next();
}

/// Mês de vencimento da fatura que recebe a compra em [purchase]. Sem histórico de
/// ciclo, usa o ciclo vigente; com histórico, o primeiro fechamento mantido após a compra.
YearMonth invoiceDueMonth(DateTime purchase, PaymentCard card) {
  if (card.cycleHistory.isNotEmpty) {
    return _closingAfter(purchase, card, 0).dueMonth;
  }
  final cycle = card.cycleOn(purchase);
  final closing = closingMonthFor(purchase, cycle.closingDay);
  return cycle.dueDay > cycle.closingDay ? closing : closing.next();
}

/// Mês de vencimento da parcela [index] (1-based) de um grupo cuja 1ª parcela tem data [firstDate].
YearMonth installmentDueMonth(DateTime firstDate, int index, PaymentCard card) {
  // shortcut: índice < 1 (dado inválido) segue a fórmula antiga, sem linha de fechamentos.
  if (card.cycleHistory.isEmpty || index < 1) {
    return invoiceDueMonth(firstDate, card).addMonths(index - 1);
  }
  return _closingAfter(firstDate, card, index - 1).dueMonth;
}

/// Data de fechamento da fatura que vence em [dueMonth]. [cycleDate] escolhe o ciclo
/// vigente quando [dueMonth] não tem fechamento mantido (padrão: início de [dueMonth]).
DateTime invoiceClosingDate(
  YearMonth dueMonth,
  PaymentCard card, {
  DateTime? cycleDate,
}) {
  final kept = _keptFor(dueMonth, card);
  if (kept != null) {
    return kept.closing;
  }
  final cycle = card.cycleOn(cycleDate ?? dueMonth.firstDay);
  return (cycle.dueDay > cycle.closingDay ? dueMonth : dueMonth.prev()).dateAt(
    cycle.closingDay,
  );
}

/// Data de vencimento da fatura que vence em [dueMonth]. [cycleDate] escolhe o ciclo
/// vigente quando [dueMonth] não tem fechamento mantido (padrão: início de [dueMonth]).
DateTime invoiceDueDate(
  YearMonth dueMonth,
  PaymentCard card, {
  DateTime? cycleDate,
}) {
  final kept = _keptFor(dueMonth, card);
  if (kept != null) {
    return dueMonth.dateAt(kept.dueDay);
  }
  return dueMonth.dateAt(card.cycleOn(cycleDate ?? dueMonth.firstDay).dueDay);
}

/// Vencimento da fatura que recebe uma compra em [purchase], com o ciclo vigente nessa data.
DateTime purchaseDueDate(DateTime purchase, PaymentCard card) => invoiceDueDate(
  invoiceDueMonth(purchase, card),
  card,
  cycleDate: dateOnly(purchase),
);

/// [k]-ésimo fechamento mantido (0 = primeiro) com data posterior a [date]. A janela de
/// [_closings] cresce se faltar fechamento (dois descartes seguidos na fronteira).
_Closing _closingAfter(DateTime date, PaymentCard card, int k) {
  final day = dateOnly(date);
  final month = YearMonth.fromDate(day);
  final from = _windowStart(month, card);
  var to = month.addMonths(k + 2);
  while (true) {
    final after = [
      for (final c in _closings(card, from, to))
        if (day.isBefore(c.closing)) c,
    ];
    if (after.length > k) {
      return after[k];
    }
    to = to.addMonths(12);
  }
}

/// Fechamento mantido cujo vencimento é [dueMonth], ou null se o mês não tem fechamento.
_Closing? _keptFor(YearMonth dueMonth, PaymentCard card) {
  if (card.cycleHistory.isEmpty) {
    return null;
  }
  for (final c in _closings(card, _windowStart(dueMonth, card), dueMonth)) {
    if (c.dueMonth == dueMonth) {
      return c;
    }
  }
  return null;
}

/// Início da janela de [_closings]: antes do mês de [month] e da 1ª fronteira de ciclo.
/// Assim a janela contém todas as fronteiras relevantes e o descarte não muda.
YearMonth _windowStart(YearMonth month, PaymentCard card) {
  final firstBoundary = YearMonth.fromDate(card.cycleHistory.first.until);
  return (month < firstBoundary ? month : firstBoundary).prev();
}

/// Linha de fechamentos mantidos com mês entre [from] e [to] (SPEC §5.1, regras 1–3), em ordem de data.
/// `cycleHistory[i]` vale até `until` (exclusivo); o ciclo atual vale a partir do último `until`.
/// Descarta fechamento cujo vencimento não passa do último mantido: cada mês de vencimento tem um só.
List<_Closing> _closings(PaymentCard card, YearMonth from, YearMonth to) {
  final segments =
      <({DateTime? since, DateTime? until, int closingDay, int dueDay})>[];
  DateTime? since;
  for (final cycle in card.cycleHistory) {
    segments.add((
      since: since,
      until: cycle.until,
      closingDay: cycle.closingDay,
      dueDay: cycle.dueDay,
    ));
    since = cycle.until;
  }
  segments.add((
    since: since,
    until: null,
    closingDay: card.closingDay,
    dueDay: card.dueDay,
  ));

  final kept = <_Closing>[];
  for (final s in segments) {
    for (var m = from; m <= to; m = m.next()) {
      final closing = m.dateAt(s.closingDay);
      if (!_inSegment(closing, s.since, s.until)) {
        continue;
      }
      final dueMonth = s.dueDay > s.closingDay ? m : m.next();
      if (kept.isNotEmpty && dueMonth <= kept.last.dueMonth) {
        continue;
      }
      kept.add((closing: closing, dueMonth: dueMonth, dueDay: s.dueDay));
    }
  }
  return kept;
}

bool _inSegment(DateTime closing, DateTime? since, DateTime? until) =>
    (since == null || !closing.isBefore(since)) &&
    (until == null || closing.isBefore(until));
