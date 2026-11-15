import 'dart:convert';

import 'package:finme/app/app_scope.dart';
import 'package:finme/app/bootstrap.dart';
import 'package:finme/app/seed.dart';
import 'package:finme/core/models/year_month.dart';
import 'package:finme/core/services/backup_service.dart';
import 'package:finme/core/services/record_store.dart';
import 'package:finme/core/utils/date_utils.dart';
import 'package:finme/features/transactions/domain/transaction.dart';
import 'package:flutter_test/flutter_test.dart';

DateTime _now() => DateTime(2026, 11, 14);

Future<AppServices> _bootstrap({bool demo = true}) async {
  final s = await bootstrap(
    storeFactory: (_) => MemoryRecordStore(),
    clock: _now,
  );
  if (demo) {
    await seedDemo(s);
    await materializeRecurring(s);
  }
  return s;
}

void main() {
  test('round-trip export→import preserva contagens e transações', () async {
    final src = await _bootstrap();
    final dst = await _bootstrap(demo: false);
    final json = BackupService.exportJson(src);

    await BackupService.importJson(dst, json);

    expect(dst.accounts.all.length, src.accounts.all.length);
    expect(dst.cards.all.length, src.cards.all.length);
    expect(dst.categories.all.length, src.categories.all.length);
    expect(dst.transactions.all.length, src.transactions.all.length);
    expect(dst.recurring.all.length, src.recurring.all.length);
    final tx = src.transactions.all.firstWhere(
      (t) => t.description == 'Passagem aérea',
    );
    expect(dst.transactions.byId(tx.id), tx);
    expect(dst.settings.value.onboardingDone, isTrue);
  });

  test('JSON inválido ou versão errada lança e não altera dados', () async {
    final s = await _bootstrap();
    final before = s.transactions.all.length;

    await expectLater(
      BackupService.importJson(s, 'não é json'),
      throwsFormatException,
    );
    await expectLater(
      BackupService.importJson(s, '{"app":"finme","version":2}'),
      throwsFormatException,
    );
    expect(s.transactions.all.length, before);
  });

  test('registro com campo inválido não grava nada (tudo-ou-nada)', () async {
    final src = await _bootstrap();
    final dst = await _bootstrap();
    final before = dst.transactions.all.length;
    final map =
        jsonDecode(BackupService.exportJson(src)) as Map<String, dynamic>;
    (map['transactions'] as List).add({'id': 'x', 'amountCents': 'nao-numero'});

    await expectLater(
      BackupService.importJson(dst, jsonEncode(map)),
      throwsFormatException,
    );
    expect(dst.transactions.all.length, before);
    expect(dst.accounts.all.length, src.accounts.all.length);
  });

  test('CSV tem cabeçalho e uma linha por lançamento', () async {
    final s = await _bootstrap();
    final lines = BackupService.transactionsCsv(s).split('\r\n');

    expect(lines.length, s.transactions.all.length + 1);
    expect(lines.first, startsWith('Data;Descrição;Tipo;Status;Valor;'));
  });

  test('CSV filtrado por mês contém só lançamentos do mês', () async {
    final s = await _bootstrap();
    const month = YearMonth(2026, 11);
    final expected = s.transactions.all.where((t) => month.contains(t.date));
    final lines = BackupService.transactionsCsv(s, month: month).split('\r\n');

    expect(lines.length, expected.length + 1);
    // Saída com sinal "-" e vírgula decimal, sem "R$".
    final market = lines.firstWhere((l) => l.contains('Supermercado Central'));
    expect(market, contains(';-387,50;'));
  });

  test(
    'CSV: transferência fora do total com destino; fórmula escapada',
    () async {
      final s = await _bootstrap();
      await s.transactions.upsert(
        Transaction(
          id: 'formula',
          type: TransactionType.expense,
          amountCents: 500,
          date: DateTime(2026, 11, 10),
          description: '=HYPERLINK("x")',
          accountId: 'acc_alfa',
        ),
      );
      final csv = BackupService.transactionsCsv(s);
      final transfer = csv
          .split('\r\n')
          .firstWhere((l) => l.contains('Reserva de emergência'));

      expect(transfer, contains(';Conta corrente;não;'));
      expect(csv, contains("'=HYPERLINK"));
    },
  );

  test('CSV: crédito fora do total; débito dentro do total', () async {
    final s = await _bootstrap();
    await s.transactions.upsert(
      Transaction(
        id: 'compra_credito',
        type: TransactionType.expense,
        amountCents: 500,
        date: DateTime(2026, 11, 10),
        description: 'Compra no crédito',
        cardId: 'card_alfa_visa',
      ),
    );
    await s.transactions.upsert(
      Transaction(
        id: 'compra_debito',
        type: TransactionType.expense,
        amountCents: 500,
        date: DateTime(2026, 11, 10),
        description: 'Compra no débito',
        cardId: 'card_alfa_debito',
      ),
    );
    final lines = BackupService.transactionsCsv(s).split('\r\n');

    expect(
      lines.firstWhere((l) => l.contains('Compra no crédito')),
      contains(';não;'),
    );
    expect(
      lines.firstWhere((l) => l.contains('Compra no débito')),
      contains(';sim;'),
    );
  });

  test(
    'import: categoria órfã vira null, lançamento órfão é descartado',
    () async {
      final src = await _bootstrap();
      final dst = await _bootstrap(demo: false);
      final map =
          jsonDecode(BackupService.exportJson(src)) as Map<String, dynamic>;
      final txs = (map['transactions'] as List).cast<Map<String, dynamic>>();
      final sample = txs.firstWhere((t) => t['categoryId'] == 'cat_mercado');
      final sampleId = sample['id'] as String;
      txs.add({...sample, 'id': 'orfa', 'cardId': 'card_fantasma'});
      sample['categoryId'] = 'cat_fantasma';
      // Força a materialização no import: sem materializedUntil ela recomeça do início.
      for (final r in map['recurring'] as List) {
        (r as Map<String, dynamic>)['materializedUntil'] = null;
      }

      await BackupService.importJson(dst, jsonEncode(map));

      expect(dst.transactions.byId('orfa'), isNull);
      expect(dst.transactions.byId(sampleId)!.categoryId, isNull);
      expect(
        isSameDay(
          dst.recurring.byId('rec_salario')!.materializedUntil!,
          DateTime(2026, 11, 13),
        ),
        isTrue,
      );
    },
  );
}
