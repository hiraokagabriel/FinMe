import 'package:finme/app/bootstrap.dart';
import 'package:finme/app/profile_registry.dart';
import 'package:finme/core/services/record_store.dart';
import 'package:finme/features/profiles/domain/profile.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('perfil default usa fm_*; outro perfil usa prefixo p<id>_', () {
    expect(boxNameFor(defaultProfileId, 'fm_accounts'), 'fm_accounts');
    expect(boxNameFor('abc', 'fm_accounts'), 'pabc_fm_accounts');
    expect(boxNamesFor('abc'), everyElement(startsWith('pabc_fm_')));
    expect(boxNamesFor(defaultProfileId), contains('fm_transactions'));
  });

  test('bootstrap de outro perfil abre só os boxes prefixados', () async {
    final opened = <String>[];
    await bootstrap(
      profileId: 'abc',
      storeFactory: (name) {
        opened.add(name);
        return MemoryRecordStore();
      },
      clock: () => DateTime(2026, 11, 17),
    );
    expect(opened, boxNamesFor('abc'));
  });

  group('ProfileRegistry', () {
    late MemoryRecordStore store;
    late List<String> deleted;
    late ProfileRegistry registry;

    setUp(() async {
      store = MemoryRecordStore();
      deleted = [];
      registry = ProfileRegistry(
        store: store,
        deleteData: (id) async => deleted.add(id),
        clock: () => DateTime(2026, 11, 17),
      );
      await registry.ensureDefault();
    });

    test('registro vazio cria "Principal" uma vez', () async {
      await registry.ensureDefault();
      expect(registry.all.map((p) => (p.id, p.name)), [
        (defaultProfileId, 'Principal'),
      ]);
    });

    test('cria, renomeia, define PIN e persiste', () async {
      final p = await registry.create('  Empresa ');
      await registry.rename(p.id, 'Empresa X');
      await registry.setPin(p.id, '1234');
      final reloaded = ProfileRegistry(store: store, deleteData: (_) async {});
      final back = reloaded.byId(p.id)!;
      expect(back.name, 'Empresa X');
      expect(back.verifyPin('1234'), isTrue);
      expect(reloaded.all.first.id, defaultProfileId);
    });

    test(
      'exclui outro perfil e apaga os dados; recusa o aberto e o último',
      () async {
        final p = await registry.create('Teste');
        expect(() => registry.delete(p.id, activeId: p.id), throwsStateError);
        await registry.delete(p.id, activeId: defaultProfileId);
        expect(deleted, [p.id]);
        expect(registry.byId(p.id), isNull);
        expect(
          () => registry.delete(defaultProfileId, activeId: 'outro'),
          throwsStateError,
        );
      },
    );
  });
}
