import 'dart:math' as math;

import '../../../core/models/year_month.dart';
import '../../../core/utils/date_utils.dart';
import '../../accounts/domain/account.dart';
import '../../accounts/domain/balances.dart';
import '../../cards/domain/invoice.dart';
import '../../cards/domain/payment_card.dart';
import '../../recurring/domain/recurrence.dart';
import '../../recurring/domain/recurring_rule.dart';
import '../../transactions/domain/transaction.dart';

enum ForecastEventKind { income, expense, boleto, invoice, transfer }

/// Movimento futuro. `amountCents` tem sinal do ponto de vista de [accountId];
/// `accountId` null = só consolidado (fatura de cartão sem conta ativa).
/// Transfer gera um evento por conta; [toAccountId] é o destino da transferência.
class ForecastEvent {
  const ForecastEvent({
    required this.date,
    required this.amountCents,
    required this.description,
    required this.kind,
    required this.sourceId,
    this.accountId,
    this.toAccountId,
    this.isProjected = false,
  });

  final DateTime date;
  final int amountCents;
  final String description;
  final ForecastEventKind kind;
  final String sourceId;
  final String? accountId;
  final String? toAccountId;

  /// true = veio de recorrência ainda não materializada.
  final bool isProjected;
}

class ForecastMonth {
  const ForecastMonth({
    required this.month,
    required this.incomeCents,
    required this.expenseCents,
    required this.invoiceCents,
    required this.endBalanceCents,
  });

  final YearMonth month;
  final int incomeCents;
  final int expenseCents;
  final int invoiceCents;
  final int endBalanceCents;
}

class DailyBalance {
  const DailyBalance({required this.date, required this.balanceCents});

  final DateTime date;
  final int balanceCents;
}

class Forecast {
  const Forecast({
    required this.today,
    required this.currentBalances,
    required this.currentTotalCents,
    required this.events,
    required this.months,
    required this.daily,
    required this.firstNegativeDate,
    required this.accountNegativeDates,
  });

  final DateTime today;
  final Map<String, int> currentBalances;
  final int currentTotalCents;
  final List<ForecastEvent> events;
  final List<ForecastMonth> months;
  final List<DailyBalance> daily;
  final DateTime? firstNegativeDate;
  final Map<String, DateTime> accountNegativeDates;

  int get lowestBalanceCents =>
      daily.fold(currentTotalCents, (low, d) => math.min(low, d.balanceCents));
}

class ForecastService {
  /// Previsão de [months] meses a partir de [today] (mês atual incluso). O horizonte
  /// vai até o último dia desses meses ou até `today + minDays`, o que for mais tarde;
  /// `months` continua com exatamente [months] entradas.
  static Forecast compute({
    required List<Account> accounts,
    required List<PaymentCard> cards,
    required List<Transaction> transactions,
    required List<RecurringRule> recurring,
    required DateTime today,
    int months = 6,
    int minDays = 0,
  }) {
    assert(months >= 1, 'months deve ser >= 1');
    assert(minDays >= 0, 'minDays deve ser >= 0');
    final day = dateOnly(today);
    final monthsEnd = YearMonth.fromDate(day).addMonths(months - 1).lastDay;
    final minEnd = DateTime(day.year, day.month, day.day + minDays);
    final end = monthsEnd.isAfter(minEnd) ? monthsEnd : minEnd;
    final activeAccounts = accounts.where((a) => !a.archived).toList();
    final activeIds = {for (final a in activeAccounts) a.id};
    final currentBalances = accountBalances(
      accounts: activeAccounts,
      cards: cards,
      transactions: transactions,
    );
    final currentTotal = currentBalances.values.fold(0, (sum, v) => sum + v);
    final cardsById = {for (final c in cards) c.id: c};
    final existingIds = {for (final t in transactions) t.id};

    final events = <ForecastEvent>[];
    final txByCard = <String, List<Transaction>>{};
    final projectedByCard = <String, List<Transaction>>{};

    // Eventos de uma transação por conta: signedEffectOn dá 0 para contas não afetadas
    // (inclui compra de crédito, que compõe a fatura em vez de gerar evento).
    void addEvents(Transaction t, {required bool projected}) {
      if (t.type == TransactionType.invoicePayment) {
        return;
      }
      final d = dateOnly(t.date);
      final date = d.isBefore(day) ? day : d;
      final accountIds = {
        t.accountId,
        t.toAccountId,
        cardsById[t.cardId]?.paymentAccountId,
      };
      for (final id in accountIds) {
        if (id == null || !activeIds.contains(id)) {
          continue;
        }
        final effect = signedEffectOn(id, t, cardsById);
        if (effect == 0) {
          continue;
        }
        events.add(
          ForecastEvent(
            date: date,
            amountCents: effect,
            description: t.description,
            kind: _kindOf(t),
            sourceId: t.id,
            accountId: id,
            toAccountId: t.toAccountId,
            isProjected: projected,
          ),
        );
      }
    }

    for (final t in transactions) {
      final cardId = t.cardId;
      if (cardId != null) {
        txByCard.putIfAbsent(cardId, () => []).add(t);
      }
      if (t.isPlanned && !dateOnly(t.date).isAfter(end)) {
        addEvents(t, projected: false);
      }
    }

    for (final r in recurring) {
      final occurrences = occurrenceTransactions(
        r,
        day,
        end,
        existingIds,
        forProjection: true,
      );
      for (final t in occurrences) {
        final cardId = t.cardId;
        if (cardId != null && cardsById[cardId]?.kind == CardKind.credit) {
          projectedByCard.putIfAbsent(cardId, () => []).add(t);
        } else {
          addEvents(t, projected: true);
        }
      }
    }

    for (final card in cards) {
      if (card.kind != CardKind.credit) {
        continue;
      }
      final invoices = InvoiceService.build(
        card: card,
        transactions: txByCard[card.id] ?? const <Transaction>[],
        projected: projectedByCard[card.id] ?? const <Transaction>[],
      );
      final payment = card.paymentAccountId;
      final accountId = payment != null && activeIds.contains(payment)
          ? payment
          : null;
      for (final invoice in invoices) {
        final due = dateOnly(invoice.dueDate);
        if (invoice.remainingCents == 0 || due.isAfter(end)) {
          continue;
        }
        events.add(
          ForecastEvent(
            date: due.isBefore(day) ? day : due,
            amountCents: -invoice.remainingCents,
            description: 'Fatura ${card.name}',
            kind: ForecastEventKind.invoice,
            sourceId: invoice.id,
            accountId: accountId,
          ),
        );
      }
    }

    events.sort((a, b) {
      final byDate = a.date.compareTo(b.date);
      if (byDate != 0) {
        return byDate;
      }
      final bySource = a.sourceId.compareTo(b.sourceId);
      return bySource != 0
          ? bySource
          : (a.accountId ?? '').compareTo(b.accountId ?? '');
    });

    final daily = <DailyBalance>[];
    var balance = currentTotal;
    var i = 0;
    for (
      var d = day;
      !d.isAfter(end);
      d = DateTime(d.year, d.month, d.day + 1)
    ) {
      while (i < events.length && !events[i].date.isAfter(d)) {
        balance += events[i].amountCents;
        i++;
      }
      daily.add(DailyBalance(date: d, balanceCents: balance));
    }

    DateTime? firstNegative;
    for (final d in daily) {
      if (d.balanceCents < 0) {
        firstNegative = d.date;
        break;
      }
    }

    final byAccount = <String, List<ForecastEvent>>{};
    for (final e in events) {
      final id = e.accountId;
      if (id != null) {
        byAccount.putIfAbsent(id, () => []).add(e);
      }
    }
    final accountNegativeDates = <String, DateTime>{};
    for (final entry in currentBalances.entries) {
      final accountEvents = byAccount[entry.key] ?? const <ForecastEvent>[];
      var acc = entry.value;
      var j = 0;
      for (final d in daily) {
        while (j < accountEvents.length &&
            !accountEvents[j].date.isAfter(d.date)) {
          acc += accountEvents[j].amountCents;
          j++;
        }
        if (acc < 0) {
          accountNegativeDates[entry.key] = d.date;
          break;
        }
      }
    }

    final totals = <YearMonth, _MonthTotals>{};
    for (final e in events) {
      totals.putIfAbsent(YearMonth.fromDate(e.date), _MonthTotals.new).add(e);
    }
    final monthList = <ForecastMonth>[];
    var running = currentTotal;
    for (var m = 0; m < months; m++) {
      final ym = YearMonth.fromDate(day).addMonths(m);
      final t = totals[ym] ?? _MonthTotals();
      running += t.netCents;
      monthList.add(
        ForecastMonth(
          month: ym,
          incomeCents: t.incomeCents,
          expenseCents: t.expenseCents,
          invoiceCents: t.invoiceCents,
          endBalanceCents: running,
        ),
      );
    }

    return Forecast(
      today: day,
      currentBalances: currentBalances,
      currentTotalCents: currentTotal,
      events: events,
      months: monthList,
      daily: daily,
      firstNegativeDate: firstNegative,
      accountNegativeDates: accountNegativeDates,
    );
  }
}

class _MonthTotals {
  int incomeCents = 0;
  int expenseCents = 0;
  int invoiceCents = 0;

  /// Soma com sinal de todos os eventos do mês, inclusive transfer (zero no consolidado).
  int netCents = 0;

  void add(ForecastEvent e) {
    netCents += e.amountCents;
    if (e.kind == ForecastEventKind.transfer) {
      return;
    }
    if (e.kind == ForecastEventKind.invoice) {
      invoiceCents -= e.amountCents;
      return;
    }
    if (e.amountCents > 0) {
      incomeCents += e.amountCents;
    } else {
      expenseCents -= e.amountCents;
    }
  }
}

ForecastEventKind _kindOf(Transaction t) {
  if (t.type == TransactionType.transfer) {
    return ForecastEventKind.transfer;
  }
  if (t.isBoleto) {
    return ForecastEventKind.boleto;
  }
  return t.type == TransactionType.income
      ? ForecastEventKind.income
      : ForecastEventKind.expense;
}
