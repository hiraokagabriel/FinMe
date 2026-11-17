import 'package:finme/app/app_scope.dart';
import 'package:finme/app/bootstrap.dart';
import 'package:finme/core/services/record_store.dart';
import 'package:finme/core/theme/app_theme.dart';
import 'package:finme/features/accounts/domain/account.dart';
import 'package:finme/features/importing/domain/import_profile.dart';
import 'package:finme/features/importing/presentation/import_mapping_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

// Extrato fictício (mesmo conteúdo de test/fixtures/import/extrato_conta.csv).
const _extrato = '''
Extrato fictício - Banco Alfa;;;
Data;Histórico;Valor;Categoria
05/11/2026;PADARIA PAO BOM CURITIBA PR;-12,50;Alimentação
06/11/2026;"MERCADO EXEMPLO; FILIAL 2";-1.234,56;Supermercado
07/11/2026;SALARIO EMPRESA FICTICIA;5.000,00;
08/11/2026;PAGTO FATURA CARTAO;-800,00;
31/02/2026;LINHA COM DATA INVALIDA;-1,00;
09/11/2026;BOLETO CONDOMINIO;abc;
10/11/2026;LOJA EXEMPLO PARC 03/10;-150,00;Compras
''';

Future<AppServices> _boot(
  WidgetTester tester, {
  bool withAccount = true,
}) async {
  return (await tester.runAsync(() async {
    final s = await bootstrap(
      storeFactory: (_) => MemoryRecordStore(),
      clock: () => DateTime(2026, 11, 14),
    );
    if (withAccount) {
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
    }
    return s;
  }))!;
}

/// Abre o diálogo pelo botão 'abrir' e guarda o retorno em [out] (null = cancelado).
Future<void> _open(
  WidgetTester tester,
  AppServices s,
  Future<ImportSetup?> Function(BuildContext) show,
  List<ImportSetup?> out,
) async {
  await tester.binding.setSurfaceSize(const Size(1400, 900));
  await tester.pumpWidget(
    AppScope(
      services: s,
      child: MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(
          body: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () async => out.add(await show(context)),
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

/// Abre o dropdown identificado pelo rótulo e escolhe a opção.
Future<void> _pick(WidgetTester tester, String label, String option) async {
  await tester.tap(find.widgetWithText(InputDecorator, label));
  await tester.pumpAndSettle();
  await tester.tap(find.text(option).last);
  await tester.pumpAndSettle();
}

FilledButton _continue(WidgetTester tester) =>
    tester.widget<FilledButton>(find.widgetWithText(FilledButton, 'Continuar'));

void main() {
  testWidgets('sem destino desabilita Continuar com a mensagem', (
    tester,
  ) async {
    final s = await _boot(tester, withAccount: false);
    await _open(
      tester,
      s,
      (c) => showImportMappingDialog(c, text: _extrato),
      [],
    );

    expect(find.text('Escolha a conta ou o cartão'), findsOneWidget);
    expect(_continue(tester).onPressed, isNull);
  });

  testWidgets('mapeia categoria e destino; Continuar devolve o perfil', (
    tester,
  ) async {
    final s = await _boot(tester);
    final out = <ImportSetup?>[];
    await _open(
      tester,
      s,
      (c) => showImportMappingDialog(c, text: _extrato),
      out,
    );

    await tester.enterText(
      find.widgetWithText(TextField, 'Linhas a pular'),
      '2',
    );
    await tester.pumpAndSettle();
    await _pick(tester, 'Categoria', 'Col 4 — Categoria');
    await _pick(tester, 'Destino', 'Conta · Conta Alfa');

    expect(
      find.text('Prévia: 5 linhas interpretadas, 2 com erro'),
      findsOneWidget,
    );
    await tester.tap(find.text('Continuar'));
    await tester.pumpAndSettle();

    final setup = out.single!;
    expect(setup.save, isFalse);
    expect(setup.profile.skipRows, 2);
    expect(setup.profile.categoryColumn, 3);
    expect(setup.profile.accountId, 'acc_alfa');
    expect(setup.profile.cardId, isNull);
  });

  testWidgets('Salvar como perfil exige nome', (tester) async {
    final s = await _boot(tester);
    final out = <ImportSetup?>[];
    await _open(
      tester,
      s,
      (c) => showImportMappingDialog(c, text: _extrato),
      out,
    );
    await _pick(tester, 'Destino', 'Conta · Conta Alfa');

    // Dialog rolável: o checkbox fica abaixo da área visível do teste.
    await tester.ensureVisible(find.text('Salvar como perfil'));
    await tester.tap(find.text('Salvar como perfil'));
    await tester.pumpAndSettle();
    expect(_continue(tester).onPressed, isNull);

    await tester.enterText(
      find.widgetWithText(TextField, 'Nome do perfil'),
      'Alfa CSV',
    );
    await tester.pumpAndSettle();
    expect(_continue(tester).onPressed, isNotNull);

    await tester.tap(find.text('Continuar'));
    await tester.pumpAndSettle();
    expect(out.single!.save, isTrue);
    expect(out.single!.profile.name, 'Alfa CSV');
  });

  testWidgets('trocar separador para vírgula recalcula sem exceção', (
    tester,
  ) async {
    final s = await _boot(tester);
    await _open(
      tester,
      s,
      (c) => showImportMappingDialog(c, text: _extrato),
      [],
    );

    await _pick(tester, 'Separador', 'Vírgula (,)');

    expect(tester.takeException(), isNull);
    expect(find.textContaining('linhas interpretadas'), findsOneWidget);
  });

  testWidgets('destino OFX: Continuar devolve perfil ofx com a conta', (
    tester,
  ) async {
    final s = await _boot(tester);
    final out = <ImportSetup?>[];
    await _open(
      tester,
      s,
      (c) => showImportTargetDialog(c, suggestCard: false),
      out,
    );

    await _pick(tester, 'Destino', 'Conta · Conta Alfa');
    await tester.tap(find.text('Continuar'));
    await tester.pumpAndSettle();

    final setup = out.single!;
    expect(setup.profile.format, ImportFormat.ofx);
    expect(setup.profile.accountId, 'acc_alfa');
    expect(setup.save, isFalse);
  });
}
