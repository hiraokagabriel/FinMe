import 'package:finme/app/app_scope.dart';
import 'package:finme/app/bootstrap.dart';
import 'package:finme/app/seed.dart';
import 'package:finme/core/models/app_settings.dart';
import 'package:finme/core/models/year_month.dart';
import 'package:finme/core/services/record_store.dart';
import 'package:finme/core/theme/app_theme.dart';
import 'package:finme/core/utils/formatters.dart';
import 'package:finme/core/widgets/widgets.dart';
import 'package:finme/features/transactions/presentation/transaction_filters.dart';
import 'package:finme/features/transactions/presentation/transactions_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Future<AppServices> _services(WidgetTester tester, AppMode mode) async {
  return (await tester.runAsync(() async {
    final s = await bootstrap(
      storeFactory: (_) => MemoryRecordStore(),
      clock: () => DateTime(2026, 11, 14),
    );
    await seedDemo(s);
    await materializeRecurring(s);
    await s.settings.update((x) => x.copyWith(mode: mode));
    return s;
  }))!;
}

Future<void> _pump(WidgetTester tester, AppServices s, Size size) async {
  await tester.binding.setSurfaceSize(size);
  await tester.pumpWidget(
    AppScope(
      services: s,
      child: MaterialApp(
        theme: AppTheme.light(),
        home: const Scaffold(body: TransactionsPage()),
      ),
    ),
  );
  await tester.pump();
}

void main() {
  testWidgets('Simples: mês, cabeçalho de 3 colunas e sem filtros Ultra', (
    tester,
  ) async {
    final s = await _services(tester, AppMode.simple);
    await _pump(tester, s, const Size(1400, 900));

    expect(find.text('Transações'), findsOneWidget);
    expect(
      find.text(formatMonthLong(const YearMonth(2026, 11))),
      findsOneWidget,
    );
    expect(find.text('Descrição'), findsOneWidget);
    expect(find.text('Conta / Cartão'), findsNothing);
    expect(find.text('Mostrar provisionados'), findsNothing);
    expect(find.text('Despesas'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Ultra: barra de filtros, colunas extras e rodapé', (
    tester,
  ) async {
    final s = await _services(tester, AppMode.ultra);
    await _pump(tester, s, const Size(1400, 900));

    expect(find.text('Mostrar provisionados'), findsOneWidget);
    expect(find.text('Conta / Cartão'), findsOneWidget);
    expect(find.text('Buscar descrição ou notas'), findsOneWidget);
    expect(find.text('Provisionado'), findsOneWidget);
    expect(find.text('Receitas'), findsOneWidget);
    expect(find.byType(PlannedMarker), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Ultra: lista mostra descrições do mês e some ao filtrar', (
    tester,
  ) async {
    final s = await _services(tester, AppMode.ultra);
    await _pump(tester, s, const Size(1400, 900));

    final rows = visibleTransactions(
      s.transactions.all,
      const YearMonth(2026, 11),
      const TransactionFilter(),
    ).where((t) => !t.isInstallment).toList();
    expect(rows, isNotEmpty);
    expect(find.text(rows.first.description), findsWidgets);

    await tester.enterText(
      find.widgetWithText(TextField, 'Buscar descrição ou notas'),
      'termo-inexistente-xyz',
    );
    await tester.pump();
    expect(find.text('Nenhuma transação neste filtro.'), findsOneWidget);
  });

  testWidgets('sem overflow em 390px nos modos Simples e Ultra', (
    tester,
  ) async {
    for (final mode in AppMode.values) {
      final s = await _services(tester, mode);
      await _pump(tester, s, const Size(390, 800));
      expect(tester.takeException(), isNull, reason: mode.name);
    }
    addTearDown(() => tester.binding.setSurfaceSize(null));
  });
}
