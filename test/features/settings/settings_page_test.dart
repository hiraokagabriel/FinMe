import 'package:finme/app/app_scope.dart';
import 'package:finme/app/bootstrap.dart';
import 'package:finme/app/seed.dart';
import 'package:finme/core/models/app_settings.dart';
import 'package:finme/core/services/record_store.dart';
import 'package:finme/core/theme/app_theme.dart';
import 'package:finme/features/importing/domain/import_profile.dart';
import 'package:finme/features/importing/domain/merchant_dictionary.dart';
import 'package:finme/features/rules/domain/transaction_rule.dart';
import 'package:finme/features/settings/presentation/settings_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Monta a página com dados demo. Não aciona file pickers.
Future<AppServices> _pump(WidgetTester tester, Size size) async {
  final s = (await tester.runAsync(() async {
    final services = await bootstrap(
      storeFactory: (_) => MemoryRecordStore(),
      clock: () => DateTime(2026, 11, 14),
    );
    await seedDemo(services);
    await materializeRecurring(services);
    return services;
  }))!;
  await tester.binding.setSurfaceSize(size);
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(
    AppScope(
      services: s,
      child: MaterialApp(
        theme: AppTheme.light(),
        home: const Scaffold(body: SettingsPage()),
      ),
    ),
  );
  return s;
}

void main() {
  testWidgets('modo Simples mostra aparência e só exportar backup', (
    tester,
  ) async {
    await _pump(tester, const Size(1400, 900));
    expect(find.text('Ajustes'), findsOneWidget);
    expect(find.text('Aparência'), findsOneWidget);
    expect(find.text('Exportar backup (JSON)'), findsOneWidget);
    expect(find.text('Previsão'), findsNothing);
    expect(find.text('Importar backup'), findsNothing);
    expect(find.text('Apagar todos os dados'), findsNothing);
    expect(find.text('FinMe v2 · dados locais'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('troca para Ultra mostra previsão e dados completos', (
    tester,
  ) async {
    final s = await _pump(tester, const Size(1400, 900));
    await tester.tap(find.text('Ultra'));
    await tester.pump();
    expect(s.settings.value.mode, AppMode.ultra);
    expect(find.text('Previsão'), findsOneWidget);
    expect(find.text('Importar backup'), findsOneWidget);
    expect(find.text('Exportar CSV do mês'), findsOneWidget);
    expect(find.text('Apagar todos os dados'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('troca tema e ocultar valores', (tester) async {
    final s = await _pump(tester, const Size(1400, 900));
    await tester.tap(find.text('Escuro'));
    await tester.pump();
    expect(s.settings.value.theme, ThemePreference.dark);

    await tester.tap(find.byType(Switch));
    await tester.pump();
    expect(s.settings.value.hideValues, isTrue);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'apagar todos os dados zera regras e perfis e volta o dicionário ao padrão',
    (tester) async {
      final s = await _pump(tester, const Size(1400, 900));
      await tester.runAsync(() async {
        await s.rules.upsert(const TransactionRule(id: 'r1', pattern: 'LOJA'));
        await s.importProfiles.upsert(
          ImportProfile(
            id: 'p1',
            name: 'Alfa',
            accountId: s.accounts.all.first.id,
          ),
        );
        await s.dictionary.delete('dict_uber');
        await s.dictionary.upsert(
          const DictionaryEntry(
            id: 'dict_loja',
            pattern: 'LOJA',
            categoryName: 'Mercado',
          ),
        );
      });
      await tester.tap(find.text('Ultra'));
      await tester.pump();

      await tester.ensureVisible(find.text('Apagar todos os dados'));
      await tester.tap(find.text('Apagar todos os dados'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Apagar'));
      await tester.pumpAndSettle();

      expect(s.rules.all, isEmpty);
      expect(s.importProfiles.all, isEmpty);
      expect(s.dictionary.all, defaultDictionary());
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('sem overflow em 390px nos dois modos', (tester) async {
    await _pump(tester, const Size(390, 800));
    expect(tester.takeException(), isNull);

    await tester.tap(find.text('Ultra'));
    await tester.pump();
    expect(tester.takeException(), isNull);
    expect(find.text('Apagar todos os dados'), findsOneWidget);
  });
}
