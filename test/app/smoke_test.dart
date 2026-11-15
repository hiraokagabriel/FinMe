import 'package:finme/app/app.dart';
import 'package:finme/app/app_scope.dart';
import 'package:finme/app/bootstrap.dart';
import 'package:finme/app/seed.dart';
import 'package:finme/core/models/app_settings.dart';
import 'package:finme/core/services/record_store.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const _pages = [
  'Painel',
  'Previsão',
  'Cartões',
  'Contas',
  'Transações',
  'Recorrentes',
  'Categorias',
  'Ajustes',
];

Future<AppServices> _boot(WidgetTester tester, AppMode mode) async {
  final s = (await tester.runAsync(() async {
    final s = await bootstrap(
      storeFactory: (_) => MemoryRecordStore(),
      clock: () => DateTime(2026, 11, 14),
    );
    await seedDemo(s);
    await materializeRecurring(s);
    await s.settings.update(
      (c) => c.copyWith(mode: mode, onboardingDone: true),
    );
    return s;
  }))!;
  return s;
}

Future<void> _pumpApp(
  WidgetTester tester,
  AppServices s, {
  required Size size,
}) async {
  // DPR 1 faz o tamanho em pixels lógicos, que é o que MediaQuery usa no HomeShell.
  tester.view.devicePixelRatio = 1.0;
  tester.view.physicalSize = size;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(FinMeApp(services: s));
  await tester.pumpAndSettle();
}

/// Abre o form pelo FAB e fecha com Cancelar.
Future<void> _openAndCancelTransactionForm(WidgetTester tester) async {
  await tester.tap(find.widgetWithText(FloatingActionButton, 'Nova transação'));
  await tester.pumpAndSettle();
  expect(find.text('Cancelar'), findsOneWidget);
  expect(tester.takeException(), isNull);

  await tester.tap(find.text('Cancelar'));
  await tester.pumpAndSettle();
  expect(find.text('Cancelar'), findsNothing);
  expect(tester.takeException(), isNull);
}

void main() {
  for (final mode in AppMode.values) {
    testWidgets('desktop 1400x900 ($mode): navega 8 páginas e abre o form', (
      tester,
    ) async {
      final s = await _boot(tester, mode);
      await _pumpApp(tester, s, size: const Size(1400, 900));

      for (final label in _pages) {
        // Na sidebar larga, o primeiro item com o rótulo é o da navegação.
        await tester.tap(find.widgetWithText(InkWell, label).first);
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull, reason: label);
      }

      await _openAndCancelTransactionForm(tester);
    });
  }

  testWidgets('mobile 390x800 (Ultra): navega 8 páginas pelo Drawer', (
    tester,
  ) async {
    final s = await _boot(tester, AppMode.ultra);
    await _pumpApp(tester, s, size: const Size(390, 800));

    for (final label in _pages) {
      await tester.tap(find.byTooltip('Open navigation menu'));
      await tester.pumpAndSettle();
      await tester.tap(
        find.descendant(
          of: find.byType(Drawer),
          matching: find.widgetWithText(InkWell, label),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull, reason: label);
    }

    await _openAndCancelTransactionForm(tester);
  });
}
