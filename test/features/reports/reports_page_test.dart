import 'package:finme/app/app_scope.dart';
import 'package:finme/app/bootstrap.dart';
import 'package:finme/core/models/app_settings.dart';
import 'package:finme/core/services/record_store.dart';
import 'package:finme/core/theme/app_theme.dart';
import 'package:finme/core/widgets/layout.dart';
import 'package:finme/features/accounts/domain/account.dart';
import 'package:finme/features/categories/domain/transaction_category.dart';
import 'package:finme/features/reports/domain/report_filter.dart';
import 'package:finme/features/reports/presentation/category_comparison_view.dart';
import 'package:finme/features/reports/presentation/merchants_view.dart';
import 'package:finme/features/reports/presentation/net_worth_report_view.dart';
import 'package:finme/features/reports/presentation/pivot_view.dart';
import 'package:finme/features/reports/presentation/reports_controller.dart';
import 'package:finme/features/reports/presentation/reports_page.dart';
import 'package:finme/features/reports/presentation/trend_view.dart';
import 'package:finme/features/transactions/domain/transaction.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

DateTime _now() => DateTime(2026, 11, 15);

TransactionCategory _cat(
  String id,
  String name,
  CategoryKind kind, {
  String? parentId,
}) => TransactionCategory(
  id: id,
  name: name,
  kind: kind,
  iconCodePoint: 0,
  colorValue: 0,
  parentId: parentId,
);

Transaction _exp(String id, DateTime date, String? categoryId, int cents) =>
    Transaction(
      id: id,
      type: TransactionType.expense,
      amountCents: cents,
      date: date,
      description: 'Loja $id',
      accountId: 'A',
      categoryId: categoryId,
    );

/// Mesmos dados de §5.28 usados no ReportsController (despesas pagas, set–nov de 2026).
List<Transaction> _seed() => [
  _exp('a1', DateTime(2026, 8, 10), 'mer', 30000),
  _exp('s1', DateTime(2026, 9, 10), 'mer', 40000),
  _exp('s2', DateTime(2026, 9, 10), 'res', 10000),
  _exp('o1', DateTime(2026, 10, 10), 'mer', 50000),
  _exp('o2', DateTime(2026, 10, 10), 'res', 20000),
  _exp('n1', DateTime(2026, 11, 3), 'mer', 60000),
  _exp('n2', DateTime(2026, 11, 3), 'res', 15000),
  _exp('n4', DateTime(2026, 11, 3), null, 3000),
];

/// Bootstrap sai do zone fake do testWidgets (o Ledger agenda um timer de meia-noite).
Future<AppServices> _boot(
  WidgetTester tester, {
  required bool ultra,
  bool seed = true,
}) async => (await tester.runAsync(() => _services(ultra: ultra, seed: seed)))!;

Future<AppServices> _services({required bool ultra, bool seed = true}) async {
  final s = await bootstrap(
    storeFactory: (_) => MemoryRecordStore(),
    clock: _now,
  );
  await s.categories.replaceAll([
    _cat('ali', 'Alimentação', CategoryKind.expense),
    _cat('mer', 'Mercado', CategoryKind.expense, parentId: 'ali'),
    _cat('res', 'Restaurante', CategoryKind.expense, parentId: 'ali'),
  ]);
  await s.accounts.upsert(
    const Account(
      id: 'A',
      name: 'Conta A',
      bankName: 'Banco A',
      type: AccountType.checking,
      initialBalanceCents: 100000,
      colorValue: 0xFF42A5F5,
    ),
  );
  if (seed) {
    await s.transactions.upsertAll(_seed());
  }
  await s.settings.update(
    (x) => x.copyWith(mode: ultra ? AppMode.ultra : AppMode.simple),
  );
  return s;
}

Future<void> _pump(
  WidgetTester tester,
  AppServices s,
  ReportsController c, {
  SaveReportCsv? save,
}) async {
  await tester.binding.setSurfaceSize(const Size(1400, 900));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(
    AppScope(
      services: s,
      child: MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(
          body: ReportsPage(controller: c, saveCsv: save),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('Ultra: 7 itens na ordem de kUltraReports e troca de relatório', (
    tester,
  ) async {
    final s = await _boot(tester, ultra: true);
    final c = ReportsController(s);
    await _pump(tester, s, c);

    double dy(ReportKind k) =>
        tester.getTopLeft(find.byKey(Key('report-tab-${k.name}'))).dy;
    for (var i = 0; i < kUltraReports.length; i++) {
      expect(
        find.byKey(Key('report-tab-${kUltraReports[i].name}')),
        findsOneWidget,
      );
      if (i > 0) {
        expect(dy(kUltraReports[i]), greaterThan(dy(kUltraReports[i - 1])));
      }
    }

    await tester.tap(find.byKey(const Key('report-tab-pivot')));
    await tester.pumpAndSettle();
    expect(find.byType(PivotView), findsOneWidget);

    await tester.tap(find.byKey(const Key('report-tab-netWorth')));
    await tester.pumpAndSettle();
    expect(find.byType(NetWorthReportView), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Simples: 3 relatórios, só período, abre em Tendência', (
    tester,
  ) async {
    final s = await _boot(tester, ultra: false);
    final c = ReportsController(s)..selected = ReportKind.pivot;
    await _pump(tester, s, c);

    expect(find.byKey(const Key('report-tab-trend')), findsOneWidget);
    expect(find.byKey(const Key('report-tab-topMerchants')), findsOneWidget);
    expect(
      find.byKey(const Key('report-tab-categoryComparison')),
      findsOneWidget,
    );
    expect(find.byKey(const Key('report-tab-pivot')), findsNothing);
    expect(find.byKey(const Key('report-period')), findsOneWidget);
    expect(find.byKey(const Key('report-flow')), findsNothing);
    expect(find.byType(TrendView), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Simples: top estabelecimentos e comparativo abrem sem exceção', (
    tester,
  ) async {
    final s = await _boot(tester, ultra: false);
    final c = ReportsController(s);
    await _pump(tester, s, c);

    await tester.tap(find.byKey(const Key('report-tab-topMerchants')));
    await tester.pumpAndSettle();
    expect(find.byType(MerchantsView), findsOneWidget);

    await tester.tap(find.byKey(const Key('report-tab-categoryComparison')));
    await tester.pumpAndSettle();
    expect(find.byType(CategoryComparisonView), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Ultra: aviso de filtros ignorados só quando há algum', (
    tester,
  ) async {
    final s = await _boot(tester, ultra: true);
    final c = ReportsController(s);
    await _pump(tester, s, c);

    c.filter = ReportFilter(flow: ReportFlow.income);
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('report-ignored')), findsOneWidget);
    expect(
      find.text('Filtros ignorados neste relatório: tipo'),
      findsOneWidget,
    );

    c.filter = ReportFilter();
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('report-ignored')), findsNothing);
  });

  testWidgets('trocar período para 3 meses mostra 3 meses na tendência', (
    tester,
  ) async {
    final s = await _boot(tester, ultra: false);
    final c = ReportsController(s);
    await _pump(tester, s, c);

    await tester.tap(find.byKey(const Key('report-period')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('3 meses').last);
    await tester.pumpAndSettle();

    expect(find.byType(TrendView), findsOneWidget);
    expect(find.text('set/2026'), findsWidgets);
    expect(find.text('nov/2026'), findsWidgets);
    expect(find.text('ago/2026'), findsNothing);
    expect(c.filter.preset, ReportPeriodPreset.last3);
  });

  group('exportar CSV', () {
    testWidgets('grava com BOM, nome sugerido e sem SnackBar ao cancelar', (
      tester,
    ) async {
      final s = await _boot(tester, ultra: true);
      final c = ReportsController(s);
      final calls = <(String, String)>[];
      await _pump(
        tester,
        s,
        c,
        save: (name, csv) async {
          calls.add((name, csv));
          return false;
        },
      );

      await tester.tap(find.byKey(const Key('report-export')));
      await tester.pumpAndSettle();

      expect(calls, hasLength(1));
      final (name, csv) = calls.single;
      expect(name, c.csvFileName(ReportKind.trend));
      expect(csv.startsWith('﻿Mês;Receitas;Despesas;'), isTrue);
      expect(find.text('CSV exportado (valores reais).'), findsNothing);
    });

    testWidgets('confirma com SnackBar quando salva', (tester) async {
      final s = await _boot(tester, ultra: true);
      final c = ReportsController(s);
      await _pump(tester, s, c, save: (n, t) async => true);

      await tester.tap(find.byKey(const Key('report-export')));
      await tester.pumpAndSettle();
      expect(find.text('CSV exportado (valores reais).'), findsOneWidget);
    });

    testWidgets('erro na gravação mostra SnackBar de falha', (tester) async {
      final s = await _boot(tester, ultra: true);
      final c = ReportsController(s);
      await _pump(
        tester,
        s,
        c,
        save: (n, t) async => throw Exception('disco cheio'),
      );

      await tester.tap(find.byKey(const Key('report-export')));
      await tester.pumpAndSettle();
      expect(find.text('Não foi possível exportar o CSV.'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  testWidgets('sem transações, cada relatório Ultra abre sem exceção', (
    tester,
  ) async {
    final s = await _boot(tester, ultra: true, seed: false);
    final c = ReportsController(s);
    await _pump(tester, s, c);

    for (final k in kUltraReports) {
      await tester.tap(find.byKey(Key('report-tab-${k.name}')));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull, reason: k.name);
      // Patrimônio sempre tem 24 pontos (zerados): a tabela aparece, não o EmptyState.
      if (k == ReportKind.netWorth) {
        expect(find.byType(NetWorthReportView), findsOneWidget);
      } else {
        expect(find.byType(EmptyState), findsOneWidget, reason: k.name);
      }
    }
  });
}
