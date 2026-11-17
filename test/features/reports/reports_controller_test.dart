import 'package:finme/app/app_scope.dart';
import 'package:finme/app/bootstrap.dart';
import 'package:finme/core/models/app_settings.dart';
import 'package:finme/core/models/year_month.dart';
import 'package:finme/core/services/record_store.dart';
import 'package:finme/features/accounts/domain/account.dart';
import 'package:finme/features/categories/domain/transaction_category.dart';
import 'package:finme/features/reports/domain/report_filter.dart';
import 'package:finme/features/reports/presentation/reports_controller.dart';
import 'package:finme/features/transactions/domain/tags.dart';
import 'package:finme/features/transactions/domain/transaction.dart';
import 'package:flutter_test/flutter_test.dart';

DateTime _now() => DateTime(2026, 11, 15);

TransactionCategory _cat(
  String id,
  String name,
  CategoryKind kind, {
  String? parentId,
}) => TransactionCategory(
  id: id,
  name: name,
  kind: kind,
  iconCodePoint: 0,
  colorValue: 0,
  parentId: parentId,
);

Transaction _exp(
  String id,
  DateTime date,
  String? categoryId,
  int cents, {
  bool planned = false,
}) => Transaction(
  id: id,
  type: TransactionType.expense,
  amountCents: cents,
  date: date,
  description: 'Loja $id',
  accountId: 'A',
  categoryId: categoryId,
  status: planned ? TransactionStatus.planned : TransactionStatus.paid,
);

/// Dados de §5.28 (despesas pagas) e uma receita em conta em nov.
List<Transaction> _seed() => [
  _exp('a1', DateTime(2026, 8, 10), 'mer', 30000),
  _exp('a2', DateTime(2026, 8, 10), 'tra', 10000),
  _exp('s1', DateTime(2026, 9, 10), 'mer', 40000),
  _exp('s2', DateTime(2026, 9, 10), 'res', 10000),
  _exp('s3', DateTime(2026, 9, 10), 'tra', 10000),
  _exp('o1', DateTime(2026, 10, 10), 'mer', 50000),
  _exp('o2', DateTime(2026, 10, 10), 'res', 20000),
  _exp('o3', DateTime(2026, 10, 10), 'ali', 5000),
  _exp('o4', DateTime(2026, 10, 10), 'tra', 20000),
  _exp('n1', DateTime(2026, 11, 3), 'mer', 60000),
  _exp('n2', DateTime(2026, 11, 3), 'res', 15000),
  _exp('n3', DateTime(2026, 11, 3), 'tra', 5000),
  _exp('n4', DateTime(2026, 11, 3), null, 3000),
  _exp('n5', DateTime(2026, 11, 20), 'mer', 99999, planned: true),
  Transaction(
    id: 'r1',
    type: TransactionType.income,
    amountCents: 500000,
    date: DateTime(2026, 11, 5),
    description: 'Salário',
    accountId: 'A',
    categoryId: 'sal',
  ),
];

Future<AppServices> _services() async {
  final s = await bootstrap(
    storeFactory: (_) => MemoryRecordStore(),
    clock: _now,
  );
  await s.categories.replaceAll([
    _cat('ali', 'Alimentação', CategoryKind.expense),
    _cat('mer', 'Mercado', CategoryKind.expense, parentId: 'ali'),
    _cat('res', 'Restaurante', CategoryKind.expense, parentId: 'ali'),
    _cat('tra', 'Transporte', CategoryKind.expense),
    _cat('sal', 'Salário', CategoryKind.income),
  ]);
  await s.accounts.upsert(
    const Account(
      id: 'A',
      name: 'Conta A',
      bankName: 'Banco A',
      type: AccountType.checking,
      initialBalanceCents: 100000,
      colorValue: 0xFF42A5F5,
    ),
  );
  await s.transactions.upsertAll(_seed());
  return s;
}

Future<void> _ultra(AppServices s) =>
    s.settings.update((x) => x.copyWith(mode: AppMode.ultra));

void main() {
  late AppServices s;
  late ReportsController c;

  setUp(() async {
    s = await _services();
    c = ReportsController(s);
  });

  tearDown(() {
    c.dispose();
  });

  test('getters são memoizados até o cache ser zerado', () {
    expect(identical(c.trend, c.trend), isTrue);
    expect(identical(c.pivot, c.pivot), isTrue);
    expect(identical(c.comparison, c.comparison), isTrue);
    expect(identical(c.merchants, c.merchants), isTrue);
    expect(identical(c.heatmap, c.heatmap), isTrue);
    expect(identical(c.fixedVariable, c.fixedVariable), isTrue);
  });

  test('comparativo e pivot seguem os números de §5.28 e §5.29', () {
    expect(c.comparison.month, const YearMonth(2026, 11));
    expect(c.comparison.total.currentCents, 83000);
    expect(c.comparison.total.previousCents, 95000);
    expect(c.comparison.total.averageCents, 65000);
    expect(c.pivot.grandTotalCents, 278000);
    expect(c.pivot.columnTotals.length, 12);
  });

  test('trocar o filtro notifica uma vez e muda o período', () {
    var notified = 0;
    c.addListener(() => notified++);

    c.filter = ReportFilter(preset: ReportPeriodPreset.last3);

    expect(notified, 1);
    expect(c.range, (
      from: const YearMonth(2026, 9),
      to: const YearMonth(2026, 11),
    ));
    expect(c.trend.length, 3);
  });

  test('atribuir filtro igual não notifica', () {
    c.filter = ReportFilter(preset: ReportPeriodPreset.last3);
    var notified = 0;
    c.addListener(() => notified++);

    c.filter = ReportFilter(preset: ReportPeriodPreset.last3);

    expect(notified, 0);
  });

  test(
    'selected e averageMonths iguais não notificam nem zeram cache',
    () async {
      await _ultra(s);
      c.selected = ReportKind.pivot;
      final cmp = c.comparison;
      var notified = 0;
      c.addListener(() => notified++);

      c.selected = ReportKind.pivot;
      c.averageMonths = 3;

      expect(notified, 0);
      expect(identical(c.comparison, cmp), isTrue);

      c.averageMonths = 6;
      expect(notified, 1);
    },
  );

  test('upsert de despesa em nov notifica e muda o pivot', () async {
    final before = c.pivot.grandTotalCents;
    var notified = 0;
    c.addListener(() => notified++);

    await s.transactions.upsert(_exp('n6', DateTime(2026, 11, 4), 'tra', 1000));

    expect(notified, greaterThan(0));
    expect(c.pivot.grandTotalCents, before + 1000);
  });

  test('após dispose, upsert não lança', () async {
    final descartado = ReportsController(s);
    descartado.dispose();
    await s.transactions.upsert(_exp('n7', DateTime(2026, 11, 4), 'tra', 500));
  });

  test('Simple: números ignoram cartões e escopo do filtro', () async {
    final baseline = ReportsController(s);
    addTearDown(baseline.dispose);
    c.filter = ReportFilter(cardIds: {'K'}, categoryIds: {'ali'});

    expect(c.available, kSimpleReports);
    expect(c.effectiveFilter, c.filter.periodOnly);
    expect(
      [for (final p in c.trend) p.expenseCents],
      [for (final p in baseline.trend) p.expenseCents],
    );
  });

  test('Simple: selected pivot cai em tendência', () {
    c.selected = ReportKind.pivot;
    expect(c.current, ReportKind.trend);
  });

  test(
    'Ultra: selected pivot é mantido e available é a lista completa',
    () async {
      await _ultra(s);
      c.selected = ReportKind.pivot;
      expect(c.available, kUltraReports);
      expect(c.current, ReportKind.pivot);
    },
  );

  test('Ultra: averageMonths 6 vale; 5 é ignorado; Simples usa 3', () async {
    await _ultra(s);
    c.averageMonths = 6;
    expect(c.comparison.averageMonths, 6);
    expect(c.comparison.total.averageCents, 32500);

    c.averageMonths = 5;
    expect(c.averageMonths, 6);
    expect(c.comparison.averageMonths, 6);

    await s.settings.update((x) => x.copyWith(mode: AppMode.simple));
    expect(c.comparison.averageMonths, 3);
    expect(c.comparison.total.averageCents, 65000);
  });

  test(
    'heatmap termina hoje sem provisionados e no fim do mês com eles',
    () async {
      expect(c.heatmap.to, DateTime(2026, 11, 15));

      await _ultra(s);
      c.filter = ReportFilter(includePlanned: true);
      expect(c.heatmap.to, DateTime(2026, 11, 30));
    },
  );

  test('patrimônio com last3 traz os 3 últimos pontos do Ledger', () {
    c.filter = ReportFilter(preset: ReportPeriodPreset.last3);
    final history = s.ledger.netWorthHistory;
    final expected = history.sublist(history.length - 3);

    expect(c.netWorth.map((p) => p.month).toList(), [
      const YearMonth(2026, 9),
      const YearMonth(2026, 10),
      const YearMonth(2026, 11),
    ]);
    expect(c.netWorth.map((p) => p.netCents).toList(), [
      for (final p in expected) p.netCents,
    ]);
  });

  test('nomes de arquivo CSV e cabeçalho do pivot', () {
    c.filter = ReportFilter(preset: ReportPeriodPreset.last3);
    expect(
      c.csvFileName(ReportKind.trend),
      'finme-tendencia-2026-09_2026-11.csv',
    );
    expect(
      c.csvFileName(ReportKind.categoryComparison),
      'finme-comparativo-categorias-2026-11.csv',
    );
    expect(
      c.csvFor(ReportKind.pivot),
      startsWith('Categoria;set/2026;out/2026;nov/2026;Total'),
    );
  });

  test('ignoredFor(patrimônio) lista contas e cartões no Ultra', () async {
    await _ultra(s);
    c.filter = ReportFilter(cardIds: {'K'});
    expect(c.ignoredFor(ReportKind.netWorth), ['contas e cartões']);
  });

  test('filtro, relatório e média persistem entre controllers', () async {
    await s.transactions.upsert(
      _exp('v1', DateTime(2026, 10, 5), 'tra', 1000).copyWith(tags: ['viagem']),
    );
    c.filter = ReportFilter(
      preset: ReportPeriodPreset.custom,
      customFrom: const YearMonth(2026, 9),
      customTo: const YearMonth(2026, 11),
      accountIds: {'A'},
      tagKeys: {tagKey('viagem')},
    );
    c.selected = ReportKind.pivot;
    c.averageMonths = 6;

    final c2 = ReportsController(s);
    addTearDown(c2.dispose);
    expect(c2.filter, c.filter);
    expect(c2.selected, ReportKind.pivot);
    expect(c2.averageMonths, 6);
  });

  test('conta excluída sai do filtro salvo e o resto fica', () async {
    c.filter = ReportFilter(accountIds: {'A'}, categoryIds: {'mer'});
    await s.accounts.delete('A');

    final c2 = ReportsController(s);
    addTearDown(c2.dispose);
    expect(c2.filter.accountIds, isEmpty);
    expect(c2.filter.categoryIds, {'mer'});
  });

  test('registro corrompido cai nos padrões sem exceção', () async {
    await s.uiState.put('reports', {
      'id': 'reports',
      'filter': 'x',
      'selected': 'nada',
      'averageMonths': 5,
    });

    final c2 = ReportsController(s);
    addTearDown(c2.dispose);
    expect(c2.filter, ReportFilter());
    expect(c2.selected, ReportKind.trend);
    expect(c2.averageMonths, 3);
  });

  test('mudar filtro não toca settings nem notifica o Ledger', () {
    final settings = s.settings.value;
    var ledgerNotified = 0;
    s.ledger.addListener(() => ledgerNotified++);

    c.filter = ReportFilter(accountIds: {'A'});

    expect(identical(s.settings.value, settings), isTrue);
    expect(ledgerNotified, 0);
  });

  test('período de 36 meses tem patrimônio próprio até o mês atual', () {
    c.filter = ReportFilter(
      preset: ReportPeriodPreset.custom,
      customFrom: const YearMonth(2023, 12),
      customTo: const YearMonth(2026, 11),
    );
    expect(c.netWorth.length, 36);
    expect(c.netWorth.last.netCents, s.ledger.netWorthHistory.last.netCents);

    c.filter = ReportFilter(preset: ReportPeriodPreset.last12);
    expect(c.netWorth.length, 12);
  });
}
