import '../../../core/models/year_month.dart';
import '../../../core/utils/date_utils.dart';
import '../../accounts/domain/account.dart';
import '../../accounts/domain/monthly_history.dart';
import '../../cards/domain/payment_card.dart';
import '../../debts/domain/debt.dart';
import '../../debts/domain/debt_math.dart';
import '../../transactions/domain/transaction.dart';
import 'asset.dart';

/// Foto do patrimônio líquido no fim de um mês (SPEC §5.26). No mês atual, [date] é hoje.
class NetWorthPoint {
  const NetWorthPoint({
    required this.month,
    required this.date,
    required this.accountsCents,
    required this.assetsCents,
    required this.receivableCents,
    required this.payableCents,
    required this.cardDebtCents,
  });

  final YearMonth month;
  final DateTime date;

  /// Saldo das contas não arquivadas, todos os tipos (investimento inclusive).
  final int accountsCents;

  /// Ativos manuais (§5.24).
  final int assetsCents;

  /// "Me devem" em aberto.
  final int receivableCents;

  /// "Devo" em aberto (>= 0).
  final int payableCents;

  /// Saldo devedor já contratado nos cartões de crédito (>= 0).
  final int cardDebtCents;

  int get liabilitiesCents => payableCents + cardDebtCents;

  int get netCents =>
      accountsCents + assetsCents + receivableCents - liabilitiesCents;
}

/// Data da compra de uma parcela: a parcela i é gravada i−1 meses depois da compra (§5.3).
DateTime cardPurchaseDate(Transaction t) {
  final index = t.installmentIndex;
  if (index != null && index > 1) {
    return addMonthsClamped(t.date, -(index - 1));
  }
  return dateOnly(t.date);
}

/// Saldo devedor já contratado dos cartões de crédito em [date] (SPEC §5.26). Por cartão:
/// max(0, compras − estornos − pagamentos). Parcelas futuras de compras feitas entram;
/// débito fica de fora (já afeta a conta). Pagamento de fatura provisionado ainda não abate.
/// [allPayments] ignora a data dos pagamentos.
int cardDebtAt({
  required Iterable<PaymentCard> cards,
  required Iterable<Transaction> transactions,
  required DateTime date,
  bool allPayments = false,
}) {
  final day = dateOnly(date);
  final creditIds = {
    for (final c in cards)
      if (c.kind == CardKind.credit) c.id,
  };
  final owed = <String, int>{};
  for (final t in transactions) {
    final cardId = t.cardId;
    if (cardId == null || !creditIds.contains(cardId)) {
      continue;
    }
    var delta = 0;
    if (t.type == TransactionType.expense || t.type == TransactionType.income) {
      if (!cardPurchaseDate(t).isAfter(day)) {
        delta = t.type == TransactionType.expense
            ? t.amountCents
            : -t.amountCents;
      }
    } else if (t.type == TransactionType.invoicePayment && !t.isPlanned) {
      if (allPayments || !dateOnly(t.date).isAfter(day)) {
        delta = -t.amountCents;
      }
    }
    owed[cardId] = (owed[cardId] ?? 0) + delta;
  }
  var total = 0;
  for (final cents in owed.values) {
    total += cents > 0 ? cents : 0;
  }
  return total;
}

/// Patrimônio líquido dos últimos [months] meses até o de [today], em ordem cronológica.
/// Meses passados fecham no último dia; o último ponto usa hoje e pagamentos sem corte de data.
List<NetWorthPoint> netWorthHistory({
  required Iterable<Account> accounts,
  required Iterable<PaymentCard> cards,
  required Iterable<Transaction> transactions,
  required Iterable<Asset> assets,
  required Iterable<Debt> debts,
  required DateTime today,
  int months = 24,
}) {
  final cardList = cards.toList();
  final txList = transactions.toList();
  final assetList = assets.toList();
  final debtList = debts.toList();
  final todayOnly = dateOnly(today);
  final hist = monthlyHistory(
    accounts: accounts,
    cards: cardList,
    transactions: txList,
    today: todayOnly,
    months: months,
  );
  final points = <NetWorthPoint>[];
  for (var i = 0; i < hist.length; i++) {
    final isLast = i == hist.length - 1;
    final month = hist[i];
    final date = isLast ? todayOnly : month.month.lastDay;
    final totals = debtTotalsAt(debtList, date);
    points.add(
      NetWorthPoint(
        month: month.month,
        date: date,
        accountsCents: month.endBalanceCents,
        assetsCents: assetsValueAt(assetList, date),
        receivableCents: totals.receivableCents,
        payableCents: totals.payableCents,
        cardDebtCents: cardDebtAt(
          cards: cardList,
          transactions: txList,
          date: date,
          allPayments: isLast,
        ),
      ),
    );
  }
  return List.unmodifiable(points);
}
