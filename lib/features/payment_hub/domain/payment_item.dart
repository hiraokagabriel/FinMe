enum PaymentItemType { provisioned, cardBill }

class PaymentItem {
  final String id;
  final PaymentItemType type;
  final String label;
  final String? cardId;
  final String? transactionId;
  final double amount;
  final DateTime dueDate;
  final DateTime? closingDate; // apenas para cardBill
  final bool isPaid;

  const PaymentItem({
    required this.id,
    required this.type,
    required this.label,
    this.cardId,
    this.transactionId,
    required this.amount,
    required this.dueDate,
    this.closingDate,
    required this.isPaid,
  });

  PaymentItem copyWith({bool? isPaid}) {
    return PaymentItem(
      id: id,
      type: type,
      label: label,
      cardId: cardId,
      transactionId: transactionId,
      amount: amount,
      dueDate: dueDate,
      closingDate: closingDate,
      isPaid: isPaid ?? this.isPaid,
    );
  }
}
