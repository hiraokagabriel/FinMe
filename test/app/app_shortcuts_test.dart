import 'package:finme/app/app_shortcuts.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

const _campo = ValueKey<String>('campo');

Widget _harness(List<Intent> log) {
  Object? record(Intent intent) {
    log.add(intent);
    return null;
  }

  return Shortcuts(
    shortcuts: kAppShortcuts,
    child: Actions(
      actions: <Type, Action<Intent>>{
        NewTransactionIntent: TypingGuardAction<NewTransactionIntent>(
          onInvoke: record,
        ),
        FocusSearchIntent: TypingGuardAction<FocusSearchIntent>(
          onInvoke: record,
        ),
        GoToPageIntent: TypingGuardAction<GoToPageIntent>(onInvoke: record),
        OpenPaletteIntent: CallbackAction<OpenPaletteIntent>(onInvoke: record),
        ImportFileIntent: CallbackAction<ImportFileIntent>(onInvoke: record),
      },
      child: const Focus(
        autofocus: true,
        child: Material(child: TextField(key: _campo)),
      ),
    ),
  );
}

Widget _selectionHarness(List<Intent> log) {
  Object? record(Intent intent) {
    log.add(intent);
    return null;
  }

  return Shortcuts(
    shortcuts: kSelectionShortcuts,
    child: Actions(
      actions: <Type, Action<Intent>>{
        SelectAllRowsIntent: TypingGuardAction<SelectAllRowsIntent>(
          onInvoke: record,
        ),
        ClearSelectionIntent: TypingGuardAction<ClearSelectionIntent>(
          onInvoke: record,
        ),
      },
      child: const Focus(
        autofocus: true,
        child: Material(child: TextField(key: _campo)),
      ),
    ),
  );
}

Future<void> _ctrl(WidgetTester tester, LogicalKeyboardKey key) async {
  await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
  await tester.sendKeyEvent(key);
  await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
  await tester.pump();
}

void main() {
  group('kAppShortcuts sem foco em campo', () {
    testWidgets('N, dígitos, / e Ctrl+K/Ctrl+I disparam os intents', (
      tester,
    ) async {
      final log = <Intent>[];
      await tester.pumpWidget(MaterialApp(home: _harness(log)));
      await tester.pump();

      expect(isTextInputFocused(), isFalse);

      await tester.sendKeyEvent(LogicalKeyboardKey.keyN);
      await tester.pump();
      expect(log, [isA<NewTransactionIntent>()]);

      log.clear();
      await tester.sendKeyEvent(LogicalKeyboardKey.digit3);
      await tester.pump();
      expect(log, [isA<GoToPageIntent>().having((i) => i.index, 'index', 2)]);

      log.clear();
      await tester.sendKeyEvent(LogicalKeyboardKey.numpad9);
      await tester.pump();
      expect(log, [isA<GoToPageIntent>().having((i) => i.index, 'index', 8)]);

      log.clear();
      await tester.sendKeyEvent(LogicalKeyboardKey.slash, character: '/');
      await tester.pump();
      expect(log, [isA<FocusSearchIntent>()]);

      log.clear();
      await _ctrl(tester, LogicalKeyboardKey.keyK);
      expect(log, [isA<OpenPaletteIntent>()]);

      log.clear();
      await _ctrl(tester, LogicalKeyboardKey.keyI);
      expect(log, [isA<ImportFileIntent>()]);
    });

    testWidgets('Shift+N não dispara NewTransactionIntent', (tester) async {
      final log = <Intent>[];
      await tester.pumpWidget(MaterialApp(home: _harness(log)));
      await tester.pump();

      await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.keyN);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
      await tester.pump();

      expect(log, isEmpty);
    });
  });

  group('kAppShortcuts com foco em campo de texto', () {
    testWidgets('N, dígito e / não disparam; Ctrl+K dispara', (tester) async {
      final log = <Intent>[];
      await tester.pumpWidget(MaterialApp(home: _harness(log)));
      await tester.pump();

      await tester.tap(find.byKey(_campo));
      await tester.pump();
      expect(isTextInputFocused(), isTrue);

      await tester.sendKeyEvent(LogicalKeyboardKey.keyN);
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.digit3);
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.slash, character: '/');
      await tester.pump();
      expect(log, isEmpty);

      await _ctrl(tester, LogicalKeyboardKey.keyK);
      expect(log, [isA<OpenPaletteIntent>()]);
    });
  });

  group('kSelectionShortcuts', () {
    testWidgets('Ctrl+A e Esc disparam sem foco em campo', (tester) async {
      final log = <Intent>[];
      await tester.pumpWidget(MaterialApp(home: _selectionHarness(log)));
      await tester.pump();

      await _ctrl(tester, LogicalKeyboardKey.keyA);
      expect(log, [isA<SelectAllRowsIntent>()]);

      log.clear();
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pump();
      expect(log, [isA<ClearSelectionIntent>()]);
    });

    testWidgets('com foco em campo, Ctrl+A não gera intent', (tester) async {
      final log = <Intent>[];
      await tester.pumpWidget(MaterialApp(home: _selectionHarness(log)));
      await tester.pump();

      await tester.tap(find.byKey(_campo));
      await tester.pump();

      await _ctrl(tester, LogicalKeyboardKey.keyA);
      expect(log, isEmpty);
    });
  });
}
