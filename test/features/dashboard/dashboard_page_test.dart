import 'package:finme/app/app_scope.dart';
import 'package:finme/app/bootstrap.dart';
import 'package:finme/app/seed.dart';
import 'package:finme/core/models/app_settings.dart';
import 'package:finme/core/services/record_store.dart';
import 'package:finme/core/theme/app_theme.dart';
import 'package:finme/core/utils/formatters.dart';
import 'package:finme/core/widgets/widgets.dart';
import 'package:finme/features/dashboard/presentation/dashboard_page.dart';
import 'package:finme/features/transactions/domain/transaction.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Demo em memória com o modo pedido. `negative` adiciona uma despesa que zera o caixa.
Future<AppServices> _boot(
  WidgetTester tester, {
  required AppMode mode,
  bool negative = false,
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
}
