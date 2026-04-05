import '../../../core/models/money.dart';
import '../domain/payment_method.dart';
import '../domain/transaction_type.dart';

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

  // Provisionamento avancado (M3)
  // installmentCount: numero de parcelas (null = nao parcelado)
  // provisionedDueDate: data de vencimento do boleto/parcela provisionada
  final int? installmentCount;
  final DateTime? provisionedDueDate;

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
  });
}
