import 'package:finme/app/app_scope.dart';
import 'package:finme/app/bootstrap.dart';
import 'package:finme/core/services/record_store.dart';
import 'package:finme/core/theme/app_theme.dart';
import 'package:finme/features/categories/domain/transaction_category.dart';
import 'package:finme/features/importing/domain/merchant_dictionary.dart';
import 'package:finme/features/importing/presentation/dictionary_section.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Future<AppServices> _boot(WidgetTester tester) async {
  return (await tester.runAsync(
    () => bootstrap(
      storeFactory: (_) => MemoryRecordStore(),
      clock: () => DateTime(2026, 11, 14),
    ),
  ))!;
}

Future<void> _pump(WidgetTester tester, AppServices s) async {
  await tester.binding.setSurfaceSize(const Size(1400, 900));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(
    AppScope(
      services: s,
      child: MaterialApp(
        theme: AppTheme.light(),
        home: const Scaffold(
          body: SingleChildScrollView(child: DictionarySection()),
        ),
      ),
    ),
  );
  await tester.pump();
}

/// Subcategoria 'Mercado X' dentro de 'Alimentação' (seed), com ícone e cor da pai.
Future<void> _addMercadoX(WidgetTester tester, AppServices s) async {
  final base = s.categories.byId('cat_alimentacao')!;
  await tester.runAsync(
    () => s.categories.upsert(
      TransactionCategory(
        id: 'cat_mercado_x',
        name: 'Mercado X',
        kind: CategoryKind.expense,
        iconCodePoint: base.iconCodePoint,
        colorValue: base.colorValue,
        parentId: 'cat_alimentacao',
      ),
    ),
  );
}

void main() {
  testWidgets('dicionário padrão aparece na lista', (tester) async {
    final s = await _boot(tester);
    await _pump(tester, s);

    expect(find.text('UBER'), findsOneWidget);
    expect(find.text('Transporte'), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  testWidgets('novo padrão grava padrão em foldText e nome da categoria', (
    tester,
  ) async {
    final s = await _boot(tester);
    await _pump(tester, s);

    await tester.tap(find.text('Novo padrão'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField), 'loja exemplo');
    await tester.tap(find.byType(DropdownButtonFormField<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Compras').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Salvar'));
    await tester.pumpAndSettle();

    final created = s.dictionary.all.where((e) => e.pattern == 'LOJA EXEMPLO');
    expect(created.length, 1);
    expect(created.single.categoryName, 'Compras');
    expect(find.text('Novo padrão'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('categoria inexistente mostra aviso', (tester) async {
    final s = await _boot(tester);
    await tester.runAsync(
      () => s.dictionary.upsert(
        const DictionaryEntry(
          id: 'dict_teste',
          pattern: 'TESTE',
          categoryName: 'Inexistente',
        ),
      ),
    );
    await _pump(tester, s);

    expect(find.text('Categoria não encontrada'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('excluir e depois restaurar padrão volta ao dicionário padrão', (
    tester,
  ) async {
    final s = await _boot(tester);
    await _pump(tester, s);

    await tester.tap(find.byTooltip('Excluir padrão').first);
    await tester.pumpAndSettle();
    expect(s.dictionary.all.length, kDefaultDictionary.length - 1);

    await tester.tap(find.text('Restaurar padrão'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Restaurar'));
    await tester.pumpAndSettle();

    expect(s.dictionary.all.length, kDefaultDictionary.length);
    expect(tester.takeException(), isNull);
  });

  testWidgets('padrão com subcategoria grava o caminho e não avisa', (
    tester,
  ) async {
    final s = await _boot(tester);
    await _addMercadoX(tester, s);
    await _pump(tester, s);

    await tester.tap(find.text('Novo padrão'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField), 'loja x');
    await tester.tap(find.byType(DropdownButtonFormField<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Alimentação › Mercado X'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Salvar'));
    await tester.pumpAndSettle();

    final created = s.dictionary.all.where((e) => e.pattern == 'LOJA X');
    expect(created.single.categoryName, 'Alimentação › Mercado X');
    expect(find.text('Categoria não encontrada'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('editar padrão com caminho seleciona a subcategoria', (
    tester,
  ) async {
    final s = await _boot(tester);
    await _addMercadoX(tester, s);
    await tester.runAsync(
      () => s.dictionary.upsert(
        const DictionaryEntry(
          id: 'dict_caminho',
          pattern: 'CAMINHO',
          categoryName: 'Alimentação › Mercado X',
        ),
      ),
    );
    await _pump(tester, s);

    final row = find
        .ancestor(of: find.text('CAMINHO'), matching: find.byType(Row))
        .first;
    await tester.tap(
      find.descendant(of: row, matching: find.byTooltip('Editar padrão')),
    );
    await tester.pumpAndSettle();

    expect(
      find.descendant(
        of: find.byType(Dialog),
        matching: find.text('Alimentação › Mercado X'),
      ),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('caminho com subcategoria inexistente mostra aviso', (
    tester,
  ) async {
    final s = await _boot(tester);
    await tester.runAsync(
      () => s.dictionary.upsert(
        const DictionaryEntry(
          id: 'dict_caminho_ruim',
          pattern: 'CAMINHO RUIM',
          categoryName: 'Alimentação › Inexistente',
        ),
      ),
    );
    await _pump(tester, s);

    expect(find.text('Categoria não encontrada'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
