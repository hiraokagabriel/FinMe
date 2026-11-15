import 'package:flutter/foundation.dart';

import 'record_store.dart';

/// Coleção de entidades em memória, persistida em um [RecordStore].
/// Mudanças atualizam a memória e notificam antes da escrita terminar.
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
      final item = fromMap(data);
      _items[idOf(item)] = item;
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
    final entries = <String, Map<String, dynamic>>{};
    for (final item in items) {
      final id = _idOf(item);
      _items[id] = item;
      entries[id] = _toMap(item);
    }
    if (entries.isEmpty) {
      return;
    }
    _changed();
    await _store.putAll(entries);
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
  Future<void> replaceAll(Iterable<T> items) async {
    _items.clear();
    final entries = <String, Map<String, dynamic>>{};
    for (final item in items) {
      final id = _idOf(item);
      _items[id] = item;
      entries[id] = _toMap(item);
    }
    _changed();
    await _store.clear();
    await _store.putAll(entries);
  }

  void _changed() {
    _all = null;
    _version++;
    notifyListeners();
  }
}
