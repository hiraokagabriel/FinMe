import '../../../core/models/year_month.dart';
import 'payment_card.dart';

/// Mês de fechamento que recebe uma compra em [purchase]. Compra no dia do
/// fechamento (ou depois) vai para o fechamento seguinte.
YearMonth closingMonthFor(DateTime purchase, int closingDay) {
  final month = YearMonth.fromDate(purchase);
  final closing = month.dateAt(closingDay);
  return purchase.day < closing.day ? month : month.next();
}

/// Mês de vencimento da fatura que recebe a compra em [purchase].
YearMonth invoiceDueMonth(DateTime purchase, PaymentCard card) {
  final closing = closingMonthFor(purchase, card.closingDay);
  return card.dueDay > card.closingDay ? closing : closing.next();
}

/// Data de fechamento da fatura que vence em [dueMonth].
DateTime invoiceClosingDate(YearMonth dueMonth, PaymentCard card) =>
    (card.dueDay > card.closingDay ? dueMonth : dueMonth.prev()).dateAt(
      card.closingDay,
    );

/// Data de vencimento da fatura que vence em [dueMonth].
DateTime invoiceDueDate(YearMonth dueMonth, PaymentCard card) =>
    dueMonth.dateAt(card.dueDay);
