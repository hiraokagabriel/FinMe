import 'package:finme/app/app.dart';
import 'package:finme/app/app_scope.dart';
import 'package:finme/app/bootstrap.dart';
import 'package:finme/app/seed.dart';
import 'package:finme/core/models/app_settings.dart';
import 'package:finme/core/services/record_store.dart';
import 'package:finme/features/debts/domain/debt.dart';
import 'package:finme/features/reports/presentation/pivot_view.dart';
import 'package:finme/features/settings/presentation/settings_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

const _pages = [
  'Painel',
  'Previsão',
  'Cartões',
  'Contas',
  'Transações',
  'Importar',
  'Recorrentes',
  'Categorias',
  'Ajustes',
  'Patrimônio',
  'Relatórios',
];

/// Tooltip do item: 'Atalho: N' nas 9 primeiras páginas; Patrimônio não tem atalho numérico.
String _shortcutTip(int i) => 'Atalho: ${i + 1}';

/// Rótulo do item colapsado: 'Rótulo · N'; Patrimônio fica só com o rótulo.
String _railTip(int i) => i < 9 ? '${_pages[i]} · ${i + 1}' : _pages[i];

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

/// Abre a paleta pela entrada da sidebar ou pelo botão colapsado e fecha com Esc.
Future<void> _openAndCloseSearch(WidgetTester tester, Finder trigger) async {
  await tester.tap(trigger);
  await tester.pumpAndSettle();
  expect(find.byKey(const ValueKey('palette-input')), findsOneWidget);
  expect(find.text('Buscar comandos e transações'), findsOneWidget);

  await tester.sendKeyEvent(LogicalKeyboardKey.escape);
  await tester.pumpAndSettle();
  expect(find.byKey(const ValueKey('palette-input')), findsNothing);
  expect(tester.takeException(), isNull);
}

void main() {
  for (final mode in AppMode.values) {
    testWidgets('desktop 1400x900 ($mode): navega 9 páginas e abre o form', (
      tester,
    ) async {
      final s = await _boot(tester, mode);
      await _pumpApp(tester, s, size: const Size(1400, 900));

      expect(find.byTooltip('Atalho: N'), findsOneWidget);
      double dy(String label) =>
          tester.getTopLeft(find.widgetWithText(InkWell, label).first).dy;
      expect(dy('Contas'), lessThan(dy('Patrimônio')));
      expect(dy('Patrimônio'), lessThan(dy('Transações')));
      expect(dy('Categorias'), lessThan(dy('Relatórios')));
      expect(dy('Relatórios'), lessThan(dy('Ajustes')));
      for (var i = 0; i < _pages.length; i++) {
        // Na sidebar larga, o primeiro item com o rótulo é o da navegação.
        await tester.tap(find.widgetWithText(InkWell, _pages[i]).first);
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull, reason: _pages[i]);
        if (i < 9) {
          expect(find.byTooltip(_shortcutTip(i)), findsWidgets);
        }
      }

      await _openAndCancelTransactionForm(tester);
    });

    testWidgets('desktop 1400x900 ($mode): entrada Buscar abre a paleta', (
      tester,
    ) async {
      final s = await _boot(tester, mode);
      await _pumpApp(tester, s, size: const Size(1400, 900));

      await _openAndCloseSearch(
        tester,
        find.byKey(const ValueKey('sidebar-search')),
      );
    });

    testWidgets(
      'estreito 800x700 ($mode): sidebar colapsada navega 9 páginas',
      (tester) async {
        final s = await _boot(tester, mode);
        await _pumpApp(tester, s, size: const Size(800, 700));

        expect(find.byType(Drawer), findsNothing);
        expect(find.byType(AppBar), findsNothing);

        for (var i = 0; i < _pages.length; i++) {
          final label = _pages[i];
          await tester.tap(find.byTooltip(_railTip(i)));
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull, reason: label);
        }

        await _openAndCancelTransactionForm(tester);
      },
    );

    testWidgets('estreito 800x700 ($mode): botão Buscar abre a paleta', (
      tester,
    ) async {
      final s = await _boot(tester, mode);
      await _pumpApp(tester, s, size: const Size(800, 700));

      await _openAndCloseSearch(tester, find.byTooltip('Buscar (Ctrl+K)'));
    });
  }

  testWidgets('estreito 800x700 (Ultra): botão de modo alterna para Simples', (
    tester,
  ) async {
    final s = await _boot(tester, AppMode.ultra);
    await _pumpApp(tester, s, size: const Size(800, 700));

    await tester.tap(find.byTooltip('Modo: Ultra'));
    await tester.pumpAndSettle();
    expect(find.byTooltip('Modo: Simples'), findsOneWidget);
    expect(s.settings.value.mode, AppMode.simple);
  });

  testWidgets('Patrimônio: badge de dívidas "devo" vencidas só no Ultra', (
    tester,
  ) async {
    final s = await _boot(tester, AppMode.ultra);
    await tester.runAsync(
      () => s.debts.upsert(
        Debt(
          id: 'venc',
          person: 'Bruno',
          direction: DebtDirection.iOwe,
          amountCents: 1000,
          date: DateTime(2026, 10, 1),
          dueDate: DateTime(2026, 11, 1),
        ),
      ),
    );
    await _pumpApp(tester, s, size: const Size(1400, 900));

    final tile = find.widgetWithText(InkWell, 'Patrimônio').first;
    expect(find.descendant(of: tile, matching: find.text('1')), findsOneWidget);
  });

  testWidgets('tecla 9 continua indo para Ajustes', (tester) async {
    final s = await _boot(tester, AppMode.ultra);
    await _pumpApp(tester, s, size: const Size(1400, 900));

    await tester.sendKeyEvent(LogicalKeyboardKey.digit9);
    await tester.pumpAndSettle();
    expect(find.byType(SettingsPage), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('paleta: Relatório: Categoria × mês abre o pivot', (
    tester,
  ) async {
    final s = await _boot(tester, AppMode.ultra);
    await _pumpApp(tester, s, size: const Size(1400, 900));

    await tester.tap(find.byKey(const ValueKey('sidebar-search')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('palette-input')),
      'Categoria × mês',
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Relatório: Categoria × mês'));
    await tester.pumpAndSettle();

    expect(find.byType(PivotView), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('filtro de Relatórios sobrevive à troca de página', (
    tester,
  ) async {
    final s = await _boot(tester, AppMode.simple);
    await _pumpApp(tester, s, size: const Size(1400, 900));

    await tester.tap(find.widgetWithText(InkWell, 'Relatórios').first);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('report-period')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('3 meses').last);
    await tester.pumpAndSettle();
    expect(find.text('set/2026 – nov/2026'), findsOneWidget);

    await tester.tap(find.widgetWithText(InkWell, 'Painel').first);
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(InkWell, 'Relatórios').first);
    await tester.pumpAndSettle();

    expect(find.text('set/2026 – nov/2026'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('redimensionar 1400 -> 800 não causa overflow', (tester) async {
    final s = await _boot(tester, AppMode.ultra);
    await _pumpApp(tester, s, size: const Size(1400, 900));

    tester.view.physicalSize = const Size(800, 700);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);

    tester.view.physicalSize = const Size(1400, 900);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}
