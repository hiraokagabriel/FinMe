import '../../../core/utils/date_utils.dart';
import '../../../core/utils/enum_utils.dart';

/// Sentinela de `copyWith`: parâmetro omitido mantém o valor; `null` explícito limpa.
const Object _keep = Object();

enum CardBrand { visa, mastercard, elo, amex, hipercard, other }

enum CardKind { credit, debit }

/// Ciclo anterior de fechamento/vencimento. Vale para compras com data < [until] (exclusivo).
class CardCycle {
  const CardCycle({
    required this.until,
    required this.closingDay,
    required this.dueDay,
  });

  factory CardCycle.fromMap(Map<String, dynamic> map) => CardCycle(
    until: parseDateKey(map['until'] as String),
    closingDay: (map['closingDay'] as num).toInt(),
    dueDay: (map['dueDay'] as num).toInt(),
  );

  final DateTime until;
  final int closingDay;
  final int dueDay;

  Map<String, dynamic> toMap() => {
    'until': dateKey(until),
    'closingDay': closingDay,
    'dueDay': dueDay,
  };

  @override
  bool operator ==(Object other) =>
      other is CardCycle &&
      other.until == until &&
      other.closingDay == closingDay &&
      other.dueDay == dueDay;

  @override
  int get hashCode => Object.hash(until, closingDay, dueDay);
}

/// Cartão de crédito ou débito. `closingDay`/`dueDay` só valem para crédito
/// (em débito são ignorados) e são o ciclo **atual**. `paymentAccountId`: crédito = conta que paga a
/// fatura; débito = conta debitada. `cycleHistory`: ciclos anteriores, ordenados por `until`.
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
    this.cycleHistory = const [],
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
    cycleHistory: _parseCycles(map['cycleHistory']),
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
  final List<CardCycle> cycleHistory;

  /// Dias de fechamento/vencimento que valem para uma compra em [date].
  ({int closingDay, int dueDay}) cycleOn(DateTime date) {
    final day = dateOnly(date);
    for (final cycle in cycleHistory) {
      if (day.isBefore(cycle.until)) {
        return (closingDay: cycle.closingDay, dueDay: cycle.dueDay);
      }
    }
    return (closingDay: closingDay, dueDay: dueDay);
  }

  /// Muda fechamento/vencimento a partir de [effectiveFrom], sem reescrever faturas passadas.
  /// Dias iguais aos atuais → this. Data não posterior ao último `until` → [ArgumentError].
  PaymentCard withCycleChange({
    required int closingDay,
    required int dueDay,
    required DateTime effectiveFrom,
  }) {
    if (closingDay == this.closingDay && dueDay == this.dueDay) {
      return this;
    }
    final until = dateOnly(effectiveFrom);
    if (cycleHistory.isNotEmpty && !until.isAfter(cycleHistory.last.until)) {
      throw ArgumentError.value(
        effectiveFrom,
        'effectiveFrom',
        'deve ser posterior a ${dateKey(cycleHistory.last.until)}',
      );
    }
    return copyWith(
      closingDay: closingDay,
      dueDay: dueDay,
      cycleHistory: [
        ...cycleHistory,
        CardCycle(
          until: until,
          closingDay: this.closingDay,
          dueDay: this.dueDay,
        ),
      ],
    );
  }

  PaymentCard copyWith({
    String? name,
    String? bankName,
    CardBrand? brand,
    CardKind? kind,
    String? last4,
    int? limitCents,
    int? closingDay,
    int? dueDay,
    Object? paymentAccountId = _keep,
    int? colorValue,
    bool? archived,
    List<CardCycle>? cycleHistory,
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
    paymentAccountId: paymentAccountId == _keep
        ? this.paymentAccountId
        : paymentAccountId as String?,
    colorValue: colorValue ?? this.colorValue,
    archived: archived ?? this.archived,
    cycleHistory: cycleHistory ?? this.cycleHistory,
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
    'cycleHistory': [for (final cycle in cycleHistory) cycle.toMap()],
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
          other.archived == archived &&
          _sameCycles(other.cycleHistory, cycleHistory);

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
    Object.hashAll(cycleHistory),
  );
}

/// Itens malformados são ignorados; ausente, `null` ou não-lista → vazio (backups antigos).
List<CardCycle> _parseCycles(Object? raw) {
  if (raw is! List) {
    return const [];
  }
  final cycles = <CardCycle>[];
  for (final item in raw) {
    if (item is! Map) {
      continue;
    }
    try {
      cycles.add(CardCycle.fromMap(Map<String, dynamic>.from(item)));
    } on Object {
      // Item inválido: ignorado para não perder o cartão inteiro.
    }
  }
  // cycleOn depende da ordem por until (primeiro ciclo que cobre a data vence).
  cycles.sort((a, b) => a.until.compareTo(b.until));
  return cycles;
}

bool _sameCycles(List<CardCycle> a, List<CardCycle> b) {
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
