import 'package:hive/hive.dart';

import 'card_entity.dart';
import 'statement_cycle.dart';
import '../../transactions/domain/transaction_entity.dart';
import '../../transactions/domain/transaction_type.dart';

class StatementService {
  StatementService._();
  static final instance = StatementService._();

  static const _box = 'settings';

  // ── helpers ─────────────────────────────────────────────────────────────

  int _effectiveClosingDay(CardEntity card) {
    if (card.closingDay != null) return card.closingDay!;
    return (card.dueDay - 7).clamp(1, 28);
  }

  // ── cálculo de ciclo ───────────────────────────────────────────────────────

  Future<StatementCycle> cycleForMonth(
    CardEntity card,
    List<TransactionEntity> allTransactions,
    int year,
    int month,
  ) async {
    final closingDay = _effectiveClosingDay(card);

    final cycleEnd = DateTime(year, month, closingDay);
    final prevClosing = DateTime(year, month - 1, closingDay);
    final cycleStart = prevClosing.add(const Duration(days: 1));

    // vencimento no mês seguinte quando closingDay >= dueDay
    final DateTime dueDate = closingDay >= card.dueDay
        ? DateTime(year, month + 1, card.dueDay)
        : DateTime(year, month, card.dueDay);

    final txs = allTransactions.where((tx) {
      if (tx.cardId != card.id) return false;
      if (tx.type != TransactionType.expense) return false;
      final d = tx.date;
      return !d.isBefore(cycleStart) && !d.isAfter(cycleEnd);
    }).toList()
      ..sort((a, b) => b.date.compareTo(a.date));

    final total = txs.fold(0.0, (s, t) => s + t.amount.amount);
    final paid = await isPaid(card.id, year, month);

    return StatementCycle(
      cycleStart: cycleStart,
      cycleEnd: cycleEnd,
      dueDate: dueDate,
      total: total,
      transactions: txs,
      isPaid: paid,
    );
  }

  /// Retorna os [count] ciclos mais recentes a partir do ciclo correto para hoje.
  ///
  /// Se hoje > closingDay, o ciclo aberto é o do próximo mês (a fatura atual
  /// já fechou). Caso contrário, o ciclo aberto é o do mês corrente.
  Future<List<StatementCycle>> cyclesForCard(
    CardEntity card,
    List<TransactionEntity> allTransactions, {
    int count = 6,
  }) async {
    final now = DateTime.now();
    final closingDay = _effectiveClosingDay(card);

    // Mês de referência do ciclo aberto
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

  // ── persistência do status pago ────────────────────────────────────────────

  String _key(String cardId, int year, int month) {
    final mm = month.toString().padLeft(2, '0');
    return 'stmt_paid_${cardId}_$year$mm';
  }

  Future<bool> isPaid(String cardId, int year, int month) async {
    final box = Hive.box(_box);
    return box.get(_key(cardId, year, month), defaultValue: false) as bool;
  }

  Future<void> markPaid(
    String cardId,
    int year,
    int month, {
    required bool paid,
  }) async {
    final box = Hive.box(_box);
    await box.put(_key(cardId, year, month), paid);
  }
}
