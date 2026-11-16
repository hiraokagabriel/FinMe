import '../../../core/utils/date_utils.dart';
import '../../../core/utils/enum_utils.dart';

/// Sentinela de `copyWith`: parâmetro omitido mantém o valor; `null` explícito limpa.
const Object _keep = Object();

/// `iOwe` é o primeiro: valor desconhecido em `fromMap` cai no lado conservador (a pagar).
enum DebtDirection { iOwe, owedToMe }

/// Pagamento (quitação total ou parcial) de uma dívida. [transactionId] é a transação
/// criada na quitação; null só em dado antigo/importado sem ela.
class DebtPayment {
  DebtPayment({
    required this.id,
    required DateTime date,
    required this.amountCents,
    this.transactionId,
  }) : date = dateOnly(date),
       assert(amountCents > 0, 'amountCents deve ser maior que zero');

  /// Dado inválido (campo ausente, tipo errado ou valor ≤ 0) lança [FormatException].
  factory DebtPayment.fromMap(Map<String, dynamic> map) {
    final amountCents = _intField(map, 'amountCents');
    if (amountCents <= 0) {
      throw const FormatException('Pagamento de dívida com valor inválido');
    }
    return DebtPayment(
      id: _stringField(map, 'id'),
      date: parseDateKey(_stringField(map, 'date')),
      amountCents: amountCents,
      transactionId: _optionalString(map, 'transactionId'),
    );
  }

  final String id;
  final DateTime date;
  final int amountCents;
  final String? transactionId;

  Map<String, dynamic> toMap() => {
    'id': id,
    'date': dateKey(date),
    'amountCents': amountCents,
    if (transactionId != null) 'transactionId': transactionId,
  };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DebtPayment &&
          other.id == id &&
          other.date == date &&
          other.amountCents == amountCents &&
          other.transactionId == transactionId;

  @override
  int get hashCode => Object.hash(id, date, amountCents, transactionId);
}

/// Valor combinado com uma pessoa (texto livre). Registrar não cria transação; cada pagamento cria uma.
class Debt {
  Debt({
    required this.id,
    required String person,
    required this.direction,
    required this.amountCents,
    required DateTime date,
    String? description,
    DateTime? dueDate,
    List<DebtPayment> payments = const [],
  }) : person = person.trim(),
       date = dateOnly(date),
       description = _cleanDescription(description),
       dueDate = dueDate == null ? null : dateOnly(dueDate),
       payments = _sortedPayments(payments),
       assert(amountCents > 0, 'amountCents deve ser maior que zero');

  /// Pessoa em branco ou valor ≤ 0 lança [FormatException] (o repositório pula o registro no boot).
  /// Pagamento inválido é ignorado; a dívida é preservada.
  factory Debt.fromMap(Map<String, dynamic> map) {
    final person = _stringField(map, 'person').trim();
    final amountCents = _intField(map, 'amountCents');
    if (person.isEmpty || amountCents <= 0) {
      throw const FormatException('Dívida com pessoa ou valor inválido');
    }
    return Debt(
      id: _stringField(map, 'id'),
      person: person,
      direction: enumByName(DebtDirection.values, map['direction']),
      amountCents: amountCents,
      date: parseDateKey(_stringField(map, 'date')),
      description: _optionalString(map, 'description'),
      dueDate: map['dueDate'] == null
          ? null
          : parseDateKey(_stringField(map, 'dueDate')),
      payments: _parsePayments(map['payments']),
    );
  }

  final String id;
  final String person;
  final DebtDirection direction;

  /// Valor total combinado.
  final int amountCents;

  /// Data em que a dívida passou a existir.
  final DateTime date;
  final String? description;
  final DateTime? dueDate;

  /// Ordenados por (data, id); lista imutável.
  final List<DebtPayment> payments;

  int get paidCents => payments.fold(0, (sum, p) => sum + p.amountCents);

  int get remainingCents {
    final rest = amountCents - paidCents;
    return rest < 0 ? 0 : rest;
  }

  /// "Quitado" é derivado do restante; não há flag gravada.
  bool get settled => remainingCents == 0;

  /// Restante na data [d]: 0 antes do registro da dívida; senão valor − pagamentos até [d].
  int remainingAt(DateTime d) {
    final day = dateOnly(d);
    if (day.isBefore(date)) {
      return 0;
    }
    var paid = 0;
    for (final p in payments) {
      if (!p.date.isAfter(day)) {
        paid += p.amountCents;
      }
    }
    final rest = amountCents - paid;
    return rest < 0 ? 0 : rest;
  }

  Debt withPayment(DebtPayment payment) =>
      copyWith(payments: [...payments, payment]);

  Debt withoutPayment(String paymentId) => copyWith(
    payments: [
      for (final p in payments)
        if (p.id != paymentId) p,
    ],
  );

  Debt copyWith({
    String? person,
    DebtDirection? direction,
    int? amountCents,
    DateTime? date,
    Object? description = _keep,
    Object? dueDate = _keep,
    List<DebtPayment>? payments,
  }) => Debt(
    id: id,
    person: person ?? this.person,
    direction: direction ?? this.direction,
    amountCents: amountCents ?? this.amountCents,
    date: date ?? this.date,
    description: identical(description, _keep)
        ? this.description
        : description as String?,
    dueDate: identical(dueDate, _keep) ? this.dueDate : dueDate as DateTime?,
    payments: payments ?? this.payments,
  );

  Map<String, dynamic> toMap() => {
    'id': id,
    'person': person,
    'direction': direction.name,
    'amountCents': amountCents,
    'date': dateKey(date),
    if (description != null) 'description': description,
    if (dueDate != null) 'dueDate': dateKey(dueDate!),
    'payments': [for (final p in payments) p.toMap()],
  };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Debt &&
          other.id == id &&
          other.person == person &&
          other.direction == direction &&
          other.amountCents == amountCents &&
          other.date == date &&
          other.description == description &&
          other.dueDate == dueDate &&
          _samePayments(other.payments, payments);

  @override
  int get hashCode => Object.hash(
    id,
    person,
    direction,
    amountCents,
    date,
    description,
    dueDate,
    Object.hashAll(payments),
  );
}

String? _cleanDescription(String? raw) {
  final trimmed = raw?.trim();
  return trimmed == null || trimmed.isEmpty ? null : trimmed;
}

List<DebtPayment> _sortedPayments(List<DebtPayment> raw) =>
    List.unmodifiable(List<DebtPayment>.of(raw)..sort(_byDateThenId));

int _byDateThenId(DebtPayment a, DebtPayment b) {
  final byDate = a.date.compareTo(b.date);
  return byDate != 0 ? byDate : a.id.compareTo(b.id);
}

bool _samePayments(List<DebtPayment> a, List<DebtPayment> b) {
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

List<DebtPayment> _parsePayments(Object? raw) {
  if (raw is! List) {
    return const [];
  }
  final payments = <DebtPayment>[];
  for (final item in raw) {
    if (item is! Map) {
      continue;
    }
    try {
      payments.add(DebtPayment.fromMap(Map<String, dynamic>.from(item)));
    } on FormatException {
      // Pagamento inválido: ignorado para não perder a dívida inteira.
    }
  }
  return payments;
}

String _stringField(Map<String, dynamic> map, String key) {
  final value = map[key];
  if (value is! String || value.isEmpty) {
    throw FormatException('Campo "$key" ausente ou inválido');
  }
  return value;
}

String? _optionalString(Map<String, dynamic> map, String key) {
  final value = map[key];
  if (value == null) {
    return null;
  }
  if (value is! String) {
    throw FormatException('Campo "$key" com tipo inválido');
  }
  return value;
}

int _intField(Map<String, dynamic> map, String key) {
  final value = map[key];
  if (value is! int) {
    throw FormatException('Campo "$key" deve ser inteiro');
  }
  return value;
}
