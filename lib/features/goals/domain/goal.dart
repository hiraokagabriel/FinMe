import '../../../core/utils/date_utils.dart';

/// Sentinela de `copyWith`: parâmetro omitido mantém o valor; `null` explícito limpa.
const Object _keep = Object();

/// Aporte (> 0) ou retirada (< 0) de uma meta. Não cria transação: só reserva dinheiro da conta.
class GoalMovement {
  GoalMovement({
    required this.id,
    required DateTime date,
    required this.amountCents,
    this.note,
  }) : date = dateOnly(date),
       assert(amountCents != 0, 'amountCents não pode ser zero');

  factory GoalMovement.fromMap(Map<String, dynamic> map) => GoalMovement(
    id: map['id'] as String,
    date: parseDateKey(map['date'] as String),
    amountCents: (map['amountCents'] as num).toInt(),
    note: map['note'] as String?,
  );

  final String id;
  final DateTime date;
  final int amountCents;
  final String? note;

  bool get isContribution => amountCents > 0;

  Map<String, dynamic> toMap() => {
    'id': id,
    'date': dateKey(date),
    'amountCents': amountCents,
    if (note != null) 'note': note,
  };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is GoalMovement &&
          other.id == id &&
          other.date == date &&
          other.amountCents == amountCents &&
          other.note == note;

  @override
  int get hashCode => Object.hash(id, date, amountCents, note);
}

/// Meta/caixinha: reserva virtual dentro de uma conta. `movements` ficam ordenados por (data, id).
/// Arquivada = reserva liberada (não entra em nenhuma conta).
class Goal {
  Goal({
    required this.id,
    required this.name,
    required this.accountId,
    required this.targetCents,
    DateTime? targetDate,
    List<GoalMovement> movements = const [],
    this.archived = false,
  }) : targetDate = targetDate == null ? null : dateOnly(targetDate),
       movements = _sortedMovements(movements),
       assert(targetCents > 0, 'targetCents deve ser maior que zero');

  /// Movimento inválido (campo ausente ou tipo errado) é ignorado; a meta é preservada.
  /// Alvo ≤ 0 lança [FormatException] (o repositório pula o registro no boot).
  factory Goal.fromMap(Map<String, dynamic> map) {
    final targetCents = (map['targetCents'] as num).toInt();
    if (targetCents <= 0) {
      throw const FormatException('Meta com alvo inválido');
    }
    return Goal(
      id: map['id'] as String,
      name: map['name'] as String,
      accountId: map['accountId'] as String,
      targetCents: targetCents,
      targetDate: map['targetDate'] == null
          ? null
          : parseDateKey(map['targetDate'] as String),
      movements: _parseMovements(map['movements']),
      archived: map['archived'] == true,
    );
  }

  final String id;
  final String name;
  final String accountId;
  final int targetCents;
  final DateTime? targetDate;
  final List<GoalMovement> movements;
  final bool archived;

  int get rawReservedCents =>
      movements.fold(0, (sum, m) => sum + m.amountCents);

  int get reservedCents {
    final raw = rawReservedCents;
    return raw < 0 ? 0 : raw;
  }

  int get remainingCents {
    final rest = targetCents - reservedCents;
    return rest < 0 ? 0 : rest;
  }

  double get progress => targetCents <= 0
      ? 0
      : (reservedCents / targetCents).clamp(0.0, 1.0).toDouble();

  bool get reached => reservedCents >= targetCents;

  Goal withMovement(GoalMovement movement) =>
      copyWith(movements: [...movements, movement]);

  Goal withoutMovement(String movementId) => copyWith(
    movements: [
      for (final m in movements)
        if (m.id != movementId) m,
    ],
  );

  Goal copyWith({
    String? name,
    String? accountId,
    int? targetCents,
    Object? targetDate = _keep,
    List<GoalMovement>? movements,
    bool? archived,
  }) => Goal(
    id: id,
    name: name ?? this.name,
    accountId: accountId ?? this.accountId,
    targetCents: targetCents ?? this.targetCents,
    targetDate: identical(targetDate, _keep)
        ? this.targetDate
        : targetDate as DateTime?,
    movements: movements ?? this.movements,
    archived: archived ?? this.archived,
  );

  Map<String, dynamic> toMap() => {
    'id': id,
    'name': name,
    'accountId': accountId,
    'targetCents': targetCents,
    if (targetDate != null) 'targetDate': dateKey(targetDate!),
    'movements': [for (final m in movements) m.toMap()],
    'archived': archived,
  };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Goal &&
          other.id == id &&
          other.name == name &&
          other.accountId == accountId &&
          other.targetCents == targetCents &&
          other.targetDate == targetDate &&
          other.archived == archived &&
          _sameMovements(other.movements, movements);

  @override
  int get hashCode => Object.hash(
    id,
    name,
    accountId,
    targetCents,
    targetDate,
    archived,
    Object.hashAll(movements),
  );
}

List<GoalMovement> _sortedMovements(List<GoalMovement> raw) =>
    List.unmodifiable(List<GoalMovement>.of(raw)..sort(_byDateThenId));

int _byDateThenId(GoalMovement a, GoalMovement b) {
  final byDate = a.date.compareTo(b.date);
  return byDate != 0 ? byDate : a.id.compareTo(b.id);
}

bool _sameMovements(List<GoalMovement> a, List<GoalMovement> b) {
  if (a.length != b.length) {
    return false;
  }
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) {
      return false;
    }
  }
  return true;
}

List<GoalMovement> _parseMovements(Object? raw) {
  if (raw is! List) {
    return const [];
  }
  final movements = <GoalMovement>[];
  for (final item in raw) {
    if (item is! Map) {
      continue;
    }
    try {
      movements.add(GoalMovement.fromMap(Map<String, dynamic>.from(item)));
    } on Object {
      // Item inválido: ignorado para não perder a meta inteira.
    }
  }
  return movements;
}
