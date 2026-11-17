import '../../cards/domain/payment_card.dart';
import '../../transactions/domain/transaction.dart';
import 'account.dart';

/// Saldo de cada conta recebida (inclui arquivadas; quem chama filtra).
/// Ignora transações provisionadas. Conta desconhecida é ignorada.
Map<String, int> accountBalances({
  required Iterable<Account> accounts,
  required Iterable<PaymentCard> cards,
  required Iterable<Transaction> transactions,
}) {
  final cardsById = {for (final c in cards) c.id: c};
  final balances = {for (final a in accounts) a.id: a.initialBalanceCents};
  for (final t in transactions) {
    if (t.isPlanned) {
      continue;
    }
    final affected = {_sourceAccountId(t, cardsById), t.toAccountId};
    for (final id in affected.whereType<String>()) {
      final current = balances[id];
      if (current != null) {
        balances[id] = current + signedEffectOn(id, t, cardsById);
      }
    }
  }
  return balances;
}

/// Efeito com sinal (+ entra, - sai) de [t] sobre [accountId]; 0 se não afeta.
/// Não olha `status`: quem decide se é planned é o chamador.
int signedEffectOn(
  String accountId,
  Transaction t,
  Map<String, PaymentCard> cardsById,
) {
  var effect = 0;
  if (accountId == _sourceAccountId(t, cardsById)) {
    effect += t.type == TransactionType.income ? t.amountCents : -t.amountCents;
  }
  if (t.type == TransactionType.transfer && accountId == t.toAccountId) {
    effect += t.amountCents;
  }
  return effect;
}

/// Conta que é debitada por [t]. Crédito não debita conta (null).
/// `cardId` só conta para despesa/receita: em invoicePayment é o cartão pago.
String? _sourceAccountId(Transaction t, Map<String, PaymentCard> cardsById) {
  final isCardMovement =
      t.type == TransactionType.expense || t.type == TransactionType.income;
  if (!isCardMovement || t.cardId == null) {
    return t.accountId;
  }
  final card = cardsById[t.cardId];
  return card?.kind == CardKind.debit ? card?.paymentAccountId : null;
}
