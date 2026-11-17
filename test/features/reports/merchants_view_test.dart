import 'package:finme/app/app_scope.dart';
import 'package:finme/app/bootstrap.dart';
import 'package:finme/core/services/record_store.dart';
import 'package:finme/core/theme/app_theme.dart';
import 'package:finme/features/categories/domain/category_tree.dart';
import 'package:finme/features/reports/domain/merchant_report.dart';
import 'package:finme/features/reports/presentation/merchants_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Monta [body] com AppScope real (store em memória) e tema claro.
Future<AppServices> _pump(WidgetTester tester, Widget body) async {
  final services = (await tester.runAsync(
    () => bootstrap(
      storeFactory: (_) => MemoryRecordStore(),
      clock: () => DateTime(2026, 11, 14),
    ),
  ))!;
  await tester.pumpWidget(
    AppScope(
      services: services,
      child: MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(body: body),
      ),
    ),
  );
  return services;
}

final CategoryTree _tree = CategoryTree([]);

MerchantTotal _m(
  String key,
  String label,
  int total,
  int count,
  DateTime last,
) => MerchantTotal(
  key: key,
  label: label,
  totalCents: total,
  purchaseCount: count,
  lastDate: last,
  categoryId: null,
);

/// Exemplo de §5.31 (já na ordem do domínio: total desc).
List<MerchantTotal> _exemplo() => [
  _m('LOJA EXEMPLO', 'LOJA EXEMPLO', 30000, 1, DateTime(2026, 11, 20)),
  _m(
    'IFOOD RESTAURANTE',
    'iFood*Restaurante 12/11',
    10000,
    2,
    DateTime(2026, 11, 12),
  ),
  _m('UBER TRIP', 'Uber Trip', 7500, 3, DateTime(2026, 11, 5)),
  _m('123456', '123456', 700, 1, DateTime(2026, 10, 1)),
];

Future<AppServices> _pumpView(
  WidgetTester tester, {
  required List<MerchantTotal> merchants,
  bool ultra = true,
}) => _pump(
  tester,
  MerchantsView(merchants: merchants, tree: _tree, ultra: ultra),
);

void main() {
  testWidgets('Ultra: colunas, apoio da chave e rodapé', (tester) async {
    await _pumpView(tester, merchants: _exemplo());
    expect(find.text('Ticket médio'), findsOneWidget);
    expect(find.text('Última compra'), findsOneWidget);
    expect(find.text('Categoria'), findsOneWidget);
    expect(
      tester.getTopLeft(find.text('LOJA EXEMPLO')).dy,
      lessThan(tester.getTopLeft(find.text('iFood*Restaurante 12/11')).dy),
    );
    expect(find.text('IFOOD RESTAURANTE'), findsOneWidget);
    expect(find.text('Sem categoria'), findsWidgets);
    expect(find.text('4 estabelecimentos'), findsOneWidget);
  });

  testWidgets('Clicar Compras ordena desc: Uber Trip (3) primeiro', (
    tester,
  ) async {
    await _pumpView(tester, merchants: _exemplo());
    await tester.tap(find.text('Compras'));
    await tester.pump();
    expect(
      tester.getTopLeft(find.text('Uber Trip')).dy,
      lessThan(tester.getTopLeft(find.text('LOJA EXEMPLO')).dy),
    );
  });

  testWidgets('Simples: só Estabelecimento, Total e Compras', (tester) async {
    await _pumpView(tester, merchants: _exemplo(), ultra: false);
    expect(find.text('Estabelecimento'), findsOneWidget);
    expect(find.text('Total'), findsOneWidget);
    expect(find.text('Compras'), findsOneWidget);
    expect(find.text('Ticket médio'), findsNothing);
    expect(find.text('Categoria'), findsNothing);
    expect(find.text('IFOOD RESTAURANTE'), findsNothing);
  });

  testWidgets('60 estabelecimentos: 50 linhas e Mostrar todos (60)', (
    tester,
  ) async {
    final many = [
      for (var i = 1; i <= 60; i++)
        _m(
          'LOJA ${i.toString().padLeft(2, '0')}',
          'Loja ${i.toString().padLeft(2, '0')}',
          100000 - i * 100,
          1,
          DateTime(2026, 11, 1),
        ),
    ];
    await _pumpView(tester, merchants: many);
    final scrollable = find.descendant(
      of: find.byType(ListView),
      matching: find.byType(Scrollable),
    );
    await tester.scrollUntilVisible(
      find.byKey(const Key('merchants-show-all')),
      200,
      scrollable: scrollable,
    );
    expect(find.text('Loja 50'), findsOneWidget);
    expect(find.text('Loja 51'), findsNothing);
    expect(find.text('Mostrar todos (60)'), findsOneWidget);
    await tester.tap(find.byKey(const Key('merchants-show-all')));
    await tester.pump();

    await tester.scrollUntilVisible(
      find.text('Loja 60'),
      200,
      scrollable: scrollable,
    );
    expect(find.text('Loja 60'), findsOneWidget);
  });

  testWidgets('Vazio: mensagem de estado vazio', (tester) async {
    await _pumpView(tester, merchants: const []);
    expect(
      find.text('Sem compras no período com estes filtros.'),
      findsOneWidget,
    );
  });

  testWidgets('hideValues: valores viram R\$ ••••', (tester) async {
    final services = await _pumpView(tester, merchants: _exemplo());
    await tester.runAsync(
      () => services.settings.update((s) => s.copyWith(hideValues: true)),
    );
    await tester.pump();
    expect(find.text('R\$ 300,00'), findsNothing);
    expect(find.text('R\$ ••••'), findsWidgets);
  });
}
