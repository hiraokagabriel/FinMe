import 'recurrence_rule.dart';

class TransactionEntity {
  final String id;
  final double amount;
  final String currency;
  final DateTime date;
  final int typeIndex;
  final int paymentMethodIndex;
  final String description;
  final String? categoryId;
  final String? cardId;
  final String? accountId; // M3-A: conta vinculada
  final bool isBoleto;
  final bool isProvisioned;
  final int? installmentCount;
  final DateTime? provisionedDueDate;
  final RecurrenceRule? recurrenceRule;
  final String? recurrenceParentId;
  final String? notes;

  const TransactionEntity({
    required this.id,
    required this.amount,
    required this.currency,
    required this.date,
    required this.typeIndex,
    required this.paymentMethodIndex,
    required this.description,
    this.categoryId,
    this.cardId,
    this.accountId,
    required this.isBoleto,
    required this.isProvisioned,
    this.installmentCount,
    this.provisionedDueDate,
    this.recurrenceRule,
    this.recurrenceParentId,
    this.notes,
  });
}
