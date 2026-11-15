import 'package:finme/app/app_scope.dart';
import 'package:finme/app/bootstrap.dart';
import 'package:finme/core/services/record_store.dart';
import 'package:finme/core/theme/app_theme.dart';
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
}
