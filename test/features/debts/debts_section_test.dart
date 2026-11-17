import 'package:finme/app/app_scope.dart';
import 'package:finme/app/bootstrap.dart';
import 'package:finme/core/models/app_settings.dart';
import 'package:finme/core/services/record_store.dart';
import 'package:finme/core/theme/app_theme.dart';
import 'package:finme/features/debts/domain/debt.dart';
import 'package:finme/features/debts/presentation/debts_section.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Hoje é 15/11/2026. Fixtures de SPEC §5.25: d1 (Ana, com p1), d2 e d3 (Bruno), d4 (Carla), d6 (Dani, quitada).
Future<AppServices> _setup(
  WidgetTester tester, {
  List<Debt> debts = const [],
  bool ultra = false,
}) async {
  return (await tester.runAsync(() async {
    final s = await bootstrap(
      storeFactory: (_) => MemoryRecordStore(),
      clock: () => DateTime(2026, 11, 15),
    );
    await s.debts.upsertAll(debts);
    if (ultra) {
      await s.settings.update((x) => x.copyWith(mode: AppMode.ultra));
    }
    return s;
  }))!;
}

Future<void> _pump(WidgetTester tester, AppServices s) async {
  await tester.binding.setSurfaceSize(const Size(1200, 1000));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(
    AppScope(
      services: s,
      child: MaterialApp(
        theme: AppTheme.light(),
        home: const Scaffold(
          body: SingleChildScrollView(child: DebtsSection()),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

final _d1 = Debt(
  id: 'd1',
  person: 'Ana',
  direction: DebtDirection.owedToMe,
  amountCents: 50000,
  date: DateTime(2026, 10, 1),
  description: 'Show',
  dueDate: DateTime(2026, 11, 30),
  payments: [
    DebtPayment(
      id: 'p1',
      date: DateTime(2026, 11, 10),
      amountCents: 20000,
      transactionId: 't1',
    ),
  ],
);

final _d2 = Debt(
  id: 'd2',
  person: 'Bruno',
  direction: DebtDirection.iOwe,
  amountCents: 80000,
  date: DateTime(2026, 9, 20),
  dueDate: DateTime(2026, 12, 1),
);

final _d3 = Debt(
  id: 'd3',
  person: 'Bruno',
  direction: DebtDirection.iOwe,
  amountCents: 10000,
  date: DateTime(2026, 11, 1),
  dueDate: DateTime(2026, 11, 10),
);

final _d4 = Debt(
  id: 'd4',
  person: 'Carla',
  direction: DebtDirection.iOwe,
  amountCents: 5000,
  date: DateTime(2026, 10, 5),
);

final _d6 = Debt(
  id: 'd6',
  person: 'Dani',
  direction: DebtDirection.iOwe,
  amountCents: 7000,
  date: DateTime(2026, 8, 1),
  dueDate: DateTime(2026, 12, 1),
  payments: [
    DebtPayment(id: 'p6', date: DateTime(2026, 10, 1), amountCents: 7000),
  ],
);

final _all = [_d1, _d2, _d3, _d4, _d6];

Finder _in(String key, String text) =>
    find.descendant(of: find.byKey(Key(key)), matching: find.text(text));

void main() {
  testWidgets('totais: me devem R\$ 300,00 e devo R\$ 950,00', (tester) async {
    final s = await _setup(tester, debts: _all);
    await _pump(tester, s);

    expect(_in('debt-totals', 'R\$ 300,00'), findsOneWidget);
    expect(_in('debt-totals', 'R\$ 950,00'), findsOneWidget);
  });

  testWidgets('Simples: 4 em aberto, vencida e sem vencimento por último', (
    tester,
  ) async {
    final s = await _setup(tester, debts: _all);
    await _pump(tester, s);

    expect(find.byKey(const Key('debt-d6')), findsNothing);
    expect(find.text('Quitar'), findsNWidgets(4));
    expect(_in('debt-d3', 'Vencida'), findsOneWidget);
    expect(find.byKey(const Key('debt-filter-direction')), findsNothing);
    expect(find.text('Por pessoa'), findsNothing);
    expect(find.byKey(const Key('debt-menu-d1')), findsNothing);

    final y = {
      for (final id in ['d1', 'd2', 'd3', 'd4'])
        id: tester.getTopLeft(find.byKey(Key('debt-$id'))).dy,
    };
    expect(y['d3']! < y['d1']!, isTrue);
    expect(y['d1']! < y['d2']!, isTrue);
    expect(y['d2']! < y['d4']!, isTrue);
  });

  testWidgets('Ultra: Por pessoa ordenado e toque filtra por pessoa', (
    tester,
  ) async {
    final s = await _setup(tester, debts: _all, ultra: true);
    await _pump(tester, s);

    expect(_in('debt-person-0', 'Bruno'), findsOneWidget);
    expect(_in('debt-person-1', 'Ana'), findsOneWidget);
    expect(_in('debt-person-2', 'Carla'), findsOneWidget);

    await tester.tap(find.byKey(const Key('debt-person-0')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('debt-d2')), findsOneWidget);
    expect(find.byKey(const Key('debt-d3')), findsOneWidget);
    expect(find.byKey(const Key('debt-d1')), findsNothing);

    await tester.tap(find.byKey(const Key('debt-person-0')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('debt-d1')), findsOneWidget);
  });

  testWidgets('Ultra: filtro Me devem mostra só d1', (tester) async {
    final s = await _setup(tester, debts: _all, ultra: true);
    await _pump(tester, s);

    await tester.tap(_in('debt-filter-direction', 'Me devem'));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('debt-d1')), findsOneWidget);
    expect(find.byKey(const Key('debt-d2')), findsNothing);
    expect(find.byKey(const Key('debt-d4')), findsNothing);
  });

  testWidgets('Ultra: Mostrar quitadas inclui Dani sem Quitar', (tester) async {
    final s = await _setup(tester, debts: _all, ultra: true);
    await _pump(tester, s);

    await tester.tap(find.byKey(const Key('debt-show-settled')));
    await tester.pumpAndSettle();

    expect(_in('debt-d6', 'Quitada'), findsOneWidget);
    expect(_in('debt-d6', 'Quitar'), findsNothing);
  });

  testWidgets('quitar abre o diálogo Pagar a Bruno', (tester) async {
    final s = await _setup(tester, debts: _all);
    await _pump(tester, s);

    await tester.tap(find.byKey(const Key('debt-settle-d2')));
    await tester.pumpAndSettle();

    expect(find.text('Pagar a Bruno'), findsOneWidget);
  });

  testWidgets('excluir dívida com pagamento mostra aviso e nada muda', (
    tester,
  ) async {
    final s = await _setup(tester, debts: _all, ultra: true);
    await _pump(tester, s);

    await tester.tap(find.byKey(const Key('debt-menu-d1')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Excluir'));
    await tester.pumpAndSettle();

    expect(find.text('Desfaça os pagamentos antes de excluir'), findsOneWidget);
    expect(s.debts.byId('d1'), isNotNull);
  });

  testWidgets('excluir dívida sem pagamento confirmada remove do repositório', (
    tester,
  ) async {
    final s = await _setup(tester, debts: _all, ultra: true);
    await _pump(tester, s);

    await tester.tap(find.byKey(const Key('debt-menu-d4')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Excluir'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Excluir'));
    await tester.pumpAndSettle();

    expect(s.debts.byId('d4'), isNull);
    expect(find.byKey(const Key('debt-d4')), findsNothing);
  });

  testWidgets('sem dívidas mostra estado vazio com Nova dívida', (
    tester,
  ) async {
    final s = await _setup(tester);
    await _pump(tester, s);

    expect(find.textContaining('Nada pendente'), findsOneWidget);
    expect(find.text('Nova dívida'), findsNWidgets(2));
  });
}
