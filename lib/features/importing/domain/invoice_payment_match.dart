// Casamento de pagamento de fatura com faturas em aberto (SPEC §9.5). Dart puro.

import '../../../core/models/year_month.dart';
import '../../cards/domain/invoice.dart';
import '../../cards/domain/payment_card.dart';

/// Fatura em aberto que um débito na conta pode quitar.
class InvoiceCandidate {
  const InvoiceCandidate({
    required this.cardId,
    required this.dueMonth,
    required this.dueDate,
    required this.remainingCents,
  });

  final String cardId;
  final YearMonth dueMonth;
  final DateTime dueDate;
  final int remainingCents;

  /// Mesma chave que `pay_invoice_dialog` grava em `Transaction.invoiceKey`.
  String get invoiceKey => dueMonth.key;

  @override
  bool operator ==(Object other) =>
      other is InvoiceCandidate &&
      other.cardId == cardId &&
      other.dueMonth == dueMonth &&
      other.dueDate == dueDate &&
      other.remainingCents == remainingCents;

  @override
  int get hashCode => Object.hash(cardId, dueMonth, dueDate, remainingCents);
}

/// Janela da sugestão automática: pagamento até 10 dias antes ou depois do vencimento.
const int _suggestWindowDays = 10;

/// Dias de calendário entre as datas (ignora horário e horário de verão).
int _dayGap(DateTime a, DateTime b) => DateTime.utc(
  a.year,
  a.month,
  a.day,
).difference(DateTime.utc(b.year, b.month, b.day)).inDays.abs();

/// Ordem de desempate: vencimento asc, depois cartão asc.
int _byDueThenCard(InvoiceCandidate a, InvoiceCandidate b) {
  final byDue = a.dueDate.compareTo(b.dueDate);
  return byDue != 0 ? byDue : a.cardId.compareTo(b.cardId);
}

/// Negativo se [a] está mais perto de [date] que [b] (empate: vencimento asc, cartão asc).
int _rank(InvoiceCandidate a, InvoiceCandidate b, DateTime date) {
  final byGap = _dayGap(a.dueDate, date).compareTo(_dayGap(b.dueDate, date));
  return byGap != 0 ? byGap : _byDueThenCard(a, b);
}

/// Faturas em aberto de cartões de crédito não arquivados que [accountId] paga.
List<InvoiceCandidate> invoiceCandidatesFor({
  required String accountId,
  required Iterable<PaymentCard> cards,
  required List<Invoice> Function(String cardId) invoicesFor,
}) {
  final out = <InvoiceCandidate>[
    for (final card in cards)
      if (card.kind == CardKind.credit &&
          !card.archived &&
          card.paymentAccountId == accountId)
        for (final invoice in invoicesFor(card.id))
          if (invoice.remainingCents > 0)
            InvoiceCandidate(
              cardId: card.id,
              dueMonth: invoice.dueMonth,
              dueDate: invoice.dueDate,
              remainingCents: invoice.remainingCents,
            ),
  ];
  out.sort(_byDueThenCard);
  return out;
}

/// Sugere a fatura cujo saldo é exatamente [amountCents] e cujo vencimento está a até
/// 10 dias de [date]. Entre várias, a mais próxima. Nenhuma → null.
InvoiceCandidate? suggestInvoicePayment({
  required int amountCents,
  required DateTime date,
  required List<InvoiceCandidate> candidates,
}) {
  InvoiceCandidate? best;
  for (final c in candidates) {
    if (c.remainingCents != amountCents ||
        _dayGap(c.dueDate, date) > _suggestWindowDays) {
      continue;
    }
    if (best == null || _rank(c, best, date) < 0) {
      best = c;
    }
  }
  return best;
}

/// Opções do menu manual: uma fatura por cartão (a de vencimento mais próximo de [date]),
/// ordenadas por cartão. Sem limite de dias.
List<InvoiceCandidate> invoiceChoicesFor(
  DateTime date,
  List<InvoiceCandidate> candidates,
) {
  final nearest = <String, InvoiceCandidate>{};
  for (final c in candidates) {
    final current = nearest[c.cardId];
    if (current == null || _rank(c, current, date) < 0) {
      nearest[c.cardId] = c;
    }
  }
  return nearest.values.toList()..sort((a, b) => a.cardId.compareTo(b.cardId));
}
