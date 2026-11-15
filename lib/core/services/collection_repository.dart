import 'package:flutter/foundation.dart';

import 'record_store.dart';

/// Coleção de entidades em memória, persistida em um [RecordStore].
/// upsertAll grava antes de mudar a memória; delete/deleteWhere mudam a memória e depois gravam.
class CollectionRepository<T> extends ChangeNotifier {
  CollectionRepository({
    required RecordStore store,
    required T Function(Map<String, dynamic>) fromMap,
    required Map<String, dynamic> Function(T) toMap,
    required String Function(T) idOf,
  }) : _store = store,
       _toMap = toMap,
       _idOf = idOf {
    for (final data in store.loadAll()) {
      try {
        final item = fromMap(data);
        _items[idOf(item)] = item;
      } catch (error) {
        debugPrint('CollectionRepository: registro inválido pulado: $error');
      }
    }
  }

  final RecordStore _store;
  final Map<String, dynamic> Function(T) _toMap;
  final String Function(T) _idOf;
  final Map<String, T> _items = {};

  List<T>? _all;
  int _version = 0;

  List<T> get all => _all ??= List.unmodifiable(_items.values);

  int get version => _version;

  bool get isEmpty => _items.isEmpty;

  T? byId(String id) => _items[id];

  Future<void> upsert(T item) => upsertAll([item]);

  Future<void> upsertAll(Iterable<T> items) async {
    final byId = <String, T>{};
    final entries = <String, Map<String, dynamic>>{};
    for (final item in items) {
      final id = _idOf(item);
      byId[id] = item;
      entries[id] = _toMap(item);
    }
    if (entries.isEmpty) {
      return;
    }
    // Grava antes: falha no store deixa a memória igual ao disco.
    await _store.putAll(entries);
    _items.addAll(byId);
    _changed();
  }

  Future<void> delete(String id) async {
    if (!_items.containsKey(id)) {
      return;
    }
    _items.remove(id);
    _changed();
    await _store.delete(id);
  }

  Future<void> deleteWhere(bool Function(T) test) async {
    final ids = [
      for (final entry in _items.entries)
        if (test(entry.value)) entry.key,
    ];
    if (ids.isEmpty) {
      return;
    }
    for (final id in ids) {
      _items.remove(id);
    }
    _changed();
    await _store.deleteAll(ids);
  }

  /// Substitui tudo (ex.: import de backup).
  /// Grava os novos antes de apagar os antigos: falha no meio não perde dados.
  Future<void> replaceAll(Iterable<T> items) async {
    final previousIds = _items.keys.toList();
    final byId = <String, T>{};
    final entries = <String, Map<String, dynamic>>{};
    for (final item in items) {
      final id = _idOf(item);
      byId[id] = item;
      entries[id] = _toMap(item);
    }
    _items
      ..clear()
      ..addAll(byId);
    _changed();
    await _store.putAll(entries);
    await _store.deleteAll(previousIds.where((id) => !entries.containsKey(id)));
  }

  void _changed() {
    _all = null;
    _version++;
    notifyListeners();
  }
}
