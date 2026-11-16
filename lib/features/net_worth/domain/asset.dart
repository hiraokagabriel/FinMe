import '../../../core/utils/date_utils.dart';
import '../../../core/utils/enum_utils.dart';

/// Sentinela de `copyWith`: parâmetro omitido mantém o valor; `null` explícito limpa.
const Object _keep = Object();

/// Primeiro valor é o fallback de `fromMap` (kind desconhecido → investment).
enum AssetKind { investment, realEstate, vehicle, other }

String assetKindLabel(AssetKind kind) => switch (kind) {
  AssetKind.investment => 'Investimento',
  AssetKind.realEstate => 'Imóvel',
  AssetKind.vehicle => 'Veículo',
  AssetKind.other => 'Outro',
};

/// Valor declarado de um ativo numa data. Valor 0 é válido (encerramento); a validação de escrita fica em [assetSnapshotError].
class AssetSnapshot {
  AssetSnapshot({
    required this.id,
    required DateTime date,
    required this.valueCents,
    this.note,
  }) : date = dateOnly(date);

  /// Lança [FormatException] para id/data/valor ausentes ou inválidos (valor negativo ou fracionado).
  factory AssetSnapshot.fromMap(Map<String, dynamic> map) => AssetSnapshot(
    id: _requireString(map, 'id'),
    date: _requireDate(map['date']),
    valueCents: _requireCents(map['valueCents']),
    note: _optionalString(map['note']),
  );

  final String id;
  final DateTime date;
  final int valueCents;
  final String? note;

  AssetSnapshot copyWith({
    DateTime? date,
    int? valueCents,
    Object? note = _keep,
  }) => AssetSnapshot(
    id: id,
    date: date ?? this.date,
    valueCents: valueCents ?? this.valueCents,
    note: identical(note, _keep) ? this.note : note as String?,
  );

  Map<String, dynamic> toMap() => {
    'id': id,
    'date': dateKey(date),
    'valueCents': valueCents,
    if (note != null) 'note': note,
  };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AssetSnapshot &&
          other.id == id &&
          other.date == date &&
          other.valueCents == valueCents &&
          other.note == note;

  @override
  int get hashCode => Object.hash(id, date, valueCents, note);
}

/// Ativo manual (fora das contas). Snapshots ficam ordenados por data, no máximo um por data;
/// o valor numa data é o do último snapshot até ela. `archived` = encerrado (só sai da lista padrão).
class Asset {
  Asset({
    required this.id,
    required this.name,
    required this.kind,
    List<AssetSnapshot> snapshots = const [],
    this.archived = false,
  }) : snapshots = _normalizeSnapshots(snapshots);

  /// Snapshot inválido é ignorado; a ausência de id/nome/kind lança [FormatException].
  factory Asset.fromMap(Map<String, dynamic> map) => Asset(
    id: _requireString(map, 'id'),
    name: _requireString(map, 'name'),
    kind: enumByName(AssetKind.values, map['kind']),
    snapshots: _parseSnapshots(map['snapshots']),
    archived: map['archived'] == true,
  );

  final String id;
  final String name;
  final AssetKind kind;
  final List<AssetSnapshot> snapshots;
  final bool archived;

  AssetSnapshot? get latest => snapshots.isEmpty ? null : snapshots.last;

  int get currentValueCents => latest?.valueCents ?? 0;

  int? get lastChangeCents => snapshots.length < 2
      ? null
      : snapshots.last.valueCents - snapshots[snapshots.length - 2].valueCents;

  /// Valor do último snapshot com data <= [date]; antes do primeiro snapshot vale 0.
  int valueAt(DateTime date) {
    final day = dateOnly(date);
    for (var i = snapshots.length - 1; i >= 0; i--) {
      if (snapshots[i].date.compareTo(day) <= 0) {
        return snapshots[i].valueCents;
      }
    }
    return 0;
  }

  /// Snapshot com a mesma data é substituído (o novo vence, pela regra de [_normalizeSnapshots]).
  Asset withSnapshot(AssetSnapshot snapshot) =>
      copyWith(snapshots: [...snapshots, snapshot]);

  Asset withoutSnapshot(String snapshotId) => copyWith(
    snapshots: [
      for (final s in snapshots)
        if (s.id != snapshotId) s,
    ],
  );

  Asset copyWith({
    String? name,
    AssetKind? kind,
    List<AssetSnapshot>? snapshots,
    bool? archived,
  }) => Asset(
    id: id,
    name: name ?? this.name,
    kind: kind ?? this.kind,
    snapshots: snapshots ?? this.snapshots,
    archived: archived ?? this.archived,
  );

  Map<String, dynamic> toMap() => {
    'id': id,
    'name': name,
    'kind': kind.name,
    'snapshots': [for (final s in snapshots) s.toMap()],
    'archived': archived,
  };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Asset &&
          other.id == id &&
          other.name == name &&
          other.kind == kind &&
          other.archived == archived &&
          _sameSnapshots(other.snapshots, snapshots);

  @override
  int get hashCode =>
      Object.hash(id, name, kind, archived, Object.hashAll(snapshots));
}

/// Mensagem de erro ao gravar um valor, ou null se válido (SPEC §5.24).
String? assetSnapshotError({
  required int valueCents,
  required DateTime date,
  required DateTime today,
}) {
  if (valueCents < 0) {
    return 'Informe um valor maior ou igual a zero';
  }
  if (dateOnly(date).isAfter(dateOnly(today))) {
    return 'A data não pode ser no futuro';
  }
  return null;
}

/// Erro ao remover um snapshot: o último valor do ativo não pode sair (SPEC §5.24).
String? removeSnapshotError(Asset asset, String snapshotId) {
  final exists = asset.snapshots.any((s) => s.id == snapshotId);
  if (exists && asset.snapshots.length <= 1) {
    return 'O ativo precisa de pelo menos um valor';
  }
  return null;
}

/// Encerra o ativo: snapshot de valor 0 na [date] e `archived`. Histórico anterior continua valendo.
Asset closeAsset(
  Asset asset, {
  required DateTime date,
  required String snapshotId,
}) => asset
    .withSnapshot(
      AssetSnapshot(
        id: snapshotId,
        date: date,
        valueCents: 0,
        note: 'Encerrado',
      ),
    )
    .copyWith(archived: true);

/// Soma do valor de todos os ativos numa data, encerrados inclusive (SPEC §5.24).
int assetsValueAt(Iterable<Asset> assets, DateTime date) =>
    assets.fold(0, (sum, asset) => sum + asset.valueAt(date));

String _requireString(Map<String, dynamic> map, String key) {
  final value = map[key];
  if (value is! String) {
    throw FormatException('Ativo com "$key" inválido');
  }
  return value;
}

DateTime _requireDate(Object? value) {
  if (value is! String) {
    throw const FormatException('Snapshot de ativo sem data');
  }
  return parseDateKey(value);
}

String? _optionalString(Object? value) {
  if (value != null && value is! String) {
    throw const FormatException('Snapshot de ativo com nota inválida');
  }
  return value as String?;
}

int _requireCents(Object? value) {
  if (value is! num || !value.isFinite || value < 0 || value % 1 != 0) {
    throw const FormatException('Snapshot de ativo com valor inválido');
  }
  return value.toInt();
}

/// Ordena por data e mantém um snapshot por data: vale o último da lista recebida.
List<AssetSnapshot> _normalizeSnapshots(List<AssetSnapshot> raw) {
  final byDate = <String, AssetSnapshot>{};
  for (final snapshot in raw) {
    byDate[dateKey(snapshot.date)] = snapshot;
  }
  final sorted = byDate.values.toList()
    ..sort((a, b) => a.date.compareTo(b.date));
  return List.unmodifiable(sorted);
}

List<AssetSnapshot> _parseSnapshots(Object? raw) {
  if (raw is! List) {
    return const [];
  }
  final snapshots = <AssetSnapshot>[];
  for (final item in raw) {
    if (item is! Map) {
      continue;
    }
    try {
      snapshots.add(AssetSnapshot.fromMap(Map<String, dynamic>.from(item)));
    } on Object {
      // Snapshot inválido: ignorado para não perder o ativo inteiro.
    }
  }
  return snapshots;
}

bool _sameSnapshots(List<AssetSnapshot> a, List<AssetSnapshot> b) {
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
