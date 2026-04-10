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

  bool get isOpen => cycleEnd.isAfter(DateTime.now());
}
