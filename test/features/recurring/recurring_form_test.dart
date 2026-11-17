import 'package:finme/app/app_scope.dart';
import 'package:finme/app/bootstrap.dart';
import 'package:finme/app/seed.dart';
import 'package:finme/core/models/app_settings.dart';
import 'package:finme/core/services/record_store.dart';
import 'package:finme/core/theme/app_theme.dart';
import 'package:finme/features/categories/domain/transaction_category.dart';
import 'package:finme/features/recurring/domain/recurring_rule.dart';
import 'package:finme/features/recurring/presentation/recurring_form.dart';
import 'package:finme/features/transactions/domain/transaction.dart';
import 'package:finme/features/transactions/presentation/tag_widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Future<AppServices> _boot(WidgetTester tester, AppMode mode) async {
  return (await tester.runAsync(() async {
    final s = await bootstrap(
      storeFactory: (_) => MemoryRecordStore(),
      clock: () => DateTime(2026, 11, 14),
    );
    await seedDemo(s);
    await s.settings.update((c) => c.copyWith(mode: mode));
    return s;
  }))!;
}

RecurringRule _regra() => RecurringRule(
  id: 'rec_casa',
  description: 'Aluguel',
  type: TransactionType.expense,
  amountCents: 150000,
  frequency: Frequency.monthly,
  startDate: DateTime(2026, 11, 5),
  accountId: 'acc_alfa',
  tags: const ['casa'],
);

Future<void> _openForm(
  WidgetTester tester,
  AppServices s, {
  RecurringRule? initial,
}) async {
  await tester.binding.setSurfaceSize(const Size(1400, 1000));
  await tester.pumpWidget(
    AppScope(
      services: s,
      child: MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(
          body: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () => showRecurringForm(context, initial: initial),
              child: const Text('abrir'),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('abrir'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('duplo tap no Salvar da recorrência cria só 1 regra', (
    tester,
  ) async {
    final s = (await tester.runAsync(() async {
      final services = await bootstrap(
        storeFactory: (_) => MemoryRecordStore(),
        clock: () => DateTime(2026, 11, 14),
      );
      await seedDemo(services);
      return services;
    }))!;
    await tester.binding.setSurfaceSize(const Size(1400, 1000));
    await tester.pumpWidget(
      AppScope(
        services: s,
        child: MaterialApp(
          theme: AppTheme.light(),
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () => showRecurringForm(context),
                child: const Text('abrir'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('abrir'));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.widgetWithText(TextFormField, 'Descrição'),
      'Assinatura dupla',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Valor'),
      '19,90',
    );
    await tester.tap(find.byType(DropdownButtonFormField<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Banco Alfa · Conta corrente').last);
    await tester.pumpAndSettle();

    // Dois cliques no mesmo frame: o 2º chega antes do rebuild que desabilita o botão.
    final save = tester
        .widget<FilledButton>(find.byType(FilledButton))
        .onPressed!;
    save();
    save();
    await tester.pumpAndSettle();

    expect(
      s.recurring.all.where((r) => r.description == 'Assinatura dupla'),
      hasLength(1),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'categoria filha aparece como Pai › Filha logo após a pai e grava o id da filha',
    (tester) async {
      final s = (await tester.runAsync(() async {
        final services = await bootstrap(
          storeFactory: (_) => MemoryRecordStore(),
          clock: () => DateTime(2026, 11, 14),
        );
        await seedDemo(services);
        final base = services.categories.byId('cat_mercado')!;
        await services.categories.upsert(
          TransactionCategory(
            id: 'cat_mercado_x',
            name: 'Mercado X',
            kind: CategoryKind.expense,
            iconCodePoint: base.iconCodePoint,
            colorValue: base.colorValue,
            parentId: 'cat_alimentacao',
          ),
        );
        return services;
      }))!;
      await tester.binding.setSurfaceSize(const Size(1400, 1000));
      await tester.pumpWidget(
        AppScope(
          services: s,
          child: MaterialApp(
            theme: AppTheme.light(),
            home: Scaffold(
              body: Builder(
                builder: (context) => ElevatedButton(
                  onPressed: () => showRecurringForm(context),
                  child: const Text('abrir'),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('abrir'));
      await tester.pumpAndSettle();

      await tester.enterText(
        find.widgetWithText(TextFormField, 'Descrição'),
        'Compra filha',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Valor'),
        '50,00',
      );
      await tester.tap(find.byType(DropdownButtonFormField<String>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Banco Alfa · Conta corrente').last);
      await tester.pumpAndSettle();

      await tester.tap(
        find.widgetWithText(DropdownButtonFormField<String?>, 'Sem categoria'),
      );
      await tester.pumpAndSettle();
      final tree = s.ledger.categoryTree;
      final labels = {
        for (final c in tree.options(CategoryKind.expense)) tree.label(c.id),
      };
      // Ordem dos textos da tela: o item filho tem que vir logo depois do pai.
      final shown = [
        for (final w in tester.widgetList<Text>(find.byType(Text)))
          if (w.data != null && labels.contains(w.data)) w.data!,
      ];
      expect(
        shown.indexOf('Alimentação › Mercado X'),
        shown.indexOf('Alimentação') + 1,
      );
      await tester.tap(find.text('Alimentação › Mercado X').last);
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(FilledButton, 'Salvar'));
      await tester.pumpAndSettle();

      expect(
        s.recurring.all
            .where((r) => r.description == 'Compra filha')
            .single
            .categoryId,
        'cat_mercado_x',
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('Ultra: tags digitadas no formulário são gravadas na regra', (
    tester,
  ) async {
    final s = await _boot(tester, AppMode.ultra);
    await _openForm(tester, s);

    await tester.enterText(
      find.widgetWithText(TextFormField, 'Descrição'),
      'Internet',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Valor'),
      '99,90',
    );
    await tester.tap(find.byType(DropdownButtonFormField<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Banco Alfa · Conta corrente').last);
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('tag-input')),
      'casa, fixo',
    );
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Salvar'));
    await tester.pumpAndSettle();

    expect(
      s.recurring.all.where((r) => r.description == 'Internet').single.tags,
      ['casa', 'fixo'],
    );
  });

  testWidgets('Ultra: editar regra com tags mostra os chips', (tester) async {
    final s = await _boot(tester, AppMode.ultra);
    final r = _regra();
    await tester.runAsync(() => s.recurring.upsert(r));
    await _openForm(tester, s, initial: r);

    expect(find.byType(TagField), findsOneWidget);
    expect(find.text('casa'), findsOneWidget);
  });

  testWidgets('Simples: sem campo de tags; salvar mantém as tags da regra', (
    tester,
  ) async {
    final s = await _boot(tester, AppMode.simple);
    final r = _regra();
    await tester.runAsync(() => s.recurring.upsert(r));
    await _openForm(tester, s, initial: r);

    expect(find.byType(TagField), findsNothing);
    await tester.tap(find.widgetWithText(FilledButton, 'Salvar'));
    await tester.pumpAndSettle();

    expect(s.recurring.all.where((x) => x.id == 'rec_casa').single.tags, [
      'casa',
    ]);
  });
}
