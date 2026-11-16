import 'package:finme/app/app_scope.dart';
import 'package:finme/app/bootstrap.dart';
import 'package:finme/app/seed.dart';
import 'package:finme/core/models/app_settings.dart';
import 'package:finme/core/services/record_store.dart';
import 'package:finme/core/theme/app_theme.dart';
import 'package:finme/core/utils/formatters.dart';
import 'package:finme/features/transactions/domain/installments.dart';
import 'package:finme/features/transactions/domain/transaction.dart';
import 'package:finme/features/transactions/presentation/transaction_form.dart';
import 'package:finme/features/transactions/presentation/transaction_row.dart';
import 'package:finme/features/transactions/presentation/transactions_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Future<AppServices> _boot(WidgetTester tester) async {
  return (await tester.runAsync(() async {
    final s = await bootstrap(
      storeFactory: (_) => MemoryRecordStore(),
      clock: () => DateTime(2026, 11, 14),
    );
    await seedDemo(s);
    await materializeRecurring(s);
    return s;
  }))!;
}

Future<void> _openForm(
  WidgetTester tester,
  AppServices s, {
  required Transaction initial,
}) async {
  await tester.binding.setSurfaceSize(const Size(1400, 1000));
  await tester.pumpWidget(
    AppScope(
      services: s,
      child: MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(
          body: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () => showTransactionForm(context, initial: initial),
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

Future<void> _pumpPage(
  WidgetTester tester,
  AppServices s, {
  required AppMode mode,
}) async {
  await tester.runAsync(() => s.settings.update((x) => x.copyWith(mode: mode)));
  await tester.binding.setSurfaceSize(const Size(1400, 900));
  await tester.pumpWidget(
    AppScope(
      services: s,
      child: MaterialApp(
        theme: AppTheme.light(),
        home: const Scaffold(body: TransactionsPage()),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

/// Botão "Ações" da linha que contém [description].
Finder _menuOf(String description) => find.descendant(
  of: find
      .ancestor(
        of: find.textContaining(description),
        matching: find.byType(TransactionRow),
      )
      .first,
  matching: find.byTooltip('Ações'),
);

void main() {
  testWidgets('editar transação comum preserva notes e recurringId', (
    tester,
  ) async {
    final s = await _boot(tester);
    final t = Transaction(
      id: 'tx_comum',
      type: TransactionType.expense,
      amountCents: 5000,
      date: DateTime(2026, 11, 10),
      description: 'Mercado',
      accountId: 'acc_alfa',
      notes: 'nota original',
      recurringId: 'rec_teste',
    );
    await tester.runAsync(() => s.transactions.upsert(t));
    await _openForm(tester, s, initial: t);

    await tester.enterText(
      find.widgetWithText(TextFormField, 'Valor'),
      '77,00',
    );
    await tester.tap(find.text('Salvar'));
    await tester.pumpAndSettle();

    final saved = s.transactions.byId('tx_comum')!;
    expect(saved.amountCents, 7700);
    expect(saved.notes, 'nota original');
    expect(saved.recurringId, 'rec_teste');
    expect(saved.accountId, 'acc_alfa');
    expect(tester.takeException(), isNull);
  });

  testWidgets('editar parcela preserva installment* e não permite mudar data', (
    tester,
  ) async {
    final s = await _boot(tester);
    final base = Transaction(
      id: 'base_loja',
      type: TransactionType.expense,
      amountCents: 6000,
      date: DateTime(2026, 11, 14),
      description: 'Parcelado loja',
      cardId: 'card_alfa_visa',
    );
    final parcels = buildInstallments(
      base: base,
      count: 3,
      groupId: 'grp_loja',
    );
    await tester.runAsync(() => s.transactions.upsertAll(parcels));
    final second = parcels[1];
    await _openForm(tester, s, initial: second);

    expect(
      find.text('Parcela 2/3 — data e cartão seguem a compra original.'),
      findsOneWidget,
    );
    await tester.tap(find.text(formatDate(second.date)), warnIfMissed: false);
    await tester.pumpAndSettle();
    expect(find.byType(DatePickerDialog), findsNothing);

    await tester.enterText(
      find.widgetWithText(TextFormField, 'Valor'),
      '25,00',
    );
    await tester.tap(find.text('Salvar'));
    await tester.pumpAndSettle();

    final saved = s.transactions.byId(second.id)!;
    expect(saved.amountCents, 2500);
    expect(saved.date, DateTime(2026, 12, 14));
    expect(saved.installmentGroupId, 'grp_loja');
    expect(saved.installmentIndex, 2);
    expect(saved.installmentCount, 3);
    expect(saved.cardId, 'card_alfa_visa');
  });

  testWidgets('editar transferência mantém toAccountId', (tester) async {
    final s = await _boot(tester);
    final t = Transaction(
      id: 'tx_transf',
      type: TransactionType.transfer,
      amountCents: 10000,
      date: DateTime(2026, 11, 10),
      description: 'Transferência',
      accountId: 'acc_alfa',
      toAccountId: 'acc_beta',
    );
    await tester.runAsync(() => s.transactions.upsert(t));
    await _openForm(tester, s, initial: t);

    await tester.enterText(
      find.widgetWithText(TextFormField, 'Valor'),
      '150,00',
    );
    await tester.tap(find.text('Salvar'));
    await tester.pumpAndSettle();

    final saved = s.transactions.byId('tx_transf')!;
    expect(saved.amountCents, 15000);
    expect(saved.type, TransactionType.transfer);
    expect(saved.accountId, 'acc_alfa');
    expect(saved.toAccountId, 'acc_beta');
  });

  testWidgets('confirmar provisionado vira paid com a data escolhida', (
    tester,
  ) async {
    final s = await _boot(tester);
    await tester.runAsync(
      () => s.transactions.upsert(
        Transaction(
          id: 'tx_plan',
          type: TransactionType.expense,
          amountCents: 4000,
          date: DateTime(2026, 11, 20),
          description: 'Conta prevista',
          accountId: 'acc_alfa',
          status: TransactionStatus.planned,
        ),
      ),
    );
    await _pumpPage(tester, s, mode: AppMode.ultra);

    await tester.tap(_menuOf('Conta prevista'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Confirmar'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Confirmar'));
    await tester.pumpAndSettle();

    final saved = s.transactions.byId('tx_plan')!;
    expect(saved.status, TransactionStatus.paid);
    expect(saved.date, DateTime(2026, 11, 14));
  });

  testWidgets('excluir "Todas as parcelas" remove o grupo inteiro', (
    tester,
  ) async {
    final s = await _boot(tester);
    final parcels = buildInstallments(
      base: Transaction(
        id: 'base_del',
        type: TransactionType.expense,
        amountCents: 3000,
        date: DateTime(2026, 11, 30),
        description: 'Parcelado excluir',
        cardId: 'card_alfa_visa',
      ),
      count: 3,
      groupId: 'grp_del',
    );
    await tester.runAsync(() => s.transactions.upsertAll(parcels));
    await _pumpPage(tester, s, mode: AppMode.simple);

    await tester.tap(_menuOf('Parcelado excluir'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Excluir'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Todas as parcelas'));
    await tester.pumpAndSettle();

    expect(
      s.transactions.all.where((t) => t.installmentGroupId == 'grp_del'),
      isEmpty,
    );
  });

  testWidgets(
    'duplicar cria registro independente, sem vínculo de recorrência',
    (tester) async {
      final s = await _boot(tester);
      await tester.runAsync(
        () => s.transactions.upsert(
          Transaction(
            id: 'tx_dup',
            type: TransactionType.expense,
            amountCents: 3000,
            date: DateTime(2026, 11, 10),
            description: 'Lanche duplicado',
            accountId: 'acc_alfa',
            notes: 'nota',
            recurringId: 'rec_x',
            externalId: 'ext-dup',
          ),
        ),
      );
      await _pumpPage(tester, s, mode: AppMode.simple);

      await tester.tap(_menuOf('Lanche duplicado'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Duplicar'));
      await tester.pumpAndSettle();

      final copies = s.transactions.all
          .where((t) => t.description == 'Lanche duplicado')
          .toList();
      expect(copies, hasLength(2));
      final copy = copies.firstWhere((t) => t.id != 'tx_dup');
      expect(copy.recurringId, isNull);
      expect(copy.installmentGroupId, isNull);
      expect(copy.externalId, isNull);
      expect(copy.notes, 'nota');
      expect(copy.amountCents, 3000);
      expect(copy.date, DateTime(2026, 11, 10));
      expect(s.transactions.byId('tx_dup')!.recurringId, 'rec_x');
      expect(s.transactions.byId('tx_dup')!.externalId, 'ext-dup');
    },
  );
}
