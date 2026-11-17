import 'package:flutter/widgets.dart';

import '../core/services/record_store.dart';
import '../core/utils/id.dart';
import '../features/profiles/domain/profile.dart';

/// Lista de perfis no box global `fm_profiles`, fora de qualquer perfil e do backup (SPEC §10.3).
class ProfileRegistry extends ChangeNotifier {
  ProfileRegistry({
    required RecordStore store,
    required Future<void> Function(String id) deleteData,
    DateTime Function() clock = DateTime.now,
  }) : _store = store,
       _deleteData = deleteData,
       _clock = clock {
    for (final row in store.loadAll()) {
      try {
        final p = Profile.fromMap(row);
        _byId[p.id] = p;
      } on Object {
        // Registro corrompido é ignorado; os dados do perfil continuam no disco.
      }
    }
  }

  final RecordStore _store;
  final Future<void> Function(String id) _deleteData;
  final DateTime Function() _clock;
  final Map<String, Profile> _byId = {};

  /// Ordem de criação; "Principal" primeiro.
  List<Profile> get all =>
      _byId.values.toList()..sort((a, b) => a.createdAt.compareTo(b.createdAt));

  Profile? byId(String id) => _byId[id];

  /// Registro vazio → cria "Principal" sobre os dados existentes (`fm_*`).
  Future<void> ensureDefault() async {
    if (_byId.isEmpty) {
      await _put(
        Profile(
          id: defaultProfileId,
          name: 'Principal',
          createdAt: DateTime(2000),
        ),
      );
    }
  }

  Future<Profile> create(String name, {String? pin}) async {
    var profile = Profile(id: newId(), name: name.trim(), createdAt: _clock());
    if (pin != null) {
      profile = profile.withPin(pin);
    }
    await _put(profile);
    return profile;
  }

  Future<void> rename(String id, String name) =>
      _put(_byId[id]!.copyWith(name: name.trim()));

  /// `null` remove o PIN.
  Future<void> setPin(String id, String? pin) => _put(_byId[id]!.withPin(pin));

  /// Apaga o perfil e os dados dele. Recusa o perfil aberto e o último perfil.
  Future<void> delete(String id, {required String activeId}) async {
    if (id == activeId || _byId.length <= 1 || !_byId.containsKey(id)) {
      throw StateError('Perfil não pode ser excluído');
    }
    // Dados antes do registro: se falhar, o perfil continua listado e dá para tentar de novo.
    await _deleteData(id);
    await _store.delete(id);
    _byId.remove(id);
    notifyListeners();
  }

  Future<void> _put(Profile p) async {
    await _store.put(p.id, p.toMap());
    _byId[p.id] = p;
    notifyListeners();
  }
}

/// Perfil aberto e troca de perfil, para a sidebar e os Ajustes. Ausente em testes do app sem gate.
class ProfileScope extends InheritedWidget {
  const ProfileScope({
    super.key,
    required this.registry,
    required this.activeId,
    required this.switchProfile,
    required super.child,
  });

  final ProfileRegistry registry;
  final String activeId;
  final VoidCallback switchProfile;

  static ProfileScope? maybeOf(BuildContext context) =>
      context.getInheritedWidgetOfExactType<ProfileScope>();

  @override
  bool updateShouldNotify(ProfileScope oldWidget) =>
      activeId != oldWidget.activeId;
}
