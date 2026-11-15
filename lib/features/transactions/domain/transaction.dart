import '../../../core/utils/date_utils.dart';
import '../../../core/utils/enum_utils.dart';

/// Sentinela de `copyWith`: parâmetro omitido mantém o campo; `null` limpa; valor troca.
const Object _keep = Object();

enum TransactionType { expense, income, transfer, invoicePayment }

/// `planned` = provisionado (ainda não saiu); `paid` = lançado.
enum TransactionStatus { paid, planned }

/// Lançamento. `amountCents` sempre > 0; o sentido vem do [type].
/// [date] é normalizada por [dateOnly] no construtor.
class Transaction {
  Transaction({
    required this.id,
    required this.type,
    required this.amountCents,
    required DateTime date,
    required this.description,
    this.categoryId,
    this.accountId,
    this.cardId,
    this.toAccountId,
    this.status = TransactionStatus.paid,
    this.isBoleto = false,
    this.invoiceKey,
    this.installmentGroupId,
    this.installmentIndex,
    this.installmentCount,
    this.recurringId,
    this.notes,
  }) : date = dateOnly(date);

  /// Data lida como `dateKey` e normalizada para meia-noite local.
  factory Transaction.fromMap(Map<String, dynamic> map) => Transaction(
    id: map['id'] as String,
    type: enumByName(TransactionType.values, map['type']),
    amountCents: (map['amountCents'] as num).toInt(),
    date: parseDateKey(map['date'] as String),
    description: map['description'] as String,
    categoryId: map['categoryId'] as String?,
    accountId: map['accountId'] as String?,
    cardId: map['cardId'] as String?,
    toAccountId: map['toAccountId'] as String?,
    status: enumByName(TransactionStatus.values, map['status']),
    isBoleto: map['isBoleto'] == true,
    invoiceKey: map['invoiceKey'] as String?,
    installmentGroupId: map['installmentGroupId'] as String?,
    installmentIndex: (map['installmentIndex'] as num?)?.toInt(),
    installmentCount: (map['installmentCount'] as num?)?.toInt(),
    recurringId: map['recurringId'] as String?,
    notes: map['notes'] as String?,
  );

  final String id;
  final TransactionType type;
  final int amountCents;
  final DateTime date;
  final String description;
  final String? categoryId;
  final String? accountId;
  final String? cardId;
  final String? toAccountId;
  final TransactionStatus status;
  final bool isBoleto;
  final String? invoiceKey;
  final String? installmentGroupId;
  final int? installmentIndex;
  final int? installmentCount;
  final String? recurringId;
  final String? notes;

  /// Provisionado: ainda não saiu, mas já se sabe que vai sair.
  bool get isPlanned => status == TransactionStatus.planned;

  /// Faz parte de um grupo de parcelas (ver `installmentGroupId`).
  bool get isInstallment => installmentGroupId != null;

  Transaction copyWith({
    TransactionType? type,
    int? amountCents,
    DateTime? date,
    String? description,
    Object? categoryId = _keep,
    Object? accountId = _keep,
    Object? cardId = _keep,
    Object? toAccountId = _keep,
    TransactionStatus? status,
    bool? isBoleto,
    Object? invoiceKey = _keep,
    Object? installmentGroupId = _keep,
    Object? installmentIndex = _keep,
    Object? installmentCount = _keep,
    Object? recurringId = _keep,
    Object? notes = _keep,
  }) => Transaction(
    id: id,
    type: type ?? this.type,
    amountCents: amountCents ?? this.amountCents,
    date: date ?? this.date,
    description: description ?? this.description,
    categoryId: identical(categoryId, _keep)
        ? this.categoryId
        : categoryId as String?,
    accountId: identical(accountId, _keep)
        ? this.accountId
        : accountId as String?,
    cardId: identical(cardId, _keep) ? this.cardId : cardId as String?,
    toAccountId: identical(toAccountId, _keep)
        ? this.toAccountId
        : toAccountId as String?,
    status: status ?? this.status,
    isBoleto: isBoleto ?? this.isBoleto,
    invoiceKey: identical(invoiceKey, _keep)
        ? this.invoiceKey
        : invoiceKey as String?,
    installmentGroupId: identical(installmentGroupId, _keep)
        ? this.installmentGroupId
        : installmentGroupId as String?,
    installmentIndex: identical(installmentIndex, _keep)
        ? this.installmentIndex
        : installmentIndex as int?,
    installmentCount: identical(installmentCount, _keep)
        ? this.installmentCount
        : installmentCount as int?,
    recurringId: identical(recurringId, _keep)
        ? this.recurringId
        : recurringId as String?,
    notes: identical(notes, _keep) ? this.notes : notes as String?,
  );

  Map<String, dynamic> toMap() => {
    'id': id,
    'type': type.name,
    'amountCents': amountCents,
    'date': dateKey(date),
    'description': description,
    'categoryId': categoryId,
    'accountId': accountId,
    'cardId': cardId,
    'toAccountId': toAccountId,
    'status': status.name,
    'isBoleto': isBoleto,
    'invoiceKey': invoiceKey,
    'installmentGroupId': installmentGroupId,
    'installmentIndex': installmentIndex,
    'installmentCount': installmentCount,
    'recurringId': recurringId,
    'notes': notes,
  };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Transaction &&
          other.id == id &&
          other.type == type &&
          other.amountCents == amountCents &&
          other.date == date &&
          other.description == description &&
          other.categoryId == categoryId &&
          other.accountId == accountId &&
          other.cardId == cardId &&
          other.toAccountId == toAccountId &&
          other.status == status &&
          other.isBoleto == isBoleto &&
          other.invoiceKey == invoiceKey &&
          other.installmentGroupId == installmentGroupId &&
          other.installmentIndex == installmentIndex &&
          other.installmentCount == installmentCount &&
          other.recurringId == recurringId &&
          other.notes == notes;

  @override
  int get hashCode => Object.hash(
    id,
    type,
    amountCents,
    date,
    description,
    categoryId,
    accountId,
    cardId,
    toAccountId,
    status,
    isBoleto,
    invoiceKey,
    installmentGroupId,
    installmentIndex,
    installmentCount,
    recurringId,
    notes,
  );
}
