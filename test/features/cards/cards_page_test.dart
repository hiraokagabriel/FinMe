import 'package:finme/app/app_scope.dart';
import 'package:finme/app/bootstrap.dart';
import 'package:finme/app/seed.dart';
import 'package:finme/core/models/app_settings.dart';
import 'package:finme/core/services/record_store.dart';
import 'package:finme/core/theme/app_theme.dart';
import 'package:finme/core/widgets/widgets.dart';
import 'package:finme/features/cards/presentation/card_detail_page.dart';
import 'package:finme/features/cards/presentation/cards_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Serviços com dados demo (clock fixo) e modo escolhido.
Future<AppServices> seeded(
  WidgetTester tester, {
  AppMode mode = AppMode.simple,
}) async {
  final s = (await tester.runAsync(() async {
    final services = await bootstrap(
      storeFactory: (_) => MemoryRecordStore(),
      clock: () => DateTime(2026, 11, 14),
    );
    await seedDemo(services);
    await materializeRecurring(services);
    await services.settings.update((x) => x.copyWith(mode: mode));
    return services;
  }))!;
  return s;
}

Future<void> pumpIn(
  WidgetTester tester,
  AppServices s,
  Widget home, {
  Size size = const Size(1400, 1400),
}) async {
  await tester.binding.setSurfaceSize(size);
  await tester.pumpWidget(
    AppScope(
      services: s,
      child: MaterialApp(theme: AppTheme.light(), home: home),
    ),
  );
}

void main() {
  testWidgets('modo Simples: cartões agrupados por banco, sem arquivados', (
    tester,
  ) async {
    final s = await seeded(tester);
    await pumpIn(tester, s, const Scaffold(body: CardsPage()));
    expect(find.text('Cartões'), findsOneWidget);
    expect(find.text('Novo cartão'), findsOneWidget);
    for (final bank in ['Banco Alfa', 'Banco Beta', 'Cooperativa Gama']) {
      expect(find.text(bank), findsOneWidget);
    }
    expect(find.text('Alfa Visa'), findsOneWidget);
    expect(find.text('Gama Elo'), findsOneWidget);
    expect(find.text('Alfa Débito'), findsOneWidget);
    expect(find.text('Visa •••• 1234'), findsOneWidget);
    expect(find.text('Mostrar arquivados'), findsNothing);
    expect(find.byType(LimitBar), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'modo Ultra: limite por cartão de crédito e toggle de arquivados',
    (tester) async {
      final s = await seeded(tester, mode: AppMode.ultra);
      await pumpIn(tester, s, const Scaffold(body: CardsPage()));
      expect(find.text('Mostrar arquivados'), findsOneWidget);
      expect(find.byType(LimitBar), findsNWidgets(3));
      expect(find.text(' de '), findsNWidgets(3));
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('arquivado some no Simples e aparece com o toggle no Ultra', (
    tester,
  ) async {
    final s = await seeded(tester, mode: AppMode.ultra);
    final gama = s.cards.byId('card_gama_elo')!;
    await tester.runAsync(() => s.cards.upsert(gama.copyWith(archived: true)));
    await pumpIn(tester, s, const Scaffold(body: CardsPage()));
    expect(find.text('Gama Elo'), findsNothing);
    await tester.tap(find.byType(Switch));
    await tester.pump();
    expect(find.text('Gama Elo'), findsOneWidget);
    expect(find.text('Arquivado'), findsOneWidget);
  });

  testWidgets('390px sem overflow nos dois modos', (tester) async {
    for (final mode in AppMode.values) {
      final s = await seeded(tester, mode: mode);
      await pumpIn(
        tester,
        s,
        const Scaffold(body: CardsPage()),
        size: const Size(390, 800),
      );
      expect(tester.takeException(), isNull, reason: mode.name);
    }
  });

  testWidgets('detalhe de crédito: seletor de faturas, resumo e lançamentos', (
    tester,
  ) async {
    final s = await seeded(tester, mode: AppMode.ultra);
    await pumpIn(
      tester,
      s,
      const CardDetailPage(cardId: 'card_alfa_visa'),
      size: const Size(390, 800),
    );
    expect(find.text('Alfa Visa'), findsOneWidget);
    expect(find.byType(ChoiceChip), findsWidgets);
    expect(find.text('Restante'), findsOneWidget);
    expect(find.text('Lançamentos'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('detalhe de débito: seletor de mês', (tester) async {
    final s = await seeded(tester);
    await pumpIn(tester, s, const CardDetailPage(cardId: 'card_alfa_debito'));
    expect(find.byType(MonthSelector), findsOneWidget);
    expect(find.text('Novembro 2026'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('melhor cartão no Simples: uma linha, sem tabela', (
    tester,
  ) async {
    final s = await seeded(tester);
    final best = s.ledger.bestCardsToday.firstWhere((o) => o.hasLimit);
    await pumpIn(tester, s, const Scaffold(body: CardsPage()));
    expect(
      find.textContaining('Melhor para comprar hoje: ${best.card.name} '),
      findsOneWidget,
    );
    expect(find.byType(DataTable), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('melhor cartão no Ultra: tabela com todos os crédito', (
    tester,
  ) async {
    final s = await seeded(tester, mode: AppMode.ultra);
    await pumpIn(tester, s, const Scaffold(body: CardsPage()));
    expect(find.text('Melhor cartão para comprar hoje'), findsOneWidget);
    final table = tester.widget<DataTable>(find.byType(DataTable));
    expect(table.rows.length, s.ledger.bestCardsToday.length);
    expect(table.rows.length, 3);
    expect(tester.takeException(), isNull);
  });

  testWidgets('crédito sem conta de pagamento ativa ganha badge', (
    tester,
  ) async {
    final s = await seeded(tester);
    final beta = s.accounts.byId('acc_beta')!;
    await tester.runAsync(
      () => s.accounts.upsert(beta.copyWith(archived: true)),
    );
    await pumpIn(tester, s, const Scaffold(body: CardsPage()));
    // Beta Master e Gama Elo usam acc_beta; Alfa Visa e o débito não.
    expect(find.text('Sem conta de pagamento'), findsNWidgets(2));
    expect(tester.takeException(), isNull);
  });
}
