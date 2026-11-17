import 'package:finme/core/theme/app_colors.dart';
import 'package:finme/core/theme/app_theme.dart';
import 'package:finme/core/widgets/layout.dart';
import 'package:finme/features/categories/domain/category_tree.dart';
import 'package:finme/features/categories/domain/transaction_category.dart';
import 'package:finme/features/reports/domain/report_filter.dart';
import 'package:finme/features/reports/domain/spending_heatmap.dart';
import 'package:finme/features/reports/presentation/heatmap_view.dart';
import 'package:finme/features/transactions/domain/transaction.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

final CategoryTree _tree = CategoryTree([
  const TransactionCategory(
    id: 'ali',
    name: 'Alimentação',
    kind: CategoryKind.expense,
    iconCodePoint: 0,
    colorValue: 0,
  ),
]);

int _seq = 0;

Transaction _tx(int cents, DateTime date) => Transaction(
  id: 't${_seq++}',
  type: TransactionType.expense,
  amountCents: cents,
  date: date,
  description: 'x',
  cardId: 'C',
  categoryId: 'ali',
  status: TransactionStatus.paid,
);

/// Exemplo de §5.31 (01/11..30/11/2026): 8 dias, total 36000, maior dia 08/11.
SpendingHeatmap _specHeatmap() {
  final txs = [
    _tx(1000, DateTime(2026, 11, 1)),
    _tx(2000, DateTime(2026, 11, 2)),
    _tx(1500, DateTime(2026, 11, 3)),
    _tx(1500, DateTime(2026, 11, 3)),
    _tx(4000, DateTime(2026, 11, 4)),
    _tx(5000, DateTime(2026, 11, 5)),
    _tx(6000, DateTime(2026, 11, 6)),
    _tx(7000, DateTime(2026, 11, 7)),
    _tx(8000, DateTime(2026, 11, 8)),
  ];
  return spendingHeatmap(
    txs,
    ReportFilter(),
    from: DateTime(2026, 11, 1),
    to: DateTime(2026, 11, 30),
    tree: _tree,
  );
}

Finder _dayCells() => find.byWidgetPredicate(
  (w) =>
      w.key is ValueKey<String> &&
      (w.key as ValueKey<String>).value.startsWith('heatmap-day-'),
);

Future<void> _pump(
  WidgetTester tester,
  SpendingHeatmap heatmap, {
  bool hideValues = false,
  double width = 900,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.light(),
      home: Scaffold(
        body: SizedBox(
          width: width,
          height: 600,
          child: HeatmapView(heatmap: heatmap, hideValues: hideValues),
        ),
      ),
    ),
  );
}

void main() {
  group('heatmapTooltipText', () {
    test('dia com gasto: total e número de transações', () {
      final s = DaySpending(date: DateTime(2026, 11, 3), cents: 3000, count: 2);
      expect(
        heatmapTooltipText(DateTime(2026, 11, 3), s, hideValues: false),
        '03/11/2026 · R\$ 30,00 · 2 transações',
      );
    });

    test('uma transação usa o singular', () {
      final s = DaySpending(date: DateTime(2026, 11, 3), cents: 3000, count: 1);
      expect(
        heatmapTooltipText(DateTime(2026, 11, 3), s, hideValues: false),
        endsWith('1 transação'),
      );
    });

    test('dia sem gasto', () {
      expect(
        heatmapTooltipText(DateTime(2026, 11, 3), null, hideValues: false),
        '03/11/2026 · sem gastos',
      );
    });

    test('hideValues mascara o valor', () {
      final s = DaySpending(date: DateTime(2026, 11, 3), cents: 3000, count: 2);
      expect(
        heatmapTooltipText(DateTime(2026, 11, 3), s, hideValues: true),
        '03/11/2026 · R\$ •••• · 2 transações',
      );
    });
  });

  testWidgets('30 células de dia e posição da grade de novembro/2026', (
    tester,
  ) async {
    await _pump(tester, _specHeatmap());
    expect(tester.takeException(), isNull);
    expect(_dayCells(), findsNWidgets(30));

    final first = tester.getTopLeft(
      find.byKey(const ValueKey('heatmap-day-20261101')),
    );
    final last = tester.getTopLeft(
      find.byKey(const ValueKey('heatmap-day-20261130')),
    );
    // 01/11 é domingo (linha 0, coluna 0); 30/11 é segunda (linha 1, coluna 4).
    expect(last.dx - first.dx, closeTo(4 * 14, 0.5));
    expect(last.dy - first.dy, closeTo(1 * 14, 0.5));
  });

  testWidgets('tooltip de cada dia traz total e transações', (tester) async {
    await _pump(tester, _specHeatmap());
    Tooltip tooltipOf(String key) =>
        tester.widget<Tooltip>(find.byKey(ValueKey('heatmap-day-$key')));
    expect(
      tooltipOf('20261103').message,
      '03/11/2026 · R\$ 30,00 · 2 transações',
    );
    expect(tooltipOf('20261110').message, '10/11/2026 · sem gastos');
  });

  testWidgets('resumo com total, dias com gasto e maior dia', (tester) async {
    await _pump(tester, _specHeatmap());
    expect(
      find.text(
        'Total R\$ 360,00 · 8 dias com gasto · Maior dia: 08/11 (R\$ 80,00)',
      ),
      findsOneWidget,
    );
  });

  testWidgets('nível máximo usa primary; legenda sem caractere ▢', (
    tester,
  ) async {
    await _pump(tester, _specHeatmap());
    // 08/11 (8000) é o maior dia: nível 4.
    final cell = find.descendant(
      of: find.byKey(const ValueKey('heatmap-day-20261108')),
      matching: find.byType(Container),
    );
    final decoration =
        tester.widget<Container>(cell).decoration! as BoxDecoration;
    final primary = tester.element(find.byType(HeatmapView)).colors.primary;
    expect(decoration.color, primary);

    expect(find.textContaining('▢'), findsNothing);
    expect(find.text('Menos'), findsOneWidget);
    expect(find.text('Mais'), findsOneWidget);
  });

  testWidgets('troca de heatmap atualiza o resumo', (tester) async {
    await _pump(tester, _specHeatmap());
    final um = spendingHeatmap(
      [_tx(1000, DateTime(2026, 11, 1))],
      ReportFilter(),
      from: DateTime(2026, 11, 1),
      to: DateTime(2026, 11, 30),
      tree: _tree,
    );
    await _pump(tester, um);
    expect(
      find.text(
        'Total R\$ 10,00 · 1 dia com gasto · Maior dia: 01/11 (R\$ 10,00)',
      ),
      findsOneWidget,
    );
  });

  testWidgets('hideValues mascara resumo e tooltips', (tester) async {
    await _pump(tester, _specHeatmap(), hideValues: true);
    expect(
      find.text(
        'Total R\$ •••• · 8 dias com gasto · Maior dia: 08/11 (R\$ ••••)',
      ),
      findsOneWidget,
    );
    final tooltip = tester.widget<Tooltip>(
      find.byKey(const ValueKey('heatmap-day-20261103')),
    );
    expect(tooltip.message, '03/11/2026 · R\$ •••• · 2 transações');
  });

  testWidgets('intervalo de 12 meses renderiza e rola na horizontal', (
    tester,
  ) async {
    final heatmap = spendingHeatmap(
      [_tx(1000, DateTime(2025, 12, 1)), _tx(2000, DateTime(2026, 11, 30))],
      ReportFilter(),
      from: DateTime(2025, 12, 1),
      to: DateTime(2026, 11, 30),
      tree: _tree,
    );
    await _pump(tester, heatmap, width: 800);
    expect(tester.takeException(), isNull);
    expect(_dayCells(), findsNWidgets(365));
    expect(
      find.byWidgetPredicate(
        (w) => w is ListView && w.scrollDirection == Axis.horizontal,
      ),
      findsOneWidget,
    );
  });

  testWidgets('60 meses monta só as colunas visíveis e rola até o fim', (
    tester,
  ) async {
    final heatmap = spendingHeatmap(
      [_tx(1000, DateTime(2021, 12, 1)), _tx(2000, DateTime(2026, 11, 30))],
      ReportFilter(),
      from: DateTime(2021, 12, 1),
      to: DateTime(2026, 11, 30),
      tree: _tree,
    );
    await _pump(tester, heatmap, width: 800);
    expect(tester.takeException(), isNull);
    expect(_dayCells().evaluate().length, lessThan(400));

    await tester.drag(find.byType(ListView), const Offset(-100000, 0));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.byKey(const ValueKey('heatmap-day-20261130')), findsOneWidget);
  });

  testWidgets('sem gastos mostra EmptyState', (tester) async {
    final heatmap = spendingHeatmap(
      const [],
      ReportFilter(),
      from: DateTime(2026, 11, 1),
      to: DateTime(2026, 11, 30),
      tree: _tree,
    );
    await _pump(tester, heatmap);
    expect(find.byType(EmptyState), findsOneWidget);
    expect(
      find.text('Sem gastos no período com estes filtros.'),
      findsOneWidget,
    );
    expect(_dayCells(), findsNothing);
  });
}
