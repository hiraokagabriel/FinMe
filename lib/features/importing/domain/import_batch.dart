// Lote de importação: ids criados e versões anteriores, para desfazer. Contrato: docs/SPEC.md §9.4.

import '../../transactions/domain/transaction.dart';
import 'import_session.dart';

/// Lotes guardados; os mais antigos são podados.
const int kImportBatchesKept = 10;

class ImportBatch {
  ImportBatch({
    required this.id,
    required this.createdAt,
    required this.label,
    this.accountId,
    this.cardId,
    List<String> createdIds = const [],
    List<Transaction> previous = const [],
  }) : createdIds = List.unmodifiable(createdIds),
       previous = List.unmodifiable(previous);

  /// Lê um lote salvo. Id ou data inválidos → [FormatException]; o resto degrada para vazio.
  factory ImportBatch.fromMap(Map<String, dynamic> map) {
    final id = map['id'];
    final rawDate = map['createdAt'];
    final createdAt = rawDate is String ? DateTime.tryParse(rawDate) : null;
    if (id is! String || createdAt == null) {
      throw const FormatException('Lote de importação sem id ou data válida');
    }
    final createdIds = map['createdIds'];
    final previous = map['previous'];
    return ImportBatch(
      id: id,
      createdAt: createdAt,
      label: map['label'] is String ? map['label'] as String : '',
      accountId: _text(map['accountId']),
      cardId: _text(map['cardId']),
      createdIds: createdIds is List
          ? createdIds.whereType<String>().toList()
          : const [],
      previous: previous is List
          ? [for (final raw in previous) ?_transactionFrom(raw)]
          : const [],
    );
  }

  final String id;

  /// Com horário; ordena o histórico.
  final DateTime createdAt;

  /// Nome do arquivo importado.
  final String label;

  /// Destino da importação (`ImportTarget`).
  final String? accountId;
  final String? cardId;

  /// Ids de `plan.create`, na ordem do plano (inclui parcelas futuras e pagamentos de fatura).
  final List<String> createdIds;

  /// Versão anterior de cada provisionado confirmado (`plan.update`).
  final List<Transaction> previous;

  int get createdCount => createdIds.length;
  int get confirmedCount => previous.length;

  Map<String, dynamic> toMap() => {
    'id': id,
    'createdAt': createdAt.toIso8601String(),
    'label': label,
    if (accountId != null) 'accountId': accountId,
    if (cardId != null) 'cardId': cardId,
    'createdIds': createdIds,
    'previous': [for (final t in previous) t.toMap()],
  };
}

String? _text(Object? raw) => raw is String ? raw : null;

/// Transação de um mapa salvo; inválida → null (o item é ignorado).
Transaction? _transactionFrom(Object? raw) {
  if (raw is! Map) {
    return null;
  }
  try {
    return Transaction.fromMap(Map<String, dynamic>.from(raw));
  } on Object {
    return null;
  }
}

/// Lote de um plano gravado. `previous` vem de `before`, pelo id de cada `plan.update`.
ImportBatch importBatchFor(
  ImportPlan plan, {
  required String id,
  required DateTime createdAt,
  required String label,
  required ImportTarget target,
  required Iterable<Transaction> before,
}) {
  final byId = {for (final t in before) t.id: t};
  return ImportBatch(
    id: id,
    createdAt: createdAt,
    label: label,
    accountId: target.accountId,
    cardId: target.cardId,
    createdIds: [for (final t in plan.create) t.id],
    previous: [for (final t in plan.update) ?byId[t.id]],
  );
}

/// Mais recente primeiro: `createdAt` maior; empate, id maior.
int _newestFirst(ImportBatch a, ImportBatch b) {
  final byDate = b.createdAt.compareTo(a.createdAt);
  return byDate != 0 ? byDate : b.id.compareTo(a.id);
}

List<ImportBatch> _sortedNewestFirst(Iterable<ImportBatch> batches) =>
    [...batches]..sort(_newestFirst);

/// Lote mais recente (o único que pode ser desfeito); vazio → null.
ImportBatch? latestImportBatch(Iterable<ImportBatch> batches) {
  final sorted = _sortedNewestFirst(batches);
  return sorted.isEmpty ? null : sorted.first;
}

/// Ids dos lotes além dos `keep` mais recentes.
List<String> importBatchesToPrune(
  Iterable<ImportBatch> batches, {
  int keep = kImportBatchesKept,
}) => [for (final b in _sortedNewestFirst(batches).skip(keep)) b.id];

/// Plano de desfazer. `deleteIds`: criados que ainda existem. `restore`: versões anteriores
/// cujo id ainda existe (transação excluída depois da importação não volta).
({List<String> deleteIds, List<Transaction> restore}) importUndoPlan(
  ImportBatch batch,
  Iterable<Transaction> current,
) {
  final ids = {for (final t in current) t.id};
  return (
    deleteIds: [
      for (final id in batch.createdIds)
        if (ids.contains(id)) id,
    ],
    restore: [
      for (final t in batch.previous)
        if (ids.contains(t.id)) t,
    ],
  );
}
