import 'package:finme/app/app_scope.dart';
import 'package:finme/app/bootstrap.dart';
import 'package:finme/app/seed.dart';
import 'package:finme/core/models/app_settings.dart';
import 'package:finme/core/services/record_store.dart';
import 'package:finme/core/services/recovery_journal.dart';
import 'package:finme/core/theme/app_theme.dart';
import 'package:finme/features/debts/domain/debt.dart';
import 'package:finme/features/importing/domain/import_batch.dart';
import 'package:finme/features/settings/presentation/settings_page.dart';
import 'package:finme/features/transactions/domain/transaction.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Future<AppServices> _boot() => bootstrap(
  storeFactory: (_) => MemoryRecordStore(),
  clock: () => DateTime(2026, 11, 14),
);

Future<void> _settle() => Future<void>.delayed(Duration.zero);

void main() {
  test('bootstrap em memória expõe os serviços da fase 13', () async {
    final s = await _boot();
    expect(s.importBatches.all, isEmpty);
    expect(s.uiState, isNotNull);
    expect(s.journal, isA<MemoryRecoveryJournal>());
    expect(s.restoredFromJournal, isFalse);
  });

  test(
    'excluir a transação de uma quitação ajusta a dívida (sync ligado)',
    () async {
      final s = await _boot();
      await s.transactions.upsert(
        Transaction(
          id: 't1',
          type: TransactionType.income,
          amountCents: 20000,
          date: DateTime(2026, 11, 10),
          description: 'Recebido de Ana',
          accountId: 'A',
        ),
      );
      await s.debts.upsert(
        Debt(
          id: 'd1',
          person: 'Ana',
          direction: DebtDirection.owedToMe,
          amountCents: 50000,
          date: DateTime(2026, 11, 1),
          payments: [
            DebtPayment(
              id: 'p1',
              date: DateTime(2026, 11, 10),
              amountCents: 20000,
              transactionId: 't1',
            ),
          ],
        ),
      );
      expect(s.debts.byId('d1')!.remainingCents, 30000);
      await s.transactions.delete('t1');
      await _settle();
      expect(s.debts.byId('d1')!.payments, isEmpty);
      expect(s.debts.byId('d1')!.remainingCents, 50000);
    },
  );

  testWidgets('apagar todos os dados zera lotes de importação e dívidas', (
    tester,
  ) async {
    final s = (await tester.runAsync(() async {
      final services = await _boot();
      await seedDemo(services);
      await services.settings.update((c) => c.copyWith(mode: AppMode.ultra));
      await services.importBatches.upsert(
        ImportBatch(
          id: 'b1',
          createdAt: DateTime(2026, 11, 10, 9),
          label: 'extrato.csv',
        ),
      );
      await services.debts.upsert(
        Debt(
          id: 'd1',
          person: 'Ana',
          direction: DebtDirection.owedToMe,
          amountCents: 50000,
          date: DateTime(2026, 11, 1),
        ),
      );
      return services;
    }))!;
    expect(s.importBatches.all, isNotEmpty);

    await tester.binding.setSurfaceSize(const Size(1400, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      AppScope(
        services: s,
        child: MaterialApp(
          theme: AppTheme.light(),
          home: const Scaffold(body: SettingsPage()),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('Apagar todos os dados'));
    await tester.tap(find.text('Apagar todos os dados'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Apagar'));
    await tester.pumpAndSettle();

    expect(s.importBatches.all, isEmpty);
    expect(s.debts.all, isEmpty);
    expect(tester.takeException(), isNull);
  });
}
