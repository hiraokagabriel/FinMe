import 'package:finme/app/app_scope.dart';
import 'package:finme/app/bootstrap.dart';
import 'package:finme/app/seed.dart';
import 'package:finme/core/models/app_settings.dart';
import 'package:finme/core/services/record_store.dart';
import 'package:finme/core/theme/app_theme.dart';
import 'package:finme/core/widgets/widgets.dart';
import 'package:finme/features/recurring/domain/recurring_rule.dart';
import 'package:finme/features/recurring/presentation/recurring_page.dart';
import 'package:finme/features/transactions/domain/transaction.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Future<AppServices> setup(WidgetTester tester, {required bool ultra}) async {
    final s = await tester.runAsync(() async {
      final s = await bootstrap(
        storeFactory: (_) => MemoryRecordStore(),
        clock: () => DateTime(2026, 11, 14),
      );
      await seedDemo(s);
      await materializeRecurring(s);
      if (ultra) {
        await s.settings.update((x) => x.copyWith(mode: AppMode.ultra));
      }
      return s;
    });
    return s!;
  }

  Future<void> pump(WidgetTester tester, AppServices s, Size size) async {
    await tester.binding.setSurfaceSize(size);
    await tester.pumpWidget(
      AppScope(
        services: s,
        child: MaterialApp(
          theme: AppTheme.light(),
          home: const Scaffold(body: RecurringPage()),
        ),
      ),
    );
  }

  testWidgets('modo Simples: KPIs de custo e lista única', (tester) async {
    final s = await setup(tester, ultra: false);
    await pump(tester, s, const Size(1400, 900));

    expect(find.text('Recorrentes'), findsOneWidget);
    expect(find.text('Nova recorrência'), findsOneWidget);
    expect(find.text('Custo mensal fixo'), findsOneWidget);
    expect(find.text('R\$ 1.959,80'), findsOneWidget);
    expect(find.text('Receitas mensais fixas'), findsOneWidget);
    expect(find.text('R\$ 6.500,00'), findsOneWidget);
    expect(find.text('Aluguel'), findsOneWidget);
    expect(find.text('Streaming de vídeo'), findsOneWidget);
    expect(find.text('Assinaturas/mês'), findsNothing);
    expect(find.text('Assinaturas'), findsNothing);
  });

  testWidgets('modo Ultra: KPIs de assinatura e seções', (tester) async {
    final s = await setup(tester, ultra: true);
    await pump(tester, s, const Size(1400, 900));

    expect(find.text('Assinaturas/mês'), findsOneWidget);
    expect(find.text('R\$ 159,80'), findsOneWidget);
    expect(find.text('Assinaturas/ano'), findsOneWidget);
    expect(find.text('R\$ 1.917,60'), findsOneWidget);
    expect(find.text('Assinaturas'), findsOneWidget);
    expect(find.text('Contas fixas e receitas'), findsOneWidget);
    // Streaming começa em 15/08 e cai em 15/11, a partir de hoje (14/11).
    expect(find.text('Próxima: 15/11/2026'), findsOneWidget);
  });

  testWidgets('normaliza semanal e anual; pausada fica fora dos totais', (
    tester,
  ) async {
    final s = await setup(tester, ultra: false);
    await tester.runAsync(() async {
      await s.recurring.upsert(
        RecurringRule(
          id: 'rec_semanal',
          description: 'Feira',
          type: TransactionType.expense,
          amountCents: 10000,
          frequency: Frequency.weekly,
          startDate: DateTime(2026, 11, 20),
        ),
      );
      await s.recurring.upsert(
        RecurringRule(
          id: 'rec_anual',
          description: 'Bônus anual',
          type: TransactionType.income,
          amountCents: 120000,
          frequency: Frequency.yearly,
          startDate: DateTime(2026, 3, 1),
        ),
      );
      await s.recurring.upsert(
        RecurringRule(
          id: 'rec_pausada',
          description: 'Revista',
          type: TransactionType.expense,
          amountCents: 99999,
          frequency: Frequency.monthly,
          startDate: DateTime(2026, 11, 20),
          active: false,
        ),
      );
    });
    await pump(tester, s, const Size(1400, 900));

    // 195980 (seed) + 43333 (10000 × 52/12 arredondado); pausada não entra.
    expect(find.text('R\$ 2.393,13'), findsOneWidget);
    // 650000 (seed) + 10000 (120000 ÷ 12).
    expect(find.text('R\$ 6.600,00'), findsOneWidget);
    expect(find.text('Pausada'), findsOneWidget);
  });

  testWidgets('formulário: cria com origem em cartão e materializa', (
    tester,
  ) async {
    final s = await setup(tester, ultra: false);
    await pump(tester, s, const Size(1400, 900));

    await tester.tap(find.text('Nova recorrência'));
    await tester.pumpAndSettle();
    expect(find.text('Editar recorrência'), findsNothing);
    await tester.enterText(
      find.byType(TextFormField).at(0),
      'Teste recorrente',
    );
    await tester.enterText(find.byType(TextFormField).at(1), '150,00');
    await tester.tap(find.byType(DropdownButton<String>).first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Banco Alfa · Alfa Visa').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Salvar'));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    final created = s.recurring.all.where(
      (r) => r.description == 'Teste recorrente',
    );
    expect(created, hasLength(1));
    final rule = created.single;
    expect(rule.cardId, 'card_alfa_visa');
    expect(rule.amountCents, 15000);
    // Início = hoje (14/11): materializa só até ontem, então hoje não é gravada.
    expect(s.transactions.all.where((t) => t.recurringId == rule.id), isEmpty);
    // Ocorrência de hoje aparece só pela projeção da fatura do cartão.
    final todayOccurrence = s.ledger
        .invoicesFor(rule.cardId!)
        .expand((i) => i.items)
        .where(
          (t) => t.recurringId == rule.id && t.date == DateTime(2026, 11, 14),
        );
    expect(todayOccurrence, hasLength(1));
  });

  testWidgets(
    'formulário: edita boleto de conta sem perder materializedUntil',
    (tester) async {
      final s = await setup(tester, ultra: false);
      await pump(tester, s, const Size(1400, 900));

      // Ordem alfabética: Academia, Aluguel, ... ; Aluguel é boleto em conta.
      await tester.tap(find.byTooltip('Mais opções').at(1));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Editar'));
      await tester.pumpAndSettle();
      expect(find.text('Editar recorrência'), findsOneWidget);
      expect(tester.takeException(), isNull);

      await tester.tap(find.text('Salvar'));
      await tester.pumpAndSettle();
      final rule = s.recurring.byId('rec_aluguel')!;
      expect(rule.isBoleto, isTrue);
      expect(rule.accountId, 'acc_beta');
      // materializedUntil = ontem (13/11), preservado na edição.
      expect(rule.materializedUntil, DateTime(2026, 11, 13));
    },
  );

  testWidgets('layout 390px sem exceções', (tester) async {
    final s = await setup(tester, ultra: true);
    await pump(tester, s, const Size(390, 800));
    expect(tester.takeException(), isNull);
    expect(find.text('Recorrentes'), findsOneWidget);
  });

  for (final ultra in [false, true]) {
    testWidgets(
      'estado vazio (${ultra ? 'Ultra' : 'Simples'}): botão abre o form',
      (tester) async {
        final s = (await tester.runAsync(() async {
          final s = await bootstrap(
            storeFactory: (_) => MemoryRecordStore(),
            clock: () => DateTime(2026, 11, 14),
          );
          if (ultra) {
            await s.settings.update((x) => x.copyWith(mode: AppMode.ultra));
          }
          return s;
        }))!;
        await pump(tester, s, const Size(1400, 900));

        expect(find.byType(EmptyState), findsOneWidget);
        await tester.tap(
          find.descendant(
            of: find.byType(EmptyState),
            matching: find.text('Nova recorrência'),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.byType(AlertDialog), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
  }
}
