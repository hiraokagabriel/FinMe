import 'package:finme/app/app_scope.dart';
import 'package:finme/app/bootstrap.dart';
import 'package:finme/app/seed.dart';
import 'package:finme/core/models/app_settings.dart';
import 'package:finme/core/services/record_store.dart';
import 'package:finme/core/theme/app_theme.dart';
import 'package:finme/core/widgets/widgets.dart';
import 'package:finme/features/dashboard/presentation/dashboard_page.dart';
import 'package:finme/features/dashboard/presentation/spendable_card.dart';
import 'package:finme/features/forecast/domain/forecast.dart';
import 'package:finme/features/forecast/domain/spendable.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Future<AppServices> _boot(
  WidgetTester tester, {
  AppMode mode = AppMode.simple,
}) async {
  final s = (await tester.runAsync(() async {
    final s = await bootstrap(
      storeFactory: (_) => MemoryRecordStore(),
      clock: () => DateTime(2026, 11, 15),
    );
    await seedDemo(s);
    await materializeRecurring(s);
    await s.settings.update((x) => x.copyWith(mode: mode));
    return s;
  }))!;
  return s;
}

final _invoiceK1 = ForecastEvent(
  date: DateTime(2026, 12, 5),
  amountCents: -80000,
  description: 'Fatura Cartão K1',
  kind: ForecastEventKind.invoice,
  sourceId: 'card_k1',
  accountId: 'acc_a',
);

final _planned = [
  ForecastEvent(
    date: DateTime(2026, 11, 20),
    amountCents: -25000,
    description: 'Boleto Luz',
    kind: ForecastEventKind.boleto,
    sourceId: 'tx_luz',
    accountId: 'acc_a',
  ),
  ForecastEvent(
    date: DateTime(2026, 11, 10),
    amountCents: -5000,
    description: 'Despesa atrasada',
    kind: ForecastEventKind.expense,
    sourceId: 'tx_atrasada',
    accountId: 'acc_b',
  ),
  ForecastEvent(
    date: DateTime(2026, 12, 1),
    amountCents: -150000,
    description: 'Aluguel',
    kind: ForecastEventKind.expense,
    sourceId: 'rule_aluguel',
    accountId: 'acc_a',
    isProjected: true,
  ),
];

/// Fórmula da SPEC §5.23: 350000 − 80000 − 180000 − reserva. Com salário em 05/12 (20 dias).
SpendableToday _fixture({int reserved = 40000, bool income = true}) {
  return SpendableToday(
    today: DateTime(2026, 11, 15),
    nextIncomeDate: income ? DateTime(2026, 12, 5) : null,
    nextIncomeDescription: income ? 'Salário' : null,
    untilDate: income ? DateTime(2026, 12, 5) : DateTime(2026, 11, 30),
    days: income ? 20 : 16,
    balanceCents: 350000,
    invoicesCents: income ? 80000 : 0,
    plannedCents: income ? 180000 : 25000,
    reservedCents: reserved,
    invoiceEvents: income ? [_invoiceK1] : const [],
    plannedEvents: income ? _planned : [_planned.first],
  );
}

Future<void> _pumpCard(
  WidgetTester tester,
  AppServices s,
  SpendableToday data, {
  bool ultra = false,
}) async {
  await tester.binding.setSurfaceSize(const Size(900, 900));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(
    AppScope(
      services: s,
      child: MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(
          body: Padding(
            padding: const EdgeInsets.all(16),
            child: SpendableCard(data: data, ultra: ultra),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _tapToggle(WidgetTester tester) async {
  await tester.tap(find.byKey(const ValueKey('spendable-toggle')));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('livre 50000, 2500/dia, até 05/12, receita Salário, 20 dias', (
    tester,
  ) async {
    final s = await _boot(tester);
    await _pumpCard(tester, s, _fixture());

    expect(find.text('Posso gastar hoje'), findsOneWidget);
    expect(find.text('R\$ 500,00'), findsOneWidget);
    expect(find.text(' livres · '), findsOneWidget);
    expect(find.text('R\$ 25,00'), findsOneWidget);
    expect(find.text('/dia até 05/12'), findsOneWidget);
    expect(
      find.text('Próxima receita: Salário em 05/12 (20 dias)'),
      findsOneWidget,
    );
    expect(find.text('Ocultar cálculo'), findsNothing);
  });

  testWidgets('Ver cálculo mostra só as parcelas; Ocultar cálculo esconde', (
    tester,
  ) async {
    final s = await _boot(tester);
    await _pumpCard(tester, s, _fixture());

    expect(find.text('= Livre'), findsNothing);
    await _tapToggle(tester);

    expect(find.text('Ocultar cálculo'), findsOneWidget);
    expect(find.text('Saldo das contas'), findsOneWidget);
    expect(find.text('− Faturas até 05/12 (1)'), findsOneWidget);
    expect(find.text('− Provisionados até 05/12 (3)'), findsOneWidget);
    expect(find.text('− Reservado em metas'), findsOneWidget);
    expect(find.text('= Livre'), findsOneWidget);
    expect(find.text('÷ 20 dias'), findsOneWidget);
    // Simples: nenhuma descrição de evento.
    expect(find.text('Fatura Cartão K1'), findsNothing);

    await _tapToggle(tester);
    expect(find.text('= Livre'), findsNothing);
    expect(find.text('Ver cálculo'), findsOneWidget);
  });

  testWidgets(
    'Ultra com detalhe aberto mostra eventos de fatura e provisionados',
    (tester) async {
      final s = await _boot(tester, mode: AppMode.ultra);
      await _pumpCard(tester, s, _fixture(), ultra: true);

      await _tapToggle(tester);
      expect(find.text('Fatura Cartão K1'), findsOneWidget);
      expect(find.text('Boleto Luz'), findsOneWidget);
      expect(find.text('Aluguel'), findsOneWidget);
    },
  );

  testWidgets('livre negativo: sem folga, faltam, sem /dia', (tester) async {
    final s = await _boot(tester);
    // Reserva efetiva 300000: 350000 − 80000 − 180000 − 300000 = −210000.
    await _pumpCard(tester, s, _fixture(reserved: 300000));

    expect(find.text('Sem folga até 05/12'), findsOneWidget);
    expect(find.text('Faltam'), findsOneWidget);
    expect(find.text('R\$ 2.100,00'), findsOneWidget);
    expect(find.textContaining('/dia'), findsNothing);
  });

  testWidgets('sem receita recorrente: legenda considera fim do mês', (
    tester,
  ) async {
    final s = await _boot(tester);
    await _pumpCard(tester, s, _fixture(income: false));

    expect(
      find.text(
        'Sem receita recorrente: considerando até o fim do mês (16 dias)',
      ),
      findsOneWidget,
    );
  });

  testWidgets('hideValues: valores viram R\$ ••••', (tester) async {
    final s = await _boot(tester);
    await tester.runAsync(
      () => s.settings.update((x) => x.copyWith(hideValues: true)),
    );
    await _pumpCard(tester, s, _fixture());

    expect(find.text('R\$ 500,00'), findsNothing);
    expect(find.text('R\$ ••••'), findsWidgets);
  });

  for (final mode in AppMode.values) {
    testWidgets('Painel com seed (${mode.name}): card acima do primeiro KPI', (
      tester,
    ) async {
      final s = await _boot(tester, mode: mode);
      await tester.binding.setSurfaceSize(const Size(1400, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
        AppScope(
          services: s,
          child: MaterialApp(
            theme: AppTheme.light(),
            home: const Scaffold(body: DashboardPage()),
          ),
        ),
      );
      await tester.pump();

      expect(tester.takeException(), isNull);
      final card = find.byKey(const ValueKey('spendable-card'));
      expect(card, findsOneWidget);
      expect(
        tester.getTopLeft(card).dy,
        lessThan(tester.getTopLeft(find.byType(KpiTile).first).dy),
      );
    });
  }
}
