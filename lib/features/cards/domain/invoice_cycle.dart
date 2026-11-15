import '../../../core/models/year_month.dart';
import '../../../core/utils/date_utils.dart';
import 'payment_card.dart';

/// Mês de fechamento que recebe uma compra em [purchase]. Compra no dia do
/// fechamento (ou depois) vai para o fechamento seguinte.
YearMonth closingMonthFor(DateTime purchase, int closingDay) {
  final month = YearMonth.fromDate(purchase);
  final closing = month.dateAt(closingDay);
  return purchase.day < closing.day ? month : month.next();
}

/// Mês de vencimento da fatura que recebe a compra em [purchase], pelo ciclo vigente nessa data.
YearMonth invoiceDueMonth(DateTime purchase, PaymentCard card) {
  final cycle = card.cycleOn(purchase);
  final closing = closingMonthFor(purchase, cycle.closingDay);
  return cycle.dueDay > cycle.closingDay ? closing : closing.next();
}

/// Data de fechamento da fatura que vence em [dueMonth]. [cycleDate] escolhe o ciclo
/// vigente (padrão: início de [dueMonth]).
DateTime invoiceClosingDate(
  YearMonth dueMonth,
  PaymentCard card, {
  DateTime? cycleDate,
}) {
  final cycle = card.cycleOn(cycleDate ?? dueMonth.firstDay);
  return (cycle.dueDay > cycle.closingDay ? dueMonth : dueMonth.prev()).dateAt(
    cycle.closingDay,
  );
}

/// Data de vencimento da fatura que vence em [dueMonth]. [cycleDate] escolhe o ciclo
/// vigente (padrão: início de [dueMonth]).
DateTime invoiceDueDate(
  YearMonth dueMonth,
  PaymentCard card, {
  DateTime? cycleDate,
}) => dueMonth.dateAt(card.cycleOn(cycleDate ?? dueMonth.firstDay).dueDay);

/// Vencimento da fatura que recebe uma compra em [purchase], com o ciclo vigente nessa data.
DateTime purchaseDueDate(DateTime purchase, PaymentCard card) => invoiceDueDate(
  invoiceDueMonth(purchase, card),
  card,
  cycleDate: dateOnly(purchase),
);
