import '../../../core/utils/date_utils.dart';
import '../../../core/utils/enum_utils.dart';
import '../../transactions/domain/transaction.dart';

enum Frequency { weekly, monthly, yearly }

/// Regra de recorrência. `type` é `expense` ou `income`.
/// Ocorrências são geradas por `recurrence.dart`; não são gravadas no futuro.
class RecurringRule {
  const RecurringRule({
    required this.id,
    required this.description,
    required this.type,
    required this.amountCents,
    required this.frequency,
    required this.startDate,
    this.categoryId,
    this.accountId,
    this.cardId,
    this.endDate,
    this.isSubscription = false,
    this.isBoleto = false,
    this.active = true,
  }) : assert(
         type == TransactionType.expense || type == TransactionType.income,
         'RecurringRule aceita apenas expense ou income',
       );

  factory RecurringRule.fromMap(Map<String, dynamic> map) {
    final end = map['endDate'] as String?;
    return RecurringRule(
      id: map['id'] as String,
      description: map['description'] as String,
      type: enumByName(TransactionType.values, map['type']),
      amountCents: (map['amountCents'] as num).toInt(),
      categoryId: map['categoryId'] as String?,
      accountId: map['accountId'] as String?,
      cardId: map['cardId'] as String?,
      frequency: enumByName(Frequency.values, map['frequency']),
      startDate: dateOnly(parseDateKey(map['startDate'] as String)),
      endDate: end == null ? null : dateOnly(parseDateKey(end)),
      isSubscription: map['isSubscription'] == true,
      isBoleto: map['isBoleto'] == true,
      active: map['active'] != false,
    );
  }

  final String id;
  final String description;
  final TransactionType type;
  final int amountCents;
  final String? categoryId;
  final String? accountId;
  final String? cardId;
  final Frequency frequency;
  final DateTime startDate;
  final DateTime? endDate;
  final bool isSubscription;
  final bool isBoleto;
  final bool active;

  RecurringRule copyWith({
    String? description,
    TransactionType? type,
    int? amountCents,
    String? categoryId,
    String? accountId,
    String? cardId,
    Frequency? frequency,
    DateTime? startDate,
    DateTime? endDate,
    bool? isSubscription,
    bool? isBoleto,
    bool? active,
  }) => RecurringRule(
    id: id,
    description: description ?? this.description,
    type: type ?? this.type,
    amountCents: amountCents ?? this.amountCents,
    categoryId: categoryId ?? this.categoryId,
    accountId: accountId ?? this.accountId,
    cardId: cardId ?? this.cardId,
    frequency: frequency ?? this.frequency,
    startDate: startDate ?? this.startDate,
    endDate: endDate ?? this.endDate,
    isSubscription: isSubscription ?? this.isSubscription,
    isBoleto: isBoleto ?? this.isBoleto,
    active: active ?? this.active,
  );

  Map<String, dynamic> toMap() => {
    'id': id,
    'description': description,
    'type': type.name,
    'amountCents': amountCents,
    'categoryId': categoryId,
    'accountId': accountId,
    'cardId': cardId,
    'frequency': frequency.name,
    'startDate': dateKey(startDate),
    'endDate': endDate == null ? null : dateKey(endDate!),
    'isSubscription': isSubscription,
    'isBoleto': isBoleto,
    'active': active,
  };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is RecurringRule &&
          other.id == id &&
          other.description == description &&
          other.type == type &&
          other.amountCents == amountCents &&
          other.categoryId == categoryId &&
          other.accountId == accountId &&
          other.cardId == cardId &&
          other.frequency == frequency &&
          other.startDate == startDate &&
          other.endDate == endDate &&
          other.isSubscription == isSubscription &&
          other.isBoleto == isBoleto &&
          other.active == active;

  @override
  int get hashCode => Object.hash(
    id,
    description,
    type,
    amountCents,
    categoryId,
    accountId,
    cardId,
    frequency,
    startDate,
    endDate,
    isSubscription,
    isBoleto,
    active,
  );
}
