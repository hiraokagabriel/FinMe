import 'dart:io';

import 'package:finme/app/app_scope.dart';
import 'package:finme/app/bootstrap.dart';
import 'package:finme/core/models/app_settings.dart';
import 'package:finme/core/services/record_store.dart';
import 'package:finme/core/theme/app_theme.dart';
import 'package:finme/features/accounts/domain/account.dart';
import 'package:finme/features/cards/domain/payment_card.dart';
import 'package:finme/features/importing/domain/import_profile.dart';
import 'package:finme/features/importing/presentation/import_flow.dart';
import 'package:finme/features/transactions/domain/transaction.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Perfil do extrato_conta.csv: duas linhas de cabeçalho, categoria na coluna 3.
const _alfaProfile = ImportProfile(
  id: 'p_alfa',
  name: 'Extrato Alfa',
  accountId: 'acc_alfa',
  skipRows: 2,
  categoryColumn: 3,
);

Future<AppServices> _boot(WidgetTester tester, {ImportProfile? profile}) async {
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
    await s.cards.upsert(
      const PaymentCard(
        id: 'card_beta',
        name: 'Cartão Beta',
        bankName: 'Banco Beta',
        brand: CardBrand.visa,
        kind: CardKind.credit,
        last4: '1234',
        closingDay: 5,
        dueDay: 12,
        colorValue: 0xFF42A5F5,
      ),
    );
    if (profile != null) {
      await s.importProfiles.upsert(profile);
    }
    return s;
  }))!;
}

/// Tela com um botão 'importar' que chama [onTap]. Não espera o fim: o teste pode tocar de novo.
Future<void> _app(
  WidgetTester tester,
  AppServices s,
  Future<void> Function(BuildContext context) onTap,
) async {
  await tester.binding.setSurfaceSize(const Size(1400, 900));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(
    AppScope(
      services: s,
      child: MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(
          body: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () => onTap(context),
              child: const Text('importar'),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('importar'));
  await tester.pumpAndSettle();
}

/// Perfil OFX de fatura do cartão Beta; [invert] liga "Inverter sinal".
ImportProfile _faturaProfile({required bool invert}) => ImportProfile(
  id: 'p_fatura',
  name: 'Fatura Beta',
  format: ImportFormat.ofx,
  cardId: 'card_beta',
  invertSign: invert,
);

Future<PickedImportFile?> Function() _fixture(String name) =>
    () async => (
      name: name,
      bytes: File('test/fixtures/import/$name').readAsBytesSync(),
    );

void main() {
  test('looksLikeOfx: extensão ou tag <OFX, sem caixa', () {
    expect(looksLikeOfx('x.OFX', ''), isTrue);
    expect(looksLikeOfx('x.csv', '<ofx>'), isTrue);
    expect(looksLikeOfx('x.csv', 'a;b'), isFalse);
  });

  testWidgets(
    'Criar regra na prévia sugere o padrão da linha, sem normalizar',
    (tester) async {
      final s = await _boot(tester, profile: _alfaProfile);
      await tester.runAsync(
        () => s.settings.update((c) => c.copyWith(mode: AppMode.ultra)),
      );
      await _app(
        tester,
        s,
        (c) => startImport(
          c,
          profile: _alfaProfile,
          pickFile: _fixture('extrato_conta.csv'),
        ),
      );

      await tester.tap(find.byIcon(Icons.more_vert).first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Criar regra a partir desta linha'));
      await tester.pumpAndSettle();

      final field = tester.widget<TextFormField>(
        find.widgetWithText(TextFormField, 'Padrão'),
      );
      expect(field.controller!.text, 'PADARIA PAO BOM CURITIBA PR');
    },
  );

  testWidgets('perfil CSV salvo abre a prévia direto e grava 11 lançamentos', (
    tester,
  ) async {
    final s = await _boot(tester, profile: _alfaProfile);
    await _app(
      tester,
      s,
      (c) => startImport(
        c,
        profile: _alfaProfile,
        pickFile: _fixture('extrato_conta.csv'),
      ),
    );

    expect(find.text('Importar 4'), findsOneWidget);
    await tester.tap(find.text('Importar 4'));
    await tester.pumpAndSettle();

    expect(find.text('11 lançamentos importados'), findsOneWidget);
    expect(s.transactions.all.length, 11);
    final learned = s.importProfiles.byId('p_alfa')!.categoryMap.keys;
    expect(learned, containsAll(['ALIMENTACAO', 'SUPERMERCADO', 'COMPRAS']));
  });

  testWidgets(
    'OFX de fatura sem perfil: destino sugerido, sem pagamento, reimport desmarcado',
    (tester) async {
      final s = await _boot(tester);
      await _app(
        tester,
        s,
        (c) => startImport(c, pickFile: _fixture('fatura_cartao.ofx')),
      );

      // Diálogo de destino: o cartão é sugerido por ser CCSTMTRS.
      await tester.tap(find.text('Continuar'));
      await tester.pumpAndSettle();

      expect(find.text('Importar 2'), findsOneWidget);
      await tester.tap(find.text('Importar 2'));
      await tester.pumpAndSettle();

      expect(find.text('9 lançamentos importados'), findsOneWidget);
      final txs = s.transactions.all;
      final netflix = txs.singleWhere((t) => t.externalId == 'CC-1');
      expect(netflix.cardId, 'card_beta');
      expect(txs.where((t) => t.installmentGroupId != null).length, 8);

      // Reimportar o mesmo arquivo: tudo desmarcado, nada a gravar.
      await tester.tap(find.text('importar'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Continuar'));
      await tester.pumpAndSettle();

      expect(find.text('Importar 0'), findsOneWidget);
      final button = tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, 'Importar 0'),
      );
      expect(button.onPressed, isNull);
    },
  );

  testWidgets(
    'OFX com invertSign nega o fatura_cartao.ofx: NETFLIX (-59,90) vira receita no cartão',
    (tester) async {
      final profile = _faturaProfile(invert: true);
      final s = await _boot(tester, profile: profile);
      await _app(
        tester,
        s,
        (c) => startImport(
          c,
          profile: profile,
          pickFile: _fixture('fatura_cartao.ofx'),
        ),
      );

      await tester.tap(find.textContaining('Importar '));
      await tester.pumpAndSettle();

      final netflix = s.transactions.all.singleWhere(
        (t) => t.externalId == 'CC-1',
      );
      expect(netflix.type, TransactionType.income);
      expect(netflix.amountCents, 5990);
      expect(netflix.cardId, 'card_beta');
    },
  );

  testWidgets('OFX com invertSign: compra positiva vira despesa no cartão', (
    tester,
  ) async {
    final profile = _faturaProfile(invert: true);
    final s = await _boot(tester, profile: profile);
    const ofx =
        '<OFX><CREDITCARDMSGSRSV1><CCSTMTRS><BANKTRANLIST>'
        '<STMTTRN><DTPOSTED>20261102</DTPOSTED><TRNAMT>59.90</TRNAMT>'
        '<FITID>CC-9</FITID><NAME>NETFLIX.COM</NAME></STMTTRN>'
        '</BANKTRANLIST></CCSTMTRS></CREDITCARDMSGSRSV1></OFX>';
    await _app(
      tester,
      s,
      (c) => startImport(
        c,
        profile: profile,
        pickFile: () async => (name: 'compra.ofx', bytes: ofx.codeUnits),
      ),
    );

    await tester.tap(find.textContaining('Importar '));
    await tester.pumpAndSettle();

    final compra = s.transactions.all.singleWhere(
      (t) => t.externalId == 'CC-9',
    );
    expect(compra.type, TransactionType.expense);
    expect(compra.amountCents, 5990);
    expect(compra.cardId, 'card_beta');
  });

  testWidgets('OFX sem linhas válidas: SnackBar e sem prévia', (tester) async {
    final profile = _faturaProfile(invert: false);
    final s = await _boot(tester, profile: profile);
    await _app(
      tester,
      s,
      (c) => startImport(
        c,
        profile: profile,
        pickFile: () async =>
            (name: 'vazio.ofx', bytes: '<OFX></OFX>'.codeUnits),
      ),
    );

    expect(find.text('Nenhuma linha válida no arquivo.'), findsOneWidget);
    expect(find.textContaining('Prévia da importação'), findsNothing);
    expect(s.transactions.all, isEmpty);
  });

  testWidgets('perfil CSV com arquivo OFX: SnackBar "O arquivo não é CSV"', (
    tester,
  ) async {
    final s = await _boot(tester, profile: _alfaProfile);
    await _app(
      tester,
      s,
      (c) => startImport(
        c,
        profile: _alfaProfile,
        pickFile: _fixture('fatura_cartao.ofx'),
      ),
    );

    expect(find.text('O arquivo não é CSV'), findsOneWidget);
    expect(s.transactions.all, isEmpty);
  });

  testWidgets('OFX inválido: SnackBar "Não foi possível ler o arquivo"', (
    tester,
  ) async {
    final s = await _boot(tester);
    await _app(
      tester,
      s,
      (c) => startImport(
        c,
        pickFile: () async => (name: 'x.ofx', bytes: 'lixo'.codeUnits),
      ),
    );

    expect(
      find.textContaining('Não foi possível ler o arquivo'),
      findsOneWidget,
    );
    expect(s.transactions.all, isEmpty);
  });
}
