import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../core/services/record_store.dart';
import '../core/theme/app_theme.dart';
import '../features/profiles/presentation/profile_picker_page.dart';
import 'app.dart';
import 'app_scope.dart';
import 'boot_screen.dart';
import 'bootstrap.dart';
import 'profile_registry.dart';

/// Abre o registro global de perfis no Hive (box `fm_profiles`).
Future<ProfileRegistry> openProfileRegistry() async {
  await Hive.initFlutter('finme');
  final registry = ProfileRegistry(
    store: await HiveRecordStore.open('fm_profiles'),
    deleteData: deleteProfileData,
  );
  await registry.ensureDefault();
  return registry;
}

/// Raiz do app (SPEC §10.4): um perfil sem PIN abre direto; senão mostra o seletor.
class ProfileGate extends StatefulWidget {
  const ProfileGate({
    super.key,
    this.openRegistry = openProfileRegistry,
    this.boot = _bootProfile,
  });

  final Future<ProfileRegistry> Function() openRegistry;
  final Future<AppServices> Function(String profileId) boot;

  static Future<AppServices> _bootProfile(String id) =>
      bootstrap(profileId: id);

  @override
  State<ProfileGate> createState() => _ProfileGateState();
}

class _ProfileGateState extends State<ProfileGate> {
  ProfileRegistry? _registry;
  AppServices? _services;
  String? _activeId;
  Object? _error;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    try {
      final registry = await widget.openRegistry();
      _registry = registry;
      final all = registry.all;
      if (all.length == 1 && !all.single.hasPin) {
        await _open(all.single.id);
        return;
      }
      setState(() => _loading = false);
    } catch (e) {
      setState(() => _error = e);
    }
  }

  Future<void> _open(String id) async {
    setState(() => _loading = true);
    try {
      final services = await widget.boot(id);
      if (!mounted) {
        return;
      }
      setState(() {
        _services = services;
        _activeId = id;
        _loading = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() => _error = e);
      }
    }
  }

  Future<void> _switch() async {
    final old = _services;
    setState(() {
      _services = null;
      _activeId = null;
    });
    // Fecha depois do quadro: a árvore antiga já soltou os listeners do Ledger.
    await SchedulerBinding.instance.endOfFrame;
    await old?.close();
  }

  @override
  Widget build(BuildContext context) {
    final error = _error;
    if (error != null) {
      return BootErrorScreen(error: error);
    }
    final services = _services;
    final registry = _registry;
    if (services != null && registry != null) {
      return ProfileScope(
        registry: registry,
        activeId: _activeId!,
        switchProfile: _switch,
        child: FinMeApp(key: ValueKey(_activeId), services: services),
      );
    }
    if (_loading || registry == null) {
      return const BootScreen();
    }
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'FinMe',
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      home: ProfilePickerPage(registry: registry, onOpen: _open),
    );
  }
}
