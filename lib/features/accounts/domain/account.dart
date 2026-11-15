import '../../../core/utils/enum_utils.dart';

enum AccountType { checking, savings, cash, investment, wallet }

/// Conta de caixa. `bankName` vazio para carteira/dinheiro.
class Account {
  const Account({
    required this.id,
    required this.name,
    required this.bankName,
    required this.type,
    required this.initialBalanceCents,
    required this.colorValue,
    this.archived = false,
  });

  factory Account.fromMap(Map<String, dynamic> map) => Account(
    id: map['id'] as String,
    name: map['name'] as String,
    bankName: map['bankName'] as String,
    type: enumByName(AccountType.values, map['type']),
    initialBalanceCents: (map['initialBalanceCents'] as num).toInt(),
    colorValue: (map['colorValue'] as num).toInt(),
    archived: map['archived'] == true,
  );

  final String id;
  final String name;
  final String bankName;
  final AccountType type;
  final int initialBalanceCents;
  final int colorValue;
  final bool archived;

  Account copyWith({
    String? name,
    String? bankName,
    AccountType? type,
    int? initialBalanceCents,
    int? colorValue,
    bool? archived,
  }) => Account(
    id: id,
    name: name ?? this.name,
    bankName: bankName ?? this.bankName,
    type: type ?? this.type,
    initialBalanceCents: initialBalanceCents ?? this.initialBalanceCents,
    colorValue: colorValue ?? this.colorValue,
    archived: archived ?? this.archived,
  );

  Map<String, dynamic> toMap() => {
    'id': id,
    'name': name,
    'bankName': bankName,
    'type': type.name,
    'initialBalanceCents': initialBalanceCents,
    'colorValue': colorValue,
    'archived': archived,
  };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Account &&
          other.id == id &&
          other.name == name &&
          other.bankName == bankName &&
          other.type == type &&
          other.initialBalanceCents == initialBalanceCents &&
          other.colorValue == colorValue &&
          other.archived == archived;

  @override
  int get hashCode => Object.hash(
    id,
    name,
    bankName,
    type,
    initialBalanceCents,
    colorValue,
    archived,
  );
}
