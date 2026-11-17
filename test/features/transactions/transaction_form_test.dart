import 'package:finme/app/app_scope.dart';
import 'package:finme/app/bootstrap.dart';
import 'package:finme/app/seed.dart';
import 'package:finme/core/models/app_settings.dart';
import 'package:finme/core/services/record_store.dart';
import 'package:finme/core/theme/app_theme.dart';
import 'package:finme/features/categories/domain/transaction_category.dart';
import 'package:finme/features/rules/domain/transaction_rule.dart';
import 'package:finme/features/transactions/domain/transaction.dart';
import 'package:finme/features/transactions/presentation/tag_widgets.dart';
import 'package:finme/features/transactions/presentation/transaction_form.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Future<AppServices> _boot(
  WidgetTester tester, {
  AppMode mode = AppMode.simple,
}) async {
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

Future<void> _pickCartao(WidgetTester tester) async {
  await tester.tap(find.byKey(const ValueKey('form-origem')));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Cartão · Alfa Visa ••••1234').last);
  await tester.pumpAndSettle();
}

Future<void> _addTag(WidgetTester tester, String tag) async {
  await tester.enterText(find.byKey(const ValueKey('tag-input')), tag);
  await tester.testTextInput.receiveAction(TextInputAction.done);
  await tester.pumpAndSettle();
}

Future<void> _openForm(
  WidgetTester tester,
  AppServices s, {
  Transaction? initial,
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
              onPressed: () => showTransactionForm(context, initial: initial),
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

/// Campo de categoria (a key muda com o valor selecionado).
Finder _categoriaField() => find.byWidgetPredicate(
  (w) =>
      w.key is ValueKey<String> &&
      (w.key! as ValueKey<String>).value.startsWith('form-categoria-'),
);

Future<void> _pickCategoria(WidgetTester tester, String name) async {
  await tester.tap(_categoriaField());
  await tester.pumpAndSettle();
  await tester.tap(find.text(name).last);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('descrição sugere categoria pelo dicionário em nova despesa', (
    tester,
  ) async {
    final s = await _boot(tester);
    await _openForm(tester, s);

    await tester.enterText(
      find.widgetWithText(TextFormField, 'Descrição'),
      'IFOOD PEDIDO',
    );
    await tester.pumpAndSettle();

    expect(find.text('Alimentação'), findsOneWidget);
    expect(find.text('Sugerida pelo dicionário'), findsOneWidget);
  });

  testWidgets(
    'sugestão some ao mudar a descrição: categoria sugerida é limpa',
    (tester) async {
      final s = await _boot(tester);
      await _openForm(tester, s);

      await tester.enterText(
        find.widgetWithText(TextFormField, 'Descrição'),
        'IFOOD PEDIDO',
      );
      await tester.pumpAndSettle();
      expect(find.text('Sugerida pelo dicionário'), findsOneWidget);

      await tester.enterText(
        find.widgetWithText(TextFormField, 'Descrição'),
        'QWERTY LOJA',
      );
      await tester.pumpAndSettle();

      expect(find.text('Sugerida pelo dicionário'), findsNothing);
      expect(find.text('Alimentação'), findsNothing);
      expect(find.text('Sem categoria'), findsOneWidget);
    },
  );

  testWidgets('categoria escolhida manualmente não é trocada pela descrição', (
    tester,
  ) async {
    final s = await _boot(tester);
    await _openForm(tester, s);

    await _pickCategoria(tester, 'Lazer');
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Descrição'),
      'UBER',
    );
    await tester.pumpAndSettle();

    expect(find.text('Lazer'), findsOneWidget);
    expect(find.text('Sugerida pelo dicionário'), findsNothing);
  });

  testWidgets(
    'editar transação com categoria e mudar a descrição mantém a categoria',
    (tester) async {
      final s = await _boot(tester);
      final tx = Transaction(
        id: 'tx_edit_lazer',
        type: TransactionType.expense,
        amountCents: 5000,
        date: DateTime(2026, 11, 10),
        description: 'Cinema exemplo',
        categoryId: 'cat_lazer',
        accountId: 'acc_alfa',
      );
      await tester.runAsync(() => s.transactions.upsert(tx));
      await _openForm(tester, s, initial: tx);

      await tester.enterText(
        find.widgetWithText(TextFormField, 'Descrição'),
        'UBER',
      );
      await tester.pumpAndSettle();

      expect(find.text('Lazer'), findsOneWidget);
      expect(find.text('Sugerida pelo dicionário'), findsNothing);
    },
  );

  testWidgets('nova receita "SALARIO EMPRESA" sugere Salário', (tester) async {
    final s = await _boot(tester);
    await _openForm(tester, s);

    await tester.tap(find.text('Receita'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Descrição'),
      'SALARIO EMPRESA',
    );
    await tester.pumpAndSettle();

    expect(find.text('Salário'), findsOneWidget);
  });

  testWidgets(
    'despesa parcelada 3x no cartão de crédito grava 3 parcelas somando o valor',
    (tester) async {
      final s = (await tester.runAsync(() async {
        final s = await bootstrap(
          storeFactory: (_) => MemoryRecordStore(),
          clock: () => DateTime(2026, 11, 14),
        );
        await seedDemo(s);
        return s;
      }))!;
      await tester.binding.setSurfaceSize(const Size(1400, 900));
      await tester.pumpWidget(
        AppScope(
          services: s,
          child: MaterialApp(
            theme: AppTheme.light(),
            home: Scaffold(
              body: Builder(
                builder: (context) => ElevatedButton(
                  onPressed: () => showTransactionForm(context),
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
        find.widgetWithText(TextFormField, 'Valor'),
        '100,00',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Descrição'),
        'Compra teste parcelada',
      );

      await tester.tap(find.byKey(const ValueKey('form-origem')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cartão · Alfa Visa ••••1234').last);
      await tester.pumpAndSettle();

      await tester.enterText(
        find.widgetWithText(TextFormField, 'Parcelas'),
        '3',
      );
      await tester.tap(find.text('Salvar'));
      await tester.pumpAndSettle();

      final parcels = s.transactions.all
          .where(
            (t) =>
                t.installmentGroupId != null &&
                t.description == 'Compra teste parcelada',
          )
          .toList();
      expect(parcels, hasLength(3));
      expect(parcels.fold<int>(0, (sum, t) => sum + t.amountCents), 10000);
      expect(
        parcels.map((t) => t.installmentIndex),
        unorderedEquals([1, 2, 3]),
      );
      expect(parcels.every((t) => t.cardId == 'card_alfa_visa'), isTrue);
      expect(parcels.every((t) => t.type == TransactionType.expense), isTrue);
      expect(
        parcels.every((t) => t.description == 'Compra teste parcelada'),
        isTrue,
      );
      expect(find.text('Salvar'), findsNothing);
    },
  );

  Transaction importada() => Transaction(
    id: 'tx_importada',
    type: TransactionType.expense,
    amountCents: 5000,
    date: DateTime(2026, 11, 10),
    description: 'Uber viagem',
    categoryId: 'cat_transporte',
    accountId: 'acc_alfa',
    tags: const ['viagem'],
    externalId: 'FIT-123',
    importedDescription: 'UBER *TRIP 9988',
  );

  testWidgets(
    'Simples: editar importada com tags preserva tags, externalId e importedDescription',
    (tester) async {
      final s = await _boot(tester);
      final tx = importada();
      await tester.runAsync(() => s.transactions.upsert(tx));
      await _openForm(tester, s, initial: tx);

      expect(find.byType(TagField), findsNothing);
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Valor'),
        '60,00',
      );
      await tester.tap(find.text('Salvar'));
      await tester.pumpAndSettle();

      final saved = s.transactions.byId('tx_importada')!;
      expect(saved.amountCents, 6000);
      expect(saved.tags, ['viagem']);
      expect(saved.externalId, 'FIT-123');
      expect(saved.importedDescription, 'UBER *TRIP 9988');
    },
  );

  testWidgets('Ultra: editar com tags mostra o chip e preserva as tags', (
    tester,
  ) async {
    final s = await _boot(tester, mode: AppMode.ultra);
    final tx = importada();
    await tester.runAsync(() => s.transactions.upsert(tx));
    await _openForm(tester, s, initial: tx);

    expect(find.byType(TagField), findsOneWidget);
    expect(find.text('viagem'), findsOneWidget);
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Valor'),
      '60,00',
    );
    await tester.tap(find.text('Salvar'));
    await tester.pumpAndSettle();

    final saved = s.transactions.byId('tx_importada')!;
    expect(saved.amountCents, 6000);
    expect(saved.tags, ['viagem']);
    expect(saved.externalId, 'FIT-123');
    expect(saved.importedDescription, 'UBER *TRIP 9988');
  });

  testWidgets('Ultra: nova despesa com tag digitada + Enter salva a tag', (
    tester,
  ) async {
    final s = await _boot(tester, mode: AppMode.ultra);
    await _openForm(tester, s);

    await tester.enterText(
      find.widgetWithText(TextFormField, 'Valor'),
      '25,00',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Descrição'),
      'Almoço trabalho',
    );
    await _pickCartao(tester);
    await _addTag(tester, 'trabalho');
    await tester.tap(find.text('Salvar'));
    await tester.pumpAndSettle();

    final saved = s.transactions.all.where(
      (t) => t.description == 'Almoço trabalho',
    );
    expect(saved, hasLength(1));
    expect(saved.single.tags, ['trabalho']);
  });

  testWidgets('Ultra: regra com tags preenche o form e salva com elas', (
    tester,
  ) async {
    final s = await _boot(tester, mode: AppMode.ultra);
    await tester.runAsync(
      () => s.rules.upsert(
        const TransactionRule(id: 'r_uber', pattern: 'UBER', tags: ['app']),
      ),
    );
    await _openForm(tester, s);

    await tester.enterText(
      find.widgetWithText(TextFormField, 'Valor'),
      '18,00',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Descrição'),
      'UBER TRIP',
    );
    await tester.pumpAndSettle();
    expect(find.text('app'), findsOneWidget);
    expect(find.text('Tags da regra'), findsOneWidget);

    await _pickCartao(tester);
    await tester.tap(find.text('Salvar'));
    await tester.pumpAndSettle();

    final saved = s.transactions.all.where((t) => t.description == 'UBER TRIP');
    expect(saved.single.tags, ['app']);
  });

  testWidgets(
    'Ultra: tags mexidas antes da descrição não são sobrescritas pela regra',
    (tester) async {
      final s = await _boot(tester, mode: AppMode.ultra);
      await tester.runAsync(
        () => s.rules.upsert(
          const TransactionRule(id: 'r_uber', pattern: 'UBER', tags: ['app']),
        ),
      );
      await _openForm(tester, s);

      await tester.enterText(
        find.widgetWithText(TextFormField, 'Valor'),
        '18,00',
      );
      await _pickCartao(tester);
      await _addTag(tester, 'trabalho');
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Descrição'),
        'UBER TRIP',
      );
      await tester.pumpAndSettle();
      expect(find.text('app'), findsNothing);
      expect(find.text('Tags da regra'), findsNothing);

      await tester.tap(find.text('Salvar'));
      await tester.pumpAndSettle();
      final saved = s.transactions.all.where(
        (t) => t.description == 'UBER TRIP',
      );
      expect(saved.single.tags, ['trabalho']);
    },
  );

  testWidgets('Simples: regra com tags aplica as tags ao novo lançamento', (
    tester,
  ) async {
    final s = await _boot(tester);
    await tester.runAsync(
      () => s.rules.upsert(
        const TransactionRule(id: 'r_uber', pattern: 'UBER', tags: ['app']),
      ),
    );
    await _openForm(tester, s);

    await tester.enterText(
      find.widgetWithText(TextFormField, 'Valor'),
      '18,00',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Descrição'),
      'UBER TRIP',
    );
    await _pickCartao(tester);
    await tester.tap(find.text('Salvar'));
    await tester.pumpAndSettle();

    final saved = s.transactions.all.where((t) => t.description == 'UBER TRIP');
    expect(saved.single.tags, ['app']);
    expect(find.byType(TagField), findsNothing);
  });

  testWidgets('regra com renameTo avisa e salva a descrição renomeada', (
    tester,
  ) async {
    final s = await _boot(tester);
    await tester.runAsync(
      () => s.rules.upsert(
        const TransactionRule(id: 'r_uber', pattern: 'UBER', renameTo: 'Uber'),
      ),
    );
    await _openForm(tester, s);

    await tester.enterText(
      find.widgetWithText(TextFormField, 'Valor'),
      '18,00',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Descrição'),
      'UBER TRIP 123',
    );
    await tester.pumpAndSettle();
    expect(find.text('Será salvo como "Uber" (regra)'), findsOneWidget);

    await _pickCartao(tester);
    await tester.tap(find.text('Salvar'));
    await tester.pumpAndSettle();

    final saved = s.transactions.all.where((t) => t.description == 'Uber');
    expect(saved.single.importedDescription, 'UBER TRIP 123');
  });

  testWidgets(
    'Manter como digitado some o aviso e salva a descrição digitada',
    (tester) async {
      final s = await _boot(tester);
      await tester.runAsync(
        () => s.rules.upsert(
          const TransactionRule(
            id: 'r_uber',
            pattern: 'UBER',
            renameTo: 'Uber',
          ),
        ),
      );
      await _openForm(tester, s);

      await tester.enterText(
        find.widgetWithText(TextFormField, 'Valor'),
        '18,00',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Descrição'),
        'UBER TRIP 123',
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('form-rename-keep')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('form-rename-hint')), findsNothing);

      await _pickCartao(tester);
      await tester.tap(find.text('Salvar'));
      await tester.pumpAndSettle();

      final saved = s.transactions.all.where(
        (t) => t.description == 'UBER TRIP 123',
      );
      expect(saved.single.importedDescription, isNull);
    },
  );

  testWidgets('edição não aplica renameTo nem mostra aviso', (tester) async {
    final s = await _boot(tester);
    await tester.runAsync(
      () => s.rules.upsert(
        const TransactionRule(id: 'r_uber', pattern: 'UBER', renameTo: 'Uber'),
      ),
    );
    final tx = Transaction(
      id: 'tx_uber_edit',
      type: TransactionType.expense,
      amountCents: 1800,
      date: DateTime(2026, 11, 10),
      description: 'UBER TRIP 123',
      accountId: 'acc_alfa',
    );
    await tester.runAsync(() => s.transactions.upsert(tx));
    await _openForm(tester, s, initial: tx);

    // Digita e volta ao mesmo texto: a regra casa, mas não vale em edição.
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Descrição'),
      'UBER TRIP 123x',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Descrição'),
      'UBER TRIP 123',
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('form-rename-hint')), findsNothing);

    await tester.tap(find.text('Salvar'));
    await tester.pumpAndSettle();

    final saved = s.transactions.byId('tx_uber_edit')!;
    expect(saved.description, 'UBER TRIP 123');
    expect(saved.importedDescription, isNull);
  });

  testWidgets(
    'parcelado com renameTo grava as parcelas com a descrição renomeada',
    (tester) async {
      final s = await _boot(tester);
      await tester.runAsync(
        () => s.rules.upsert(
          const TransactionRule(
            id: 'r_uber',
            pattern: 'UBER',
            renameTo: 'Uber',
          ),
        ),
      );
      await _openForm(tester, s);

      await tester.enterText(
        find.widgetWithText(TextFormField, 'Valor'),
        '100,00',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Descrição'),
        'UBER TRIP 123',
      );
      await _pickCartao(tester);
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Parcelas'),
        '3',
      );
      await tester.tap(find.text('Salvar'));
      await tester.pumpAndSettle();

      final parcels = s.transactions.all.where((t) => t.description == 'Uber');
      expect(parcels, hasLength(3));
    },
  );

  testWidgets(
    'categoria: subcategoria aparece logo depois da principal, com Pai › Filha',
    (tester) async {
      final s = await _boot(tester);
      await tester.runAsync(
        () => s.categories.upsert(
          const TransactionCategory(
            id: 'cat_mercado_x',
            name: 'Mercado X',
            kind: CategoryKind.expense,
            iconCodePoint: 0xe8cc,
            colorValue: 0xFF42A5F5,
            parentId: 'cat_alimentacao',
          ),
        ),
      );
      await _openForm(tester, s);

      await tester.tap(_categoriaField());
      await tester.pumpAndSettle();

      final parentY = tester.getTopLeft(find.text('Alimentação').last).dy;
      final childY = tester
          .getTopLeft(find.text('Alimentação › Mercado X').last)
          .dy;
      expect(childY, greaterThan(parentY));
      for (final c in s.categories.all.where(
        (c) =>
            c.kind == CategoryKind.expense &&
            c.id != 'cat_alimentacao' &&
            c.id != 'cat_mercado_x',
      )) {
        final f = find.text(c.name);
        if (f.evaluate().isEmpty) {
          continue;
        }
        final y = tester.getTopLeft(f.last).dy;
        expect(y < parentY || y > childY, isTrue, reason: c.name);
      }

      await tester.tap(find.text('Alimentação › Mercado X').last);
      await tester.pumpAndSettle();
      expect(find.text('Alimentação › Mercado X'), findsOneWidget);
    },
  );

  testWidgets(
    'Ultra: parcelado em 3x com tags grava as 3 parcelas com as tags',
    (tester) async {
      final s = await _boot(tester, mode: AppMode.ultra);
      await _openForm(tester, s);

      await tester.enterText(
        find.widgetWithText(TextFormField, 'Valor'),
        '100,00',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Descrição'),
        'Compra tag parcelada',
      );
      await _pickCartao(tester);
      await _addTag(tester, 'x');
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Parcelas'),
        '3',
      );
      await tester.tap(find.text('Salvar'));
      await tester.pumpAndSettle();

      final parcels = s.transactions.all.where(
        (t) => t.description == 'Compra tag parcelada',
      );
      expect(parcels, hasLength(3));
      expect(
        parcels.every((t) => t.tags.length == 1 && t.tags.single == 'x'),
        isTrue,
      );
    },
  );
}
