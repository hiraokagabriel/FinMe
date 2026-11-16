import 'package:finme/app/app_commands.dart';
import 'package:finme/app/app_scope.dart';
import 'package:finme/app/bootstrap.dart';
import 'package:finme/app/command_palette.dart';
import 'package:finme/app/ledger.dart';
import 'package:finme/app/seed.dart';
import 'package:finme/core/models/app_settings.dart';
import 'package:finme/core/services/record_store.dart';
import 'package:finme/core/utils/fuzzy.dart';
import 'package:finme/core/widgets/money.dart';
import 'package:finme/features/categories/domain/transaction_category.dart';
import 'package:finme/features/transactions/domain/transaction.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const _pages = <PageInfo>[
  (label: 'Painel', icon: Icons.dashboard_outlined),
  (label: 'Previsão', icon: Icons.show_chart),
  (label: 'Cartões', icon: Icons.credit_card),
  (label: 'Contas', icon: Icons.account_balance_wallet_outlined),
  (label: 'Transações', icon: Icons.receipt_long),
  (label: 'Importar', icon: Icons.upload_file),
  (label: 'Recorrentes', icon: Icons.autorenew),
  (label: 'Categorias', icon: Icons.category_outlined),
  (label: 'Ajustes', icon: Icons.settings_outlined),
  (label: 'Patrimônio', icon: Icons.account_balance_outlined),
  (label: 'Relatórios', icon: Icons.insights_outlined),
];

/// Comandos com callbacks que gravam o que foi chamado em [ran].
List<PaletteEntry> _commands(List<String> ran, {AppSettings? settings}) =>
    buildAppCommands(
      settings: settings ?? AppSettings(),
      pages: _pages,
      onGoTo: (i) => ran.add('goto $i'),
      onNewTransaction: () => ran.add('nova'),
      onImport: () => ran.add('importar'),
      onNewRecurring: () => ran.add('recorrencia'),
      onNewAsset: () => ran.add('ativo'),
      onNewDebt: () => ran.add('divida'),
      onOpenReport: (k) => ran.add('relatorio ${k.name}'),
      onToggleMode: () => ran.add('modo'),
      onToggleTheme: () => ran.add('tema'),
      onToggleHideValues: () => ran.add('ocultar'),
    );

PaletteEntry _named(List<PaletteEntry> list, String label) =>
    list.firstWhere((e) => e.label == label);

void main() {
  test('22 comandos (Simples) na ordem do SPEC, com atalhos corretos', () {
    final ran = <String>[];
    final cmds = _commands(ran);

    expect(cmds.length, 22);
    expect(cmds.map((e) => e.label).toList(), [
      for (final p in _pages) 'Ir para ${p.label}',
      'Nova transação',
      'Importar arquivo',
      'Nova recorrência',
      'Novo ativo',
      'Nova dívida (devo / me devem)',
      'Relatório: Tendência',
      'Relatório: Top estabelecimentos',
      'Relatório: Comparativo por categoria',
      'Mudar para Modo Ultra',
      'Alternar tema claro/escuro',
      'Ocultar valores',
    ]);

    final transactions = _named(cmds, 'Ir para Transações');
    expect(transactions.shortcut, '5');
    transactions.onRun();
    expect(ran, ['goto 4']);

    expect(_named(cmds, 'Nova transação').shortcut, 'N');
    expect(_named(cmds, 'Importar arquivo').shortcut, 'Ctrl+I');
    expect(_named(cmds, 'Ir para Painel').shortcut, '1');
    expect(_named(cmds, 'Ir para Ajustes').shortcut, '9');
    expect(_named(cmds, 'Ir para Patrimônio').shortcut, isNull);
    expect(_named(cmds, 'Ir para Relatórios').shortcut, isNull);
  });

  test('Ultra: 26 comandos, 7 relatórios no grupo Relatórios', () {
    final ran = <String>[];
    final cmds = _commands(ran, settings: AppSettings(mode: AppMode.ultra));

    expect(cmds.length, 26);
    final reports = cmds.where((e) => e.group == 'Relatórios').toList();
    expect(reports.length, 7);
    final debt = cmds.indexOf(_named(cmds, 'Nova dívida (devo / me devem)'));
    expect(cmds[debt + 1].label, 'Relatório: Comparativo por categoria');
    expect(cmds[debt + 7].label, 'Relatório: Evolução do patrimônio');
    expect(cmds[debt + 8].label, 'Mudar para Modo Simples');
  });

  test('ações chamam os callbacks certos', () {
    final ran = <String>[];
    final cmds = _commands(ran);
    _named(cmds, 'Nova transação').onRun();
    _named(cmds, 'Importar arquivo').onRun();
    _named(cmds, 'Nova recorrência').onRun();
    _named(cmds, 'Novo ativo').onRun();
    _named(cmds, 'Nova dívida (devo / me devem)').onRun();
    _named(cmds, 'Mudar para Modo Ultra').onRun();
    _named(cmds, 'Alternar tema claro/escuro').onRun();
    _named(cmds, 'Ocultar valores').onRun();
    expect(ran, [
      'nova',
      'importar',
      'recorrencia',
      'ativo',
      'divida',
      'modo',
      'tema',
      'ocultar',
    ]);
  });

  test('comando de relatório chama onOpenReport com o tipo certo', () {
    final ran = <String>[];
    final cmds = _commands(ran, settings: AppSettings(mode: AppMode.ultra));
    _named(cmds, 'Relatório: Categoria × mês').onRun();
    _named(cmds, 'Relatório: Gasto por dia').onRun();
    expect(ran, ['relatorio pivot', 'relatorio heatmap']);
  });

  test('rótulo de modo e de privacidade acompanha as configurações', () {
    final ultra = _commands(
      [],
      settings: AppSettings(mode: AppMode.ultra, hideValues: true),
    );
    expect(ultra.any((e) => e.label == 'Mudar para Modo Simples'), isTrue);
    expect(ultra.any((e) => e.label == 'Mostrar valores'), isTrue);
    expect(ultra.any((e) => e.label == 'Ocultar valores'), isFalse);
  });

  test('busca fuzzy encontra importar por csv e tema por escuro', () {
    final cmds = _commands([]);
    List<String> keys(PaletteEntry e) => [e.label, ...e.keywords];

    final csv = fuzzyRank(cmds, 'csv', keys);
    expect(csv.first.label, 'Importar arquivo');

    final dark = fuzzyRank(cmds, 'escuro', keys);
    expect(dark.first.label, 'Alternar tema claro/escuro');

    final loan = fuzzyRank(cmds, 'emprest', keys);
    expect(loan.first.label, 'Nova dívida (devo / me devem)');
  });

  test('busca fuzzy acha relatórios por palavra-chave', () {
    final cmds = _commands([], settings: AppSettings(mode: AppMode.ultra));
    List<String> keys(PaletteEntry e) => [e.label, ...e.keywords];

    final heat = fuzzyRank(cmds, 'heatmap', keys);
    expect(heat.first.label, 'Relatório: Gasto por dia');

    final where = fuzzyRank(cmds, 'onde gasto', keys);
    expect(where.first.label, 'Relatório: Top estabelecimentos');
  });

  group('transactionEntries', () {
    late Ledger ledger;
    late AppServices services;

    setUp(() async {
      final s = await bootstrap(
        storeFactory: (_) => MemoryRecordStore(),
        clock: () => DateTime(2026, 11, 14),
      );
      await seedDemo(s);
      services = s;
      ledger = s.ledger;
    });

    test(
      'subcategoria no subtitle (Pai › Filha) e tags com # no fim',
      () async {
        await services.categories.upsert(
          const TransactionCategory(
            id: 'cat_mercado_x',
            name: 'Mercado X',
            kind: CategoryKind.expense,
            iconCodePoint: 0xe59c,
            colorValue: 0xFF42A5F5,
            parentId: 'cat_compras',
          ),
        );
        final t = Transaction(
          id: 'm1',
          type: TransactionType.expense,
          amountCents: 3000,
          date: DateTime(2026, 11, 14),
          description: 'Mercado Exemplo',
          cardId: 'card_beta_master',
          categoryId: 'cat_mercado_x',
          tags: const ['casa'],
        );
        final entry = transactionEntries(
          [t],
          ledger: ledger,
          onOpen: (_) {},
        ).single;
        expect(
          entry.subtitle,
          '14/11/2026 · Beta Master · Compras › Mercado X · #casa',
        );
      },
    );

    Transaction parcela() => Transaction(
      id: 'p1',
      type: TransactionType.expense,
      amountCents: 4590,
      date: DateTime(2026, 11, 14),
      description: 'Loja Exemplo',
      cardId: 'card_beta_master',
      categoryId: 'cat_compras',
      installmentGroupId: 'g1',
      installmentIndex: 3,
      installmentCount: 10,
    );

    test('parcela: label com i/n, subtitle com data, cartão e categoria', () {
      final opened = <Transaction>[];
      final t = parcela();
      final entry = transactionEntries(
        [t],
        ledger: ledger,
        onOpen: opened.add,
      ).single;

      expect(entry.label, 'Loja Exemplo 3/10');
      expect(entry.subtitle, '14/11/2026 · Beta Master · Compras');
      expect(entry.group, 'Transações');
      expect((entry.trailing! as MoneyText).cents, -4590);

      entry.onRun();
      expect(opened, [t]);
    });

    test('receita é positiva e transferência não tem sinal', () {
      final income = Transaction(
        id: 'i1',
        type: TransactionType.income,
        amountCents: 1000,
        date: DateTime(2026, 11, 14),
        description: 'Salário',
      );
      final transfer = Transaction(
        id: 'x1',
        type: TransactionType.transfer,
        amountCents: 2000,
        date: DateTime(2026, 11, 14),
        description: 'Pix',
      );
      final entries = transactionEntries(
        [income, transfer],
        ledger: ledger,
        onOpen: (_) {},
      );
      expect((entries[0].trailing! as MoneyText).cents, 1000);
      expect((entries[1].trailing! as MoneyText).cents, 2000);
      expect(entries[1].subtitle, '14/11/2026');
    });
  });

  test('filterTransactionsEntry: rótulo com a query e grupo Transações', () {
    var ran = false;
    final entry = filterTransactionsEntry('uber', onRun: () => ran = true);

    expect(entry.label, 'Filtrar Transações do mês por “uber”');
    expect(entry.group, 'Transações');
    entry.onRun();
    expect(ran, isTrue);
  });
}
