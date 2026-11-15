import 'dart:math' as math;

import '../../../core/models/year_month.dart';
import '../../../core/utils/date_utils.dart';
import '../../transactions/domain/transaction.dart';
import 'invoice_cycle.dart';
import 'payment_card.dart';

enum InvoiceStatus { open, closed, paid, overdue }

/// Fatura de cartão de crédito que vence em [dueMonth]. `items` são compras e
/// estornos (inclui projetados), ordenados por data.
class Invoice {
  const Invoice({
    required this.card,
    required this.dueMonth,
    required this.closingDate,
    required this.dueDate,
    required this.items,
    required this.chargesCents,
    required this.creditsCents,
    required this.paidCents,
  });

  final PaymentCard card;
  final YearMonth dueMonth;
  final DateTime closingDate;
  final DateTime dueDate;
  final List<Transaction> items;
  final int chargesCents;
  final int creditsCents;
  final int paidCents;

  int get totalCents => chargesCents - creditsCents;

  int get remainingCents => math.max(0, totalCents - paidCents);

  String get id => '${card.id}_${dueMonth.key}';

  InvoiceStatus statusOn(DateTime today) {
    final day = dateOnly(today);
    if (remainingCents == 0) {
      return InvoiceStatus.paid;
    }
    if (day.isAfter(dueDate)) {
      return InvoiceStatus.overdue;
    }
    if (!day.isBefore(closingDate)) {
      return InvoiceStatus.closed;
    }
    return InvoiceStatus.open;
  }
}

class _Group {
  final items = <Transaction>[];
  int charges = 0;
  int credits = 0;
  int paid = 0;
}

class InvoiceService {
  /// Faturas de [card] (só crédito; débito retorna vazio), ordenadas por vencimento.
  /// `projected` são recorrências futuras do cartão.
  static List<Invoice> build({
    required PaymentCard card,
    required Iterable<Transaction> transactions,
    Iterable<Transaction> projected = const [],
  }) {
    if (card.kind != CardKind.credit) {
      return const [];
    }
    final all = transactions.followedBy(projected);
    // Parcelas: a data da 1ª parcela ancora o grupo; as demais avançam um mês por índice.
    final firstInstallmentDate = <String, DateTime>{};
    for (final t in all) {
      final groupId = t.installmentGroupId;
      if (groupId != null && t.cardId == card.id && t.installmentIndex == 1) {
        firstInstallmentDate[groupId] = t.date;
      }
    }
    final groups = <YearMonth, _Group>{};
    for (final t in all) {
      if (t.cardId != card.id || t.type == TransactionType.transfer) {
        continue;
      }
      if (t.type == TransactionType.invoicePayment) {
        final key = _parseKey(t.invoiceKey);
        if (key != null) {
          final month = invoiceMonthForKey(key, card);
          groups.putIfAbsent(month, _Group.new).paid += t.amountCents;
        }
        continue;
      }
      final groupId = t.installmentGroupId;
      final index = t.installmentIndex;
      final firstDate = groupId == null ? null : firstInstallmentDate[groupId];
      final YearMonth month;
      if (groupId != null && index != null) {
        month = firstDate == null
            ? invoiceDueMonth(t.date, card)
            : installmentDueMonth(firstDate, index, card);
      } else {
        month = invoiceDueMonth(t.date, card);
      }
      final group = groups.putIfAbsent(month, _Group.new);
      group.items.add(t);
      if (t.type == TransactionType.expense) {
        group.charges += t.amountCents;
      } else {
        group.credits += t.amountCents;
      }
    }
    final months = groups.keys.toList()..sort();
    return [
      for (final month in months) _toInvoice(card, month, groups[month]!),
    ];
  }

  /// Soma do saldo em aberto de todas as faturas não quitadas (inclui parcelas futuras).
  static int usedLimitCents(Iterable<Invoice> invoices, DateTime today) {
    var used = 0;
    for (final invoice in invoices) {
      if (invoice.statusOn(today) != InvoiceStatus.paid) {
        used += invoice.remainingCents;
      }
    }
    return used;
  }

  /// Fatura não quitada mais antiga (inclusive vencida). Null se todas estiverem quitadas.
  /// [today] não altera o resultado (assinatura mantida pelo SPEC §5.2).
  static Invoice? currentInvoice(Iterable<Invoice> invoices, DateTime today) {
    Invoice? best;
    for (final invoice in invoices) {
      if (invoice.remainingCents == 0) {
        continue;
      }
      if (best == null || invoice.dueDate.isBefore(best.dueDate)) {
        best = invoice;
      }
    }
    return best;
  }

  /// `invoiceKey` malformado (ex.: "2026-13", "abc") → null; o pagamento é ignorado.
  static YearMonth? _parseKey(String? key) {
    if (key == null) {
      return null;
    }
    try {
      return YearMonth.fromKey(key);
    } on FormatException {
      return null;
    }
  }

  static Invoice _toInvoice(PaymentCard card, YearMonth month, _Group group) {
    final items = [...group.items]..sort((a, b) => a.date.compareTo(b.date));
    // Ciclo das datas = item mais recente (lista ordenada); sem itens → início do mês.
    final cycleDate = items.isEmpty ? null : items.last.date;
    return Invoice(
      card: card,
      dueMonth: month,
      closingDate: invoiceClosingDate(month, card, cycleDate: cycleDate),
      dueDate: invoiceDueDate(month, card, cycleDate: cycleDate),
      items: items,
      chargesCents: group.charges,
      creditsCents: group.credits,
      paidCents: group.paid,
    );
  }
}
