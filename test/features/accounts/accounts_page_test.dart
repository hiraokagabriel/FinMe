import 'package:finme/app/app_scope.dart';
import 'package:finme/app/bootstrap.dart';
import 'package:finme/app/seed.dart';
import 'package:finme/core/models/app_settings.dart';
import 'package:finme/core/services/record_store.dart';
import 'package:finme/core/theme/app_theme.dart';
import 'package:finme/core/utils/formatters.dart';
import 'package:finme/features/accounts/presentation/accounts_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Future<AppServices> _boot(WidgetTester tester, AppMode mode) async {
  final s = (await tester.runAsync(() async {
    final s = await bootstrap(
      storeFactory: (_) => MemoryRecordStore(),
      clock: () => DateTime(2026, 11, 14),
    );
    await seedDemo(s);
    await materializeRecurring(s);
    return s;
  }))!;
  if (mode == AppMode.ultra) {
    await tester.runAsync(
      () => s.settings.update((x) => x.copyWith(mode: AppMode.ultra)),
    );
  }
  return s;
}

Future<void> _pump(WidgetTester tester, AppServices s, Size size) async {
  // MediaQuery lê tester.view; setSurfaceSize não atualiza essa fonte.
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = size;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  // Desmonta antes: o mesmo `const AccountsPage()` não seria reconstruído com novos serviços.
  await tester.pumpWidget(const SizedBox());
  await tester.pumpWidget(
    AppScope(
      services: s,
      child: MaterialApp(
        theme: AppTheme.light(),
        home: const Scaffold(body: AccountsPage()),
      ),
    ),
  );
}

void main() {
  testWidgets('modo Simples: cabeçalho, bancos agrupados e saldo total', (
    tester,
  ) async {
    final s = await _boot(tester, AppMode.simple);
    await _pump(tester, s, const Size(1400, 900));

    expect(find.text('Contas'), findsOneWidget);
    expect(find.text('Transferir'), findsOneWidget);
    expect(find.text('Nova conta'), findsOneWidget);
    expect(find.text('Banco Alfa'), findsOneWidget);
    expect(find.text('Banco Beta'), findsOneWidget);
    expect(find.text('Sem banco'), findsOneWidget);
    expect(find.text('Carteira'), findsOneWidget);
    // Nome das contas correntes e rótulo do tipo têm o mesmo texto.
    expect(find.text('Conta corrente'), findsWidgets);

    final total = s.ledger.accountBalances.values.fold<int>(0, (a, b) => a + b);
    expect(find.text(formatMoney(total)), findsWidgets);

    expect(find.text('Previsto fim do mês'), findsNothing);
    expect(find.text('Mostrar arquivadas'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('modo Ultra: previsto do fim do mês e toggle de arquivadas', (
    tester,
  ) async {
    final s = await _boot(tester, AppMode.ultra);
    await _pump(tester, s, const Size(1400, 900));

    expect(find.text('Previsto fim do mês'), findsWidgets);
    expect(find.text('Mostrar arquivadas'), findsOneWidget);
    expect(find.text('Banco Alfa'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('390px sem overflow nos dois modos', (tester) async {
    final simple = await _boot(tester, AppMode.simple);
    await _pump(tester, simple, const Size(390, 800));
    expect(find.text('Banco Alfa'), findsOneWidget);
    expect(tester.takeException(), isNull);

    final ultra = await _boot(tester, AppMode.ultra);
    await _pump(tester, ultra, const Size(390, 800));
    expect(find.textContaining('Previsto fim do mês'), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Transferir desabilitado com menos de duas contas ativas', (
    tester,
  ) async {
    final s = await _boot(tester, AppMode.simple);
    final accounts = s.accounts.all.toList();
    await tester.runAsync(() async {
      for (final a in accounts.take(2)) {
        await s.accounts.upsert(a.copyWith(archived: true));
      }
    });
    await _pump(tester, s, const Size(1400, 900));

    final button = tester.widget<OutlinedButton>(
      find.widgetWithText(OutlinedButton, 'Transferir'),
    );
    expect(button.onPressed, isNull);
  });

  testWidgets('botões abrem formulário de conta e transferência', (
    tester,
  ) async {
    final s = await _boot(tester, AppMode.simple);
    await _pump(tester, s, const Size(1400, 900));

    await tester.tap(find.text('Nova conta'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Saldo inicial'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.tapAt(const Offset(5, 5));
    await tester.pump(const Duration(milliseconds: 300));

    await tester.tap(find.text('Transferir'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Provisionar (ainda não feita)'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
