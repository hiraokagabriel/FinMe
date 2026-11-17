import 'package:finme/app/app_scope.dart';
import 'package:finme/app/bootstrap.dart';
import 'package:finme/core/models/app_settings.dart';
import 'package:finme/core/models/year_month.dart';
import 'package:finme/core/services/record_store.dart';
import 'package:finme/core/theme/app_theme.dart';
import 'package:finme/features/cards/domain/payment_card.dart';
import 'package:finme/features/importing/domain/import_matcher.dart';
import 'package:finme/features/importing/domain/import_session.dart';
import 'package:finme/features/importing/domain/imported_line.dart';
import 'package:finme/features/importing/domain/invoice_payment_match.dart';
import 'package:finme/features/importing/presentation/import_preview_page.dart';
import 'package:finme/features/rules/domain/transaction_rule.dart';
import 'package:finme/features/transactions/domain/transaction.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const _target = ImportTarget(accountId: 'conta_alfa');

/// Cinco linhas: IFOOD casa com um lançamento existente (probableDuplicate) e começa desmarcada.
List<ImportedLine> _lines() => [
  ImportedLine(
    row: 2,
    date: DateTime(2026, 11, 5),
    description: 'PADARIA PAO BOM CURITIBA PR',
    amountCents: -1250,
    bankCategory: 'Alimentação',
  ),
  ImportedLine(
    row: 3,
    date: DateTime(2026, 11, 6),
    description: 'MERCADO EXEMPLO; FILIAL 2',
    amountCents: -123456,
    bankCategory: 'Mercado',
  ),
  ImportedLine(
    row: 4,
    date: DateTime(2026, 11, 7),
    description: 'DEPOSITO EXEMPLO FICTICIO',
    amountCents: 500000,
  ),
  ImportedLine(
    row: 5,
    date: DateTime(2026, 11, 10),
    description: 'LOJA EXEMPLO PARC 03/10',
    amountCents: -15000,
    bankCategory: 'Compras',
  ),
  ImportedLine(
    row: 6,
    date: DateTime(2026, 11, 2),
    description: 'IFOOD RESTAURANTE X',
    amountCents: -4590,
  ),
];

Transaction _existingIfood() => Transaction(
  id: 'tx_ifood',
  type: TransactionType.expense,
  amountCents: 4590,
  date: DateTime(2026, 11, 2),
  description: 'IFOOD RESTAURANTE X',
  accountId: 'conta_alfa',
);

Future<AppServices> _boot(WidgetTester tester, AppMode mode) async {
  return (await tester.runAsync(() async {
    final s = await bootstrap(
      storeFactory: (_) => MemoryRecordStore(),
      clock: () => DateTime(2026, 11, 14),
    );
    await s.settings.update(
      (c) => c.copyWith(mode: mode, onboardingDone: true),
    );
    return s;
  }))!;
}

ImportSession _session(AppServices s, {List<ImportedLine>? lines}) =>
    ImportSession.build(
      lines: lines ?? _lines(),
      target: _target,
      categorizer: s.ledger.categorizer,
      matcher: ImportMatcher([_existingIfood()]),
    );

/// Resultado devolvido pela prévia (preenchido quando a tela fecha).
class _Outcome {
  bool done = false;
  ImportSession? session;
}

/// Abre a prévia por um botão e devolve o resultado em [_Outcome].
Future<_Outcome> _open(
  WidgetTester tester,
  AppServices s,
  ImportSession session, {
  List<ImportLineError> errors = const [],
  Future<TransactionRule?> Function(ImportRow row)? onCreateRule,
  Size size = const Size(1400, 900),
}) async {
  final out = _Outcome();
  await tester.binding.setSurfaceSize(size);
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(
    AppScope(
      services: s,
      child: MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(
          body: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () async {
                out.session = await showImportPreview(
                  context,
                  session: session,
                  sourceLabel: 'Conta Alfa',
                  errors: errors,
                  onCreateRule: onCreateRule,
                );
                out.done = true;
              },
              child: const Text('abrir'),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('abrir'));
  await tester.pumpAndSettle();
  return out;
}

ImportRow _rowOf(ImportSession session, String description) =>
    session.rows.firstWhere((r) => r.line.description == description);

void main() {
  testWidgets('Simples: prévia enxuta, contagem e erros', (tester) async {
    final s = await _boot(tester, AppMode.simple);
    final out = await _open(
      tester,
      s,
      _session(s),
      errors: const [ImportLineError(9, 'Valor inválido')],
    );

    expect(find.text('Prévia da importação — Conta Alfa'), findsOneWidget);
    expect(
      find.text('5 linhas · 4 a criar · 0 a confirmar · 1 ignoradas'),
      findsOneWidget,
    );
    expect(find.text('Importar 4'), findsOneWidget);
    expect(find.text('1 linhas com erro'), findsOneWidget);
    // Sem origem, confiança, filtro nem menu de regra.
    expect(find.text('Banco'), findsNothing);
    expect(find.text('Dicionário'), findsNothing);
    expect(find.text('Só sem categoria'), findsNothing);
    expect(find.byIcon(Icons.more_vert), findsNothing);
    // Só o duplicado tem alerta.
    expect(find.byIcon(Icons.error_outline), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.tap(find.text('Cancelar'));
    await tester.pumpAndSettle();
    expect(out.done, isTrue);
    expect(out.session, isNull);
  });

  testWidgets('Ultra: origem, confiança, parcela e filtro sem categoria', (
    tester,
  ) async {
    final s = await _boot(tester, AppMode.ultra);
    await _open(tester, s, _session(s));

    expect(find.text('Banco'), findsNWidgets(3));
    expect(find.text('Dicionário'), findsOneWidget);
    expect(find.text('média'), findsWidgets);
    expect(find.text('3/10'), findsOneWidget);
    expect(find.text('Só sem categoria'), findsOneWidget);
    expect(find.byIcon(Icons.content_copy), findsOneWidget);
    expect(
      find.text(
        '5 linhas · 4 a criar · 0 a confirmar · 1 ignoradas · 7 parcelas futuras',
      ),
      findsOneWidget,
    );

    await tester.tap(find.text('Só sem categoria'));
    await tester.pumpAndSettle();
    expect(find.text('DEPOSITO EXEMPLO FICTICIO'), findsOneWidget);
    expect(find.text('PADARIA PAO BOM CURITIBA PR'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'desmarcar uma linha atualiza o botão; desmarcar todas desabilita',
    (tester) async {
      final s = await _boot(tester, AppMode.ultra);
      await _open(tester, s, _session(s));

      // A 1ª checkbox é a da PADARIA.
      await tester.tap(find.byType(Checkbox).first);
      await tester.pumpAndSettle();
      expect(find.text('Importar 3'), findsOneWidget);

      await tester.tap(find.text('Desmarcar todas'));
      await tester.pumpAndSettle();
      final button = tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, 'Importar 0'),
      );
      expect(button.onPressed, isNull);
    },
  );

  testWidgets('trocar categoria no dropdown aparece na sessão devolvida', (
    tester,
  ) async {
    final s = await _boot(tester, AppMode.simple);
    final out = await _open(tester, s, _session(s));

    // Linha 3 (depósito, receita) é o 3º dropdown; a lista só tem categorias de receita.
    await tester.tap(find.byType(DropdownButton<String?>).at(2));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Freelance').last);
    await tester.pumpAndSettle();

    await tester.tap(find.text('Importar 4'));
    await tester.pumpAndSettle();
    expect(out.done, isTrue);
    final row = _rowOf(out.session!, 'DEPOSITO EXEMPLO FICTICIO');
    expect(row.categoryId, 'cat_freelance');
    expect(row.categoryEdited, isTrue);
  });

  testWidgets('criar regra recategoriza linhas não editadas que casam', (
    tester,
  ) async {
    final s = await _boot(tester, AppMode.ultra);
    final session = _session(s);
    expect(_rowOf(session, 'DEPOSITO EXEMPLO FICTICIO').categoryId, isNull);

    final out = await _open(
      tester,
      s,
      session,
      onCreateRule: (row) async {
        final rule = const TransactionRule(
          id: 'rule_salario',
          pattern: 'DEPOSITO EXEMPLO',
          categoryId: 'cat_salario',
        );
        await s.rules.upsert(rule);
        return rule;
      },
    );

    // Menu da 1ª linha (PADARIA) → "Criar regra a partir desta linha".
    await tester.tap(find.byIcon(Icons.more_vert).first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Criar regra a partir desta linha'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Importar 4'));
    await tester.pumpAndSettle();
    expect(out.done, isTrue);
    expect(
      _rowOf(out.session!, 'DEPOSITO EXEMPLO FICTICIO').categoryId,
      'cat_salario',
    );
  });

  testWidgets('Cancelar devolve null', (tester) async {
    final s = await _boot(tester, AppMode.simple);
    final out = await _open(tester, s, _session(s));
    await tester.tap(find.text('Cancelar'));
    await tester.pumpAndSettle();
    expect(out.done, isTrue);
    expect(out.session, isNull);
  });

  for (final mode in AppMode.values) {
    testWidgets('2.000 linhas abrem e rolam sem exceção ($mode)', (
      tester,
    ) async {
      final s = await _boot(tester, mode);
      final lines = [
        for (var i = 0; i < 2000; i++)
          ImportedLine(
            row: i + 2,
            date: DateTime(2026, 11, 1 + i % 20),
            description: 'LOJA EXEMPLO $i',
            amountCents: -(100 + i),
          ),
      ];
      await _open(tester, s, _session(s, lines: lines));
      expect(tester.takeException(), isNull);

      await tester.drag(find.byType(ListView), const Offset(0, -1500));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('Ultra abaixo de 1100 px rola na horizontal sem exceção', (
    tester,
  ) async {
    final s = await _boot(tester, AppMode.ultra);
    await _open(tester, s, _session(s), size: const Size(900, 800));
    expect(find.text('Importar 4'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Marcar todas não remarca a duplicata provável (IFOOD)', (
    tester,
  ) async {
    final s = await _boot(tester, AppMode.ultra);
    final out = await _open(tester, s, _session(s));
    expect(find.text('Importar 4'), findsOneWidget);

    await tester.tap(find.text('Marcar todas'));
    await tester.pumpAndSettle();
    expect(find.text('Importar 4'), findsOneWidget);

    await tester.tap(find.text('Importar 4'));
    await tester.pumpAndSettle();
    expect(out.session!.rows.where((r) => r.include).length, 4);
    expect(
      out.session!.rows
          .singleWhere((r) => r.line.description.startsWith('IFOOD'))
          .include,
      isFalse,
    );
  });

  group('pagamento de fatura', () {
    const card = PaymentCard(
      id: 'card_alfa',
      name: 'Cartão Alfa',
      bankName: 'Banco Alfa',
      brand: CardBrand.visa,
      kind: CardKind.credit,
      last4: '1234',
      closingDay: 5,
      dueDay: 12,
      colorValue: 0xFF42A5F5,
      paymentAccountId: 'conta_alfa',
    );
    // Vence em 05/11 e tem 150,00 em aberto.
    final invoice = InvoiceCandidate(
      cardId: 'card_alfa',
      dueMonth: const YearMonth(2026, 11),
      dueDate: DateTime(2026, 11, 5),
      remainingCents: 15000,
    );
    // Valor igual ao saldo e a 2 dias do vencimento: sugerida.
    final suggested = ImportedLine(
      row: 2,
      date: DateTime(2026, 11, 7),
      description: 'PAGAMENTO FATURA CARTAO ALFA',
      amountCents: -15000,
    );
    // Valor diferente: flag sem sugestão.
    final unsuggested = ImportedLine(
      row: 3,
      date: DateTime(2026, 11, 20),
      description: 'PGTO CARTAO OUTRO',
      amountCents: -9999,
    );

    Future<AppServices> bootWithCard(WidgetTester tester) async {
      final s = await _boot(tester, AppMode.simple);
      await tester.runAsync(() => s.cards.upsert(card));
      return s;
    }

    ImportSession sessionOf(
      AppServices s,
      List<ImportedLine> lines, {
      ImportTarget target = _target,
    }) => ImportSession.build(
      lines: lines,
      target: target,
      categorizer: s.ledger.categorizer,
      matcher: ImportMatcher(const []),
      invoiceCandidates: [invoice],
    );

    testWidgets('sugerida: menu com a fatura no lugar da categoria', (
      tester,
    ) async {
      final s = await bootWithCard(tester);
      await _open(tester, s, sessionOf(s, [suggested, unsuggested]));

      expect(find.byKey(const Key('import-invoice-0')), findsOneWidget);
      expect(find.text('Fatura Cartão Alfa · venc. 05/11'), findsOneWidget);
      // Sem o chip de alerta: a linha já é pagamento de fatura.
      expect(find.byIcon(Icons.credit_score), findsNothing);
      expect(
        find.text(
          '2 linhas · 0 a criar · 0 a confirmar · 1 ignoradas · '
          '1 pagamentos de fatura',
        ),
        findsOneWidget,
      );
      expect(find.text('Importar 1'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('não sugerida: escolher a fatura marca a linha; "Não é" desfaz', (
      tester,
    ) async {
      final s = await bootWithCard(tester);
      await _open(tester, s, sessionOf(s, [unsuggested]));

      expect(find.text('Pagamento de fatura?'), findsOneWidget);
      expect(find.byType(DropdownButton<String?>), findsOneWidget);

      await tester.tap(find.byKey(const Key('import-invoice-0')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Fatura Cartão Alfa · venc. 05/11'));
      await tester.pumpAndSettle();
      expect(find.text('Importar 1'), findsOneWidget);
      expect(find.byType(DropdownButton<String?>), findsNothing);

      await tester.tap(find.byKey(const Key('import-invoice-0')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Não é pagamento de fatura'));
      await tester.pumpAndSettle();
      // Desfazer não muda a inclusão: a linha segue marcada como despesa comum.
      expect(find.text('Importar 1'), findsOneWidget);
      expect(find.byType(DropdownButton<String?>), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('importação em cartão não mostra o menu', (tester) async {
      final s = await bootWithCard(tester);
      await _open(
        tester,
        s,
        sessionOf(s, [
          suggested,
        ], target: const ImportTarget(cardId: 'card_alfa')),
      );

      expect(find.byKey(const Key('import-invoice-0')), findsNothing);
      expect(find.text('Pagamento de fatura?'), findsNothing);
    });
  });
}
