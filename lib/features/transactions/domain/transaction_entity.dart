import 'recurrence_rule.dart';
import '../../accounts/domain/account_entity.dart';
import '../../../core/models/money.dart';
import 'transaction_type.dart';
import 'payment_method.dart';

class TransactionEntity {
  final String id;
  final Money amount;
  final DateTime date;
  final TransactionType type;
  final PaymentMethod paymentMethod;
  final String? description;
  final String? categoryId;
  final String? cardId;
  final String? accountId;      // conta de origem
  final String? toAccountId;    // conta de destino (apenas para transfer)
  final bool isBoleto;
  final bool isProvisioned;
  final int? installmentCount;
  final DateTime? provisionedDueDate;
  final RecurrenceRule recurrenceRule;
  final String? recurrenceSourceId;
  final String? notes;

  const TransactionEntity({
    required this.id,
    required this.amount,
    required this.date,
    required this.type,
    required this.paymentMethod,
    this.description,
    this.categoryId,
    this.cardId,
    this.accountId,
    this.toAccountId,
    required this.isBoleto,
    required this.isProvisioned,
    this.installmentCount,
    this.provisionedDueDate,
    this.recurrenceRule = RecurrenceRule.none,
    this.recurrenceSourceId,
    this.notes,
  });
}
