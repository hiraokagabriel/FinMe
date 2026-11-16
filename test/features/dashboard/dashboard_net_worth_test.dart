import 'package:finme/app/app_scope.dart';
import 'package:finme/app/bootstrap.dart';
import 'package:finme/app/seed.dart';
import 'package:finme/core/models/app_settings.dart';
import 'package:finme/core/services/record_store.dart';
import 'package:finme/core/theme/app_theme.dart';
import 'package:finme/core/widgets/widgets.dart';
import 'package:finme/features/dashboard/presentation/dashboard_page.dart';
import 'package:finme/features/dashboard/presentation/dashboard_summary.dart';
import 'package:finme/features/net_worth/domain/asset.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Demo em memória com um ativo de 100000 com snapshot de hoje (15/11/2026).
Future<AppServices> _boot(WidgetTester tester, {required AppMode mode}) async {
  final s = (await tester.runAsync(() async {
    final s = await bootstrap(
      storeFactory: (_) => MemoryRecordStore(),
      clock: () => DateTime(2026, 11, 15),
    );
    await seedDemo(s);
    await s.settings.update((x) => x.copyWith(mode: mode));
    await s.assets.upsert(
      Asset(
        id: 'carro',
        name: 'Carro',
        kind: AssetKind.vehicle,
        snapshots: [
          AssetSnapshot(
            id: 's1',
            date: DateTime(2026, 11, 15),
            valueCents: 100000,
          ),
        ],
      ),
    );
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
  const narrow = Size(900, 800);

  testWidgets(
    'Ultra: KPI Patrimônio líquido com delta e sparkline de 6 meses',
    (tester) async {
      final s = await _boot(tester, mode: AppMode.ultra);
      final summary = DashboardSummary.of(s.ledger, ultra: true);
      expect(summary.netWorthCents, s.ledger.netWorthHistory.last.netCents);
      expect(summary.netWorthTrend, hasLength(6));
      expect(summary.netWorthTrend!.last, summary.netWorthCents);
      await _pump(tester, s, desktop);

      expect(tester.takeException(), isNull);
      expect(find.text('Patrimônio líquido'), findsOneWidget);
      expect(find.byType(Sparkline), findsNWidgets(3));
      expect(find.byType(DeltaBadge), findsNWidgets(3));
    },
  );

  testWidgets('Ultra: KPI Patrimônio líquido cabe na janela de 900px', (
    tester,
  ) async {
    final s = await _boot(tester, mode: AppMode.ultra);
    await _pump(tester, s, narrow);

    expect(tester.takeException(), isNull);
    expect(find.text('Patrimônio líquido'), findsOneWidget);
  });

  testWidgets('Simples: sem campos de patrimônio e sem KPI no Painel', (
    tester,
  ) async {
    final s = await _boot(tester, mode: AppMode.simple);
    final summary = DashboardSummary.of(s.ledger, ultra: false);
    expect(summary.netWorthCents, isNull);
    expect(summary.netWorthDelta, isNull);
    expect(summary.netWorthTrend, isNull);
    await _pump(tester, s, desktop);

    expect(tester.takeException(), isNull);
    expect(find.text('Patrimônio líquido'), findsNothing);
  });
}
