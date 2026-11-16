import 'package:finme/core/models/year_month.dart';
import 'package:finme/features/categories/domain/category_tree.dart';
import 'package:finme/features/categories/domain/transaction_category.dart';
import 'package:finme/features/reports/domain/report_filter.dart';
import 'package:finme/features/transactions/domain/transaction.dart';
import 'package:flutter_test/flutter_test.dart';

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

final CategoryTree _tree = CategoryTree([
  _cat('ali', 'Alimentação', CategoryKind.expense),
  _cat('mer', 'Mercado', CategoryKind.expense, parentId: 'ali'),
  _cat('res', 'Restaurante', CategoryKind.expense, parentId: 'ali'),
  _cat('tra', 'Transporte', CategoryKind.expense),
  _cat('sal', 'Salário', CategoryKind.income),
]);

final DateTime _today = DateTime(2026, 11, 15);

Transaction _tx({
  TransactionType type = TransactionType.expense,
  String? accountId = 'A',
  String? cardId,
  String? categoryId = 'mer',
  TransactionStatus status = TransactionStatus.paid,
  List<String> tags = const ['Viagem'],
}) => Transaction(
  id: 't1',
  type: type,
  amountCents: 1000,
  date: DateTime(2026, 11, 3),
  description: 'x',
  accountId: accountId,
  cardId: cardId,
  categoryId: categoryId,
  status: status,
  tags: tags,
);

void main() {
  group('rótulos', () {
    test('kindLabel e kindSlug dos 7 relatórios', () {
      expect(ReportKind.values.map(reportKindLabel).toList(), [
        'Comparativo por categoria',
        'Tendência',
        'Categoria × mês',
        'Gasto por dia',
        'Top estabelecimentos',
        'Fixo × variável',
        'Evolução do patrimônio',
      ]);
      expect(ReportKind.values.map(reportKindSlug).toList(), [
        'comparativo-categorias',
        'tendencia',
        'categoria-mes',
        'gasto-por-dia',
        'estabelecimentos',
        'fixo-variavel',
        'patrimonio',
      ]);
    });

    test('periodLabel dos 6 presets', () {
      expect(ReportPeriodPreset.values.map(reportPeriodLabel).toList(), [
        '3 meses',
        '6 meses',
        '12 meses',
        'Ano atual',
        'Ano anterior',
        'Personalizado',
      ]);
    });

    test('kSimpleReports e kUltraReports', () {
      expect(kSimpleReports, [
        ReportKind.trend,
        ReportKind.topMerchants,
        ReportKind.categoryComparison,
      ]);
      expect(kUltraReports, ReportKind.values);
    });

    test('reportCategoryLabel', () {
      expect(reportCategoryLabel(null, _tree), 'Sem categoria');
      expect(reportCategoryLabel('mer', _tree), 'Alimentação › Mercado');
      expect(
        reportCategoryLabel('ali', _tree, isDirect: true),
        'Alimentação › (sem subcategoria)',
      );
      expect(reportCategoryLabel('apagada', _tree), 'Categoria removida');
    });
  });

  group('ReportFilter', () {
    test('padrão', () {
      final f = ReportFilter();
      expect(f.preset, ReportPeriodPreset.last12);
      expect(f.accountIds, isEmpty);
      expect(f.cardIds, isEmpty);
      expect(f.categoryIds, isEmpty);
      expect(f.tagKeys, isEmpty);
      expect(f.flow, ReportFlow.expense);
      expect(f.includePlanned, isFalse);
      expect(f.hasScopeFilters, isFalse);
    });

    test('copyWith omitido mantém; customFrom null limpa', () {
      final base = ReportFilter(
        preset: ReportPeriodPreset.custom,
        customFrom: const YearMonth(2026, 2),
        customTo: const YearMonth(2026, 5),
        cardIds: const {'K'},
      );
      final same = base.copyWith(flow: ReportFlow.income);
      expect(same.customFrom, const YearMonth(2026, 2));
      expect(same.cardIds, {'K'});
      expect(same.flow, ReportFlow.income);
      expect(base.copyWith(customFrom: null).customFrom, isNull);
      expect(
        base.copyWith(customFrom: null).customTo,
        const YearMonth(2026, 5),
      );
    });

    test('sets são imutáveis e isolados do argumento do construtor', () {
      final ids = {'A'};
      final f = ReportFilter(accountIds: ids);
      ids.add('B');
      expect(f.accountIds, {'A'});
      expect(() => f.accountIds.add('C'), throwsUnsupportedError);
    });

    test('igualdade por conteúdo, sets como conjuntos', () {
      final a = ReportFilter(accountIds: const {'a', 'b'});
      final b = ReportFilter(accountIds: const {'b', 'a'});
      expect(a, b);
      expect(a.hashCode, b.hashCode);
      expect(a == ReportFilter(accountIds: const {'a'}), isFalse);
    });

    test('periodOnly mantém só preset e datas', () {
      final f = ReportFilter(
        preset: ReportPeriodPreset.custom,
        customFrom: const YearMonth(2026, 2),
        customTo: const YearMonth(2026, 5),
        cardIds: const {'K'},
        flow: ReportFlow.income,
        includePlanned: true,
      );
      final p = f.periodOnly;
      expect(p.preset, ReportPeriodPreset.custom);
      expect(p.customFrom, const YearMonth(2026, 2));
      expect(p.customTo, const YearMonth(2026, 5));
      expect(p.hasScopeFilters, isFalse);
    });
  });

  group('resolveReportRange (hoje 15/11/2026)', () {
    ReportRange r(ReportFilter f) => resolveReportRange(f, _today);

    test('presets', () {
      expect(r(ReportFilter(preset: ReportPeriodPreset.last3)), (
        from: const YearMonth(2026, 9),
        to: const YearMonth(2026, 11),
      ));
      expect(r(ReportFilter()), (
        from: const YearMonth(2025, 12),
        to: const YearMonth(2026, 11),
      ));
      expect(r(ReportFilter(preset: ReportPeriodPreset.thisYear)), (
        from: const YearMonth(2026, 1),
        to: const YearMonth(2026, 11),
      ));
      expect(r(ReportFilter(preset: ReportPeriodPreset.lastYear)), (
        from: const YearMonth(2025, 1),
        to: const YearMonth(2025, 12),
      ));
    });

    test('custom: troca quando from > to', () {
      final f = ReportFilter(
        preset: ReportPeriodPreset.custom,
        customFrom: const YearMonth(2026, 5),
        customTo: const YearMonth(2026, 2),
      );
      expect(r(f), (
        from: const YearMonth(2026, 2),
        to: const YearMonth(2026, 5),
      ));
    });

    test('custom: corta em 60 meses', () {
      final f = ReportFilter(
        preset: ReportPeriodPreset.custom,
        customFrom: const YearMonth(2020, 1),
        customTo: const YearMonth(2026, 11),
      );
      final range = r(f);
      expect(range.from, const YearMonth(2021, 12));
      expect(monthsOf(range).length, kReportMaxMonths);
    });

    test('custom sem datas → igual a last12', () {
      expect(
        r(ReportFilter(preset: ReportPeriodPreset.custom)),
        r(ReportFilter()),
      );
    });

    test('monthsOf', () {
      expect(
        monthsOf((
          from: const YearMonth(2025, 11),
          to: const YearMonth(2026, 2),
        )),
        [
          const YearMonth(2025, 11),
          const YearMonth(2025, 12),
          const YearMonth(2026, 1),
          const YearMonth(2026, 2),
        ],
      );
    });
  });

  test('roundDiv', () {
    expect(roundDiv(155000, 3), 51667);
    expect(roundDiv(5, 2), 3);
    expect(roundDiv(4, 3), 1);
    expect(roundDiv(-1, 2), -1);
    expect(roundDiv(-11, 2), -6);
    expect(roundDiv(0, 7), 0);
  });

  group('reportFlowOf', () {
    test('tipos', () {
      expect(reportFlowOf(_tx()), ReportFlow.expense);
      expect(
        reportFlowOf(_tx(accountId: null, cardId: 'K')),
        ReportFlow.expense,
      );
      expect(
        reportFlowOf(_tx(type: TransactionType.income)),
        ReportFlow.income,
      );
      expect(
        reportFlowOf(
          _tx(type: TransactionType.income, accountId: null, cardId: 'K'),
        ),
        isNull,
      );
      expect(reportFlowOf(_tx(type: TransactionType.transfer)), isNull);
      expect(reportFlowOf(_tx(type: TransactionType.invoicePayment)), isNull);
    });
  });

  group('matchesReportScope', () {
    bool m(Transaction t, ReportFilter f) => matchesReportScope(t, f, _tree);

    test('filtro padrão e categorias', () {
      final t = _tx();
      expect(m(t, ReportFilter()), isTrue);
      expect(m(t, ReportFilter(categoryIds: const {'ali'})), isTrue);
      expect(m(t, ReportFilter(categoryIds: const {'mer'})), isTrue);
      expect(m(t, ReportFilter(categoryIds: const {'res'})), isFalse);
      expect(m(t, ReportFilter(categoryIds: const {'tra'})), isFalse);
      expect(
        m(_tx(categoryId: null), ReportFilter(categoryIds: const {'ali'})),
        isFalse,
      );
    });

    test('tags', () {
      final t = _tx();
      expect(m(t, ReportFilter(tagKeys: const {'VIAGEM'})), isTrue);
      expect(m(t, ReportFilter(tagKeys: const {'CASA'})), isFalse);
    });

    test('contas e cartões', () {
      final t = _tx();
      expect(m(t, ReportFilter(accountIds: const {'A'})), isTrue);
      expect(m(t, ReportFilter(accountIds: const {'B'})), isFalse);
      expect(m(t, ReportFilter(cardIds: const {'K'})), isFalse);
      final card = _tx(accountId: null, cardId: 'K');
      expect(
        m(card, ReportFilter(accountIds: const {'B'}, cardIds: const {'K'})),
        isTrue,
      );
    });

    test('provisionado só com includePlanned', () {
      final t = _tx(status: TransactionStatus.planned);
      expect(m(t, ReportFilter()), isFalse);
      expect(m(t, ReportFilter(includePlanned: true)), isTrue);
    });
  });

  group('ignoredFilters', () {
    test('exemplos de §5.27', () {
      expect(
        ignoredFilters(ReportKind.trend, ReportFilter(flow: ReportFlow.income)),
        ['tipo'],
      );
      expect(ignoredFilters(ReportKind.trend, ReportFilter()), isEmpty);
      expect(
        ignoredFilters(
          ReportKind.topMerchants,
          ReportFilter(flow: ReportFlow.income),
        ),
        isEmpty,
      );
      expect(
        ignoredFilters(
          ReportKind.netWorth,
          ReportFilter(
            cardIds: const {'K'},
            tagKeys: const {'VIAGEM'},
            includePlanned: true,
          ),
        ),
        ['contas e cartões', 'tags', 'provisionados'],
      );
    });

    test('filtro que liga tudo, por relatório', () {
      final all = ReportFilter(
        accountIds: const {'A'},
        categoryIds: const {'ali'},
        tagKeys: const {'VIAGEM'},
        flow: ReportFlow.income,
        includePlanned: true,
      );
      const rows = [
        'contas e cartões',
        'categorias',
        'tags',
        'tipo',
        'provisionados',
      ];
      expect(ignoredFilters(ReportKind.categoryComparison, all), isEmpty);
      expect(ignoredFilters(ReportKind.pivot, all), isEmpty);
      expect(ignoredFilters(ReportKind.topMerchants, all), isEmpty);
      expect(ignoredFilters(ReportKind.trend, all), ['categorias', 'tipo']);
      expect(ignoredFilters(ReportKind.heatmap, all), ['categorias', 'tipo']);
      expect(ignoredFilters(ReportKind.fixedVariable, all), [
        'categorias',
        'tipo',
      ]);
      expect(ignoredFilters(ReportKind.netWorth, all), rows);
    });

    test(
      'categorias: tendência sempre; despesa-only só com receita no filtro',
      () {
        final cats = ReportFilter(categoryIds: const {'ali'});
        expect(ignoredFilters(ReportKind.trend, cats), ['categorias']);
        expect(ignoredFilters(ReportKind.heatmap, cats), isEmpty);
        expect(ignoredFilters(ReportKind.fixedVariable, cats), isEmpty);

        final receita = ReportFilter(
          categoryIds: const {'ali'},
          flow: ReportFlow.income,
        );
        expect(ignoredFilters(ReportKind.heatmap, receita), [
          'categorias',
          'tipo',
        ]);
        expect(ignoredFilters(ReportKind.fixedVariable, receita), [
          'categorias',
          'tipo',
        ]);
      },
    );
  });

  group('isFutureUnplanned', () {
    Transaction onDay(DateTime d, {TransactionStatus? status}) => Transaction(
      id: 'f',
      type: TransactionType.expense,
      amountCents: 1000,
      date: d,
      description: 'x',
      accountId: 'A',
      status: status ?? TransactionStatus.paid,
    );

    test('paga com data depois de hoje é futura; hoje e passado não são', () {
      final hoje = DateTime(2026, 11, 15, 18, 30);
      expect(isFutureUnplanned(onDay(DateTime(2026, 11, 20)), hoje), isTrue);
      expect(isFutureUnplanned(onDay(DateTime(2026, 11, 15)), hoje), isFalse);
      expect(isFutureUnplanned(onDay(DateTime(2026, 11, 14)), hoje), isFalse);
    });

    test('provisionada nunca entra aqui (quem decide é includePlanned)', () {
      final hoje = DateTime(2026, 11, 15);
      final planejada = onDay(
        DateTime(2026, 11, 20),
        status: TransactionStatus.planned,
      );
      expect(isFutureUnplanned(planejada, hoje), isFalse);
    });
  });
}
