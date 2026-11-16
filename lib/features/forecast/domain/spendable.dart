import 'dart:math' as math;

import '../../../core/models/year_month.dart';
import '../../../core/utils/date_utils.dart';
import '../../accounts/domain/account.dart';
import '../../recurring/domain/recurrence.dart';
import '../../recurring/domain/recurring_rule.dart';
import '../../transactions/domain/transaction.dart';
import 'forecast.dart';

/// "Posso gastar hoje" (SPEC §5.23). Dinheiro livre até [untilDate] = saldo elegível −
/// faturas − provisionados − reservas. Valores em centavos.
class SpendableToday {
  const SpendableToday({
    required this.today,
    required this.untilDate,
    required this.days,
    this.nextIncomeDate,
    this.nextIncomeDescription,
    required this.balanceCents,
    required this.invoicesCents,
    required this.plannedCents,
    required this.reservedCents,
    required this.invoiceEvents,
    required this.plannedEvents,
  });

  final DateTime today;
  final DateTime?
  nextIncomeDate; // próxima ocorrência de receita recorrente; null = sem no horizonte
  final String? nextIncomeDescription; // descrição da regra que deu a data
  final DateTime untilDate; // limite (inclusivo): nextIncomeDate ?? fim do mês
  final int days; // dias de gasto (sempre >= 1)
  final int balanceCents; // saldo atual das contas elegíveis
  final int invoicesCents; // >= 0
  final int plannedCents; // >= 0
  final int reservedCents; // >= 0, reserva efetiva das metas
  final List<ForecastEvent> invoiceEvents, plannedEvents; // em ordem de data

  int get freeCents =>
      balanceCents -
      invoicesCents -
      plannedCents -
      reservedCents; // pode ser <= 0
  int get perDayCents =>
      freeCents <= 0 ? 0 : freeCents ~/ days; // arredonda para baixo
  bool get overcommitted => freeCents <= 0;
}

/// Calcula o "posso gastar hoje" sobre a [forecast] (horizonte até [horizonEnd]).
/// Conta de investimento sai do saldo e das reservas, mas suas faturas e provisionados entram.
SpendableToday spendableToday({
  required Forecast forecast,
  required Iterable<RecurringRule> recurring,
  required Map<String, Account> accountsById,
  required Map<String, int> reservedByAccount,
  required DateTime horizonEnd,
}) {
  final today = dateOnly(forecast.today);
  final tomorrow = DateTime(today.year, today.month, today.day + 1);

  // Próxima receita: a de hoje não conta (já está no saldo, ou é conservador se não entrou).
  DateTime? nextIncome;
  String? nextDescription;
  for (final r in recurring) {
    final account = r.accountId == null ? null : accountsById[r.accountId];
    if (!r.active ||
        r.type != TransactionType.income ||
        r.cardId != null ||
        account == null ||
        account.archived) {
      continue;
    }
    final occurrences = occurrencesBetween(r, tomorrow, horizonEnd);
    if (occurrences.isEmpty) {
      continue;
    }
    // Empate: a 1ª regra na ordem de entrada vence (comparação estrita).
    if (nextIncome == null || occurrences.first.isBefore(nextIncome)) {
      nextIncome = occurrences.first;
      nextDescription = r.description;
    }
  }
  final untilDate = nextIncome ?? YearMonth.fromDate(today).lastDay;
  final days = _daysBetween(today, untilDate) + (nextIncome == null ? 1 : 0);

  // Conta elegível: existe, não arquivada e não é de investimento.
  bool eligible(String? id) {
    final account = id == null ? null : accountsById[id];
    return account != null &&
        !account.archived &&
        account.type != AccountType.investment;
  }

  var balance = 0;
  var reserved = 0;
  for (final entry in forecast.currentBalances.entries) {
    if (!eligible(entry.key)) {
      continue;
    }
    balance += entry.value;
    // Reserva acima do saldo positivo não desconta de novo (§5.22 regra 3).
    reserved += math.min(
      math.max(0, reservedByAccount[entry.key] ?? 0),
      math.max(0, entry.value),
    );
  }

  final invoiceEvents = <ForecastEvent>[];
  final plannedEvents = <ForecastEvent>[];
  for (final e in forecast.events) {
    if (e.date.isAfter(untilDate)) {
      continue;
    }
    if (e.kind == ForecastEventKind.invoice) {
      invoiceEvents.add(e);
    } else if (e.amountCents < 0 &&
        (e.kind == ForecastEventKind.expense ||
            e.kind == ForecastEventKind.boleto ||
            // Transferência que sai de conta elegível para uma que não é: saída real.
            (e.kind == ForecastEventKind.transfer &&
                eligible(e.accountId) &&
                !eligible(e.toAccountId)))) {
      plannedEvents.add(e);
    }
  }

  return SpendableToday(
    today: today,
    untilDate: untilDate,
    days: days,
    nextIncomeDate: nextIncome,
    nextIncomeDescription: nextDescription,
    balanceCents: balance,
    invoicesCents: _outflow(invoiceEvents),
    plannedCents: _outflow(plannedEvents),
    reservedCents: reserved,
    invoiceEvents: invoiceEvents,
    plannedEvents: plannedEvents,
  );
}

int _outflow(List<ForecastEvent> events) =>
    events.fold(0, (sum, e) => sum - e.amountCents);

int _daysBetween(DateTime from, DateTime to) => DateTime.utc(
  to.year,
  to.month,
  to.day,
).difference(DateTime.utc(from.year, from.month, from.day)).inDays;
