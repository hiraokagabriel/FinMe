import 'package:finme/app/app.dart';
import 'package:finme/app/app_scope.dart';
import 'package:finme/app/app_shortcuts.dart';
import 'package:finme/app/bootstrap.dart';
import 'package:finme/app/seed.dart';
import 'package:finme/core/models/app_settings.dart';
import 'package:finme/core/services/record_store.dart';
import 'package:finme/features/dashboard/presentation/dashboard_page.dart';
import 'package:finme/features/settings/presentation/settings_page.dart';
import 'package:finme/features/transactions/presentation/transaction_filters.dart';
import 'package:finme/features/transactions/presentation/transaction_row.dart';
import 'package:finme/features/transactions/presentation/transactions_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

Future<AppServices> _boot(WidgetTester tester, AppMode mode) async {
  return (await tester.runAsync(() async {
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
}

Future<void> _pumpApp(WidgetTester tester, AppServices s) async {
  tester.view.devicePixelRatio = 1.0;
  tester.view.physicalSize = const Size(1400, 900);
  addTearDown(tester.view.reset);
  await tester.pumpWidget(FinMeApp(services: s));
  await tester.pumpAndSettle();
}

Future<void> _key(WidgetTester tester, LogicalKeyboardKey key) async {
  await tester.sendKeyEvent(key);
  await tester.pumpAndSettle();
}

Future<void> _ctrl(WidgetTester tester, LogicalKeyboardKey key) async {
  await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
  await tester.sendKeyEvent(key);
  await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
  await tester.pumpAndSettle();
}

Future<void> _openPalette(WidgetTester tester) async {
  await _ctrl(tester, LogicalKeyboardKey.keyK);
  expect(find.byKey(const ValueKey('palette-input')), findsOneWidget);
}

Future<void> _searchPalette(WidgetTester tester, String text) async {
  await tester.enterText(find.byKey(const ValueKey('palette-input')), text);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('N abre o form, Esc fecha, N com diálogo aberto não abre outro', (
    tester,
  ) async {
    final s = await _boot(tester, AppMode.simple);
    await _pumpApp(tester, s);

    await _key(tester, LogicalKeyboardKey.keyN);
    expect(find.byType(Dialog), findsOneWidget);
    expect(
      find.descendant(
        of: find.byType(Dialog),
        matching: find.text('Nova transação'),
      ),
      findsOneWidget,
    );

    await _key(tester, LogicalKeyboardKey.keyN);
    expect(find.byType(Dialog), findsOneWidget);

    await _key(tester, LogicalKeyboardKey.escape);
    expect(find.byType(Dialog), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('dígitos e numpad navegam entre páginas', (tester) async {
    final s = await _boot(tester, AppMode.simple);
    await _pumpApp(tester, s);

    await _key(tester, LogicalKeyboardKey.digit5);
    expect(find.byType(TransactionsPage), findsOneWidget);

    await _key(tester, LogicalKeyboardKey.digit9);
    expect(find.byType(SettingsPage), findsOneWidget);

    await _key(tester, LogicalKeyboardKey.numpad1);
    expect(find.byType(DashboardPage), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Ctrl+K abre a paleta e Enter executa a página escolhida', (
    tester,
  ) async {
    final s = await _boot(tester, AppMode.simple);
    await _pumpApp(tester, s);

    await _openPalette(tester);
    await _searchPalette(tester, 'ajus');
    await _key(tester, LogicalKeyboardKey.enter);
    expect(find.byType(SettingsPage), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('paleta: transação do seed abre o form de edição', (
    tester,
  ) async {
    final s = await _boot(tester, AppMode.simple);
    await _pumpApp(tester, s);

    await _openPalette(tester);
    await _searchPalette(tester, 'supermercado');
    expect(
      find.descendant(
        of: find.byType(Dialog),
        matching: find.text('Transações'),
      ),
      findsOneWidget,
    );
    await tester.tap(find.text('Supermercado Central').first);
    await tester.pumpAndSettle();
    expect(find.text('Editar transação'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Ultra: paleta filtra Transações do mês pela busca', (
    tester,
  ) async {
    final s = await _boot(tester, AppMode.ultra);
    await _pumpApp(tester, s);

    await _openPalette(tester);
    await _searchPalette(tester, 'mercado');
    await tester.tap(find.text('Filtrar Transações do mês por “mercado”'));
    await tester.pumpAndSettle();

    expect(find.byType(TransactionsPage), findsOneWidget);
    final field = find.descendant(
      of: find.byType(TransactionFilterBar),
      matching: find.byType(TextField),
    );
    expect(tester.widget<TextField>(field).controller?.text, 'mercado');
  });

  testWidgets('Ultra em Transações: / foca a busca e N não abre o form', (
    tester,
  ) async {
    final s = await _boot(tester, AppMode.ultra);
    await _pumpApp(tester, s);

    await _key(tester, LogicalKeyboardKey.digit5);
    await _key(tester, LogicalKeyboardKey.slash);
    expect(isTextInputFocused(), isTrue);
    expect(find.byKey(const ValueKey('palette-input')), findsNothing);

    await _key(tester, LogicalKeyboardKey.keyN);
    expect(find.byType(Dialog), findsNothing);
  });

  testWidgets('Simples em Transações: / abre a paleta', (tester) async {
    final s = await _boot(tester, AppMode.simple);
    await _pumpApp(tester, s);

    await _key(tester, LogicalKeyboardKey.digit5);
    await _key(tester, LogicalKeyboardKey.slash);
    expect(find.byKey(const ValueKey('palette-input')), findsOneWidget);
  });

  testWidgets('comandos da paleta mudam modo, valores ocultos e tema', (
    tester,
  ) async {
    final s = await _boot(tester, AppMode.simple);
    await _pumpApp(tester, s);

    await _openPalette(tester);
    await _searchPalette(tester, 'ultra');
    await tester.tap(find.text('Mudar para Modo Ultra'));
    await tester.pumpAndSettle();
    expect(s.settings.value.mode, AppMode.ultra);

    await _openPalette(tester);
    await _searchPalette(tester, 'ocultar');
    await tester.tap(find.text('Ocultar valores'));
    await tester.pumpAndSettle();
    expect(s.settings.value.hideValues, isTrue);

    await _openPalette(tester);
    await _searchPalette(tester, 'tema');
    await tester.tap(find.text('Alternar tema claro/escuro'));
    await tester.pumpAndSettle();
    expect(s.settings.value.theme, ThemePreference.dark);
    expect(tester.takeException(), isNull);
  });

  testWidgets('excluir uma linha devolve o foco ao shell: 1 continua navegando', (
    tester,
  ) async {
    final s = await _boot(tester, AppMode.ultra);
    await _pumpApp(tester, s);

    await _key(tester, LogicalKeyboardKey.digit5);
    // Uma linha só: é o último elemento da ListView, então excluí-la tira o nó focado da árvore.
    // (Excluir uma linha do meio não descarta foco: a ListView reaproveita os elementos.)
    final search = find.descendant(
      of: find.byType(TransactionFilterBar),
      matching: find.byType(TextField),
    );
    await tester.enterText(search, 'Salário');
    await tester.pumpAndSettle();
    FocusManager.instance.primaryFocus?.unfocus();
    await tester.pumpAndSettle();
    expect(find.byType(TransactionRow), findsOneWidget);
    final before = s.transactions.all.length;

    await tester.tap(find.byTooltip('Ações'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Excluir'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Excluir'));
    await tester.pumpAndSettle();
    expect(s.transactions.all.length, before - 1);
    expect(tester.takeException(), isNull);

    await _key(tester, LogicalKeyboardKey.digit1);
    expect(find.byType(DashboardPage), findsOneWidget);
  });
}
