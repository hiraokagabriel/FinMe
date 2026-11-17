import 'package:finme/core/models/year_month.dart';
import 'package:finme/core/theme/app_theme.dart';
import 'package:finme/core/widgets/layout.dart';
import 'package:finme/features/categories/domain/category_tree.dart';
import 'package:finme/features/reports/domain/monthly_flow.dart';
import 'package:finme/features/reports/domain/report_filter.dart';
import 'package:finme/features/reports/presentation/fixed_variable_view.dart';
import 'package:finme/features/transactions/domain/installments.dart';
import 'package:finme/features/transactions/domain/transaction.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

final DateTime _hoje = DateTime(2026, 11, 30);

final CategoryTree _tree = CategoryTree(const []);

const YearMonth _out = YearMonth(2026, 10);
const YearMonth _nov = YearMonth(2026, 11);

int _n = 0;

Transaction _tx({
  TransactionType type = TransactionType.expense,
  required int amountCents,
  required DateTime date,
  String? accountId = 'A',
  String? cardId,
  String? recurringId,
}) {
  _n++;
  return Transaction(
    id: 't$_n',
    type: type,
    amountCents: amountCents,
    date: date,
    description: 'x',
    accountId: accountId,
    cardId: cardId,
    status: TransactionStatus.paid,
    recurringId: recurringId,
  );
}

/// Exemplo de §5.30: out 220000 (79,1% fixo), nov 200000 (87,0% fixo).
List<Transaction> _base() => [
  _tx(amountCents: 150000, date: DateTime(2026, 10, 5), recurringId: 'rent'),
  _tx(
    amountCents: 4000,
    date: DateTime(2026, 10, 6),
    accountId: null,
    cardId: 'K',
    recurringId: 'st',
  ),
  _tx(amountCents: 46000, date: DateTime(2026, 10, 7)),
  ...buildInstallments(
    base: _tx(amountCents: 60000, date: DateTime(2026, 10, 20)),
    count: 3,
    groupId: 'loja',
  ),
  _tx(amountCents: 150000, date: DateTime(2026, 11, 5), recurringId: 'rent'),
  _tx(
    amountCents: 4000,
    date: DateTime(2026, 11, 6),
    accountId: null,
    cardId: 'K',
    recurringId: 'st',
  ),
  _tx(amountCents: 26000, date: DateTime(2026, 11, 7)),
  _tx(
    type: TransactionType.income,
    amountCents: 500000,
    date: DateTime(2026, 11, 8),
    recurringId: 'sal',
  ),
];

List<FixedVariableMonth> _months([List<Transaction>? txs]) =>
    fixedVariableByMonth(
      txs ?? _base(),
      ReportFilter(),
      months: const [_out, _nov],
      tree: _tree,
      today: _hoje,
    );

Future<void> pumpView(
  WidgetTester tester,
  List<FixedVariableMonth> months, {
  bool hideValues = false,
  double width = 840,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.light(),
      home: Scaffold(
        body: SizedBox(
          width: width,
          height: 600,
          child: FixedVariableView(months: months, hideValues: hideValues),
        ),
      ),
    ),
  );
}

void main() {
  test('tooltip de novembro com o exemplo de §5.30', () {
    expect(
      fixedVariableTooltipText(_months()[1], hideValues: false),
      'Novembro 2026\n'
      'Recorrentes: R\$ 1.540,00\n'
      'Parcelas: R\$ 200,00\n'
      'Variável: R\$ 260,00\n'
      'Fixo: 87,0% do total',
    );
  });

  test('mês sem despesas termina em Fixo: –', () {
    final empty = _months([]).first;
    expect(
      fixedVariableTooltipText(empty, hideValues: false).split('\n').last,
      'Fixo: –',
    );
  });

  test('hideValues mascara os valores do tooltip, não o percentual', () {
    expect(
      fixedVariableTooltipText(_months()[1], hideValues: true),
      'Novembro 2026\n'
      'Recorrentes: R\$ ••••\n'
      'Parcelas: R\$ ••••\n'
      'Variável: R\$ ••••\n'
      'Fixo: 87,0% do total',
    );
  });

  testWidgets('barras empilhadas com 3 itens cada', (tester) async {
    await pumpView(tester, _months());
    final chart = tester.widget<BarChart>(find.byType(BarChart));
    expect(chart.data.barGroups, hasLength(2));
    for (final g in chart.data.barGroups) {
      expect(g.barRods.single.rodStackItems, hasLength(3));
    }
  });

  testWidgets('tooltip do toque mostra o mês certo', (tester) async {
    await pumpView(tester, _months());
    final chart = tester.widget<BarChart>(find.byType(BarChart));
    final group = chart.data.barGroups[1];
    final item = chart.data.barTouchData.touchTooltipData.getTooltipItem(
      group,
      1,
      group.barRods.single,
      0,
    );
    expect(item?.text, startsWith('Novembro 2026\n'));
  });

  testWidgets('tabela mostra percentuais por mês e no total', (tester) async {
    await pumpView(tester, _months());
    expect(find.text('79,1%'), findsOneWidget);
    expect(find.text('87,0%'), findsOneWidget);
    expect(find.text('82,9%'), findsOneWidget);
    expect(find.text('Total'), findsNWidgets(2));
    expect(
      find.text(
        'Fixo = lançamentos de recorrências e parcelas. Variável = o resto.',
      ),
      findsOneWidget,
    );
  });

  testWidgets('cabeçalho ordena as linhas; segundo toque inverte', (
    tester,
  ) async {
    await pumpView(tester, _months());
    double y(String s) => tester.getTopLeft(find.text(s)).dy;

    // % fixo: 79,1% (out) e 87,0% (nov). Primeiro toque é desc.
    await tester.tap(find.text('% fixo'));
    await tester.pump();
    expect(y('87,0%'), lessThan(y('79,1%')));

    await tester.tap(find.text('% fixo'));
    await tester.pump();
    expect(y('79,1%'), lessThan(y('87,0%')));
  });

  testWidgets('hideValues oculta os valores da tabela', (tester) async {
    await pumpView(tester, _months(), hideValues: true);
    expect(find.text('R\$ ••••'), findsWidgets);
    expect(find.text('R\$ 1.540,00'), findsNothing);
    expect(find.text('87,0%'), findsOneWidget);
  });

  testWidgets('tudo zero mostra EmptyState', (tester) async {
    await pumpView(tester, _months([]));
    expect(find.byType(BarChart), findsNothing);
    expect(find.byType(EmptyState), findsOneWidget);
    expect(
      find.text('Sem gastos no período com estes filtros.'),
      findsOneWidget,
    );
  });

  testWidgets('janela estreita rola na horizontal sem exceção', (tester) async {
    await pumpView(tester, _months(), width: 400);
    expect(tester.takeException(), isNull);
    expect(find.byType(SingleChildScrollView), findsWidgets);
  });
}
