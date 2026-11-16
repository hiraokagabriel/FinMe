import 'package:finme/app/app_scope.dart';
import 'package:finme/app/bootstrap.dart';
import 'package:finme/core/services/record_store.dart';
import 'package:finme/core/theme/app_colors.dart';
import 'package:finme/core/theme/app_theme.dart';
import 'package:finme/features/net_worth/domain/asset.dart';
import 'package:finme/features/net_worth/presentation/asset_dialogs.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

final _light = AppTheme.light().extension<AppColors>()!;

/// Hoje é 15/11/2026. Só ativos; nenhuma transação.
Future<AppServices> _setup(
  WidgetTester tester, {
  List<Asset> assets = const [],
}) async {
  return (await tester.runAsync(() async {
    final s = await bootstrap(
      storeFactory: (_) => MemoryRecordStore(),
      clock: () => DateTime(2026, 11, 15),
    );
    await s.assets.upsertAll(assets);
    return s;
  }))!;
}

/// Abre o diálogo pelo botão 'abrir' (`open` recebe o context da página).
Future<void> _pump(
  WidgetTester tester,
  AppServices s,
  Future<void> Function(BuildContext) open,
) async {
  await tester.binding.setSurfaceSize(const Size(900, 1000));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(
    AppScope(
      services: s,
      child: MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () => open(context),
              child: const Text('abrir'),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('abrir'));
  await tester.pumpAndSettle();
}

Future<void> _tapSalvar(WidgetTester tester) async {
  await tester.tap(find.widgetWithText(FilledButton, 'Salvar'));
  await tester.pumpAndSettle();
}

/// Escolhe um dia no date picker aberto a partir do campo de data que mostra [current].
Future<void> _pickDay(WidgetTester tester, String current, String day) async {
  await tester.tap(find.text(current));
  await tester.pumpAndSettle();
  await tester.tap(
    find.descendant(
      of: find.byType(DatePickerDialog),
      matching: find.text(day),
    ),
  );
  await tester.tap(find.text('OK'));
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

void main() {
  testWidgets('form: nome e valor vazios mostram erro e nada é gravado', (
    tester,
  ) async {
    final s = await _setup(tester);
    await _pump(tester, s, (c) => showAssetForm(c));
    await _tapSalvar(tester);
    expect(find.text('Informe o nome'), findsOneWidget);
    expect(find.text('Informe o valor'), findsOneWidget);
    expect(s.assets.all, isEmpty);
  });

  testWidgets(
    'form: criar grava 1 snapshot na data padrão, devolve o ativo e não cria transação',
    (tester) async {
      final s = await _setup(tester);
      Asset? saved;
      await _pump(tester, s, (c) async {
        saved = await showAssetForm(c);
      });
      await tester.enterText(find.byType(TextFormField).at(0), 'Carro X');
      await tester.tap(find.byKey(const Key('asset-kind')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Veículo'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextFormField).at(1), '40.000,00');
      await _tapSalvar(tester);

      expect(saved?.kind, AssetKind.vehicle);
      final stored = s.assets.byId(saved!.id)!;
      expect(stored.name, 'Carro X');
      expect(stored.snapshots, hasLength(1));
      expect(stored.currentValueCents, 4000000);
      expect(stored.latest!.date, DateTime(2026, 11, 15));
      expect(s.transactions.all, isEmpty);
    },
  );

  testWidgets('form: data no futuro bloqueia o salvar', (tester) async {
    final s = await _setup(tester);
    await _pump(tester, s, (c) => showAssetForm(c));
    await _pickDay(tester, '15/11/2026', '16');
    await tester.enterText(find.byType(TextFormField).at(0), 'Carro X');
    await tester.enterText(find.byType(TextFormField).at(1), '1000');
    await _tapSalvar(tester);
    expect(find.text('A data não pode ser no futuro'), findsOneWidget);
    expect(s.assets.all, isEmpty);
  });

  testWidgets('form: edição muda só nome e tipo, sem campos de valor e data', (
    tester,
  ) async {
    final s = await _setup(tester, assets: [_carro]);
    Asset? saved;
    await _pump(tester, s, (c) async {
      saved = await showAssetForm(c, initial: _carro);
    });
    expect(find.text('Valor atual'), findsNothing);
    expect(find.text('Data do valor'), findsNothing);
    await tester.enterText(find.byType(TextFormField).at(0), 'Carro Novo');
    await _tapSalvar(tester);

    expect(saved?.name, 'Carro Novo');
    final stored = s.assets.byId('carro')!;
    expect(stored.name, 'Carro Novo');
    expect(stored.kind, AssetKind.vehicle);
    expect(stored.snapshots, _carro.snapshots);
  });

  testWidgets('form: ativo excluído com o diálogo aberto não é regravado', (
    tester,
  ) async {
    final s = await _setup(tester, assets: [_carro]);
    await _pump(tester, s, (c) => showAssetForm(c, initial: _carro));
    await tester.runAsync(() => s.assets.delete('carro'));
    await tester.enterText(find.byType(TextFormField).at(0), 'Carro Novo');
    await _tapSalvar(tester);
    expect(find.text('Este ativo foi excluído.'), findsOneWidget);
    expect(s.assets.byId('carro'), isNull);
  });

  testWidgets(
    'valor: título, apoio com o valor atual e salvar grava snapshot sem transação',
    (tester) async {
      final s = await _setup(tester, assets: [_carro]);
      await _pump(tester, s, (c) => showAssetValueDialog(c, _carro));
      expect(find.text('Atualizar valor · Carro'), findsOneWidget);
      expect(
        find.text('Valor atual: R\$ 38.000,00 em 01/11/2026'),
        findsOneWidget,
      );
      await tester.enterText(find.byType(TextFormField).at(0), '38.000,00');
      await _tapSalvar(tester);

      expect(find.text('Atualizar valor · Carro'), findsNothing);
      final stored = s.assets.byId('carro')!;
      expect(stored.snapshots, hasLength(3));
      expect(stored.currentValueCents, 3800000);
      expect(stored.latest!.date, DateTime(2026, 11, 15));
      expect(s.transactions.all, isEmpty);
    },
  );

  testWidgets('valor: data no futuro mostra erro em danger e nada é gravado', (
    tester,
  ) async {
    final s = await _setup(tester, assets: [_carro]);
    await _pump(tester, s, (c) => showAssetValueDialog(c, _carro));
    await _pickDay(tester, '15/11/2026', '16');
    await tester.enterText(find.byType(TextFormField).at(0), '1000');
    await _tapSalvar(tester);

    final error = find.text('A data não pode ser no futuro');
    expect(error, findsOneWidget);
    expect(tester.widget<Text>(error).style?.color, _light.danger);
    expect(s.assets.byId('carro')!.snapshots, hasLength(2));
  });

  testWidgets('valor > 0 em ativo encerrado reativa o ativo e avisa', (
    tester,
  ) async {
    final encerrado = Asset(
      id: 'moto',
      name: 'Moto',
      kind: AssetKind.vehicle,
      archived: true,
      snapshots: [
        AssetSnapshot(
          id: 'm1',
          date: DateTime(2026, 10, 1),
          valueCents: 0,
          note: 'Encerrado',
        ),
      ],
    );
    final s = await _setup(tester, assets: [encerrado]);
    await _pump(tester, s, (c) => showAssetValueDialog(c, encerrado));
    await tester.enterText(find.byType(TextFormField).at(0), '5.000,00');
    await _tapSalvar(tester);

    expect(find.text('Ativo reativado.'), findsOneWidget);
    final stored = s.assets.byId('moto')!;
    expect(stored.archived, isFalse);
    expect(stored.currentValueCents, 500000);
  });

  testWidgets(
    'valor: data de snapshot existente mostra "Substitui" e mantém a quantidade',
    (tester) async {
      final s = await _setup(tester, assets: [_carro]);
      await _pump(tester, s, (c) => showAssetValueDialog(c, _carro));
      await _pickDay(tester, '15/11/2026', '1');
      expect(find.text('Substitui o valor de 01/11/2026'), findsOneWidget);
      await tester.enterText(find.byType(TextFormField).at(0), '35.000,00');
      await _tapSalvar(tester);

      final stored = s.assets.byId('carro')!;
      expect(stored.snapshots, hasLength(2));
      expect(stored.currentValueCents, 3500000);
    },
  );

  testWidgets('histórico: do mais recente ao mais antigo, com a variação', (
    tester,
  ) async {
    final s = await _setup(tester, assets: [_carro]);
    await _pump(tester, s, (c) => showAssetHistory(c, _carro));
    expect(find.text('Histórico · Carro'), findsOneWidget);
    expect(find.text('-R\$ 2.000,00'), findsOneWidget);
    expect(
      tester.getCenter(find.text('01/11/2026')).dy,
      lessThan(tester.getCenter(find.text('01/08/2026')).dy),
    );
  });

  testWidgets('histórico: excluir com 2 valores sobra 1', (tester) async {
    final s = await _setup(tester, assets: [_carro]);
    await _pump(tester, s, (c) => showAssetHistory(c, _carro));
    await tester.tap(find.byTooltip('Excluir valor').first);
    await tester.pumpAndSettle();
    final stored = s.assets.byId('carro')!;
    expect(stored.snapshots, hasLength(1));
    expect(stored.currentValueCents, 4000000);
  });

  testWidgets('histórico: excluir o único valor mostra SnackBar e nada muda', (
    tester,
  ) async {
    final tesouro = Asset(
      id: 'tesouro',
      name: 'Tesouro',
      kind: AssetKind.investment,
      snapshots: [
        AssetSnapshot(
          id: 't1',
          date: DateTime(2026, 10, 10),
          valueCents: 200000,
        ),
      ],
    );
    final s = await _setup(tester, assets: [tesouro]);
    await _pump(tester, s, (c) => showAssetHistory(c, tesouro));
    await tester.tap(find.byTooltip('Excluir valor'));
    await tester.pumpAndSettle();
    expect(find.text('O ativo precisa de pelo menos um valor'), findsOneWidget);
    expect(s.assets.byId('tesouro')!.snapshots, hasLength(1));
  });
}
