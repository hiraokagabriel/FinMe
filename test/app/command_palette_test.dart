import 'package:finme/app/command_palette.dart';
import 'package:finme/core/theme/app_colors.dart';
import 'package:finme/core/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> _open(
  WidgetTester tester, {
  required List<PaletteEntry> commands,
  List<PaletteEntry> Function(String query)? search,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.light(),
      home: Scaffold(
        body: Builder(
          builder: (context) => Center(
            child: ElevatedButton(
              onPressed: () => showCommandPalette(
                context,
                commands: commands,
                search: search,
              ),
              child: const Text('Abrir'),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('Abrir'));
  await tester.pumpAndSettle();
}

List<PaletteEntry> _commands(List<String> ran) => [
  PaletteEntry(
    label: 'Nova transação',
    icon: Icons.add,
    shortcut: 'N',
    keywords: const ['lançar', 'despesa', 'receita', 'adicionar'],
    onRun: () => ran.add('Nova transação'),
  ),
  PaletteEntry(
    label: 'Nova recorrência',
    icon: Icons.repeat,
    keywords: const ['assinatura', 'fixo'],
    onRun: () => ran.add('Nova recorrência'),
  ),
  PaletteEntry(
    label: 'Ir para Painel',
    icon: Icons.dashboard,
    shortcut: '1',
    onRun: () => ran.add('Ir para Painel'),
  ),
];

void main() {
  testWidgets('abre com foco no campo, comandos, cabeçalho e rodapé', (
    tester,
  ) async {
    final ran = <String>[];
    await _open(tester, commands: _commands(ran));

    final field = tester.widget<EditableText>(find.byType(EditableText));
    expect(field.focusNode.hasFocus, isTrue);
    expect(find.text('Comandos'), findsOneWidget);
    expect(find.byKey(const ValueKey('palette-item-0')), findsOneWidget);
    expect(find.byKey(const ValueKey('palette-item-2')), findsOneWidget);
    expect(find.text('N'), findsOneWidget);
    expect(
      find.text('↑↓ navegar · Enter executar · Esc fechar'),
      findsOneWidget,
    );
  });

  testWidgets('digitar nova mostra 2 itens; ↓ e Enter executa a segunda', (
    tester,
  ) async {
    final ran = <String>[];
    var dialogGoneWhenRun = false;
    final commands = _commands(ran);
    commands[1] = PaletteEntry(
      label: 'Nova recorrência',
      icon: Icons.repeat,
      keywords: const ['assinatura', 'fixo'],
      onRun: () {
        dialogGoneWhenRun = find.byType(Dialog).evaluate().isEmpty;
        ran.add('Nova recorrência');
      },
    );
    await _open(tester, commands: commands);

    await tester.enterText(find.byKey(const ValueKey('palette-input')), 'nova');
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('palette-item-0')), findsOneWidget);
    expect(find.byKey(const ValueKey('palette-item-1')), findsOneWidget);
    expect(find.byKey(const ValueKey('palette-item-2')), findsNothing);

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pumpAndSettle();
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();

    expect(ran, ['Nova recorrência']);
    expect(dialogGoneWhenRun, isTrue);
    expect(find.byType(Dialog), findsNothing);
  });

  testWidgets('↑ no primeiro e ↓ além do último mantêm o destaque nas pontas', (
    tester,
  ) async {
    final ran = <String>[];
    await _open(tester, commands: _commands(ran));

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
    await tester.pumpAndSettle();
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
    expect(ran, ['Nova transação']);
  });

  testWidgets('↓ além do último fica no último', (tester) async {
    final ran = <String>[];
    await _open(tester, commands: _commands(ran));

    for (var i = 0; i < 5; i++) {
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.pumpAndSettle();
    }
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
    expect(ran, ['Ir para Painel']);
  });

  testWidgets('resultados de busca vêm depois dos comandos, com cabeçalho', (
    tester,
  ) async {
    final ran = <String>[];
    final commands = [
      ..._commands(ran),
      PaletteEntry(
        label: 'Abrir extrato',
        icon: Icons.upload_file,
        onRun: () => ran.add('Abrir extrato'),
      ),
    ];
    List<PaletteEntry> search(String q) => q != 'ab'
        ? const []
        : [
            PaletteEntry(
              group: 'Transações',
              label: 'Mercado Abril',
              subtitle: '10/11/2026 · Conta · Mercado',
              icon: Icons.receipt_long,
              onRun: () => ran.add('T1'),
            ),
            PaletteEntry(
              group: 'Transações',
              label: 'Padaria Abril',
              subtitle: '11/11/2026 · Cartão · Alimentação',
              icon: Icons.receipt_long,
              onRun: () => ran.add('T2'),
            ),
          ];
    await _open(tester, commands: commands, search: search);

    await tester.enterText(find.byKey(const ValueKey('palette-input')), 'ab');
    await tester.pumpAndSettle();

    final headerTransacoes = find.text('Transações');
    expect(headerTransacoes, findsOneWidget);
    expect(
      tester.getTopLeft(headerTransacoes).dy,
      greaterThan(tester.getTopLeft(find.text('Abrir extrato')).dy),
    );

    await tester.tap(find.byKey(const ValueKey('palette-item-2')));
    await tester.pumpAndSettle();
    expect(ran, ['T2']);
    expect(find.byType(Dialog), findsNothing);
  });

  testWidgets('sem resultados mostra "Nada encontrado" e Enter não faz nada', (
    tester,
  ) async {
    final ran = <String>[];
    await _open(tester, commands: _commands(ran));

    await tester.enterText(find.byKey(const ValueKey('palette-input')), 'xyz');
    await tester.pumpAndSettle();
    expect(find.text('Nada encontrado'), findsOneWidget);

    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
    expect(ran, isEmpty);
    expect(find.byKey(const ValueKey('palette-input')), findsOneWidget);
  });

  testWidgets('Esc fecha sem executar', (tester) async {
    final ran = <String>[];
    await _open(tester, commands: _commands(ran));

    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(find.byType(Dialog), findsNothing);
    expect(ran, isEmpty);
  });

  testWidgets('rodapé e itens usam tokens de cor do tema', (tester) async {
    await _open(tester, commands: _commands([]));
    final footer = tester.widget<Text>(
      find.text('↑↓ navegar · Enter executar · Esc fechar'),
    );
    expect(footer.style?.color, AppColors.light.textSecondary);
  });
}
