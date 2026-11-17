import 'package:finme/features/net_worth/domain/asset.dart';
import 'package:flutter_test/flutter_test.dart';

final _today = DateTime(2026, 11, 15);

/// SPEC §5.24: 'Carro' com 01/08 → 4000000 e 01/11 → 3800000.
Asset carro({bool archived = false}) => Asset(
  id: 'carro',
  name: 'Carro',
  kind: AssetKind.vehicle,
  archived: archived,
  snapshots: [
    AssetSnapshot(id: 's1', date: DateTime(2026, 8, 1), valueCents: 4000000),
    AssetSnapshot(id: 's2', date: DateTime(2026, 11, 1), valueCents: 3800000),
  ],
);

/// SPEC §5.24: 'Tesouro' com 10/10 → 200000.
Asset tesouro() => Asset(
  id: 'tesouro',
  name: 'Tesouro',
  kind: AssetKind.investment,
  snapshots: [
    AssetSnapshot(id: 't1', date: DateTime(2026, 10, 10), valueCents: 200000),
  ],
);

void main() {
  group('valor por data (SPEC §5.24)', () {
    test('valueAt usa o último snapshot até a data, sem interpolação', () {
      final c = carro();
      expect(c.valueAt(DateTime(2026, 7, 31)), 0);
      expect(c.valueAt(DateTime(2026, 8, 1)), 4000000);
      expect(c.valueAt(DateTime(2026, 10, 31)), 4000000);
      expect(c.valueAt(_today), 3800000);
      expect(c.currentValueCents, 3800000);
      expect(c.lastChangeCents, -200000);
    });

    test(
      'withSnapshot na mesma data substitui o valor e mantém a original',
      () {
        final original = carro();
        final c = original.withSnapshot(
          AssetSnapshot(
            id: 'n',
            date: DateTime(2026, 11, 1),
            valueCents: 3700000,
          ),
        );
        expect(c.snapshots.length, 2);
        expect(c.valueAt(_today), 3700000);
        expect(original.valueAt(_today), 3800000);
        expect(original.snapshots.length, 2);
      },
    );

    test('withoutSnapshot de id inexistente devolve igual à original', () {
      final c = carro();
      expect(c.withoutSnapshot('inexistente'), c);
      expect(c.withoutSnapshot('s2').snapshots.length, 1);
      expect(c.snapshots.length, 2);
    });

    test(
      'closeAsset: snapshot 0 na data e arquivado, histórico preservado',
      () {
        final c = closeAsset(carro(), date: _today, snapshotId: 'c');
        expect(c.archived, isTrue);
        expect(c.valueAt(_today), 0);
        expect(c.valueAt(DateTime(2026, 10, 31)), 4000000);
      },
    );

    test('assetsValueAt soma todos os ativos, encerrados inclusive', () {
      final encerrado = closeAsset(
        tesouro(),
        date: DateTime(2026, 11, 1),
        snapshotId: 'x',
      );
      expect(
        assetsValueAt([carro(), tesouro()], DateTime(2026, 10, 31)),
        4200000,
      );
      expect(
        assetsValueAt([carro(), tesouro()], DateTime(2026, 9, 30)),
        4000000,
      );
      expect(
        assetsValueAt([carro(), encerrado], DateTime(2026, 11, 15)),
        3800000,
      );
    });

    test('assetSnapshotError: valor negativo, data futura e válido', () {
      expect(
        assetSnapshotError(valueCents: -1, date: _today, today: _today),
        'Informe um valor maior ou igual a zero',
      );
      expect(
        assetSnapshotError(
          valueCents: 0,
          date: DateTime(2026, 11, 16),
          today: _today,
        ),
        'A data não pode ser no futuro',
      );
      expect(
        assetSnapshotError(valueCents: 0, date: _today, today: _today),
        isNull,
      );
    });

    test('removeSnapshotError: último valor não pode sair', () {
      final um = Asset(
        id: 'u',
        name: 'U',
        kind: AssetKind.other,
        snapshots: [AssetSnapshot(id: 'a', date: _today, valueCents: 1)],
      );
      expect(
        removeSnapshotError(um, 'a'),
        'O ativo precisa de pelo menos um valor',
      );
      expect(removeSnapshotError(carro(), 's1'), isNull);
    });
  });

  group('construção', () {
    test(
      'snapshots fora de ordem são ordenados; mesma data: vale o último',
      () {
        final a = Asset(
          id: 'a',
          name: 'A',
          kind: AssetKind.other,
          snapshots: [
            AssetSnapshot(id: 'b', date: DateTime(2026, 11, 1), valueCents: 2),
            AssetSnapshot(id: 'c', date: DateTime(2026, 8, 1), valueCents: 1),
            AssetSnapshot(id: 'd', date: DateTime(2026, 11, 1), valueCents: 3),
          ],
        );
        expect([for (final s in a.snapshots) s.id], ['c', 'd']);
        expect(a.currentValueCents, 3);
      },
    );

    test('lista de snapshots é imutável', () {
      expect(
        () => carro().snapshots.add(
          AssetSnapshot(id: 'x', date: _today, valueCents: 1),
        ),
        throwsUnsupportedError,
      );
    });
  });

  group('serialização', () {
    test('round-trip com 2 snapshots (um com nota) e arquivado', () {
      final asset = Asset(
        id: 'apto',
        name: 'Apartamento',
        kind: AssetKind.realEstate,
        archived: true,
        snapshots: [
          AssetSnapshot(
            id: 's1',
            date: DateTime(2026, 1, 1),
            valueCents: 50000000,
          ),
          AssetSnapshot(
            id: 's2',
            date: DateTime(2026, 6, 1),
            valueCents: 52000000,
            note: 'Avaliação',
          ),
        ],
      );
      final back = Asset.fromMap(asset.toMap());
      expect(back, asset);
      expect(back.snapshots.last.note, 'Avaliação');
      expect(back.archived, isTrue);
    });

    test('fromMap sem snapshots/archived e kind desconhecido', () {
      final a = Asset.fromMap({'id': 'x', 'name': 'X', 'kind': 'vehicle'});
      expect(a.snapshots, isEmpty);
      expect(a.archived, isFalse);
      expect(a.kind, AssetKind.vehicle);

      final desconhecido = Asset.fromMap({
        'id': 'y',
        'name': 'Y',
        'kind': 'cripto',
      });
      expect(desconhecido.kind, AssetKind.investment);
    });

    test('snapshot inválido dentro do ativo é ignorado', () {
      final a = Asset.fromMap({
        'id': 'x',
        'name': 'X',
        'kind': 'other',
        'snapshots': [
          {'id': 's1', 'date': '20260101'},
          {'id': 's2', 'date': '20260201', 'valueCents': 100},
        ],
      });
      expect(a.snapshots.length, 1);
      expect(a.currentValueCents, 100);
    });

    test('AssetSnapshot.fromMap lança FormatException para dado inválido', () {
      expect(
        () => AssetSnapshot.fromMap({
          'id': 's',
          'date': '20261301',
          'valueCents': 1,
        }),
        throwsFormatException,
      );
      expect(
        () => AssetSnapshot.fromMap({
          'id': 's',
          'date': '20260101',
          'valueCents': -1,
        }),
        throwsFormatException,
      );
      expect(
        () => AssetSnapshot.fromMap({'id': 's', 'date': '20260101'}),
        throwsFormatException,
      );
      expect(
        () => Asset.fromMap({'name': 'sem id', 'kind': 'other'}),
        throwsFormatException,
      );
    });

    test('AssetSnapshot.copyWith: note omitido mantém, null limpa', () {
      final s = AssetSnapshot(id: 's', date: _today, valueCents: 10, note: 'x');
      expect(s.copyWith(valueCents: 20).note, 'x');
      expect(s.copyWith(note: null).note, isNull);
    });
  });

  group('rótulos e estado vazio', () {
    test('assetKindLabel dos 4 tipos', () {
      expect(assetKindLabel(AssetKind.investment), 'Investimento');
      expect(assetKindLabel(AssetKind.realEstate), 'Imóvel');
      expect(assetKindLabel(AssetKind.vehicle), 'Veículo');
      expect(assetKindLabel(AssetKind.other), 'Outro');
    });

    test('lastChangeCents é null com um snapshot', () {
      expect(tesouro().lastChangeCents, isNull);
    });

    test('ativo sem snapshots vale 0 e não tem último', () {
      final vazio = Asset(id: 'v', name: 'V', kind: AssetKind.other);
      expect(vazio.currentValueCents, 0);
      expect(vazio.latest, isNull);
      expect(vazio.valueAt(_today), 0);
    });
  });
}
