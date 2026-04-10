import 'package:hive/hive.dart';

import '../domain/card_entity.dart';
import '../domain/statement_cycle.dart';
import '../../transactions/domain/transaction_entity.dart';
import '../../transactions/domain/transaction_type.dart';

class StatementService {
  StatementService._();
  static final instance = StatementService._();

  static const _box = 'settings';

  // ── Cálculo de ciclos ──────────────────────────────────────────────────────

  /// Dia de fechamento efetivo: usa o declarado ou dueDay - 7, clampado em [1, 28].
  int _effectiveClosingDay(CardEntity card) {
    if (card.closingDay != null) return card.closingDay!;
    return (card.dueDay - 7).clamp(1, 28);
  }

  /// Retorna o [StatementCycle] para o mês [year/month] de um cartão.
  Future<StatementCycle> cycleForMonth(
    CardEntity card,
    List<TransactionEntity> allTransactions,
    int year,
    int month,
  ) async {
    final closingDay = _effectiveClosingDay(card);

    // cycleEnd = fechamento deste mês (inclusive)
    final cycleEnd = DateTime(year, month, closingDay);

    // cycleStart = dia seguinte ao fechamento do mês anterior
    final prevClosing = DateTime(year, month - 1, closingDay);
    final cycleStart = prevClosing.add(const Duration(days: 1));

    // vencimento: se closingDay >= dueDay, cai no mês seguinte
    final DateTime dueDate = closingDay >= card.dueDay
        ? DateTime(year, month + 1, card.dueDay)
        : DateTime(year, month, card.dueDay);

    // filtra transações do ciclo
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

  /// Retorna os [count] ciclos mais recentes, do mais novo para o mais antigo.
  Future<List<StatementCycle>> cyclesForCard(
    CardEntity card,
    List<TransactionEntity> allTransactions, {
    int count = 4,
  }) async {
    final now = DateTime.now();
    final cycles = <StatementCycle>[];
    for (int i = 0; i < count; i++) {
      final ref = DateTime(now.year, now.month - i, 1);
      cycles.add(
        await cycleForMonth(card, allTransactions, ref.year, ref.month),
      );
    }
    return cycles;
  }

  // ── Persistência do status pago ────────────────────────────────────────────

  String _key(String cardId, int year, int month) {
    final mm = month.toString().padLeft(2, '0');
    return 'stmt_paid_${cardId}_$year$mm';
  }

  Future<bool> isPaid(String cardId, int year, int month) async {
    final box = Hive.box(_box);
    return box.get(_key(cardId, year, month), defaultValue: false) as bool;
  }

  Future<void> markPaid(String cardId, int year, int month, {required bool paid}) async {
    final box = Hive.box(_box);
    await box.put(_key(cardId, year, month), paid);
  }
}
