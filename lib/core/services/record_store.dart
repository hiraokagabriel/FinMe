import 'package:hive/hive.dart';

/// Armazenamento bruto de registros (mapas JSON-like) indexados por id.
abstract interface class RecordStore {
  Iterable<Map<String, dynamic>> loadAll();
  Future<void> put(String id, Map<String, dynamic> data);
  Future<void> putAll(Map<String, Map<String, dynamic>> entries);
  Future<void> delete(String id);
  Future<void> deleteAll(Iterable<String> ids);
  Future<void> clear();
}

/// Em memória; guarda cópias para isolar o chamador (uso: testes).
class MemoryRecordStore implements RecordStore {
  final Map<String, Map<String, dynamic>> _data = {};

  @override
  Iterable<Map<String, dynamic>> loadAll() =>
      _data.values.map(normalizeMap).toList();

  @override
  Future<void> put(String id, Map<String, dynamic> data) async {
    _data[id] = normalizeMap(data);
  }

  @override
  Future<void> putAll(Map<String, Map<String, dynamic>> entries) async {
    for (final entry in entries.entries) {
      _data[entry.key] = normalizeMap(entry.value);
    }
  }

  @override
  Future<void> delete(String id) async {
    _data.remove(id);
  }

  @override
  Future<void> deleteAll(Iterable<String> ids) async {
    for (final id in ids) {
      _data.remove(id);
    }
  }

  @override
  Future<void> clear() async {
    _data.clear();
  }
}

/// Persistência em um `Box<Map>` do Hive. Requer `Hive.initFlutter()` antes.
class HiveRecordStore implements RecordStore {
  HiveRecordStore(this._box);

  final Box<Map> _box;

  static Future<HiveRecordStore> open(String boxName) async {
    return HiveRecordStore(await Hive.openBox<Map>(boxName));
  }

  Future<void> close() => _box.close();

  @override
  Iterable<Map<String, dynamic>> loadAll() =>
      _box.values.map(normalizeMap).toList();

  @override
  Future<void> put(String id, Map<String, dynamic> data) => _box.put(id, data);

  @override
  Future<void> putAll(Map<String, Map<String, dynamic>> entries) =>
      _box.putAll(entries);

  @override
  Future<void> delete(String id) => _box.delete(id);

  @override
  Future<void> deleteAll(Iterable<String> ids) => _box.deleteAll(ids);

  @override
  Future<void> clear() async {
    await _box.clear();
  }
}

/// Converte recursivamente `Map<dynamic,dynamic>` e listas (vindos do Hive)
/// para `Map<String,dynamic>` e `List<dynamic>`. Sempre devolve cópia nova.
Map<String, dynamic> normalizeMap(Map<dynamic, dynamic> m) => {
  for (final entry in m.entries)
    entry.key.toString(): _normalizeValue(entry.value),
};

dynamic _normalizeValue(dynamic value) {
  if (value is Map) {
    return normalizeMap(value);
  }
  if (value is List) {
    return value.map(_normalizeValue).toList();
  }
  return value;
}
