import '../../../core/utils/date_utils.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/utils/text_normalize.dart';
import '../../forecast/domain/forecast.dart';
import '../../transactions/domain/transaction.dart';
import 'debt.dart';

/// Erro de pagamento ou `null`. Ordem fixa: valor, restante, futuro, antes da dívida.
String? debtPaymentError({
  required Debt debt,
  required int amountCents,
  required DateTime date,
  required DateTime today,
}) {
  if (amountCents <= 0) {
    return 'Informe um valor maior que zero';
  }
  if (amountCents > debt.remainingCents) {
    return 'Restante: ${formatMoney(debt.remainingCents)}';
  }
  final day = dateOnly(date);
  if (day.isAfter(dateOnly(today))) {
    return 'A data não pode ser no futuro';
  }
  if (day.isBefore(debt.date)) {
    return 'Data antes do registro da dívida';
  }
  return null;
}

/// Descrição da transação de quitação: "Recebido de Ana" / "Pago a Bruno", com " · descrição" se houver.
String debtTransactionDescription(Debt debt) {
  final base = debt.direction == DebtDirection.owedToMe
      ? 'Recebido de ${debt.person}'
      : 'Pago a ${debt.person}';
  return _withDescription(base, debt.description);
}

/// Registra um pagamento e devolve a transação paga que ele gera. Não valida: a UI chama [debtPaymentError] antes.
({Debt debt, Transaction transaction}) settleDebt(
  Debt debt, {
  required String paymentId,
  required String transactionId,
  required int amountCents,
  required DateTime date,
  required String accountId,
  String? categoryId,
}) {
  final transaction = Transaction(
    id: transactionId,
    type: debt.direction == DebtDirection.owedToMe
        ? TransactionType.income
        : TransactionType.expense,
    amountCents: amountCents,
    date: date,
    description: debtTransactionDescription(debt),
    accountId: accountId,
    categoryId: categoryId,
    status: TransactionStatus.paid,
  );
  final updated = debt.withPayment(
    DebtPayment(
      id: paymentId,
      date: date,
      amountCents: amountCents,
      transactionId: transactionId,
    ),
  );
  return (debt: updated, transaction: transaction);
}

/// Remove o pagamento e devolve o id da transação ligada. Id inexistente → dívida igual e `null`.
({Debt debt, String? transactionId}) undoDebtPayment(
  Debt debt,
  String paymentId,
) {
  for (final payment in debt.payments) {
    if (payment.id == paymentId) {
      return (
        debt: debt.withoutPayment(paymentId),
        transactionId: payment.transactionId,
      );
    }
  }
  return (debt: debt, transactionId: null);
}

bool isDebtOverdue(Debt debt, DateTime today) {
  final due = debt.dueDate;
  return due != null && dateOnly(today).isAfter(due) && !debt.settled;
}

/// transactionId dos pagamentos cuja transação existe agora (`exists`).
Set<String> linkedTransactionIds(
  Iterable<Debt> debts,
  bool Function(String id) exists,
) {
  final ids = <String>{};
  for (final debt in debts) {
    for (final payment in debt.payments) {
      final id = payment.transactionId;
      if (id != null && exists(id)) {
        ids.add(id);
      }
    }
  }
  return ids;
}

/// Ajusta pagamentos ligados a transações de [knownIds]: transação ausente (ou com valor ≤ 0) remove o pagamento;
/// valor ou data diferentes trocam o pagamento (mesmo id). Devolve só as dívidas que mudaram.
/// Ids fora de [knownIds] (órfãos de backup) não são tocados.
List<Debt> syncDebtsWithTransactions(
  Iterable<Debt> debts, {
  required Set<String> knownIds,
  required Transaction? Function(String id) lookup,
}) {
  final changed = <Debt>[];
  for (final debt in debts) {
    var current = debt;
    for (final payment in debt.payments) {
      final id = payment.transactionId;
      if (id == null || !knownIds.contains(id)) {
        continue;
      }
      final transaction = lookup(id);
      if (transaction == null || transaction.amountCents <= 0) {
        // shortcut: transação com valor ≤ 0 some do pagamento porque DebtPayment exige valor > 0.
        current = current.withoutPayment(payment.id);
      } else if (transaction.amountCents != payment.amountCents ||
          transaction.date != payment.date) {
        current = current.copyWith(
          payments: [
            for (final p in current.payments)
              if (p.id == payment.id)
                DebtPayment(
                  id: p.id,
                  date: transaction.date,
                  amountCents: transaction.amountCents,
                  transactionId: id,
                )
              else
                p,
          ],
        );
      }
    }
    if (current != debt) {
      changed.add(current);
    }
  }
  return changed;
}

/// Soma do restante em [date] por direção.
({int receivableCents, int payableCents}) debtTotalsAt(
  Iterable<Debt> debts,
  DateTime date,
) {
  var receivable = 0;
  var payable = 0;
  for (final debt in debts) {
    final rest = debt.remainingAt(date);
    if (debt.direction == DebtDirection.owedToMe) {
      receivable += rest;
    } else {
      payable += rest;
    }
  }
  return (receivableCents: receivable, payableCents: payable);
}

/// Só "devo" com vencimento e restante > 0. "Me devem" nunca entra na previsão.
List<ForecastEvent> debtForecastEvents(Iterable<Debt> debts) {
  final events = <ForecastEvent>[];
  for (final debt in debts) {
    final due = debt.dueDate;
    if (debt.direction != DebtDirection.iOwe ||
        due == null ||
        debt.remainingCents <= 0) {
      continue;
    }
    events.add(
      ForecastEvent(
        date: due,
        amountCents: -debt.remainingCents,
        description: _withDescription(
          'Devo a ${debt.person}',
          debt.description,
        ),
        kind: ForecastEventKind.expense,
        sourceId: debt.id,
      ),
    );
  }
  return events;
}

/// Resumo de uma pessoa: [netCents] > 0 significa que ela me deve no líquido.
class PersonDebtSummary {
  const PersonDebtSummary({
    required this.person,
    required this.receivableCents,
    required this.payableCents,
    required this.openCount,
  });

  final String person;
  final int receivableCents;
  final int payableCents;
  final int openCount;

  int get netCents => receivableCents - payableCents;
}

/// Só dívidas com restante > 0, agrupadas por `foldText(person)`. Ordem: |líquido| desc, nome asc.
List<PersonDebtSummary> debtsByPerson(Iterable<Debt> debts) {
  final open = debts.where((d) => d.remainingCents > 0);
  final summaries = [
    for (final group in _groupByFold(open).values) _summarize(group),
  ];
  summaries.sort((a, b) {
    final byNet = b.netCents.abs().compareTo(a.netCents.abs());
    return byNet != 0
        ? byNet
        : foldText(a.person).compareTo(foldText(b.person));
  });
  return summaries;
}

/// Sugestões do campo Pessoa: inclui quitadas. Grafia da dívida mais recente; ordem: data desc, nome asc.
List<String> debtPeople(Iterable<Debt> debts) {
  final groups = _groupByFold(debts).values.toList();
  groups.sort((a, b) {
    final byDate = _latest(b).date.compareTo(_latest(a).date);
    return byDate != 0
        ? byDate
        : foldText(_latest(a).person).compareTo(foldText(_latest(b).person));
  });
  return [for (final group in groups) _latest(group).person];
}

PersonDebtSummary _summarize(List<Debt> group) {
  var receivable = 0;
  var payable = 0;
  for (final debt in group) {
    if (debt.direction == DebtDirection.owedToMe) {
      receivable += debt.remainingCents;
    } else {
      payable += debt.remainingCents;
    }
  }
  return PersonDebtSummary(
    person: _latest(group).person,
    receivableCents: receivable,
    payableCents: payable,
    openCount: group.length,
  );
}

Map<String, List<Debt>> _groupByFold(Iterable<Debt> debts) {
  final groups = <String, List<Debt>>{};
  for (final debt in debts) {
    groups.putIfAbsent(foldText(debt.person), () => []).add(debt);
  }
  return groups;
}

/// Dívida mais recente do grupo: maior (date, id).
Debt _latest(List<Debt> group) =>
    group.reduce((a, b) => _compareRecency(a, b) >= 0 ? a : b);

int _compareRecency(Debt a, Debt b) {
  final byDate = a.date.compareTo(b.date);
  return byDate != 0 ? byDate : a.id.compareTo(b.id);
}

String _withDescription(String base, String? description) =>
    description == null ? base : '$base · $description';
