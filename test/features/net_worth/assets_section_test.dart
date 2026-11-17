import 'package:finme/app/app_scope.dart';
import 'package:finme/app/bootstrap.dart';
import 'package:finme/core/models/app_settings.dart';
import 'package:finme/core/services/record_store.dart';
import 'package:finme/core/theme/app_theme.dart';
import 'package:finme/core/widgets/widgets.dart';
import 'package:finme/features/net_worth/domain/asset.dart';
import 'package:finme/features/net_worth/presentation/assets_section.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Hoje é 15/11/2026. Carro (2 valores, 3800000) e Tesouro (200000).
Future<AppServices> _setup(
  WidgetTester tester, {
  List<Asset> assets = const [],
  bool ultra = false,
  bool hideValues = false,
}) async {
  return (await tester.runAsync(() async {
    final s = await bootstrap(
      storeFactory: (_) => MemoryRecordStore(),
      clock: () => DateTime(2026, 11, 15),
    );
    await s.assets.upsertAll(assets);
    if (ultra || hideValues) {
      await s.settings.update(
        (x) => x.copyWith(
          mode: ultra ? AppMode.ultra : null,
          hideValues: hideValues,
        ),
      );
    }
    return s;
  }))!;
}

Future<void> _pump(WidgetTester tester, AppServices s) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = const Size(1200, 900);
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    AppScope(
      services: s,
      child: MaterialApp(
        theme: AppTheme.light(),
        home: const Scaffold(
          body: SingleChildScrollView(child: AssetsSection()),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

final _carro = Asset(
  id: 'carro',
  name: 'Carro',
  kind: AssetKind.vehicle,
  snapshots: [
    AssetSnapshot(id: 's1', date: DateTime(2026, 8, 1), valueCents: 4000000),
    AssetSnapshot(id: 's2', date: DateTime(2026, 11, 1), valueCents: 3800000),
  ],
);

final _tesouro = Asset(
  id: 'tesouro',
  name: 'Tesouro',
  kind: AssetKind.investment,
  snapshots: [
    AssetSnapshot(id: 's3', date: DateTime(2026, 10, 10), valueCents: 200000),
  ],
);

void main() {
  testWidgets('sem ativos: EmptyState com ação Novo ativo', (tester) async {
    final s = await _setup(tester);
    await _pump(tester, s);
    expect(find.byType(EmptyState), findsOneWidget);
    expect(
      find.descendant(
        of: find.byType(EmptyState),
        matching: find.text('Novo ativo'),
      ),
      findsOneWidget,
    );
  });

  testWidgets('Simples: maior valor primeiro, sem data, total nem menu', (
    tester,
  ) async {
    final s = await _setup(tester, assets: [_tesouro, _carro]);
    await _pump(tester, s);
    expect(
      tester.getTopLeft(find.text('Carro')).dy,
      lessThan(tester.getTopLeft(find.text('Tesouro')).dy),
    );
    expect(find.text('Veículo'), findsOneWidget);
    expect(find.text('R\$ 38.000,00'), findsOneWidget);
    expect(find.byKey(const Key('asset-update-carro')), findsOneWidget);
    expect(find.byKey(const Key('asset-menu-carro')), findsNothing);
    expect(find.textContaining('Atualizado em'), findsNothing);
    expect(find.text('Total'), findsNothing);
    expect(find.byKey(const Key('assets-show-archived')), findsNothing);
  });

  testWidgets('Ultra: data do valor, variação e total dos ativos', (
    tester,
  ) async {
    final s = await _setup(tester, assets: [_carro, _tesouro], ultra: true);
    await _pump(tester, s);
    expect(find.text('Atualizado em 01/11/2026'), findsOneWidget);
    expect(find.text('-R\$ 2.000,00'), findsOneWidget);
    expect(find.text('Total'), findsOneWidget);
    expect(find.text('R\$ 40.000,00'), findsOneWidget);
  });

  testWidgets(
    'Ultra: Encerrar com confirmação some; Mostrar encerrados; Reativar',
    (tester) async {
      final s = await _setup(tester, assets: [_carro], ultra: true);
      await _pump(tester, s);
      await tester.tap(find.byKey(const Key('asset-menu-carro')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Encerrar'));
      await tester.pumpAndSettle();
      expect(find.text('Encerrar ativo?'), findsOneWidget);
      await tester.tap(find.widgetWithText(FilledButton, 'Encerrar'));
      await tester.pumpAndSettle();

      expect(find.text('Carro'), findsNothing);
      expect(s.assets.byId('carro')!.archived, isTrue);
      expect(find.byKey(const Key('assets-show-archived')), findsOneWidget);

      await tester.tap(find.byKey(const Key('assets-show-archived')));
      await tester.pumpAndSettle();
      expect(find.text('Carro'), findsOneWidget);
      expect(find.text('Encerrado'), findsOneWidget);

      await tester.tap(find.byKey(const Key('asset-menu-carro')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Reativar'));
      await tester.pumpAndSettle();
      expect(s.assets.byId('carro')!.archived, isFalse);
    },
  );

  testWidgets('Ultra: Excluir confirmado remove o ativo do repositório', (
    tester,
  ) async {
    final s = await _setup(tester, assets: [_carro, _tesouro], ultra: true);
    await _pump(tester, s);
    await tester.tap(find.byKey(const Key('asset-menu-tesouro')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Excluir'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Excluir'));
    await tester.pumpAndSettle();
    expect(s.assets.byId('tesouro'), isNull);
    expect(find.text('Tesouro'), findsNothing);
    expect(find.text('Carro'), findsOneWidget);
  });

  testWidgets('Atualizar valor abre o diálogo do ativo', (tester) async {
    final s = await _setup(tester, assets: [_carro]);
    await _pump(tester, s);
    await tester.tap(find.byKey(const Key('asset-update-carro')));
    await tester.pumpAndSettle();
    expect(find.text('Atualizar valor · Carro'), findsOneWidget);
  });

  testWidgets('hideValues: valores ocultos, nome continua visível', (
    tester,
  ) async {
    final s = await _setup(tester, assets: [_carro], hideValues: true);
    await _pump(tester, s);
    expect(find.text('R\$ 38.000,00'), findsNothing);
    expect(find.text('R\$ ••••'), findsOneWidget);
    expect(find.text('Carro'), findsOneWidget);
  });
}
