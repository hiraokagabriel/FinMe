import '../../../core/utils/enum_utils.dart';

enum CardBrand { visa, mastercard, elo, amex, hipercard, other }

enum CardKind { credit, debit }

/// Cartão de crédito ou débito. `closingDay`/`dueDay` só valem para crédito
/// (em débito são ignorados). `paymentAccountId`: crédito = conta que paga a
/// fatura; débito = conta debitada.
class PaymentCard {
  const PaymentCard({
    required this.id,
    required this.name,
    required this.bankName,
    required this.brand,
    required this.kind,
    required this.last4,
    required this.closingDay,
    required this.dueDay,
    required this.colorValue,
    this.limitCents = 0,
    this.paymentAccountId,
    this.archived = false,
  });

  factory PaymentCard.fromMap(Map<String, dynamic> map) => PaymentCard(
    id: map['id'] as String,
    name: map['name'] as String,
    bankName: map['bankName'] as String,
    brand: enumByName(CardBrand.values, map['brand']),
    kind: enumByName(CardKind.values, map['kind']),
    last4: map['last4'] as String,
    limitCents: (map['limitCents'] as num?)?.toInt() ?? 0,
    closingDay: (map['closingDay'] as num).toInt(),
    dueDay: (map['dueDay'] as num).toInt(),
    paymentAccountId: map['paymentAccountId'] as String?,
    colorValue: (map['colorValue'] as num).toInt(),
    archived: map['archived'] == true,
  );

  final String id;
  final String name;
  final String bankName;
  final CardBrand brand;
  final CardKind kind;
  final String last4;
  final int limitCents;
  final int closingDay;
  final int dueDay;
  final String? paymentAccountId;
  final int colorValue;
  final bool archived;

  PaymentCard copyWith({
    String? name,
    String? bankName,
    CardBrand? brand,
    CardKind? kind,
    String? last4,
    int? limitCents,
    int? closingDay,
    int? dueDay,
    String? paymentAccountId,
    int? colorValue,
    bool? archived,
  }) => PaymentCard(
    id: id,
    name: name ?? this.name,
    bankName: bankName ?? this.bankName,
    brand: brand ?? this.brand,
    kind: kind ?? this.kind,
    last4: last4 ?? this.last4,
    limitCents: limitCents ?? this.limitCents,
    closingDay: closingDay ?? this.closingDay,
    dueDay: dueDay ?? this.dueDay,
    paymentAccountId: paymentAccountId ?? this.paymentAccountId,
    colorValue: colorValue ?? this.colorValue,
    archived: archived ?? this.archived,
  );

  Map<String, dynamic> toMap() => {
    'id': id,
    'name': name,
    'bankName': bankName,
    'brand': brand.name,
    'kind': kind.name,
    'last4': last4,
    'limitCents': limitCents,
    'closingDay': closingDay,
    'dueDay': dueDay,
    'paymentAccountId': paymentAccountId,
    'colorValue': colorValue,
    'archived': archived,
  };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PaymentCard &&
          other.id == id &&
          other.name == name &&
          other.bankName == bankName &&
          other.brand == brand &&
          other.kind == kind &&
          other.last4 == last4 &&
          other.limitCents == limitCents &&
          other.closingDay == closingDay &&
          other.dueDay == dueDay &&
          other.paymentAccountId == paymentAccountId &&
          other.colorValue == colorValue &&
          other.archived == archived;

  @override
  int get hashCode => Object.hash(
    id,
    name,
    bankName,
    brand,
    kind,
    last4,
    limitCents,
    closingDay,
    dueDay,
    paymentAccountId,
    colorValue,
    archived,
  );
}
