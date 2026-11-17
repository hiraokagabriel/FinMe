import 'package:finme/app/app_scope.dart';
import 'package:finme/app/bootstrap.dart';
import 'package:finme/core/services/record_store.dart';
import 'package:finme/core/theme/app_theme.dart';
import 'package:finme/core/widgets/widgets.dart';
import 'package:finme/features/rules/domain/transaction_rule.dart';
import 'package:finme/features/rules/presentation/rule_form.dart';
import 'package:finme/features/rules/presentation/rules_section.dart';
import 'package:finme/features/transactions/domain/transaction.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Future<AppServices> _setup(WidgetTester tester) async {
  return (await tester.runAsync(
    () => bootstrap(
      storeFactory: (_) => MemoryRecordStore(),
      clock: () => DateTime(2026, 11, 14),
    ),
  ))!;
}

Future<void> _pump(WidgetTester tester, AppServices s, Widget child) async {
  await tester.binding.setSurfaceSize(const Size(1000, 1200));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(
    AppScope(
      services: s,
      child: MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: child,
          ),
        ),
      ),
    ),
  );
  await tester.pump();
}

/// Botão que abre o form direto, com os parâmetros da prévia de importação.
Widget _opener({String? pattern, String? sample}) => Builder(
  builder: (context) => TextButton(
    onPressed: () => showRuleForm(
      context,
      initialPattern: pattern,
      sampleDescription: sample,
    ),
    child: const Text('abrir'),
  ),
);

String _categoryId(AppServices s, String name) =>
    s.categories.all.firstWhere((c) => c.name == name).id;

void main() {
  testWidgets(
    'vazio mostra estado vazio; criar regra pelo form aparece na lista',
    (tester) async {
      final s = await _setup(tester);
      await _pump(tester, s, const RulesSection());

      expect(find.byType(EmptyState), findsOneWidget);
      await tester.tap(find.widgetWithText(FilledButton, 'Nova regra').first);
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextFormField).first, 'IFOOD');
      await tester.tap(find.byType(DropdownButtonFormField<String?>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Alimentação').last);
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Salvar'));
      await tester.pumpAndSettle();

      expect(s.rules.all.length, 1);
      final rule = s.rules.all.single;
      expect(rule.pattern, 'IFOOD');
      expect(rule.categoryId, _categoryId(s, 'Alimentação'));
      expect(rule.priority, 0);
      expect(find.text('IFOOD'), findsOneWidget);
      expect(find.byType(EmptyState), findsNothing);
    },
  );

  testWidgets(
    'regra só com tags salva; sem nada mostra o erro; linha mostra #app',
    (tester) async {
      final s = await _setup(tester);
      await _pump(tester, s, const RulesSection());

      await tester.tap(find.widgetWithText(FilledButton, 'Nova regra').first);
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextFormField).first, 'UBER');
      await tester.tap(find.widgetWithText(FilledButton, 'Salvar'));
      await tester.pumpAndSettle();
      expect(find.text('Defina categoria, renomeação ou tags'), findsOneWidget);
      expect(s.rules.all, isEmpty);

      await tester.enterText(find.byKey(const ValueKey('tag-input')), 'app,');
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Salvar'));
      await tester.pumpAndSettle();

      final rule = s.rules.all.single;
      expect(rule.tags, ['app']);
      expect(rule.categoryId, isNull);
      expect(find.text('#app'), findsOneWidget);
    },
  );

  testWidgets('regex inválida mostra "Padrão inválido" e não salva', (
    tester,
  ) async {
    final s = await _setup(tester);
    await _pump(tester, s, _opener());
    await tester.tap(find.text('abrir'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Regex'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField).first, '(');
    await tester.tap(find.widgetWithText(FilledButton, 'Salvar'));
    await tester.pumpAndSettle();

    expect(find.text('Padrão inválido'), findsOneWidget);
    expect(s.rules.all, isEmpty);
  });

  testWidgets('"Testar padrão" com linha de exemplo mostra se casa', (
    tester,
  ) async {
    final s = await _setup(tester);
    await _pump(
      tester,
      s,
      _opener(pattern: 'LOJA EXEMPLO', sample: 'LOJA EXEMPLO PARC 03/10'),
    );
    await tester.tap(find.text('abrir'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Testar padrão'));
    await tester.pumpAndSettle();
    expect(find.text('Casa com a linha'), findsOneWidget);
  });

  testWidgets('arrastar a 2ª regra para o topo renumera as prioridades', (
    tester,
  ) async {
    final s = await _setup(tester);
    await s.rules.upsertAll([
      const TransactionRule(id: 'a', pattern: 'AAA', priority: 0),
      const TransactionRule(id: 'b', pattern: 'BBB', priority: 1),
      const TransactionRule(id: 'c', pattern: 'CCC', priority: 2),
    ]);
    await _pump(tester, s, const RulesSection());

    await tester.drag(
      find.byIcon(Icons.drag_indicator).at(1),
      const Offset(0, -120),
    );
    await tester.pumpAndSettle();

    expect(s.rules.byId('b')!.priority, 0);
    expect(s.rules.byId('a')!.priority, 1);
    expect(s.rules.byId('c')!.priority, 2);
  });

  testWidgets('desligar o switch grava active false', (tester) async {
    final s = await _setup(tester);
    await s.rules.upsert(const TransactionRule(id: 'a', pattern: 'AAA'));
    await _pump(tester, s, const RulesSection());

    await tester.tap(find.byType(Switch));
    await tester.pumpAndSettle();

    expect(s.rules.byId('a')!.active, isFalse);
  });

  testWidgets('reaplicar regra de tags conta só as que ganham tag nova', (
    tester,
  ) async {
    final s = await _setup(tester);
    await s.rules.upsert(
      const TransactionRule(id: 'a', pattern: 'UBER', tags: ['app']),
    );
    final day = DateTime(2026, 11, 12);
    await s.transactions.upsertAll([
      Transaction(
        id: 't1',
        type: TransactionType.expense,
        amountCents: 1000,
        date: day,
        description: 'UBER TRIP',
      ),
      Transaction(
        id: 't2',
        type: TransactionType.expense,
        amountCents: 2000,
        date: day,
        description: 'UBER EATS',
        tags: const ['app'],
      ),
      Transaction(
        id: 't3',
        type: TransactionType.expense,
        amountCents: 900,
        date: day,
        description: 'UBER X',
      ),
      Transaction(
        id: 't4',
        type: TransactionType.expense,
        amountCents: 900,
        date: day,
        description: 'PADARIA',
      ),
    ]);
    await _pump(tester, s, const RulesSection());

    await tester.tap(find.text('Reaplicar às transações'));
    await tester.pumpAndSettle();
    expect(
      find.text(
        '2 transações vão mudar (0 de categoria, 0 de descrição, 2 de tags)',
      ),
      findsOneWidget,
    );

    await tester.tap(find.widgetWithText(FilledButton, 'Aplicar'));
    await tester.pumpAndSettle();
    expect(s.transactions.byId('t1')!.tags, ['app']);
    expect(s.transactions.byId('t3')!.tags, ['app']);
    expect(s.transactions.byId('t4')!.tags, isEmpty);
  });

  testWidgets('reaplicar: mostra a prévia, aplica e fica zerado ao reabrir', (
    tester,
  ) async {
    final s = await _setup(tester);
    await s.rules.upsert(
      TransactionRule(
        id: 'a',
        pattern: 'IFOOD',
        categoryId: _categoryId(s, 'Alimentação'),
      ),
    );
    final day = DateTime(2026, 11, 12);
    await s.transactions.upsertAll([
      Transaction(
        id: 't1',
        type: TransactionType.expense,
        amountCents: 3000,
        date: day,
        description: 'IFOOD RESTAURANTE',
      ),
      Transaction(
        id: 't2',
        type: TransactionType.expense,
        amountCents: 1500,
        date: day,
        description: 'IFOOD X 12/11',
      ),
      Transaction(
        id: 't3',
        type: TransactionType.expense,
        amountCents: 900,
        date: day,
        description: 'PADARIA',
      ),
    ]);
    await _pump(tester, s, const RulesSection());

    await tester.tap(find.text('Reaplicar às transações'));
    await tester.pumpAndSettle();
    expect(
      find.text(
        '2 transações vão mudar (2 de categoria, 0 de descrição, 0 de tags)',
      ),
      findsOneWidget,
    );

    await tester.tap(find.widgetWithText(FilledButton, 'Aplicar'));
    await tester.pumpAndSettle();
    expect(
      s.transactions.byId('t1')!.categoryId,
      _categoryId(s, 'Alimentação'),
    );
    expect(s.transactions.byId('t3')!.categoryId, isNull);

    await tester.tap(find.text('Reaplicar às transações'));
    await tester.pumpAndSettle();
    expect(
      find.text(
        '0 transações vão mudar (0 de categoria, 0 de descrição, 0 de tags)',
      ),
      findsOneWidget,
    );
    expect(
      tester
          .widget<FilledButton>(find.widgetWithText(FilledButton, 'Aplicar'))
          .onPressed,
      isNull,
    );
  });
}
