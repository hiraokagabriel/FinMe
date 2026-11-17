import 'package:finme/core/models/year_month.dart';
import 'package:finme/core/theme/app_theme.dart';
import 'package:finme/core/widgets/layout.dart';
import 'package:finme/features/net_worth/domain/net_worth.dart';
import 'package:finme/features/net_worth/presentation/net_worth_chart.dart';
import 'package:finme/features/reports/presentation/net_worth_report_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Exemplo de §5.26 (set, out, nov de 2026). Líquidos: set 48.000, out 49.200, nov 46.700.
NetWorthPoint _point(
  YearMonth month,
  DateTime date, {
  required int accounts,
  required int assets,
  int receivable = 0,
  int payable = 0,
  int card = 0,
}) => NetWorthPoint(
  month: month,
  date: date,
  accountsCents: accounts,
  assetsCents: assets,
  receivableCents: receivable,
  payableCents: payable,
  cardDebtCents: card,
);

final List<NetWorthPoint> _trio = [
  _point(
    const YearMonth(2026, 9),
    DateTime(2026, 9, 30),
    accounts: 800000,
    assets: 4000000,
  ),
  _point(
    const YearMonth(2026, 10),
    DateTime(2026, 10, 31),
    accounts: 870000,
    assets: 4200000,
    receivable: 50000,
    payable: 80000,
    card: 120000,
  ),
  _point(
    const YearMonth(2026, 11),
    DateTime(2026, 11, 15),
    accounts: 900000,
    assets: 4200000,
    receivable: 50000,
    payable: 80000,
    card: 400000,
  ),
];

/// Célula da tabela: o eixo do gráfico também imprime os meses.
Finder _cell(String text) =>
    find.descendant(of: find.byType(DataTable), matching: find.text(text));

Future<void> _pump(
  WidgetTester tester,
  List<NetWorthPoint> points, {
  bool hideValues = false,
}) async {
  // Largura para a tabela inteira (rola na horizontal só em janela estreita).
  await tester.binding.setSurfaceSize(const Size(2000, 1000));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.light(),
      home: Scaffold(
        body: NetWorthReportView(points: points, hideValues: hideValues),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('três meses: gráfico, tabela com meses, líquido e variação', (
    tester,
  ) async {
    await _pump(tester, _trio);
    expect(find.byType(NetWorthChart), findsOneWidget);
    expect(_cell('set/2026'), findsOneWidget);
    expect(_cell('out/2026'), findsOneWidget);
    expect(_cell('nov/2026'), findsOneWidget);
    // O eixo do gráfico também pode imprimir 46.700: conferir só na tabela.
    expect(_cell('R\$ 46.700,00'), findsOneWidget);
    expect(_cell('-R\$ 2.500,00'), findsOneWidget);
    expect(_cell('–'), findsOneWidget);
    expect(
      find.textContaining('Histórico disponível: últimos 24 meses.'),
      findsNothing,
    );
  });

  testWidgets('lista vazia mostra estado vazio sem gráfico nem tabela', (
    tester,
  ) async {
    await _pump(tester, const []);
    expect(
      find.text('Sem histórico de patrimônio no período.'),
      findsOneWidget,
    );
    expect(find.byType(NetWorthChart), findsNothing);
    expect(find.byType(DataTable), findsNothing);
    expect(find.byType(EmptyState), findsOneWidget);
  });

  testWidgets('todos os componentes zerados mostram estado vazio', (
    tester,
  ) async {
    await _pump(tester, [
      _point(
        const YearMonth(2026, 9),
        DateTime(2026, 9, 30),
        accounts: 0,
        assets: 0,
      ),
      _point(
        const YearMonth(2026, 10),
        DateTime(2026, 10, 31),
        accounts: 0,
        assets: 0,
      ),
    ]);
    expect(find.byType(NetWorthChart), findsNothing);
    expect(find.byType(DataTable), findsNothing);
    expect(find.byType(EmptyState), findsOneWidget);
  });

  testWidgets('apoio explica sinal de A pagar e dívida de cartão', (
    tester,
  ) async {
    await _pump(tester, _trio);
    expect(
      find.textContaining(
        'A pagar e dívida de cartão aparecem negativos aqui e positivos no CSV.',
      ),
      findsOneWidget,
    );
  });

  testWidgets('hideValues não mostra nenhum valor em claro', (tester) async {
    await _pump(tester, _trio, hideValues: true);
    final texts = tester
        .widgetList<Text>(find.byType(Text))
        .map((t) => t.data ?? '');
    expect(texts.where((t) => RegExp(r'R\$ \d').hasMatch(t)), isEmpty);
    expect(find.text('R\$ ••••'), findsWidgets);
    expect(find.text('R\$ 46.700,00'), findsNothing);
    expect(_cell('nov/2026'), findsOneWidget);
  });

  testWidgets('clicar em Líquido ordena desc; clicar de novo inverte', (
    tester,
  ) async {
    await _pump(tester, _trio);
    final out = _cell('out/2026');
    final nov = _cell('nov/2026');
    final set = _cell('set/2026');

    await tester.tap(find.text('Líquido'));
    await tester.pumpAndSettle();
    // Desc por líquido: out 49.200 > set 48.000 > nov 46.700.
    expect(tester.getTopLeft(out).dy, lessThan(tester.getTopLeft(set).dy));
    expect(tester.getTopLeft(set).dy, lessThan(tester.getTopLeft(nov).dy));

    await tester.tap(find.text('Líquido'));
    await tester.pumpAndSettle();
    expect(tester.getTopLeft(nov).dy, lessThan(tester.getTopLeft(set).dy));
  });
}
