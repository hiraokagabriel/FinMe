import '../../../core/models/year_month.dart';
import '../../../core/utils/date_utils.dart';
import '../../transactions/domain/transaction.dart';
import 'invoice.dart';
import 'invoice_cycle.dart';
import 'payment_card.dart';

/// Cartão de crédito como opção de compra "hoje", com vencimento da fatura que a compra cairia.
class CardPurchaseOption {
  const CardPurchaseOption({
    required this.card,
    required this.dueDate,
    required this.daysUntilDue,
    required this.freeLimitCents,
  });

  final PaymentCard card;
  final DateTime dueDate;
  final int daysUntilDue;

  /// Pode ser <= 0. Limite 0 significa "não informado".
  final int freeLimitCents;

  bool get hasLimit => freeLimitCents > 0;
}

/// Crédito ativo ordenado: com limite livre primeiro, depois mais dias até o vencimento,
/// depois mais limite livre, depois nome. [usedLimitByCard] ausente → 0.
List<CardPurchaseOption> bestCardsToBuy({
  required Iterable<PaymentCard> cards,
  required Map<String, int> usedLimitByCard,
  required DateTime today,
}) {
  final day = dateOnly(today);
  final options = <CardPurchaseOption>[];
  for (final card in cards) {
    if (card.kind != CardKind.credit || card.archived) {
      continue;
    }
    final dueDate = purchaseDueDate(day, card);
    options.add(
      CardPurchaseOption(
        card: card,
        dueDate: dueDate,
        daysUntilDue: _daysBetween(day, dueDate),
        freeLimitCents: card.limitCents - (usedLimitByCard[card.id] ?? 0),
      ),
    );
  }
  options.sort((a, b) {
    if (a.hasLimit != b.hasLimit) {
      return a.hasLimit ? -1 : 1;
    }
    final byDays = b.daysUntilDue.compareTo(a.daysUntilDue);
    if (byDays != 0) {
      return byDays;
    }
    final byFree = b.freeLimitCents.compareTo(a.freeLimitCents);
    if (byFree != 0) {
      return byFree;
    }
    return a.card.name.compareTo(b.card.name);
  });
  return options;
}

/// Parcelas que vencem em [month], por cartão. `byCard` omite cartões com 0 centavos.
class InstallmentCommitment {
  const InstallmentCommitment({required this.month, required this.byCard});

  /// Mês de vencimento da fatura.
  final YearMonth month;

  /// cardId → centavos.
  final Map<String, int> byCard;

  int get totalCents => byCard.values.fold(0, (sum, cents) => sum + cents);
}

/// Exatamente [months] entradas a partir de [from], inclusive zeradas. Só itens com
/// `installmentGroupId` (despesa +, receita −); compras à vista e recorrências ficam de fora.
List<InstallmentCommitment> installmentCommitments({
  required Iterable<Invoice> invoices,
  required YearMonth from,
  int months = 12,
}) {
  final end = from.addMonths(months);
  final byMonth = <YearMonth, Map<String, int>>{};
  for (final invoice in invoices) {
    final due = invoice.dueMonth;
    if (due < from || due >= end) {
      continue;
    }
    final cards = byMonth.putIfAbsent(due, () => <String, int>{});
    for (final item in invoice.items) {
      if (item.installmentGroupId == null) {
        continue;
      }
      final signed = _installmentSign(item);
      if (signed == 0) {
        continue;
      }
      cards.update(
        invoice.card.id,
        (cents) => cents + signed,
        ifAbsent: () => signed,
      );
    }
  }
  final result = <InstallmentCommitment>[];
  for (var i = 0; i < months; i++) {
    final month = from.addMonths(i);
    final byCard = {...?byMonth[month]}..removeWhere((_, cents) => cents == 0);
    result.add(InstallmentCommitment(month: month, byCard: byCard));
  }
  return result;
}

/// Cartões que não têm conta de pagamento ativa. Mantém a ordem de entrada.
List<PaymentCard> cardsWithoutPaymentAccount(
  Iterable<PaymentCard> cards,
  Set<String> activeAccountIds,
) => [
  for (final card in cards)
    if (!card.archived &&
        (card.paymentAccountId == null ||
            !activeAccountIds.contains(card.paymentAccountId)))
      card,
];

int _daysBetween(DateTime from, DateTime to) => DateTime.utc(
  to.year,
  to.month,
  to.day,
).difference(DateTime.utc(from.year, from.month, from.day)).inDays;

int _installmentSign(Transaction item) => switch (item.type) {
  TransactionType.expense => item.amountCents,
  TransactionType.income => -item.amountCents,
  TransactionType.transfer || TransactionType.invoicePayment => 0,
};
