import 'package:flutter/foundation.dart';

import '../models/app_settings.dart';
import 'record_store.dart';

/// Dono único das [AppSettings], persistidas no registro `settings`.
class SettingsController extends ChangeNotifier {
  SettingsController(RecordStore store) : _store = store, _value = _load(store);

  static const _id = 'settings';

  final RecordStore _store;
  AppSettings _value;

  AppSettings get value => _value;

  Future<void> update(AppSettings Function(AppSettings) change) async {
    _value = change(_value);
    notifyListeners();
    await _store.put(_id, {'id': _id, ..._value.toMap()});
  }

  static AppSettings _load(RecordStore store) {
    final rows = store.loadAll().where((m) => m['id'] == _id);
    return AppSettings.fromMap(rows.isEmpty ? const {} : rows.first);
  }
}
