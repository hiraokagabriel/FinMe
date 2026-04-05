import '../../../core/models/money.dart';
import '../../../core/models/date_range.dart';
import '../../cards/domain/card_entity.dart';
import '../../categories/domain/category_entity.dart';
import 'payment_method.dart';
import 'transaction_type.dart';

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
  });
}
