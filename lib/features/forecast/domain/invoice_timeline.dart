import '../../../core/utils/date_utils.dart';
import '../../cards/domain/invoice.dart';
import 'forecast.dart';

/// Fatura a vencer na previsão. `date` é o evento (max(vencimento, hoje)); o saldo
/// da conta é o previsto ao fim desse dia, já com todos os eventos do dia aplicados.
class InvoiceDue {
  const InvoiceDue({
    required this.invoice,
    required this.date,
    required this.amountCents,
    this.accountId,
    this.accountBalanceAfterCents,
  });

  final Invoice invoice;
  final DateTime date;
  final int amountCents;

  /// Conta de pagamento ativa; null = sem conta (ou arquivada).
  final String? accountId;
  final int? accountBalanceAfterCents;

  bool get overdue => invoice.dueDate.isBefore(date);
  bool get hasAccount => accountId != null;
  bool get uncovered =>
      accountBalanceAfterCents != null && accountBalanceAfterCents! < 0;
  bool get needsAttention => !hasAccount || uncovered;
}

/// Faturas da previsão que vencem em até [days] dias a partir de `forecast.today`.
/// Uma passada sobre os eventos (já ordenados); eventos cujo `sourceId` não é fatura de [invoices] são ignorados.
List<InvoiceDue> invoiceTimeline({
  required Forecast forecast,
  required Iterable<Invoice> invoices,
  int days = 60,
}) {
  final invoicesById = {for (final i in invoices) i.id: i};
  final today = forecast.today;
  final limit = DateTime(today.year, today.month, today.day + days);
  final balances = Map<String, int>.of(forecast.currentBalances);
  final events = forecast.events;
  final out = <InvoiceDue>[];
  var start = 0;
  while (start < events.length && !events[start].date.isAfter(limit)) {
    final day = events[start].date;
    var end = start;
    while (end < events.length && isSameDay(events[end].date, day)) {
      final id = events[end].accountId;
      if (id != null) {
        balances[id] = (balances[id] ?? 0) + events[end].amountCents;
      }
      end++;
    }
    for (var i = start; i < end; i++) {
      final e = events[i];
      final invoice = e.kind == ForecastEventKind.invoice
          ? invoicesById[e.sourceId]
          : null;
      if (invoice == null) {
        continue;
      }
      final id = e.accountId;
      out.add(
        InvoiceDue(
          invoice: invoice,
          date: day,
          amountCents: -e.amountCents,
          accountId: id,
          accountBalanceAfterCents: id == null ? null : balances[id],
        ),
      );
    }
    start = end;
  }
  return out;
}
