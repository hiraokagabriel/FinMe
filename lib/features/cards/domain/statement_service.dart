import 'package:hive/hive.dart';

import '../../../core/models/money.dart';
import '../../../core/services/repository_locator.dart';
import 'card_entity.dart';
import 'statement_cycle.dart';
import '../../transactions/domain/transaction_entity.dart';
import '../../transactions/domain/transaction_type.dart';
import '../../transactions/domain/payment_method.dart';
import '../../transactions/domain/recurrence_rule.dart';

class StatementService {
  StatementService._();
  static final instance = StatementService._();

  static const _box = 'preferences';

  // ── helpers ───────────────────────────────────────────────────────

  int _effectiveClosingDay(CardEntity card) {
    if (card.closingDay != null) return card.closingDay!;
    return (card.dueDay - 7).clamp(1, 28);
  }

  // ── cálculo de ciclo ─────────────────────────────────────────────

  Future<StatementCycle> cycleForMonth(
    CardEntity card,
    List<TransactionEntity> allTransactions,
    int year,
    int month,
  ) async {
    final closingDay = _effectiveClosingDay(card);

    final cycleEnd    = DateTime(year, month, closingDay);
    final prevClosing = DateTime(year, month - 1, closingDay);
    final cycleStart  = prevClosing.add(const Duration(days: 1));

    final DateTime dueDate = closingDay >= card.dueDay
        ? DateTime(year, month + 1, card.dueDay)
        : DateTime(year, month, card.dueDay);

    final txs = allTransactions.where((tx) {
      if (tx.cardId != card.id) return false;
      if (tx.type != TransactionType.expense) return false;
      if (tx.isBillPayment) return false;
      final d = tx.date;
      return !d.isBefore(cycleStart) && !d.isAfter(cycleEnd);
    }).toList()
      ..sort((a, b) => b.date.compareTo(a.date));

    final total = txs.fold(0.0, (s, t) => s + t.amount.amount);
    final paid  = await isPaid(card.id, year, month);

    return StatementCycle(
      cycleStart:   cycleStart,
      cycleEnd:     cycleEnd,
      dueDate:      dueDate,
      total:        total,
      transactions: txs,
      isPaid:       paid,
    );
  }

  Future<List<StatementCycle>> cyclesForCard(
    CardEntity card,
    List<TransactionEntity> allTransactions, {
    int count = 6,
  }) async {
    final now        = DateTime.now();
    final closingDay = _effectiveClosingDay(card);

    final refMonth = now.day > closingDay
        ? DateTime(now.year, now.month + 1, 1)
        : DateTime(now.year, now.month, 1);

    final cycles = <StatementCycle>[];
    for (int i = 0; i < count; i++) {
      final ref = DateTime(refMonth.year, refMonth.month - i, 1);
      cycles.add(
        await cycleForMonth(card, allTransactions, ref.year, ref.month),
      );
    }
    return cycles;
  }

  // ── persistência do status pago ─────────────────────────────────

  String _key(String cardId, int year, int month) {
    final mm = month.toString().padLeft(2, '0');
    return 'stmt_paid_${cardId}_$year$mm';
  }

  Future<bool> isPaid(String cardId, int year, int month) async {
    final box = Hive.box<String>(_box);
    return box.get(_key(cardId, year, month)) == '1';
  }

  /// Marca ou desmarca fatura como paga.
  /// Ao marcar (paid=true): persiste flag + cria transação isBillPayment
  ///   vinculada a [accountId] (conta debitada).
  /// Ao desmarcar (paid=false): remove flag + remove transação isBillPayment.
  Future<void> markPaid(
    String cardId,
    int year,
    int month, {
    required bool paid,
    double? amount,
    String? cardName,
    String? accountId, // obrigatório quando paid=true
  }) async {
    final box    = Hive.box<String>(_box);
    final repo   = RepositoryLocator.instance.transactions;
    final allTx  = await repo.getAll();
    final txKey  = _billPaymentTxKey(cardId, year, month);

    if (paid) {
      await box.put(_key(cardId, year, month), '1');

      final alreadyExists = allTx.any((t) => t.id == txKey);
      if (!alreadyExists && amount != null && amount > 0) {
        await repo.add(TransactionEntity(
          id:            txKey,
          amount:        Money(amount),
          date:          DateTime.now(),
          type:          TransactionType.expense,
          paymentMethod: PaymentMethod.other,
          description:   'Fatura ${cardName ?? cardId}',
          cardId:        cardId,
          accountId:     accountId,
          isBoleto:      false,
          isProvisioned: false,
          recurrenceRule: RecurrenceRule.none,
          isBillPayment: true,
        ));
      }
    } else {
      await box.put(_key(cardId, year, month), '0');

      if (allTx.any((t) => t.id == txKey)) {
        await repo.remove(txKey);
      }
    }
  }

  /// Chave determinística da transação de pagamento de fatura.
  String _billPaymentTxKey(String cardId, int year, int month) {
    final mm = month.toString().padLeft(2, '0');
    return 'bill_payment_${cardId}_$year$mm';
  }
}
