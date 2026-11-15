import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:finme/core/models/app_settings.dart';
import 'package:finme/core/services/collection_repository.dart';
import 'package:finme/core/services/record_store.dart';
import 'package:finme/core/services/settings_controller.dart';

class _Item {
  const _Item(this.id, this.name);

  factory _Item.fromMap(Map<String, dynamic> m) =>
      _Item(m['id'] as String, m['name'] as String);

  final String id;
  final String name;

  Map<String, dynamic> toMap() => {'id': id, 'name': name};
}

/// Registra a ordem das escritas; delega ao MemoryRecordStore.
class _LogStore implements RecordStore {
  final inner = MemoryRecordStore();
  final log = <String>[];

  @override
  Iterable<Map<String, dynamic>> loadAll() => inner.loadAll();

  @override
  Future<void> put(String id, Map<String, dynamic> data) => inner.put(id, data);

  @override
  Future<void> putAll(Map<String, Map<String, dynamic>> entries) {
    log.add('putAll');
    return inner.putAll(entries);
  }

  @override
  Future<void> delete(String id) => inner.delete(id);

  @override
  Future<void> deleteAll(Iterable<String> ids) {
    log.add('deleteAll');
    return inner.deleteAll(ids);
  }

  @override
  Future<void> clear() {
    log.add('clear');
    return inner.clear();
  }
}

CollectionRepository<_Item> _repo(RecordStore store) =>
    CollectionRepository<_Item>(
      store: store,
      fromMap: _Item.fromMap,
      toMap: (i) => i.toMap(),
      idOf: (i) => i.id,
    );

void main() {
  group('CollectionRepository', () {
    test('upsert, byId, isEmpty e persistência no store', () async {
      final store = MemoryRecordStore();
      final repo = _repo(store);
      expect(repo.isEmpty, isTrue);

      await repo.upsert(const _Item('a', 'Alpha'));
      expect(repo.byId('a')?.name, 'Alpha');
      expect(repo.byId('zz'), isNull);
      expect(repo.isEmpty, isFalse);

      // Recarrega de um repositório novo sobre o mesmo store.
      final reloaded = _repo(store);
      expect(reloaded.byId('a')?.name, 'Alpha');
    });

    test(
      'upsertAll notifica uma única vez e preserva ordem de inserção',
      () async {
        final repo = _repo(MemoryRecordStore());
        var notifications = 0;
        repo.addListener(() => notifications++);

        await repo.upsertAll(const [_Item('b', 'B'), _Item('a', 'A')]);
        expect(notifications, 1);
        expect(repo.all.map((i) => i.id), ['b', 'a']);

        await repo.upsert(const _Item('b', 'B2'));
        expect(repo.all.map((i) => i.id), ['b', 'a']);
        expect(repo.byId('b')?.name, 'B2');
      },
    );

    test('version incrementa a cada mudança e não em no-op', () async {
      final repo = _repo(MemoryRecordStore());
      expect(repo.version, 0);

      await repo.upsert(const _Item('a', 'A'));
      expect(repo.version, 1);

      await repo.delete('nope');
      expect(repo.version, 1);

      await repo.delete('a');
      expect(repo.version, 2);
    });

    test('all é cacheado e recriado só após mudança', () async {
      final repo = _repo(MemoryRecordStore());
      await repo.upsert(const _Item('a', 'A'));

      final first = repo.all;
      expect(identical(first, repo.all), isTrue);

      await repo.upsert(const _Item('b', 'B'));
      expect(identical(first, repo.all), isFalse);
      expect(repo.all.length, 2);
    });

    test('all é imutável', () async {
      final repo = _repo(MemoryRecordStore());
      await repo.upsert(const _Item('a', 'A'));
      expect(() => repo.all.add(const _Item('x', 'X')), throwsUnsupportedError);
    });

    test('deleteWhere remove apenas os que casam', () async {
      final store = MemoryRecordStore();
      final repo = _repo(store);
      await repo.upsertAll(const [
        _Item('a', 'keep'),
        _Item('b', 'drop'),
        _Item('c', 'drop'),
      ]);

      await repo.deleteWhere((i) => i.name == 'drop');
      expect(repo.all.map((i) => i.id), ['a']);
      expect(store.loadAll().map((m) => m['id']), ['a']);
    });

    test('replaceAll substitui o conteúdo na memória e no store', () async {
      final store = MemoryRecordStore();
      final repo = _repo(store);
      await repo.upsert(const _Item('old', 'Old'));

      await repo.replaceAll(const [_Item('n1', 'N1'), _Item('n2', 'N2')]);
      expect(repo.byId('old'), isNull);
      expect(repo.all.map((i) => i.id), ['n1', 'n2']);
      expect(store.loadAll().map((m) => m['id']), ['n1', 'n2']);
    });

    test('replaceAll grava os novos antes de apagar os antigos', () async {
      final store = _LogStore();
      final repo = _repo(store);
      await repo.upsert(const _Item('old', 'Old'));
      store.log.clear();

      await repo.replaceAll(const [_Item('old', 'Keep'), _Item('n1', 'N1')]);
      expect(store.log, ['putAll', 'deleteAll']);
      expect(store.loadAll().map((m) => m['id']), ['old', 'n1']);
    });

    test('registro inválido é pulado no construtor', () async {
      final store = MemoryRecordStore();
      await store.put('a', {'id': 'a', 'name': 'A'});
      await store.put('bad', {'id': 'bad'});

      final repo = _repo(store);
      expect(repo.all.map((i) => i.id), ['a']);
      expect(repo.byId('bad'), isNull);
    });

    test('MemoryRecordStore guarda cópias isoladas do chamador', () async {
      final store = MemoryRecordStore();
      final data = <String, dynamic>{
        'id': 'a',
        'tags': ['x'],
      };
      await store.put('a', data);
      (data['tags'] as List).add('mutated');

      final read = store.loadAll().single;
      expect(read['tags'], ['x']);
    });
  });

  group('normalizeMap', () {
    test('converte mapas e listas aninhadas recursivamente', () {
      final raw = <dynamic, dynamic>{
        'name': 'x',
        'nested': <dynamic, dynamic>{
          'inner': <dynamic, dynamic>{'v': 1},
        },
        'list': <dynamic>[
          <dynamic, dynamic>{'k': 'a'},
          2,
        ],
      };

      final out = normalizeMap(raw);
      expect(out['nested'], isA<Map<String, dynamic>>());
      expect(
        (out['nested'] as Map<String, dynamic>)['inner'],
        isA<Map<String, dynamic>>(),
      );
      final list = out['list'] as List<dynamic>;
      expect(list[0], isA<Map<String, dynamic>>());
      expect((list[0] as Map<String, dynamic>)['k'], 'a');
      expect(list[1], 2);
    });
  });

  group('HiveRecordStore', () {
    late Directory dir;

    setUp(() {
      dir = Directory.systemTemp.createTempSync('finme_hive_test');
      Hive.init(dir.path);
    });

    tearDown(() async {
      await Hive.close();
      dir.deleteSync(recursive: true);
    });

    test(
      'mapas aninhados voltam como Map<String,dynamic> após reabrir',
      () async {
        final store = await HiveRecordStore.open('fm_test');
        await store.put('a', {
          'id': 'a',
          'meta': {
            'tags': ['x'],
          },
        });
        await Hive.close();

        final reopened = await HiveRecordStore.open('fm_test');
        final read = reopened.loadAll().single;
        expect(read['meta'], isA<Map<String, dynamic>>());
        expect((read['meta'] as Map<String, dynamic>)['tags'], ['x']);
      },
    );
  });

  group('AppSettings', () {
    test('fromMap({}) devolve os padrões', () {
      final s = AppSettings.fromMap({});
      expect(s.mode, AppMode.simple);
      expect(s.theme, ThemePreference.system);
      expect(s.hideValues, isFalse);
      expect(s.forecastMonths, 6);
      expect(s.onboardingDone, isFalse);
    });

    test('forecastMonths é limitado a 3..24', () {
      expect(AppSettings(forecastMonths: 1).forecastMonths, 3);
      expect(AppSettings(forecastMonths: 100).forecastMonths, 24);
      expect(AppSettings.fromMap({'forecastMonths': 0}).forecastMonths, 3);
      expect(AppSettings().copyWith(forecastMonths: 99).forecastMonths, 24);
    });

    test('enum desconhecido cai no primeiro valor', () {
      final s = AppSettings.fromMap({'mode': 'xyz', 'theme': 42});
      expect(s.mode, AppMode.simple);
      expect(s.theme, ThemePreference.system);
    });

    test('toMap -> fromMap preserva valores', () {
      final s = AppSettings(
        mode: AppMode.ultra,
        theme: ThemePreference.dark,
        hideValues: true,
        forecastMonths: 12,
        onboardingDone: true,
      );
      final back = AppSettings.fromMap(s.toMap());
      expect(back.mode, AppMode.ultra);
      expect(back.theme, ThemePreference.dark);
      expect(back.hideValues, isTrue);
      expect(back.forecastMonths, 12);
      expect(back.onboardingDone, isTrue);
    });

    test('copyWith altera só o campo informado', () {
      final s = AppSettings().copyWith(mode: AppMode.ultra);
      expect(s.mode, AppMode.ultra);
      expect(s.theme, ThemePreference.system);
      expect(s.forecastMonths, 6);
    });
  });

  group('SettingsController', () {
    test('começa com padrões e persiste update', () async {
      final store = MemoryRecordStore();
      final controller = SettingsController(store);
      expect(controller.value.mode, AppMode.simple);

      var notifications = 0;
      controller.addListener(() => notifications++);
      await controller.update((s) => s.copyWith(mode: AppMode.ultra));

      expect(notifications, 1);
      expect(controller.value.mode, AppMode.ultra);

      final reloaded = SettingsController(store);
      expect(reloaded.value.mode, AppMode.ultra);
    });
  });
}
