import 'dart:convert';

import 'package:finme/app/app_scope.dart';
import 'package:finme/app/bootstrap.dart';
import 'package:finme/app/seed.dart';
import 'package:finme/core/models/app_settings.dart';
import 'package:finme/core/models/year_month.dart';
import 'package:finme/core/services/backup_service.dart';
import 'package:finme/core/services/record_store.dart';
import 'package:finme/core/services/recovery_journal.dart';
import 'package:finme/core/utils/date_utils.dart';
import 'package:finme/features/debts/domain/debt.dart';
import 'package:finme/features/goals/domain/goal.dart';
import 'package:finme/features/importing/domain/import_batch.dart';
import 'package:finme/features/importing/domain/import_profile.dart';
import 'package:finme/features/importing/domain/merchant_dictionary.dart';
import 'package:finme/features/net_worth/domain/asset.dart';
import 'package:finme/features/rules/domain/transaction_rule.dart';
import 'package:finme/features/transactions/domain/transaction.dart';
import 'package:flutter_test/flutter_test.dart';

DateTime _now() => DateTime(2026, 11, 14);

/// Falha uma vez na próxima gravação (put ou putAll), depois volta ao normal.
class _FlakyStore extends MemoryRecordStore {
  bool failNext = false;

  void _check() {
    if (failNext) {
      failNext = false;
      throw StateError('disco cheio');
    }
  }

  @override
  Future<void> put(String id, Map<String, dynamic> data) async {
    _check();
    return super.put(id, data);
  }

  @override
  Future<void> putAll(Map<String, Map<String, dynamic>> entries) async {
    _check();
    return super.putAll(entries);
  }
}

/// Estado comparável de todos os repositórios e das configurações.
List<Object?> _state(AppServices s) => [
  [for (final a in s.accounts.all) a.toMap()],
  [for (final c in s.cards.all) c.toMap()],
  [for (final c in s.categories.all) c.toMap()],
  [for (final t in s.transactions.all) t.toMap()],
  [for (final r in s.recurring.all) r.toMap()],
  s.settings.value.toMap(),
  [for (final r in s.rules.all) r.toMap()],
  [for (final p in s.importProfiles.all) p.toMap()],
  [for (final e in s.dictionary.all) e.toMap()],
  [for (final g in s.goals.all) g.toMap()],
  [for (final a in s.assets.all) a.toMap()],
  [for (final d in s.debts.all) d.toMap()],
];

/// Falha em toda gravação enquanto [broken] for true (o rollback também falha).
class _BrokenStore extends MemoryRecordStore {
  bool broken = false;

  @override
  Future<void> putAll(Map<String, Map<String, dynamic>> entries) async {
    if (broken) {
      throw StateError('disco quebrado');
    }
    return super.putAll(entries);
  }
}

Future<AppServices> _bootstrap({
  bool demo = true,
  Map<String, RecordStore> stores = const {},
  RecoveryJournal? journal,
}) async {
  final s = await bootstrap(
    storeFactory: (box) => stores[box] ?? MemoryRecordStore(),
    clock: _now,
    journal: journal,
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

  test(
    'export→import devolve metas, parentId, tags de lançamento e de regra',
    () async {
      final src = await _bootstrap();
      final dst = await _bootstrap(demo: false);
      final accountId = src.accounts.all.first.id;
      await src.goals.upsert(
        Goal(
          id: 'g1',
          name: 'Viagem',
          accountId: accountId,
          targetCents: 100000,
          targetDate: DateTime(2027, 3, 1),
          movements: [
            GoalMovement(
              id: 'm1',
              date: DateTime(2026, 11, 2),
              amountCents: 30000,
            ),
            GoalMovement(
              id: 'm2',
              date: DateTime(2026, 11, 10),
              amountCents: -5000,
              note: 'Imprevisto',
            ),
          ],
        ),
      );
      await src.categories.upsert(
        src.categories
            .byId('cat_mercado')!
            .copyWith(parentId: 'cat_alimentacao'),
      );
      await src.transactions.upsert(
        Transaction(
          id: 'tagged',
          type: TransactionType.expense,
          amountCents: 1000,
          date: _now(),
          description: 'Com tags',
          accountId: accountId,
          tags: const ['viagem', 'casa'],
        ),
      );
      await src.rules.upsert(
        const TransactionRule(id: 'r_tag', pattern: 'LOJA', tags: ['casa']),
      );

      await BackupService.importJson(dst, BackupService.exportJson(src));

      expect(dst.goals.all, src.goals.all);
      expect(dst.categories.byId('cat_mercado')!.parentId, 'cat_alimentacao');
      expect(dst.transactions.byId('tagged')!.tags, ['viagem', 'casa']);
      expect(dst.rules.byId('r_tag')!.tags, ['casa']);
    },
  );

  test('backup sem goals: metas vazias; meta com conta ausente some', () async {
    final src = await _bootstrap();
    final dst = await _bootstrap(demo: false);
    await dst.goals.upsert(
      Goal(id: 'local', name: 'Local', accountId: 'conta_x', targetCents: 100),
    );
    final map =
        jsonDecode(BackupService.exportJson(src)) as Map<String, dynamic>;
    map.remove('goals');

    await BackupService.importJson(dst, jsonEncode(map));
    expect(dst.goals.all, isEmpty);

    final accountId = src.accounts.all.first.id;
    map['goals'] = [
      Goal(
        id: 'ok',
        name: 'OK',
        accountId: accountId,
        targetCents: 100,
      ).toMap(),
      Goal(
        id: 'orfa',
        name: 'Órfã',
        accountId: 'conta_fantasma',
        targetCents: 100,
      ).toMap(),
    ];
    await BackupService.importJson(dst, jsonEncode(map));
    expect(dst.goals.all.map((g) => g.id), ['ok']);
  });

  test(
    'backup com meta de alvo 0 ou nulo: FormatException e nada gravado',
    () async {
      final src = await _bootstrap();
      final dst = await _bootstrap(demo: false);
      await dst.goals.upsert(
        Goal(
          id: 'local',
          name: 'Local',
          accountId: 'conta_x',
          targetCents: 100,
        ),
      );
      final antes = _state(dst);
      final accountId = src.accounts.all.first.id;
      for (final alvo in [0, null]) {
        final map =
            jsonDecode(BackupService.exportJson(src)) as Map<String, dynamic>;
        map['goals'] = [
          {
            'id': 'ruim',
            'name': 'Ruim',
            'accountId': accountId,
            'targetCents': alvo,
          },
        ];
        await expectLater(
          BackupService.importJson(dst, jsonEncode(map)),
          throwsA(
            isA<FormatException>().having(
              (e) => e.message,
              'message',
              'Backup com meta de alvo inválido',
            ),
          ),
        );
      }
      expect(_state(dst), antes);
      expect(dst.goals.byId('local'), isNotNull);
    },
  );

  test(
    'CSV: cabeçalho termina em Tags; subcategoria como Pai › Filha; tags com vírgula',
    () async {
      final s = await _bootstrap();
      await s.categories.upsert(
        s.categories.byId('cat_mercado')!.copyWith(parentId: 'cat_alimentacao'),
      );
      await s.transactions.upsert(
        Transaction(
          id: 'sub',
          type: TransactionType.expense,
          amountCents: 700,
          date: DateTime(2026, 11, 10),
          description: 'Compra de mercado',
          accountId: s.accounts.all.first.id,
          categoryId: 'cat_mercado',
          tags: const ['a', 'b'],
        ),
      );
      final lines = BackupService.transactionsCsv(s).split('\r\n');

      expect(lines.first, endsWith(';Notas;Tags'));
      final line = lines.firstWhere((l) => l.contains('Compra de mercado'));
      expect(line, contains(';Alimentação › Mercado;'));
      expect(line, endsWith(';a, b'));
    },
  );

  test('import descarta regra e transferência com vínculo órfão', () async {
    final src = await _bootstrap();
    final dst = await _bootstrap(demo: false);
    final map =
        jsonDecode(BackupService.exportJson(src)) as Map<String, dynamic>;
    final rule = (map['recurring'] as List).first as Map<String, dynamic>;
    final accountId = src.accounts.all.first.id;
    final transfer = Transaction(
      id: 'tr_ok',
      type: TransactionType.transfer,
      amountCents: 100,
      date: _now(),
      description: 'Transferência',
      accountId: accountId,
      toAccountId: accountId,
    );
    final orphanTransfer = Transaction(
      id: 'tr_orfa',
      type: TransactionType.transfer,
      amountCents: 100,
      date: _now(),
      description: 'Transferência órfã',
      accountId: accountId,
      toAccountId: 'conta_fantasma',
    );
    map['recurring'] = [
      ...(map['recurring'] as List),
      {
        ...rule,
        'id': 'rec_orfa_conta',
        'accountId': 'conta_fantasma',
        'cardId': null,
      },
      {
        ...rule,
        'id': 'rec_orfa_cartao',
        'accountId': null,
        'cardId': 'cartao_fantasma',
      },
    ];
    map['transactions'] = [
      ...(map['transactions'] as List),
      transfer.toMap(),
      orphanTransfer.toMap(),
    ];

    await BackupService.importJson(dst, jsonEncode(map));

    expect(dst.recurring.byId('rec_orfa_conta'), isNull);
    expect(dst.recurring.byId('rec_orfa_cartao'), isNull);
    expect(dst.transactions.byId('tr_orfa'), isNull);
    expect(dst.transactions.byId('tr_ok'), isNotNull);
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

  test('export→import devolve regras, perfis e dicionário editados', () async {
    final src = await _bootstrap();
    final dst = await _bootstrap(demo: false);
    final accountId = src.accounts.all.first.id;
    await src.rules.upsert(
      const TransactionRule(
        id: 'r1',
        pattern: 'LOJA EXEMPLO',
        categoryId: 'cat_mercado',
        renameTo: 'Mercado Exemplo',
        priority: 2,
      ),
    );
    await src.importProfiles.upsert(
      ImportProfile(
        id: 'p1',
        name: 'Alfa CSV',
        accountId: accountId,
        categoryMap: {'SUPERMERCADO': 'cat_mercado'},
        invertSign: true,
      ),
    );
    await src.dictionary.delete('dict_uber');
    await src.dictionary.upsert(
      const DictionaryEntry(
        id: 'dict_loja',
        pattern: 'LOJA EXEMPLO',
        categoryName: 'Mercado',
      ),
    );

    await BackupService.importJson(dst, BackupService.exportJson(src));

    expect(dst.rules.all, src.rules.all);
    expect(dst.importProfiles.all, src.importProfiles.all);
    expect(dst.dictionary.all, src.dictionary.all);
  });

  test(
    'backup sem regras, perfis e dicionário: vazios e dicionário padrão',
    () async {
      final src = await _bootstrap();
      final dst = await _bootstrap(demo: false);
      await dst.rules.upsert(
        const TransactionRule(id: 'local', pattern: 'LOCAL'),
      );
      await dst.dictionary.delete('dict_uber');
      final map =
          jsonDecode(BackupService.exportJson(src)) as Map<String, dynamic>;
      map
        ..remove('rules')
        ..remove('importProfiles')
        ..remove('dictionary');

      await BackupService.importJson(dst, jsonEncode(map));

      expect(dst.rules.all, isEmpty);
      expect(dst.importProfiles.all, isEmpty);
      expect(dst.dictionary.all, defaultDictionary());
    },
  );

  test(
    'import: perfil com destino ausente some; regra com categoria ausente fica null',
    () async {
      final src = await _bootstrap();
      final dst = await _bootstrap(demo: false);
      final accountId = src.accounts.all.first.id;
      final map =
          jsonDecode(BackupService.exportJson(src)) as Map<String, dynamic>;
      map['rules'] = [
        const TransactionRule(
          id: 'r_ok',
          pattern: 'LOJA',
          categoryId: 'cat_mercado',
        ).toMap(),
        const TransactionRule(
          id: 'r_orfa',
          pattern: 'LOJA',
          categoryId: 'cat_fantasma',
        ).toMap(),
      ];
      map['importProfiles'] = [
        ImportProfile(id: 'p_ok', name: 'OK', accountId: accountId).toMap(),
        const ImportProfile(
          id: 'p_orfa',
          name: 'Órfão',
          accountId: 'conta_fantasma',
        ).toMap(),
        const ImportProfile(id: 'p_sem_destino', name: 'Sem destino').toMap(),
      ];

      await BackupService.importJson(dst, jsonEncode(map));

      expect(dst.importProfiles.all.map((p) => p.id), ['p_ok']);
      expect(dst.rules.byId('r_ok')!.categoryId, 'cat_mercado');
      expect(dst.rules.byId('r_orfa')!.categoryId, isNull);
    },
  );

  test(
    'export→import devolve ativos (snapshots, arquivado) e dívidas (pagamentos com transactionId)',
    () async {
      final src = await _bootstrap();
      final dst = await _bootstrap(demo: false);
      await src.assets.upsert(
        Asset(
          id: 'a1',
          name: 'Carro X',
          kind: AssetKind.vehicle,
          snapshots: [
            AssetSnapshot(
              id: 's1',
              date: DateTime(2026, 10, 1),
              valueCents: 4000000,
            ),
            AssetSnapshot(
              id: 's2',
              date: DateTime(2026, 11, 1),
              valueCents: 3800000,
              note: 'FIPE',
            ),
          ],
          archived: true,
        ),
      );
      await src.debts.upsert(
        Debt(
          id: 'd1',
          person: 'Ana',
          direction: DebtDirection.owedToMe,
          amountCents: 50000,
          date: DateTime(2026, 11, 1),
          description: 'Jantar',
          dueDate: DateTime(2026, 12, 1),
          payments: [
            DebtPayment(
              id: 'p1',
              date: DateTime(2026, 11, 5),
              amountCents: 20000,
              transactionId: 'tx_pagamento',
            ),
            DebtPayment(
              id: 'p2',
              date: DateTime(2026, 11, 10),
              amountCents: 5000,
            ),
          ],
        ),
      );

      await BackupService.importJson(dst, BackupService.exportJson(src));

      expect(dst.assets.all, src.assets.all);
      expect(dst.debts.all, src.debts.all);
    },
  );

  test('backup sem assets/debts: coleções vazias e o resto importa', () async {
    final src = await _bootstrap();
    final dst = await _bootstrap(demo: false);
    await dst.assets.upsert(
      Asset(id: 'local', name: 'Local', kind: AssetKind.other),
    );
    await dst.debts.upsert(
      Debt(
        id: 'local',
        person: 'Local',
        direction: DebtDirection.iOwe,
        amountCents: 100,
        date: _now(),
      ),
    );
    final map =
        jsonDecode(BackupService.exportJson(src)) as Map<String, dynamic>;
    map
      ..remove('assets')
      ..remove('debts');

    await BackupService.importJson(dst, jsonEncode(map));

    expect(dst.assets.all, isEmpty);
    expect(dst.debts.all, isEmpty);
    expect(dst.transactions.all.length, src.transactions.all.length);
  });

  test(
    'ativo ou dívida inválidos no backup: FormatException e nada gravado',
    () async {
      final src = await _bootstrap();
      final dst = await _bootstrap(demo: false);
      await dst.assets.upsert(
        Asset(id: 'local', name: 'Local', kind: AssetKind.other),
      );
      final antes = _state(dst);
      final map =
          jsonDecode(BackupService.exportJson(src)) as Map<String, dynamic>;
      final debt = Debt(
        id: 'ruim',
        person: 'Bruno',
        direction: DebtDirection.iOwe,
        amountCents: 100,
        date: _now(),
      ).toMap();
      final asset = Asset(
        id: 'ruim',
        name: 'Carro',
        kind: AssetKind.vehicle,
      ).toMap();
      for (final (key, row) in [
        ('debts', {...debt, 'amountCents': 0}),
        ('assets', {...asset, 'name': 42}),
      ]) {
        map[key] = [row];
        await expectLater(
          BackupService.importJson(dst, jsonEncode(map)),
          throwsFormatException,
        );
        expect(_state(dst), antes);
      }
    },
  );

  for (final box in [
    'fm_transactions',
    'fm_settings',
    'fm_rules',
    'fm_import_profiles',
    'fm_dictionary',
    'fm_goals',
    'fm_assets',
    'fm_debts',
  ]) {
    test('import com falha em $box restaura tudo (tudo-ou-nada)', () async {
      final src = await _bootstrap();
      final flaky = _FlakyStore();
      final dst = await _bootstrap(stores: {box: flaky});
      // Estado local diferente do backup, para a restauração ser observável.
      await dst.transactions.upsert(
        Transaction(
          id: 'local',
          type: TransactionType.expense,
          amountCents: 900,
          date: _now(),
          description: 'Só neste aparelho',
          accountId: dst.accounts.all.first.id,
        ),
      );
      await dst.settings.update((s) => s.copyWith(mode: AppMode.ultra));
      await dst.rules.upsert(
        const TransactionRule(id: 'local_regra', pattern: 'LOCAL'),
      );
      await dst.importProfiles.upsert(
        ImportProfile(
          id: 'local_perfil',
          name: 'Local',
          accountId: dst.accounts.all.first.id,
        ),
      );
      await dst.dictionary.upsert(
        const DictionaryEntry(
          id: 'local_dic',
          pattern: 'LOCAL',
          categoryName: 'Mercado',
        ),
      );
      await dst.goals.upsert(
        Goal(
          id: 'local_meta',
          name: 'Local',
          accountId: dst.accounts.all.first.id,
          targetCents: 5000,
        ),
      );
      await src.goals.upsert(
        Goal(
          id: 'backup_meta',
          name: 'Do backup',
          accountId: src.accounts.all.first.id,
          targetCents: 9000,
        ),
      );
      await dst.assets.upsert(
        Asset(id: 'local_ativo', name: 'Local', kind: AssetKind.other),
      );
      await dst.debts.upsert(
        Debt(
          id: 'local_divida',
          person: 'Local',
          direction: DebtDirection.iOwe,
          amountCents: 700,
          date: _now(),
        ),
      );
      await src.assets.upsert(
        Asset(
          id: 'backup_ativo',
          name: 'Do backup',
          kind: AssetKind.realEstate,
        ),
      );
      await src.debts.upsert(
        Debt(
          id: 'backup_divida',
          person: 'Do backup',
          direction: DebtDirection.owedToMe,
          amountCents: 800,
          date: _now(),
        ),
      );
      final json = BackupService.exportJson(src);
      final before = _state(dst);

      flaky.failNext = true;
      await expectLater(
        BackupService.importJson(dst, json),
        throwsA(isA<StateError>()),
      );

      expect(_state(dst), before);
      expect(dst.goals.byId('local_meta'), isNotNull);
      expect(dst.assets.byId('local_ativo'), isNotNull);
      expect(dst.debts.byId('local_divida'), isNotNull);
      expect(dst.transactions.byId('local'), isNotNull);
      expect(dst.settings.value.mode, AppMode.ultra);
    });
  }

  group('import recuperável (SPEC §9.13)', () {
    test('import ok apaga o retrato e os lotes de importação', () async {
      final src = await _bootstrap();
      final journal = MemoryRecoveryJournal();
      final dst = await _bootstrap(demo: false, journal: journal);
      await dst.importBatches.upsert(
        ImportBatch(id: 'lote', createdAt: _now(), label: 'antigo.csv'),
      );

      await BackupService.importJson(dst, BackupService.exportJson(src));

      expect(await journal.read(), isNull);
      expect(dst.importBatches.all, isEmpty);
    });

    test(
      'falha ao gravar o retrato: lança e nenhum repositório muda',
      () async {
        final src = await _bootstrap();
        final journal = MemoryRecoveryJournal()..failWrites = true;
        final dst = await _bootstrap(journal: journal);
        final antes = _state(dst);

        await expectLater(
          BackupService.importJson(dst, BackupService.exportJson(src)),
          throwsStateError,
        );

        expect(_state(dst), antes);
        expect(await journal.read(), isNull);
      },
    );

    test(
      'falha no meio com rollback completo: estado anterior e sem retrato',
      () async {
        final src = await _bootstrap();
        final journal = MemoryRecoveryJournal();
        final flaky = _FlakyStore();
        final dst = await _bootstrap(
          stores: {'fm_transactions': flaky},
          journal: journal,
        );
        final antes = _state(dst);
        flaky.failNext = true;

        await expectLater(
          BackupService.importJson(dst, BackupService.exportJson(src)),
          throwsA(isA<StateError>()),
        );

        expect(_state(dst), antes);
        expect(await journal.read(), isNull);
      },
    );

    test(
      'rollback incompleto: o retrato do estado anterior fica no journal',
      () async {
        final src = await _bootstrap();
        final journal = MemoryRecoveryJournal();
        final broken = _BrokenStore();
        final dst = await _bootstrap(
          stores: {'fm_transactions': broken},
          journal: journal,
        );
        final antes = BackupService.exportJson(dst);
        broken.broken = true;

        await expectLater(
          BackupService.importJson(dst, BackupService.exportJson(src)),
          throwsA(isA<StateError>()),
        );

        expect(await journal.read(), antes);
      },
    );

    test(
      'recoverPendingImport volta ao retrato, devolve true e apaga o retrato',
      () async {
        final journal = MemoryRecoveryJournal();
        final s = await _bootstrap(journal: journal);
        // O backup sempre marca onboarding como feito; o estado X precisa já estar assim.
        await s.settings.update((st) => st.copyWith(onboardingDone: true));
        final x = _state(s);
        await journal.write(BackupService.exportJson(s));
        await s.transactions.upsert(
          Transaction(
            id: 'depois',
            type: TransactionType.expense,
            amountCents: 500,
            date: _now(),
            description: 'Depois do retrato',
            accountId: s.accounts.all.first.id,
          ),
        );

        expect(await BackupService.recoverPendingImport(s), isTrue);

        expect(_state(s), x);
        expect(await journal.read(), isNull);
      },
    );

    test('recoverPendingImport sem retrato devolve false', () async {
      final s = await _bootstrap(journal: MemoryRecoveryJournal());

      expect(await BackupService.recoverPendingImport(s), isFalse);
    });

    test(
      'recoverPendingImport com retrato inválido devolve false e mantém o retrato',
      () async {
        final journal = MemoryRecoveryJournal();
        final s = await _bootstrap(journal: journal);
        await journal.write('não é json');

        expect(await BackupService.recoverPendingImport(s), isFalse);
        expect(await journal.read(), 'não é json');
      },
    );

    test(
      'pagamento de dívida ligado a transação que o backup não traz sobrevive ao import',
      () async {
        final src = await _bootstrap();
        final dst = await _bootstrap();
        final debt = Debt(
          id: 'd1',
          person: 'Ana',
          direction: DebtDirection.owedToMe,
          amountCents: 50000,
          date: _now(),
          payments: [
            DebtPayment(
              id: 'p1',
              date: _now(),
              amountCents: 20000,
              transactionId: 'tx_quitacao',
            ),
          ],
        );
        await src.debts.upsert(debt);
        await dst.debts.upsert(debt);
        await dst.transactions.upsert(
          Transaction(
            id: 'tx_quitacao',
            type: TransactionType.income,
            amountCents: 20000,
            date: _now(),
            description: 'Ana pagou',
            accountId: dst.accounts.all.first.id,
          ),
        );

        await BackupService.importJson(dst, BackupService.exportJson(src));

        expect(dst.transactions.byId('tx_quitacao'), isNull);
        expect(dst.debts.byId('d1'), debt);
      },
    );
  });
}
