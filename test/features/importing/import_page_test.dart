import 'package:finme/app/app_scope.dart';
import 'package:finme/app/bootstrap.dart';
import 'package:finme/core/models/app_settings.dart';
import 'package:finme/core/services/record_store.dart';
import 'package:finme/core/theme/app_theme.dart';
import 'package:finme/core/widgets/widgets.dart';
import 'package:finme/features/accounts/domain/account.dart';
import 'package:finme/features/importing/domain/import_profile.dart';
import 'package:finme/features/importing/presentation/import_flow.dart';
import 'package:finme/features/importing/presentation/import_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const _profile = ImportProfile(
  id: 'p_alfa',
  name: 'Extrato Alfa',
  accountId: 'acc_alfa',
  skipRows: 2,
  categoryColumn: 3,
);

Future<AppServices> _setup(
  WidgetTester tester, {
  AppMode mode = AppMode.simple,
  ImportProfile? profile,
}) async {
  return (await tester.runAsync(() async {
    final s = await bootstrap(
      storeFactory: (_) => MemoryRecordStore(),
      clock: () => DateTime(2026, 11, 14),
    );
    await s.accounts.upsert(
      const Account(
        id: 'acc_alfa',
        name: 'Conta Alfa',
        bankName: 'Banco Alfa',
        type: AccountType.checking,
        initialBalanceCents: 0,
        colorValue: 0xFF42A5F5,
      ),
    );
    if (profile != null) {
      await s.importProfiles.upsert(profile);
    }
    await s.settings.update((c) => c.copyWith(mode: mode));
    return s;
  }))!;
}

Future<void> _pump(
  WidgetTester tester,
  AppServices s, {
  Future<PickedImportFile?> Function()? pickFile,
}) async {
  await tester.binding.setSurfaceSize(const Size(1000, 1200));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(
    AppScope(
      services: s,
      child: MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(body: ImportPage(pickFile: pickFile)),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('Simples: sem regras nem dicionário', (tester) async {
    final s = await _setup(tester);
    await _pump(tester, s);

    expect(find.text('Importar arquivo'), findsWidgets);
    expect(find.text('Perfis salvos'), findsOneWidget);
    expect(find.text('Regras'), findsNothing);
    expect(find.text('Dicionário de estabelecimentos'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Ultra: mostra regras e dicionário', (tester) async {
    final s = await _setup(tester, mode: AppMode.ultra);
    await _pump(tester, s);

    expect(find.text('Regras'), findsOneWidget);
    expect(find.text('Dicionário de estabelecimentos'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('sem perfis mostra estado vazio', (tester) async {
    final s = await _setup(tester);
    await _pump(tester, s);

    expect(find.byType(EmptyState), findsOneWidget);
  });

  testWidgets('perfil aparece com nome, destino e formato', (tester) async {
    final s = await _setup(tester, profile: _profile);
    await _pump(tester, s);

    expect(find.text('Extrato Alfa'), findsOneWidget);
    expect(find.text('Conta · Conta Alfa'), findsOneWidget);
    expect(find.text('CSV'), findsOneWidget);
    expect(find.byType(EmptyState), findsNothing);
  });

  testWidgets('destino removido: aviso e Importar desabilitado', (
    tester,
  ) async {
    final s = await _setup(
      tester,
      profile: const ImportProfile(
        id: 'p_gone',
        name: 'Extrato Antigo',
        accountId: 'acc_gone',
      ),
    );
    await _pump(tester, s);

    expect(find.text('Destino removido'), findsOneWidget);
    final button = tester.widget<OutlinedButton>(
      find.widgetWithText(OutlinedButton, 'Importar'),
    );
    expect(button.onPressed, isNull);
  });

  testWidgets('excluir perfil pede confirmação e remove', (tester) async {
    final s = await _setup(tester, profile: _profile);
    await _pump(tester, s);

    await tester.tap(find.byTooltip('Excluir perfil'));
    await tester.pumpAndSettle();
    expect(find.text('Excluir perfil?'), findsOneWidget);

    await tester.tap(find.widgetWithText(FilledButton, 'Excluir'));
    await tester.pumpAndSettle();
    expect(s.importProfiles.all, isEmpty);
    expect(find.text('Extrato Alfa'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Importar do perfil com pickFile nulo não lança', (tester) async {
    final s = await _setup(tester, profile: _profile);
    await _pump(tester, s, pickFile: () async => null);

    await tester.tap(find.widgetWithText(OutlinedButton, 'Importar'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(s.transactions.all, isEmpty);
  });
}
