import '../../../core/models/money.dart';
import '../domain/payment_method.dart';
import '../domain/transaction_type.dart';
import '../domain/recurrence_rule.dart';

class TransactionEntity {
  final String id;
  final Money amount;
  final DateTime date;
  final TransactionType type;
  final PaymentMethod paymentMethod;
  final String? description;
  final String categoryId;
  final String? cardId;
  final bool isBoleto;
  final bool isProvisioned;
  final int? installmentCount;
  final DateTime? provisionedDueDate;

  /// Regra de recorrência. `none` = sem repetição.
  final RecurrenceRule recurrenceRule;

  /// ID da transação-origem de onde esta foi gerada (null = é a origem).
  final String? recurrenceSourceId;

  const TransactionEntity({
    required this.id,
    required this.amount,
    required this.date,
    required this.type,
    required this.paymentMethod,
    this.description,
    required this.categoryId,
    this.cardId,
    this.isBoleto = false,
    this.isProvisioned = false,
    this.installmentCount,
    this.provisionedDueDate,
    this.recurrenceRule = RecurrenceRule.none,
    this.recurrenceSourceId,
  });
}
