import 'package:finme/app/app_scope.dart';
import 'package:finme/app/bootstrap.dart';
import 'package:finme/app/seed.dart';
import 'package:finme/core/models/app_settings.dart';
import 'package:finme/core/services/record_store.dart';
import 'package:finme/core/theme/app_theme.dart';
import 'package:finme/core/utils/formatters.dart';
import 'package:finme/core/widgets/widgets.dart';
import 'package:finme/features/cards/domain/payment_card.dart';
import 'package:finme/features/dashboard/presentation/dashboard_page.dart';
import 'package:finme/features/dashboard/presentation/dashboard_summary.dart';
import 'package:finme/features/transactions/domain/transaction.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Demo em memória com o modo pedido. `negative` adiciona uma despesa que zera o caixa.
Future<AppServices> _boot(
  WidgetTester tester, {
  required AppMode mode,
  bool negative = false,
  bool cardSemConta = false,
  bool contaSemSaldo = false,
}) async {
  final s = (await tester.runAsync(() async {
    final s = await bootstrap(
      storeFactory: (_) => MemoryRecordStore(),
      clock: () => DateTime(2026, 11, 14),
    );
    await seedDemo(s);
    await materializeRecurring(s);
    await s.settings.update((x) => x.copyWith(mode: mode));
    if (negative) {
      await s.transactions.upsert(
        Transaction(
          id: 'tx_negativo',
          type: TransactionType.expense,
          amountCents: 99999999,
          date: DateTime(2026, 11, 14),
          description: 'Compra grande',
          accountId: 'acc_cash',
        ),
      );
    }
    if (cardSemConta) {
      await s.cards.upsert(
        const PaymentCard(
          id: 'card_sem_conta',
          name: 'Teste Sem Conta',
          bankName: 'Banco Teste',
          brand: CardBrand.visa,
          kind: CardKind.credit,
          last4: '9999',
          limitCents: 300000,
          closingDay: 5,
          dueDay: 12,
          colorValue: 0xFF999999,
        ),
      );
      await s.transactions.upsert(
        Transaction(
          id: 'tx_sem_conta',
          type: TransactionType.expense,
          amountCents: 10000,
          date: DateTime(2026, 11, 14),
          description: 'Compra sem conta',
          cardId: 'card_sem_conta',
        ),
      );
    }
    if (contaSemSaldo) {
      await s.transactions.upsert(
        Transaction(
          id: 'tx_sem_saldo',
          type: TransactionType.expense,
          amountCents: 99999999,
          date: DateTime(2026, 11, 14),
          description: 'Gasto no Beta',
          accountId: 'acc_beta',
        ),
      );
    }
    return s;
  }))!;
  return s;
}

Future<void> _pump(WidgetTester tester, AppServices s, Size size) async {
  await tester.binding.setSurfaceSize(size);
  addTearDown(() => tester.binding.setSurfaceSize(null));
  // Desmonta antes: DashboardPage é const, então trocar só o AppScope não a reconstrói.
  await tester.pumpWidget(const SizedBox());
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
}

void main() {
  const desktop = Size(1400, 900);
  const mobile = Size(390, 800);

  testWidgets('Simples: KPIs, faturas, vencimentos e categorias (lista)', (
    tester,
  ) async {
    final s = await _boot(tester, mode: AppMode.simple);
    await _pump(tester, s, desktop);

    expect(tester.takeException(), isNull);
    expect(find.text('Visão geral'), findsOneWidget);
    for (final label in [
      'Saldo atual',
      'A pagar em 30 dias',
      'Faturas em aberto',
      'Saldo previsto fim do mês',
      'Próximas faturas',
      'Próximos vencimentos',
      'Gastos por categoria (mês)',
    ]) {
      expect(find.text(label), findsOneWidget, reason: label);
    }
    expect(
      find.text(formatMoney(s.ledger.forecast.currentTotalCents)),
      findsWidgets,
    );
    expect(find.byType(LimitBar), findsNothing);
    expect(find.text('Alfa Visa'), findsWidgets);
  });

  testWidgets('Ultra: barras de limite e de categoria', (tester) async {
    final s = await _boot(tester, mode: AppMode.ultra);
    await _pump(tester, s, desktop);

    expect(tester.takeException(), isNull);
    expect(find.text('Próximas faturas'), findsOneWidget);
    expect(find.byType(LimitBar), findsWidgets);
    expect(find.text('Saldo atual'), findsOneWidget);
  });

  testWidgets('Mobile 390px sem overflow nos dois modos', (tester) async {
    for (final mode in AppMode.values) {
      final s = await _boot(tester, mode: mode);
      await _pump(tester, s, mobile);
      expect(tester.takeException(), isNull, reason: mode.name);
      expect(find.text('Saldo atual'), findsOneWidget, reason: mode.name);
      expect(find.text('Próximos vencimentos'), findsOneWidget);
    }
  });

  testWidgets('Saldo negativo: banner em ambos; Ultra lista a conta', (
    tester,
  ) async {
    final simple = await _boot(tester, mode: AppMode.simple, negative: true);
    await _pump(tester, simple, desktop);
    expect(
      find.text('Seu saldo consolidado fica negativo em 14/11/2026'),
      findsOneWidget,
    );
    expect(find.textContaining('Carteira: negativa'), findsNothing);

    final ultra = await _boot(tester, mode: AppMode.ultra, negative: true);
    await _pump(tester, ultra, desktop);
    expect(
      find.text('Seu saldo consolidado fica negativo em 14/11/2026'),
      findsOneWidget,
    );
    expect(find.text('Carteira: negativa em 14/11/2026'), findsOneWidget);
  });

  testWidgets('Cobertura Simples: banner com contagem e a mais próxima', (
    tester,
  ) async {
    final s = await _boot(tester, mode: AppMode.simple, cardSemConta: true);
    final nearest = s.ledger.invoiceTimeline.firstWhere(
      (d) => d.needsAttention,
    );
    final n = s.ledger.invoiceTimeline.where((d) => d.needsAttention).length;
    expect(n, greaterThan(0));
    await _pump(tester, s, desktop);

    expect(tester.takeException(), isNull);
    expect(
      find.text(
        n == 1
            ? '1 fatura precisa de atenção (sem saldo previsto ou sem conta de pagamento)'
            : '$n faturas precisam de atenção (sem saldo previsto ou sem conta de pagamento)',
      ),
      findsOneWidget,
    );
    expect(
      find.text(
        'Mais próxima: ${nearest.invoice.card.name} em ${formatDate(nearest.date)}',
      ),
      findsOneWidget,
    );
    expect(find.text('Cobertura de faturas'), findsNothing);
  });

  testWidgets('Cobertura Ultra: card com linhas, conta e sem conta', (
    tester,
  ) async {
    final s = await _boot(
      tester,
      mode: AppMode.ultra,
      cardSemConta: true,
      contaSemSaldo: true,
    );
    await _pump(tester, s, desktop);

    expect(tester.takeException(), isNull);
    expect(find.text('Cobertura de faturas'), findsOneWidget);
    expect(find.text('Teste Sem Conta'), findsWidgets);
    expect(find.text('Sem conta de pagamento'), findsWidgets);
    expect(find.text('Conta corrente (Banco Beta)'), findsWidgets);
    expect(find.text('Saldo após'), findsWidgets);
  });

  testWidgets('Cobertura: sem pendências não renderiza nada', (tester) async {
    for (final mode in AppMode.values) {
      final s = await _boot(tester, mode: mode);
      // Demo já tem pendências; saldos altos cobrem todas as faturas.
      await tester.runAsync(() async {
        for (final a in s.accounts.all) {
          await s.accounts.upsert(
            a.copyWith(initialBalanceCents: 100000000000),
          );
        }
      });
      expect(
        s.ledger.invoiceTimeline.where((d) => d.needsAttention),
        isEmpty,
        reason: mode.name,
      );
      await _pump(tester, s, desktop);
      expect(tester.takeException(), isNull, reason: mode.name);
      expect(find.text('Cobertura de faturas'), findsNothing);
      expect(find.textContaining('sem saldo previsto'), findsNothing);
    }
  });

  testWidgets('Cobertura em 390px sem overflow nos dois modos', (tester) async {
    for (final mode in AppMode.values) {
      final s = await _boot(
        tester,
        mode: mode,
        cardSemConta: true,
        contaSemSaldo: true,
      );
      await _pump(tester, s, mobile);
      expect(tester.takeException(), isNull, reason: mode.name);
    }
  });

  testWidgets('Ultra: KPIs com delta, sparkline e Gasto no mês', (
    tester,
  ) async {
    final s = await _boot(tester, mode: AppMode.ultra);
    final summary = DashboardSummary.of(s.ledger, ultra: true);
    expect(summary.balanceTrend, hasLength(6));
    expect(summary.expenseTrend, hasLength(6));
    expect(summary.monthExpenseCents, s.ledger.expenseMonthToDate.current);
    await _pump(tester, s, desktop);

    expect(tester.takeException(), isNull);
    expect(find.text('Gasto no mês'), findsOneWidget);
    expect(find.byType(Sparkline), findsNWidgets(3));
    expect(find.byType(DeltaBadge), findsNWidgets(3));
    final withDelta = tester
        .widgetList<DeltaBadge>(find.byType(DeltaBadge))
        .where((b) => b.ratio != null)
        .length;
    expect(
      withDelta,
      [
        summary.balanceDelta,
        summary.monthExpenseDelta,
        summary.netWorthDelta,
      ].whereType<double>().length,
    );
  });

  testWidgets('Simples: sem delta, sparkline nem Gasto no mês', (tester) async {
    final s = await _boot(tester, mode: AppMode.simple);
    final summary = DashboardSummary.of(s.ledger, ultra: false);
    expect(summary.balanceTrend, isNull);
    expect(summary.balanceDelta, isNull);
    expect(summary.monthExpenseCents, isNull);
    expect(summary.monthExpenseDelta, isNull);
    expect(summary.expenseTrend, isNull);
    await _pump(tester, s, desktop);

    expect(tester.takeException(), isNull);
    expect(find.byType(Sparkline), findsNothing);
    expect(find.byType(DeltaBadge), findsNothing);
    expect(find.text('Gasto no mês'), findsNothing);
  });
}
