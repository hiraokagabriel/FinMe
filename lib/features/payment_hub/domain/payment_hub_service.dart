import 'package:hive/hive.dart';

import '../../../core/models/money.dart';
import '../../../core/services/repository_locator.dart';
import '../../cards/domain/card_entity.dart';
import '../../transactions/domain/transaction_entity.dart';
import '../../transactions/domain/transaction_type.dart';
import '../../transactions/domain/payment_method.dart';
import '../../transactions/domain/recurrence_rule.dart';
import 'payment_item.dart';

class PaymentHubService {
  PaymentHubService._();
  static final PaymentHubService instance = PaymentHubService._();

  static const _kBoxName    = 'preferences';
  static const _kWindowDays = 'paymentWindowDays';

  Box<String> get _box => Hive.box<String>(_kBoxName);

  // ─── Janela ─────────────────────────────────────────────────

  int get windowDays => int.tryParse(_box.get(_kWindowDays) ?? '') ?? 7;

  Future<void> setWindowDays(int days) =>
      _box.put(_kWindowDays, days.toString());

  // ─── Cálculo de datas ──────────────────────────────────────────

  DateTime _nextDueDate(int dueDay) {
    final now   = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    var candidate = DateTime(today.year, today.month, dueDay);
    if (!candidate.isAfter(today)) {
      candidate = DateTime(today.year, today.month + 1, dueDay);
    }
    return candidate;
  }

  DateTime _closingDateFor(CardEntity card) {
    final due = _nextDueDate(card.dueDay);
    if (card.closingDay != null) {
      var closing = DateTime(due.year, due.month, card.closingDay!);
      if (closing.isAfter(due)) {
        closing = DateTime(due.year, due.month - 1, card.closingDay!);
      }
      return closing;
    }
    return due.subtract(const Duration(days: 7));
  }

  // ─── Valor estimado da fatura ───────────────────────────────────

  double _billAmount(
    CardEntity card,
    List<TransactionEntity> allTx,
    DateTime closingDate,
  ) {
    final prevClosing = DateTime(
      closingDate.year,
      closingDate.month - 1,
      closingDate.day,
    );
    return allTx
        .where(
          (tx) =>
              tx.cardId == card.id &&
              tx.type == TransactionType.expense &&
              !tx.isProvisioned &&
              !tx.date.isBefore(prevClosing) &&
              tx.date.isBefore(closingDate),
        )
        .fold(0.0, (sum, tx) => sum + tx.amount.amount);
  }

  // ─── Carregamento ─────────────────────────────────────────────

  Future<List<PaymentItem>> load() async {
    final locator = RepositoryLocator.instance;
    final now     = DateTime.now();
    final today   = DateTime(now.year, now.month, now.day);
    final windowEnd = today.add(Duration(days: windowDays - 1));

    final allTx    = await locator.transactions.getAll();
    final allCards = await locator.cards.getAll();

    final items = <PaymentItem>[];

    // Faturas de cartão de crédito (typeIndex == 0)
    for (final card in allCards.where((c) => c.type.index == 0)) {
      final dueDate     = _nextDueDate(card.dueDay);
      final closingDate = _closingDateFor(card);
      if (dueDate.isAfter(windowEnd)) continue;

      items.add(PaymentItem(
        id:          'bill_${card.id}',
        type:        PaymentItemType.cardBill,
        label:       'Fatura ${card.name}',
        cardId:      card.id,
        amount:      _billAmount(card, allTx, closingDate),
        dueDate:     dueDate,
        closingDate: closingDate,
        isPaid:      false,
      ));
    }

    // Transações provisionadas
    for (final tx in allTx.where((t) => t.isProvisioned)) {
      final due = tx.provisionedDueDate;
      if (due == null) continue;
      if (due.isBefore(today) || due.isAfter(windowEnd)) continue;

      items.add(PaymentItem(
        id:            'prov_${tx.id}',
        type:          PaymentItemType.provisioned,
        label:         tx.description ?? 'Sem descrição',
        transactionId: tx.id,
        amount:        tx.amount.amount,
        dueDate:       due,
        isPaid:        false,
      ));
    }

    items.sort((a, b) => a.dueDate.compareTo(b.dueDate));
    return items;
  }

  // ─── Marcar como pago ──────────────────────────────────────────

  Future<void> markAsPaid(PaymentItem item) async {
    final locator = RepositoryLocator.instance;
    final now     = DateTime.now();

    if (item.type == PaymentItemType.provisioned) {
      final txId = item.transactionId;
      if (txId == null) return;
      final allTx  = await locator.transactions.getAll();
      final source = allTx.where((t) => t.id == txId).firstOrNull;
      if (source == null) return;

      final alreadyPaid = allTx.any(
        (t) =>
            !t.isProvisioned &&
            t.recurrenceSourceId == source.id &&
            t.date.year  == now.year &&
            t.date.month == now.month,
      );
      if (alreadyPaid) return;

      await locator.transactions.add(TransactionEntity(
        id:                DateTime.now().microsecondsSinceEpoch.toString(),
        amount:            source.amount,
        date:              now,
        type:              source.type,
        paymentMethod:     source.paymentMethod,
        description:       source.description,
        categoryId:        source.categoryId,
        cardId:            source.cardId,
        accountId:         source.accountId,
        toAccountId:       source.toAccountId,
        isBoleto:          source.isBoleto,
        isProvisioned:     false,
        recurrenceRule:    RecurrenceRule.none,
        recurrenceSourceId: source.id,
        notes:             source.notes,
      ));
      await locator.transactions.remove(txId);
      return;
    }

    if (item.type == PaymentItemType.cardBill) {
      final cardId = item.cardId;
      if (cardId == null) return;
      final allTx = await locator.transactions.getAll();
      final alreadyPaid = allTx.any(
        (t) =>
            t.cardId      == cardId &&
            t.description == item.label &&
            !t.isProvisioned &&
            t.date.year  == now.year &&
            t.date.month == now.month,
      );
      if (alreadyPaid) return;

      await locator.transactions.add(TransactionEntity(
        id:            DateTime.now().microsecondsSinceEpoch.toString(),
        amount:        Money(item.amount),
        date:          now,
        type:          TransactionType.expense,
        paymentMethod: PaymentMethod.creditCard,
        description:   item.label,
        cardId:        cardId,
        isBoleto:      false,
        isProvisioned: false,
        recurrenceRule: RecurrenceRule.none,
      ));
    }
  }
}
