import 'package:finme/features/importing/domain/import_batch.dart';
import 'package:finme/features/importing/domain/import_session.dart';
import 'package:finme/features/transactions/domain/transaction.dart';
import 'package:flutter_test/flutter_test.dart';

final _at = DateTime(2026, 11, 10, 9);

Transaction _tx(
  String id, {
  TransactionStatus status = TransactionStatus.paid,
  List<String> tags = const [],
  String? externalId,
}) => Transaction(
  id: id,
  type: TransactionType.expense,
  amountCents: 1000,
  date: DateTime(2026, 11, 5),
  description: 'Mercado $id',
  accountId: 'acc',
  status: status,
  externalId: externalId,
  tags: tags,
);

ImportBatch _batch(
  String id, {
  DateTime? createdAt,
  List<String> created = const [],
  List<Transaction> previous = const [],
}) => ImportBatch(
  id: id,
  createdAt: createdAt ?? _at,
  label: 'extrato.ofx',
  accountId: 'acc',
  createdIds: created,
  previous: previous,
);

void main() {
  group('importBatchFor', () {
    test('guarda ids criados e versões planned dos provisionados', () {
      final p = _tx('p', status: TransactionStatus.planned);
      final plan = ImportPlan(
        create: [_tx('a'), _tx('b')],
        update: [_tx('p', status: TransactionStatus.paid)],
      );
      final batch = importBatchFor(
        plan,
        id: 'lote',
        createdAt: _at,
        label: 'extrato.ofx',
        target: const ImportTarget(accountId: 'acc'),
        before: [p, _tx('outra')],
      );
      expect(batch.createdIds, ['a', 'b']);
      expect(batch.previous, [p]);
      expect(batch.createdCount, 2);
      expect(batch.confirmedCount, 1);
      expect(batch.accountId, 'acc');
      expect(batch.cardId, isNull);
    });

    test('update cujo id não estava em before é ignorado', () {
      final plan = ImportPlan(create: const [], update: [_tx('fantasma')]);
      final batch = importBatchFor(
        plan,
        id: 'lote',
        createdAt: _at,
        label: 'x',
        target: const ImportTarget(accountId: 'acc'),
        before: [_tx('p', status: TransactionStatus.planned)],
      );
      expect(batch.previous, isEmpty);
      expect(batch.confirmedCount, 0);
    });
  });

  group('toMap / fromMap', () {
    test('ida e volta preserva previous com tags e externalId', () {
      final original = ImportBatch(
        id: 'lote',
        createdAt: _at,
        label: 'extrato.ofx',
        cardId: 'card',
        createdIds: const ['a', 'b'],
        previous: [
          _tx(
            'p',
            status: TransactionStatus.planned,
            tags: const ['viagem'],
            externalId: 'FIT1',
          ),
        ],
      );
      final back = ImportBatch.fromMap(original.toMap());
      expect(back.id, 'lote');
      expect(back.createdAt, _at);
      expect(back.label, 'extrato.ofx');
      expect(back.accountId, isNull);
      expect(back.cardId, 'card');
      expect(back.createdIds, ['a', 'b']);
      expect(back.previous.single, original.previous.single);
      expect(back.previous.single.tags, ['viagem']);
      expect(back.previous.single.externalId, 'FIT1');
      expect(back.toMap(), original.toMap());
    });

    test('createdAt inválido → FormatException', () {
      final map = _batch('x').toMap()..['createdAt'] = 'não é data';
      expect(() => ImportBatch.fromMap(map), throwsFormatException);
    });

    test('createdIds não-lista → vazio; itens não String ignorados', () {
      final map = _batch('x').toMap()..['createdIds'] = 'a';
      expect(ImportBatch.fromMap(map).createdIds, isEmpty);
      final mixed = _batch('x', created: const ['a']).toMap()
        ..['createdIds'] = ['a', 3];
      expect(ImportBatch.fromMap(mixed).createdIds, ['a']);
    });

    test('item inválido de previous é ignorado', () {
      final map = _batch('x', previous: [_tx('p')]).toMap()
        ..['previous'] = [
          _tx('p').toMap(),
          {'id': 'q'},
          'lixo',
        ];
      expect(ImportBatch.fromMap(map).previous.map((t) => t.id), ['p']);
    });
  });

  group('importUndoPlan', () {
    final batch = _batch(
      'lote',
      created: const ['a', 'b'],
      previous: [_tx('p', status: TransactionStatus.planned)],
    );

    test('caso normal: apaga a e b, restaura p', () {
      final current = [_tx('a'), _tx('b'), _tx('p')];
      final plan = importUndoPlan(batch, current);
      expect(plan.deleteIds, ['a', 'b']);
      expect(plan.restore.map((t) => t.id), ['p']);
    });

    test('a excluída depois não entra em deleteIds', () {
      final plan = importUndoPlan(batch, [_tx('b'), _tx('p')]);
      expect(plan.deleteIds, ['b']);
    });

    test('p excluído depois não é restaurado', () {
      final plan = importUndoPlan(batch, [_tx('a'), _tx('b')]);
      expect(plan.restore, isEmpty);
    });
  });

  group('latestImportBatch e poda', () {
    test('escolhe o maior createdAt; empate, maior id; vazio → null', () {
      expect(latestImportBatch(const []), isNull);
      final older = _batch('z', createdAt: DateTime(2026, 11, 1));
      final newer = _batch('a', createdAt: DateTime(2026, 11, 2));
      expect(latestImportBatch([older, newer])!.id, 'a');
      final tieLow = _batch('a');
      final tieHigh = _batch('b');
      expect(latestImportBatch([tieLow, tieHigh])!.id, 'b');
    });

    test('12 lotes → poda os 2 mais antigos', () {
      final batches = [
        for (var i = 1; i <= 12; i++)
          _batch('l$i', createdAt: DateTime(2026, 11, i)),
      ];
      final pruned = importBatchesToPrune(batches);
      expect(pruned, unorderedEquals(['l1', 'l2']));
      expect(kImportBatchesKept, 10);
    });
  });
}
