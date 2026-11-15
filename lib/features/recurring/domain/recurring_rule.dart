import '../../../core/utils/date_utils.dart';
import '../../../core/utils/enum_utils.dart';
import '../../transactions/domain/transaction.dart';

/// Sentinela de `copyWith`: parâmetro omitido mantém o campo; `null` limpa; valor troca.
const Object _keep = Object();

enum Frequency { weekly, monthly, yearly }

/// Regra de recorrência. `type` é `expense` ou `income`.
/// Ocorrências são geradas por `recurrence.dart`; não são gravadas no futuro.
class RecurringRule {
  RecurringRule({
    required this.id,
    required this.description,
    required this.type,
    required this.amountCents,
    required this.frequency,
    required DateTime startDate,
    this.categoryId,
    this.accountId,
    this.cardId,
    DateTime? endDate,
    this.isSubscription = false,
    this.isBoleto = false,
    this.active = true,
    DateTime? materializedUntil,
  }) : assert(
         type == TransactionType.expense || type == TransactionType.income,
         'RecurringRule aceita apenas expense ou income',
       ),
       startDate = dateOnly(startDate),
       endDate = endDate == null ? null : dateOnly(endDate),
       materializedUntil = materializedUntil == null
           ? null
           : dateOnly(materializedUntil);

  factory RecurringRule.fromMap(Map<String, dynamic> map) {
    final end = map['endDate'] as String?;
    final until = map['materializedUntil'] as String?;
    return RecurringRule(
      id: map['id'] as String,
      description: map['description'] as String,
      type: enumByName(TransactionType.values, map['type']),
      amountCents: (map['amountCents'] as num).toInt(),
      categoryId: map['categoryId'] as String?,
      accountId: map['accountId'] as String?,
      cardId: map['cardId'] as String?,
      frequency: enumByName(Frequency.values, map['frequency']),
      startDate: parseDateKey(map['startDate'] as String),
      endDate: end == null ? null : parseDateKey(end),
      isSubscription: map['isSubscription'] == true,
      isBoleto: map['isBoleto'] == true,
      active: map['active'] != false,
      materializedUntil: until == null ? null : parseDateKey(until),
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

  /// Última data já materializada no boot (SPEC §4.5); evita ressuscitar ocorrência apagada.
  final DateTime? materializedUntil;

  RecurringRule copyWith({
    String? description,
    TransactionType? type,
    int? amountCents,
    Object? categoryId = _keep,
    Object? accountId = _keep,
    Object? cardId = _keep,
    Frequency? frequency,
    DateTime? startDate,
    Object? endDate = _keep,
    bool? isSubscription,
    bool? isBoleto,
    bool? active,
    Object? materializedUntil = _keep,
  }) => RecurringRule(
    id: id,
    description: description ?? this.description,
    type: type ?? this.type,
    amountCents: amountCents ?? this.amountCents,
    categoryId: identical(categoryId, _keep)
        ? this.categoryId
        : categoryId as String?,
    accountId: identical(accountId, _keep)
        ? this.accountId
        : accountId as String?,
    cardId: identical(cardId, _keep) ? this.cardId : cardId as String?,
    frequency: frequency ?? this.frequency,
    startDate: startDate ?? this.startDate,
    endDate: identical(endDate, _keep) ? this.endDate : endDate as DateTime?,
    isSubscription: isSubscription ?? this.isSubscription,
    isBoleto: isBoleto ?? this.isBoleto,
    active: active ?? this.active,
    materializedUntil: identical(materializedUntil, _keep)
        ? this.materializedUntil
        : materializedUntil as DateTime?,
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
    'materializedUntil': materializedUntil == null
        ? null
        : dateKey(materializedUntil!),
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
          other.active == active &&
          other.materializedUntil == materializedUntil;

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
    materializedUntil,
  );
}
