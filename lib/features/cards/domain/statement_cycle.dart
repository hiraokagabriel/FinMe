import '../../transactions/domain/transaction_entity.dart';

class StatementCycle {
  final DateTime cycleStart;
  final DateTime cycleEnd;
  final DateTime dueDate;
  final double total;
  final List<TransactionEntity> transactions;
  final bool isPaid;

  const StatementCycle({
    required this.cycleStart,
    required this.cycleEnd,
    required this.dueDate,
    required this.total,
    required this.transactions,
    required this.isPaid,
  });

  static DateTime _dateOnly(DateTime dt) =>
      DateTime(dt.year, dt.month, dt.day);

  /// true enquanto o dia de fechamento ainda não chegou
  bool get isOpen {
    final today = _dateOnly(DateTime.now());
    final end = _dateOnly(cycleEnd);
    return end.isAfter(today);
  }

  /// true apenas no dia exato do fechamento
  bool get isClosingToday {
    final today = _dateOnly(DateTime.now());
    final end = _dateOnly(cycleEnd);
    return end == today;
  }
}
