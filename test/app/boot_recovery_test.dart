import 'package:finme/app/app.dart';
import 'package:finme/app/bootstrap.dart';
import 'package:finme/core/models/app_settings.dart';
import 'package:finme/core/services/backup_service.dart';
import 'package:finme/core/services/record_store.dart';
import 'package:finme/core/services/recovery_journal.dart';
import 'package:finme/features/transactions/domain/transaction.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const _aviso =
    'A última importação de backup não terminou. Os dados anteriores foram restaurados.';

Transaction _lancamento(String id) => Transaction(
  id: id,
  type: TransactionType.income,
  amountCents: 20000,
  date: DateTime(2026, 11, 10),
  description: 'Lançamento $id',
);

void main() {
  test(
    'boot com retrato de X sobre estado Y restaura X e limpa o retrato',
    () async {
      // Mesmos stores nos dois boots: o segundo enxerga o estado Y gravado pelo primeiro.
      final stores = <String, MemoryRecordStore>{};
      RecordStore factory(String box) =>
          stores.putIfAbsent(box, () => MemoryRecordStore());
      DateTime clock() => DateTime(2026, 11, 14);

      final first = await bootstrap(storeFactory: factory, clock: clock);
      await first.transactions.upsert(_lancamento('x1'));
      final retrato = BackupService.exportJson(first); // estado X
      await first.transactions.upsert(_lancamento('y1')); // estado Y

      final journal = MemoryRecoveryJournal();
      await journal.write(retrato);
      final s = await bootstrap(
        storeFactory: factory,
        clock: clock,
        journal: journal,
      );

      expect(s.transactions.all.map((t) => t.id), ['x1']);
      expect(s.restoredFromJournal, isTrue);
      expect(await journal.read(), isNull);
    },
  );

  test('sem retrato: restoredFromJournal fica false', () async {
    final s = await bootstrap(
      storeFactory: (_) => MemoryRecordStore(),
      clock: () => DateTime(2026, 11, 14),
    );
    expect(s.restoredFromJournal, isFalse);
  });

  testWidgets(
    'aviso de restauração aparece uma vez e não repete ao trocar de página',
    (tester) async {
      final s = (await tester.runAsync(() async {
        final services = await bootstrap(
          storeFactory: (_) => MemoryRecordStore(),
          clock: () => DateTime(2026, 11, 14),
        );
        await services.settings.update(
          (c) => c.copyWith(mode: AppMode.simple, onboardingDone: true),
        );
        return services;
      }))!;
      s.restoredFromJournal = true;

      tester.view.devicePixelRatio = 1.0;
      tester.view.physicalSize = const Size(1400, 900);
      addTearDown(tester.view.reset);
      await tester.pumpWidget(FinMeApp(services: s));
      await tester.pumpAndSettle();

      expect(find.text(_aviso), findsOneWidget);
      expect(s.restoredFromJournal, isFalse);
      // SnackBar some sozinho (4 s); uma nova exibição após o toque apareceria em seguida.
      await tester.pump(const Duration(seconds: 5));
      await tester.pumpAndSettle();
      expect(find.text(_aviso), findsNothing);

      await tester.tap(find.widgetWithText(InkWell, 'Contas').first);
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text(_aviso), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );
}
