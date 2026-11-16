import 'package:finme/core/models/year_month.dart';
import 'package:finme/features/categories/domain/category_tree.dart';
import 'package:finme/features/categories/domain/transaction_category.dart';
import 'package:finme/features/net_worth/domain/net_worth.dart';
import 'package:finme/features/reports/domain/category_pivot.dart';
import 'package:finme/features/reports/domain/category_reports.dart';
import 'package:finme/features/reports/domain/merchant_report.dart';
import 'package:finme/features/reports/domain/monthly_flow.dart';
import 'package:finme/features/reports/domain/report_csv.dart';
import 'package:finme/features/reports/domain/report_filter.dart';
import 'package:finme/features/reports/domain/spending_heatmap.dart';
import 'package:finme/features/transactions/domain/transaction.dart';
import 'package:flutter_test/flutter_test.dart';

final DateTime _hoje = DateTime(2026, 11, 30);

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
]);

Transaction _exp(String id, DateTime date, String? categoryId, int cents) =>
    Transaction(
      id: id,
      type: TransactionType.expense,
      amountCents: cents,
      date: date,
      description: 'x',
      accountId: 'A',
      categoryId: categoryId,
    );

/// Despesas de §5.28 (agosto a novembro de 2026).
final List<Transaction> _base = [
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
];

const _aug = YearMonth(2026, 8);
const _nov = YearMonth(2026, 11);

CategoryComparison _comparison() => categoryComparison(
  monthlyCategoryTotals(
    _base,
    ReportFilter(),
    from: _aug,
    to: _nov,
    tree: _tree,
    today: _hoje,
  ),
  month: _nov,
  averageMonths: 3,
  tree: _tree,
);

void main() {
  group('cabeçalhos', () {
    test('comparativo: sem subcategorias e com subcategorias', () {
      final rows = comparisonCsvRows(
        _comparison(),
        tree: _tree,
        includeChildren: false,
      );
      expect(rows.first, [
        'Categoria',
        'nov/2026',
        'out/2026',
        'Média 3 meses',
        'Variação',
        'Variação %',
        'Vs. média %',
      ]);
    });

    test(
      'tendência, pivot, mapa, estabelecimentos, fixo × variável e patrimônio',
      () {
        final trend = trendCsvRows(
          const [],
          expenseAverage: const [],
          balanceAverage: const [],
        );
        expect(trend.first, [
          'Mês',
          'Receitas',
          'Despesas',
          'Saldo do mês',
          'Média 3m despesas',
          'Média 3m saldo',
        ]);
        final pivot = categoryPivot(
          monthlyCategoryTotals(
            _base,
            ReportFilter(),
            from: _aug,
            to: _nov,
            tree: _tree,
            today: _hoje,
          ),
          months: [
            _aug,
            const YearMonth(2026, 9),
            const YearMonth(2026, 10),
            _nov,
          ],
          tree: _tree,
        );
        expect(pivotCsvRows(pivot, tree: _tree).first, [
          'Categoria',
          'ago/2026',
          'set/2026',
          'out/2026',
          'nov/2026',
          'Total',
        ]);
        expect(heatmapCsvRows(_emptyHeatmap()).first, [
          'Data',
          'Total',
          'Transações',
        ]);
        expect(merchantsCsvRows(const [], tree: _tree).first, [
          'Estabelecimento',
          'Chave',
          'Total',
          'Compras',
          'Ticket médio',
          'Última compra',
          'Categoria',
        ]);
        expect(fixedVariableCsvRows(const []).first, [
          'Mês',
          'Recorrentes',
          'Parcelas',
          'Fixo',
          'Variável',
          'Total',
          '% fixo',
        ]);
        expect(netWorthCsvRows(const []).first, [
          'Mês',
          'Data',
          'Contas',
          'Ativos',
          'A receber',
          'A pagar',
          'Dívida de cartão',
          'Patrimônio líquido',
        ]);
      },
    );
  });

  group('comparativo (exemplo de §5.32)', () {
    test('linha da raiz, Sem categoria e Total', () {
      final rows = comparisonCsvRows(
        _comparison(),
        tree: _tree,
        includeChildren: false,
      );
      expect(rows, hasLength(1 + 3 + 1));
      expect(rows[1], [
        'Alimentação',
        '750,00',
        '750,00',
        '516,67',
        '0,00',
        '0,0%',
        '45,2%',
      ]);
      expect(rows.last, [
        'Total',
        '830,00',
        '950,00',
        '650,00',
        '-120,00',
        '-12,6%',
        '27,7%',
      ]);
      expect(rows[3], [
        'Sem categoria',
        '30,00',
        '0,00',
        '0,00',
        '30,00',
        '',
        '',
      ]);
    });

    test('com includeChildren: filhas logo depois do pai', () {
      final rows = comparisonCsvRows(
        _comparison(),
        tree: _tree,
        includeChildren: true,
      );
      expect(rows.map((r) => r.first).take(5).toList(), [
        'Categoria',
        'Alimentação',
        'Alimentação › Mercado',
        'Alimentação › Restaurante',
        'Alimentação › (sem subcategoria)',
      ]);
      expect(rows.last.first, 'Total');
    });
  });

  group('tendência', () {
    test('início exato do texto de §5.32', () {
      final text = reportCsv(
        trendCsvRows(
          [
            const TrendPoint(
              month: YearMonth(2026, 9),
              incomeCents: 500000,
              expenseCents: 60000,
            ),
          ],
          expenseAverage: const [null],
          balanceAverage: const [null],
        ),
      );
      expect(
        text,
        startsWith(
          'Mês;Receitas;Despesas;Saldo do mês;Média 3m despesas;Média 3m saldo\r\n'
          'set/2026;5000,00;600,00;4400,00;;\r\n',
        ),
      );
    });
  });

  group('pivot', () {
    test('linha Total de §5.32', () {
      final pivot = categoryPivot(
        monthlyCategoryTotals(
          _base,
          ReportFilter(),
          from: _aug,
          to: _nov,
          tree: _tree,
          today: _hoje,
        ),
        months: [
          _aug,
          const YearMonth(2026, 9),
          const YearMonth(2026, 10),
          _nov,
        ],
        tree: _tree,
      );
      final rows = pivotCsvRows(pivot, tree: _tree);
      expect(rows.last, [
        'Total',
        '400,00',
        '600,00',
        '950,00',
        '830,00',
        '2780,00',
      ]);
      expect(rows.map((r) => r.first), contains('Alimentação › Mercado'));
    });
  });

  group('mapa de calor', () {
    test('dia com gasto em ordem crescente', () {
      final heat = SpendingHeatmap(
        from: DateTime(2026, 11),
        to: DateTime(2026, 11, 30),
        days: {
          DateTime(2026, 11, 5): DaySpending(
            date: DateTime(2026, 11, 5),
            cents: 1000,
            count: 1,
          ),
          DateTime(2026, 11, 3): DaySpending(
            date: DateTime(2026, 11, 3),
            cents: 3000,
            count: 2,
          ),
        },
        thresholds: const [],
      );
      expect(heatmapCsvRows(heat), [
        ['Data', 'Total', 'Transações'],
        ['03/11/2026', '30,00', '2'],
        ['05/11/2026', '10,00', '1'],
      ]);
    });
  });

  group('estabelecimentos', () {
    test('linha de exemplo e proteção de fórmula', () {
      final rows = merchantsCsvRows([
        MerchantTotal(
          key: 'IFOOD RESTAURANTE',
          label: 'iFood*Restaurante 12/11',
          totalCents: 10000,
          purchaseCount: 2,
          lastDate: DateTime(2026, 11, 12),
          categoryId: null,
        ),
        MerchantTotal(
          key: '1 1',
          label: '=1+1',
          totalCents: 100,
          purchaseCount: 1,
          lastDate: DateTime(2026, 11, 1),
          categoryId: 'mer',
        ),
      ], tree: _tree);
      expect(rows[1], [
        'iFood*Restaurante 12/11',
        'IFOOD RESTAURANTE',
        '100,00',
        '2',
        '50,00',
        '12/11/2026',
        'Sem categoria',
      ]);
      expect(rows[2].first, "'=1+1");
      expect(rows[2].last, 'Alimentação › Mercado');
    });
  });

  group('fixo × variável', () {
    test('linha de nov e Total de §5.32', () {
      final rows = fixedVariableCsvRows([
        const FixedVariableMonth(
          month: _nov,
          recurringCents: 154000,
          installmentCents: 20000,
          variableCents: 26000,
        ),
        const FixedVariableMonth(
          month: YearMonth(2026, 10),
          recurringCents: 154000,
          installmentCents: 20000,
          variableCents: 46000,
        ),
      ]);
      expect(rows[1], [
        'nov/2026',
        '1540,00',
        '200,00',
        '1740,00',
        '260,00',
        '2000,00',
        '87,0%',
      ]);
      expect(rows.last, [
        'Total',
        '3080,00',
        '400,00',
        '3480,00',
        '720,00',
        '4200,00',
        '82,9%',
      ]);
    });
  });

  group('patrimônio', () {
    test('ponto de out/2026 de §5.32', () {
      final rows = netWorthCsvRows([
        NetWorthPoint(
          month: const YearMonth(2026, 10),
          date: DateTime(2026, 10, 31),
          accountsCents: 870000,
          assetsCents: 4200000,
          receivableCents: 50000,
          payableCents: 80000,
          cardDebtCents: 120000,
        ),
      ]);
      expect(rows[1], [
        'out/2026',
        '31/10/2026',
        '8700,00',
        '42000,00',
        '500,00',
        '800,00',
        '1200,00',
        '49200,00',
      ]);
    });
  });
}

SpendingHeatmap _emptyHeatmap() => SpendingHeatmap(
  from: DateTime(2026, 11),
  to: DateTime(2026, 11, 30),
  days: const {},
  thresholds: const [],
);
