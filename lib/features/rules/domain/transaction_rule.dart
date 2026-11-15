import '../../../core/utils/enum_utils.dart';

/// Sentinela de `copyWith`: parâmetro omitido mantém o campo; `null` limpa; valor troca.
const Object _keep = Object();

/// Como o `pattern` casa com o assunto da transação: texto (contém/começa com) ou regex.
enum RuleMatchType { contains, startsWith, regex }

/// Regra de categorização e renomeação. Menor `priority` vence; empate por `id`.
class TransactionRule {
  const TransactionRule({
    required this.id,
    required this.pattern,
    this.matchType = RuleMatchType.contains,
    this.categoryId,
    this.renameTo,
    this.priority = 0,
    this.active = true,
  });

  factory TransactionRule.fromMap(Map<String, dynamic> map) => TransactionRule(
    id: map['id'] as String,
    pattern: map['pattern'] as String,
    matchType: enumByName(RuleMatchType.values, map['matchType']),
    categoryId: map['categoryId'] as String?,
    renameTo: map['renameTo'] as String?,
    priority: (map['priority'] as num?)?.toInt() ?? 0,
    active: map['active'] != false,
  );

  final String id;
  final String pattern;
  final RuleMatchType matchType;

  /// Categoria a aplicar; null = a regra só renomeia.
  final String? categoryId;

  /// Descrição final; null ou vazio = não renomeia.
  final String? renameTo;
  final int priority;
  final bool active;

  TransactionRule copyWith({
    String? pattern,
    RuleMatchType? matchType,
    Object? categoryId = _keep,
    Object? renameTo = _keep,
    int? priority,
    bool? active,
  }) => TransactionRule(
    id: id,
    pattern: pattern ?? this.pattern,
    matchType: matchType ?? this.matchType,
    categoryId: identical(categoryId, _keep)
        ? this.categoryId
        : categoryId as String?,
    renameTo: identical(renameTo, _keep) ? this.renameTo : renameTo as String?,
    priority: priority ?? this.priority,
    active: active ?? this.active,
  );

  Map<String, dynamic> toMap() => {
    'id': id,
    'pattern': pattern,
    'matchType': matchType.name,
    'categoryId': categoryId,
    'renameTo': renameTo,
    'priority': priority,
    'active': active,
  };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TransactionRule &&
          other.id == id &&
          other.pattern == pattern &&
          other.matchType == matchType &&
          other.categoryId == categoryId &&
          other.renameTo == renameTo &&
          other.priority == priority &&
          other.active == active;

  @override
  int get hashCode => Object.hash(
    id,
    pattern,
    matchType,
    categoryId,
    renameTo,
    priority,
    active,
  );
}
