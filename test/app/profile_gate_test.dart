import 'package:finme/app/app_scope.dart';
import 'package:finme/app/bootstrap.dart';
import 'package:finme/app/profile_gate.dart';
import 'package:finme/app/profile_registry.dart';
import 'package:finme/core/services/record_store.dart';
import 'package:finme/features/profiles/domain/profile.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Future<AppServices> _services(WidgetTester tester) async {
  return (await tester.runAsync(() async {
    final s = await bootstrap(
      storeFactory: (_) => MemoryRecordStore(),
      clock: () => DateTime(2026, 11, 17),
    );
    await s.settings.update((c) => c.copyWith(onboardingDone: true));
    return s;
  }))!;
}

Future<ProfileRegistry> _registry({String? pin}) async {
  final r = ProfileRegistry(
    store: MemoryRecordStore(),
    deleteData: (_) async {},
  );
  await r.ensureDefault();
  if (pin != null) {
    await r.setPin(defaultProfileId, pin);
  }
  return r;
}

Future<void> _pumpGate(
  WidgetTester tester,
  ProfileRegistry registry,
  AppServices services,
  List<String> booted,
) async {
  tester.view.devicePixelRatio = 1.0;
  tester.view.physicalSize = const Size(1400, 900);
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProfileGate(
      openRegistry: () async => registry,
      boot: (id) async {
        booted.add(id);
        return services;
      },
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('um perfil sem PIN abre direto e mostra o nome na sidebar', (
    tester,
  ) async {
    final services = await _services(tester);
    final registry = (await tester.runAsync(_registry))!;
    final booted = <String>[];
    await _pumpGate(tester, registry, services, booted);

    expect(booted, [defaultProfileId]);
    expect(find.text('Quem está usando?'), findsNothing);
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('sidebar-profile')),
        matching: find.text('Principal'),
      ),
      findsOneWidget,
    );
  });

  testWidgets('perfil com PIN: seletor, PIN errado não abre, certo abre', (
    tester,
  ) async {
    final services = await _services(tester);
    final registry = (await tester.runAsync(() => _registry(pin: '2468')))!;
    final booted = <String>[];
    await _pumpGate(tester, registry, services, booted);

    expect(find.text('Quem está usando?'), findsOneWidget);
    expect(booted, isEmpty);

    await tester.tap(find.byKey(const ValueKey('profile-default')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const ValueKey('pin-field')), '1111');
    await tester.tap(find.text('Abrir'));
    await tester.pumpAndSettle();
    expect(find.text('PIN incorreto.'), findsOneWidget);
    expect(booted, isEmpty);

    await tester.enterText(find.byKey(const ValueKey('pin-field')), '2468');
    await tester.tap(find.text('Abrir'));
    await tester.pumpAndSettle();
    expect(booted, [defaultProfileId]);
    expect(find.byKey(const ValueKey('sidebar-profile')), findsOneWidget);
  });

  testWidgets('trocar perfil volta ao seletor', (tester) async {
    final services = await _services(tester);
    final registry = (await tester.runAsync(_registry))!;
    final booted = <String>[];
    await _pumpGate(tester, registry, services, booted);

    await tester.tap(find.byKey(const ValueKey('sidebar-profile')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Trocar perfil'));
    await tester.pumpAndSettle();

    expect(find.text('Quem está usando?'), findsOneWidget);
    expect(find.byKey(const ValueKey('profile-default')), findsOneWidget);
  });
}
