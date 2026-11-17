import 'package:finme/core/theme/app_theme.dart';
import 'package:finme/features/transactions/presentation/tag_widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> _pump(WidgetTester tester, Widget child) => tester.pumpWidget(
  MaterialApp(
    theme: AppTheme.light(),
    home: Scaffold(
      body: Padding(padding: const EdgeInsets.all(16), child: child),
    ),
  ),
);

final _input = find.byKey(const ValueKey('tag-input'));

/// Abre o diálogo a partir de um botão; o resultado é guardado em [out].
Future<void> _openBulk(
  WidgetTester tester,
  int count,
  void Function(BulkTagsChoice?) out,
) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.light(),
      home: Scaffold(
        body: Builder(
          builder: (ctx) => TextButton(
            onPressed: () async => out(
              await showBulkTagsDialog(
                ctx,
                count: count,
                suggestions: const [],
              ),
            ),
            child: const Text('abrir'),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('abrir'));
  await tester.pumpAndSettle();
}

void main() {
  group('TagField', () {
    testWidgets('vírgula confirma as tags e limpa o campo', (tester) async {
      List<String>? got;
      await _pump(tester, TagField(tags: const [], onChanged: (v) => got = v));
      await tester.tap(_input);
      await tester.enterText(_input, 'viagem, Casa');
      expect(got, ['viagem', 'Casa']);
      expect(
        tester.widget<EditableText>(find.byType(EditableText)).controller.text,
        '',
      );
    });

    testWidgets('Enter com tag repetida (outra caixa) mantém a 1ª grafia', (
      tester,
    ) async {
      List<String>? got;
      await _pump(
        tester,
        TagField(tags: const ['viagem'], onChanged: (v) => got = v),
      );
      await tester.tap(_input);
      await tester.enterText(_input, 'VIAGEM');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pump();
      expect(got, ['viagem']);
    });

    testWidgets('X do chip remove só aquela tag', (tester) async {
      List<String>? got;
      await _pump(
        tester,
        TagField(tags: const ['a', 'b'], onChanged: (v) => got = v),
      );
      final chipA = find.widgetWithText(InputChip, 'a');
      await tester.tap(find.descendant(of: chipA, matching: find.byType(Icon)));
      expect(got, ['b']);
    });

    testWidgets('Backspace com campo vazio remove a última tag', (
      tester,
    ) async {
      List<String>? got;
      await _pump(
        tester,
        TagField(tags: const ['a', 'b'], onChanged: (v) => got = v),
      );
      await tester.tap(_input);
      await tester.sendKeyEvent(LogicalKeyboardKey.backspace);
      expect(got, ['a']);
    });

    testWidgets('sugestões filtradas pelo texto; toque adiciona', (
      tester,
    ) async {
      List<String>? got;
      await _pump(
        tester,
        TagField(
          tags: const ['casa'],
          suggestions: const ['viagem', 'trabalho', 'casa'],
          onChanged: (v) => got = v,
        ),
      );
      await tester.tap(_input);
      await tester.enterText(_input, 'tr');
      await tester.pump();
      expect(find.widgetWithText(ActionChip, 'trabalho'), findsOneWidget);
      expect(find.widgetWithText(ActionChip, 'viagem'), findsNothing);
      expect(find.widgetWithText(ActionChip, 'casa'), findsNothing);
      await tester.tap(find.widgetWithText(ActionChip, 'trabalho'));
      expect(got, ['casa', 'trabalho']);
    });
  });

  group('TagChips', () {
    testWidgets('até 3 chips e depois +N', (tester) async {
      await _pump(tester, const TagChips(tags: ['a', 'b', 'c', 'd']));
      expect(find.text('#a'), findsOneWidget);
      expect(find.text('#b'), findsOneWidget);
      expect(find.text('#c'), findsOneWidget);
      expect(find.text('+1'), findsOneWidget);
      expect(find.text('#d'), findsNothing);
    });

    testWidgets('sem tags não renderiza nada', (tester) async {
      await _pump(tester, const TagChips(tags: []));
      expect(find.byType(Container), findsNothing);
      expect(find.textContaining('#'), findsNothing);
    });
  });

  group('showBulkTagsDialog', () {
    testWidgets('adicionar tag e aplicar', (tester) async {
      BulkTagsChoice? result;
      var done = false;
      await _openBulk(tester, 3, (r) {
        result = r;
        done = true;
      });
      expect(find.text('Tags em 3 transações'), findsOneWidget);
      expect(
        tester
            .widget<FilledButton>(find.widgetWithText(FilledButton, 'Aplicar'))
            .onPressed,
        isNull,
      );
      await tester.tap(_input);
      await tester.enterText(_input, 'x');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pump();
      await tester.tap(find.widgetWithText(FilledButton, 'Aplicar'));
      await tester.pumpAndSettle();
      expect(done, isTrue);
      expect(result?.remove, false);
      expect(result?.tags, ['x']);
    });

    testWidgets('modo Remover devolve remove: true', (tester) async {
      BulkTagsChoice? result;
      await _openBulk(tester, 3, (r) => result = r);
      await tester.tap(find.text('Remover'));
      await tester.pump();
      await tester.tap(_input);
      await tester.enterText(_input, 'x,');
      await tester.pump();
      await tester.tap(find.widgetWithText(FilledButton, 'Aplicar'));
      await tester.pumpAndSettle();
      expect(result?.remove, true);
      expect(result?.tags, ['x']);
    });

    testWidgets('Cancelar devolve null', (tester) async {
      BulkTagsChoice? result = (remove: true, tags: ['sentinela']);
      await _openBulk(tester, 3, (r) => result = r);
      await tester.tap(find.text('Cancelar'));
      await tester.pumpAndSettle();
      expect(result, isNull);
    });
  });
}
