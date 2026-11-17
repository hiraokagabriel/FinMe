import 'package:finme/core/models/year_month.dart';
import 'package:finme/core/theme/app_theme.dart';
import 'package:finme/features/accounts/domain/account.dart';
import 'package:finme/features/cards/domain/payment_card.dart';
import 'package:finme/features/categories/domain/category_tree.dart';
import 'package:finme/features/categories/domain/transaction_category.dart';
import 'package:finme/features/reports/domain/report_filter.dart';
import 'package:finme/features/reports/presentation/report_filter_bar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

final _today = DateTime(2026, 11, 15);

const _accounts = [
  Account(
    id: 'A',
    name: 'Conta A',
    bankName: 'Banco',
    type: AccountType.checking,
    initialBalanceCents: 0,
    colorValue: 0,
  ),
  Account(
    id: 'V',
    name: 'Conta Velha',
    bankName: 'Banco',
    type: AccountType.checking,
    initialBalanceCents: 0,
    colorValue: 0,
    archived: true,
  ),
];

const _cards = [
  PaymentCard(
    id: 'K',
    name: 'Cartão K',
    bankName: 'Banco',
    brand: CardBrand.visa,
    kind: CardKind.credit,
    last4: '1234',
    closingDay: 5,
    dueDay: 10,
    colorValue: 0,
  ),
];

TransactionCategory _cat(String id, String name, [String? parentId]) =>
    TransactionCategory(
      id: id,
      name: name,
      kind: CategoryKind.expense,
      iconCodePoint: 0,
      colorValue: 0,
      parentId: parentId,
    );

final _tree = CategoryTree([
  _cat('ali', 'Alimentação'),
  _cat('mer', 'Mercado', 'ali'),
  _cat('res', 'Restaurante', 'ali'),
  _cat('tra', 'Transporte'),
]);

/// Monta a barra e devolve a lista de filtros emitidos por `onChanged`.
Future<List<ReportFilter>> pumpBar(
  WidgetTester tester, {
  ReportFilter? filter,
  bool ultra = true,
  List<String> tags = const ['Viagem', 'casa'],
}) async {
  final current = filter ?? ReportFilter();
  final emitted = <ReportFilter>[];
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.light(),
      home: Scaffold(
        body: SizedBox(
          width: 900,
          child: ReportFilterBar(
            filter: current,
            range: resolveReportRange(current, _today),
            ultra: ultra,
            onChanged: emitted.add,
            accounts: _accounts,
            cards: _cards,
            categoryTree: _tree,
            tags: tags,
          ),
        ),
      ),
    ),
  );
  return emitted;
}

void main() {
  testWidgets('Simples mostra só período e intervalo', (tester) async {
    await pumpBar(tester, ultra: false);

    expect(find.byKey(const Key('report-period')), findsOneWidget);
    expect(find.text('dez/2025 – nov/2026'), findsOneWidget);
    expect(find.byKey(const Key('report-filter-accounts')), findsNothing);
    expect(find.byKey(const Key('report-filter-categories')), findsNothing);
    expect(find.byKey(const Key('report-filter-tags')), findsNothing);
    expect(find.byKey(const Key('report-flow')), findsNothing);
    expect(find.byKey(const Key('report-planned')), findsNothing);
  });

  testWidgets('Personalizado emite preset custom e mostra De/Até', (
    tester,
  ) async {
    final emitted = await pumpBar(tester, ultra: false);

    await tester.tap(find.byKey(const Key('report-period')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Personalizado').last);
    await tester.pumpAndSettle();

    expect(emitted.single.preset, ReportPeriodPreset.custom);
    expect(emitted.single.customFrom, const YearMonth(2025, 12));
    expect(emitted.single.customTo, const YearMonth(2026, 11));
  });

  testWidgets('De com custom emite customFrom novo', (tester) async {
    final custom = ReportFilter(
      preset: ReportPeriodPreset.custom,
      customFrom: const YearMonth(2026, 1),
      customTo: const YearMonth(2026, 11),
    );
    final emitted = await pumpBar(tester, filter: custom, ultra: false);

    expect(find.byKey(const Key('report-from')), findsOneWidget);
    expect(find.byKey(const Key('report-to')), findsOneWidget);

    await tester.tap(
      find.descendant(
        of: find.byKey(const Key('report-from')),
        matching: find.byIcon(Icons.chevron_left),
      ),
    );
    await tester.pump();

    expect(emitted.single.customFrom, const YearMonth(2025, 12));
  });

  testWidgets('Contas e cartões: diálogo aplica e conta no botão', (
    tester,
  ) async {
    final emitted = await pumpBar(tester);

    await tester.tap(find.byKey(const Key('report-filter-accounts')));
    await tester.pumpAndSettle();
    expect(find.text('Conta A'), findsOneWidget);
    expect(find.text('Conta Velha (arquivada)'), findsOneWidget);
    expect(find.text('Cartão K'), findsOneWidget);

    await tester.tap(find.text('Conta A'));
    await tester.tap(find.text('Cartão K'));
    await tester.tap(find.text('Aplicar'));
    await tester.pumpAndSettle();

    expect(emitted.single.accountIds, {'A'});
    expect(emitted.single.cardIds, {'K'});
  });

  testWidgets('botão de contas mostra a contagem com filtro ativo', (
    tester,
  ) async {
    await pumpBar(
      tester,
      filter: ReportFilter(accountIds: {'A'}, cardIds: {'K'}),
    );

    expect(find.text('Contas e cartões: 2'), findsOneWidget);
  });

  testWidgets('categorias: subcategoria indentada, Limpar e Cancelar', (
    tester,
  ) async {
    final emitted = await pumpBar(
      tester,
      filter: ReportFilter(categoryIds: {'ali'}),
    );

    await tester.tap(find.byKey(const Key('report-filter-categories')));
    await tester.pumpAndSettle();

    final child = tester.widget<CheckboxListTile>(
      find.widgetWithText(CheckboxListTile, 'Alimentação › Mercado'),
    );
    expect(child.contentPadding, const EdgeInsets.only(left: 24));

    await tester.tap(find.text('Cancelar'));
    await tester.pumpAndSettle();
    expect(emitted, isEmpty);

    await tester.tap(find.byKey(const Key('report-filter-categories')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Limpar'));
    await tester.pumpAndSettle();

    expect(emitted.single.categoryIds, isEmpty);
  });

  testWidgets('tags: seleção vira tagKey; sem tags o botão fica desabilitado', (
    tester,
  ) async {
    final emitted = await pumpBar(tester);

    await tester.tap(find.byKey(const Key('report-filter-tags')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Viagem'));
    await tester.tap(find.text('Aplicar'));
    await tester.pumpAndSettle();

    expect(emitted.single.tagKeys, {'VIAGEM'});

    await pumpBar(tester, tags: const []);
    final button = tester.widget<OutlinedButton>(
      find.byKey(const Key('report-filter-tags')),
    );
    expect(button.onPressed, isNull);
  });

  testWidgets('Receitas limpa categorias; provisionados; Limpar filtros', (
    tester,
  ) async {
    final emitted = await pumpBar(
      tester,
      filter: ReportFilter(categoryIds: {'ali'}, cardIds: {'K'}),
    );

    await tester.tap(find.text('Receitas'));
    await tester.pump();
    expect(emitted.last.flow, ReportFlow.income);
    expect(emitted.last.categoryIds, isEmpty);

    await tester.tap(find.text('Incluir provisionados'));
    await tester.pump();
    expect(emitted.last.includePlanned, isTrue);

    await tester.tap(find.byKey(const Key('report-clear')));
    await tester.pump();
    expect(emitted.last, ReportFilter(preset: ReportPeriodPreset.last12));
  });

  testWidgets('Limpar filtros só aparece com filtro de escopo', (tester) async {
    await pumpBar(tester);

    expect(find.byKey(const Key('report-clear')), findsNothing);
  });
}
