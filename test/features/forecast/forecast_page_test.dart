import 'package:finme/app/app_scope.dart';
import 'package:finme/app/bootstrap.dart';
import 'package:finme/app/seed.dart';
import 'package:finme/core/models/app_settings.dart';
import 'package:finme/core/models/year_month.dart';
import 'package:finme/core/services/record_store.dart';
import 'package:finme/core/theme/app_theme.dart';
import 'package:finme/features/cards/domain/card_insights.dart';
import 'package:finme/features/forecast/presentation/forecast_installments.dart';
import 'package:finme/features/forecast/presentation/forecast_invoice_timeline.dart';
import 'package:finme/features/forecast/presentation/forecast_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Future<AppServices> _setup(WidgetTester tester) async {
  final s = await tester.runAsync(() async {
    final s = await bootstrap(
      storeFactory: (_) => MemoryRecordStore(),
      clock: () => DateTime(2026, 11, 14),
    );
    await seedDemo(s);
    await materializeRecurring(s);
    return s;
  });
  return s!;
}

Future<void> _pumpPage(WidgetTester tester, AppServices s) async {
  await tester.pumpWidget(
    AppScope(
      services: s,
      child: MaterialApp(
        theme: AppTheme.light(),
        home: const Scaffold(body: ForecastPage()),
      ),
    ),
  );
  await tester.pump();
}

Future<void> _setMode(WidgetTester tester, AppServices s, AppMode mode) async {
  await tester.runAsync(
    () => s.settings.update((st) => st.copyWith(mode: mode)),
  );
  await tester.pump();
}

void main() {
  testWidgets('modo Simples: KPIs, cards por mês e próximos eventos', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1400, 900));
    final s = await _setup(tester);
    await _pumpPage(tester, s);

    expect(find.text('Previsão'), findsOneWidget);
    expect(find.text('Saldo atual'), findsOneWidget);
    expect(find.text('Menor saldo previsto'), findsOneWidget);
    expect(find.text('Primeiro saldo negativo'), findsOneWidget);
    expect(find.text('Novembro 2026'), findsOneWidget);
    expect(find.text('Abril 2027'), findsOneWidget);
    expect(find.text('Próximos eventos'), findsOneWidget);
    expect(find.text('Saldo diário'), findsNothing);
    expect(find.text('Vencimentos (60 dias)'), findsNothing);
    expect(find.text('Parcelas já comprometidas'), findsNothing);
    expect(find.text('Todas as contas'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('modo Ultra: gráfico diário e filtros de eventos', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1400, 900));
    final s = await _setup(tester);
    await _pumpPage(tester, s);
    await _setMode(tester, s, AppMode.ultra);

    // ListView preguiçoso: as seções ficam fora da viewport até rolar.
    await tester.scrollUntilVisible(
      find.text('Vencimentos (60 dias)'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Vencimentos (60 dias)'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('Parcelas já comprometidas'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Parcelas já comprometidas'), findsOneWidget);
    // Seed tem parcelas que caem em dezembro/2026 (primeiro mês do compromisso).
    expect(find.text('dez/2026'), findsOneWidget);
    expect(find.text('Nenhuma parcela futura'), findsNothing);
    await tester.scrollUntilVisible(
      find.text('Saldo diário'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Saldo diário'), findsOneWidget);
    // ListView preguiçoso: a seção de eventos fica fora da viewport até rolar.
    await tester.scrollUntilVisible(
      find.text('Eventos'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Eventos'), findsOneWidget);
    expect(find.text('Todas as contas'), findsOneWidget);
    expect(find.widgetWithText(FilterChip, 'Transferência'), findsOneWidget);
    expect(find.text('Próximos eventos'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('linha do tempo sem faturas mostra estado vazio', (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 800));
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: const Scaffold(
          body: InvoiceTimelineSection(items: [], accounts: {}),
        ),
      ),
    );
    expect(find.text('Vencimentos (60 dias)'), findsOneWidget);
    expect(
      find.text('Nenhuma fatura a vencer nos próximos 60 dias'),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('parcelas sem valor no período mostram estado vazio', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 800));
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: const Scaffold(
          body: InstallmentCommitmentsSection(
            items: [
              InstallmentCommitment(month: YearMonth(2026, 12), byCard: {}),
            ],
            cards: {},
          ),
        ),
      ),
    );
    expect(find.text('Parcelas já comprometidas'), findsOneWidget);
    expect(find.text('Nenhuma parcela futura'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('seletor de horizonte atualiza os meses exibidos', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1400, 900));
    final s = await _setup(tester);
    await _pumpPage(tester, s);

    await tester.tap(find.text('12m'));
    await tester.pump();
    expect(s.settings.value.forecastMonths, 12);
    expect(find.text('Outubro 2027'), findsOneWidget);
    expect(find.text('Novembro 2027'), findsNothing);
  });

  testWidgets('sem overflow em 390px nos dois modos', (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 800));
    final s = await _setup(tester);
    await _pumpPage(tester, s);
    expect(tester.takeException(), isNull);

    await _setMode(tester, s, AppMode.ultra);
    expect(tester.takeException(), isNull);
  });
}
