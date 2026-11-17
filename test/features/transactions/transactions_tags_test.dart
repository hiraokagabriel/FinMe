import 'package:finme/app/app_scope.dart';
import 'package:finme/app/bootstrap.dart';
import 'package:finme/app/seed.dart';
import 'package:finme/core/models/app_settings.dart';
import 'package:finme/core/models/year_month.dart';
import 'package:finme/core/services/record_store.dart';
import 'package:finme/core/theme/app_theme.dart';
import 'package:finme/features/categories/domain/category_tree.dart';
import 'package:finme/features/categories/domain/transaction_category.dart';
import 'package:finme/features/transactions/domain/transaction.dart';
import 'package:finme/features/transactions/presentation/transaction_filters.dart';
import 'package:finme/features/transactions/presentation/transaction_row.dart';
import 'package:finme/features/transactions/presentation/transactions_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const _nov = YearMonth(2026, 11);

const _ali = TransactionCategory(
  id: 'ali',
  name: 'Alimentação',
  kind: CategoryKind.expense,
  iconCodePoint: 1,
  colorValue: 1,
);
const _mercadoX = TransactionCategory(
  id: 'mer',
  name: 'Mercado X',
  kind: CategoryKind.expense,
  iconCodePoint: 1,
  colorValue: 1,
  parentId: 'ali',
);
const _tra = TransactionCategory(
  id: 'tra',
  name: 'Transporte',
  kind: CategoryKind.expense,
  iconCodePoint: 1,
  colorValue: 1,
);

Transaction _pure(String id, int day, String category, List<String> tags) =>
    Transaction(
      id: id,
      type: TransactionType.expense,
      amountCents: 1000,
      date: DateTime(2026, 11, day),
      description: 'Compra $id',
      categoryId: category,
      tags: tags,
    );

// A em Alimentação, B em Mercado X (filha) com #viagem, C em Transporte com #Trabalho.
final _a = _pure('a', 10, 'ali', const []);
final _b = _pure('b', 9, 'mer', const ['viagem']);
final _c = _pure('c', 8, 'tra', const ['Trabalho']);

List<String> _ids(TransactionFilter f, {CategoryTree? tree}) => [
  for (final t in visibleTransactions([_a, _b, _c], _nov, f, tree: tree)) t.id,
];

Future<AppServices> _services(WidgetTester tester, AppMode mode) async {
  return (await tester.runAsync(() async {
    final s = await bootstrap(
      storeFactory: (_) => MemoryRecordStore(),
      clock: () => DateTime(2026, 11, 15),
    );
    await seedDemo(s);
    final mercado = s.categories.all.firstWhere((c) => c.id == 'cat_mercado');
    await s.categories.upsert(
      TransactionCategory(
        id: 'cat_mercado_x',
        name: 'Mercado X',
        kind: mercado.kind,
        iconCodePoint: mercado.iconCodePoint,
        colorValue: mercado.colorValue,
        parentId: 'cat_alimentacao',
      ),
    );
    final account = s.accounts.all.first.id;
    Transaction tx(
      String id,
      String description,
      int day,
      String category,
      List<String> tags,
    ) => Transaction(
      id: id,
      type: TransactionType.expense,
      amountCents: 1000,
      date: DateTime(2026, 11, day),
      description: description,
      categoryId: category,
      accountId: account,
      tags: tags,
    );
    await s.transactions.replaceAll([
      tx('a', 'Restaurante', 10, 'cat_alimentacao', const []),
      tx('b', 'Feira', 9, 'cat_mercado_x', const ['viagem']),
      tx('c', 'Uber', 8, 'cat_transporte', const ['Trabalho']),
    ]);
    await s.settings.update((x) => x.copyWith(mode: mode));
    return s;
  }))!;
}

Future<void> _pump(WidgetTester tester, AppServices s) async {
  await tester.binding.setSurfaceSize(const Size(1400, 900));
  await tester.pumpWidget(
    AppScope(
      services: s,
      child: MaterialApp(
        theme: AppTheme.light(),
        home: const Scaffold(body: TransactionsPage()),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

/// Abre o menu de tags e toca no item [label].
/// O centro calculado do item fica fora do hit test; o efeito é conferido pelas contagens.
Future<void> _tagMenu(WidgetTester tester, String label) async {
  await tester.tap(find.byKey(const Key('filter-tags')));
  await tester.pumpAndSettle();
  await tester.tap(find.text(label).last, warnIfMissed: false);
  await tester.pumpAndSettle();
}

void main() {
  group('domínio (filtro com árvore e tags)', () {
    final tree = CategoryTree([_ali, _mercadoX, _tra]);

    test('categoria raiz casa as filhas; filha só casa ela mesma', () {
      expect(_ids(const TransactionFilter(categoryId: 'ali'), tree: tree), [
        'a',
        'b',
      ]);
      expect(_ids(const TransactionFilter(categoryId: 'mer'), tree: tree), [
        'b',
      ]);
      // Sem árvore a raiz não enxerga as filhas.
      expect(_ids(const TransactionFilter(categoryId: 'ali')), ['a']);
    });

    test('tags: OR entre as chaves; busca de texto casa tags', () {
      expect(_ids(const TransactionFilter(tags: {'VIAGEM'})), ['b']);
      expect(_ids(const TransactionFilter(tags: {'TRABALHO', 'VIAGEM'})), [
        'b',
        'c',
      ]);
      expect(_ids(const TransactionFilter(query: 'trabalho')), ['c']);
      expect(_ids(const TransactionFilter(query: 'viagem')), ['b']);
    });

    test('tags entram em hasCriteria e sobrevivem a copyWith', () {
      const f = TransactionFilter(tags: {'VIAGEM'});
      expect(f.hasCriteria, isTrue);
      expect(f.copyWith(query: 'x').tags, {'VIAGEM'});
      expect(f.copyWith(tags: const {}).hasCriteria, isFalse);
    });
  });

  testWidgets('Ultra: filtro de categoria inclui as filhas', (tester) async {
    final s = await _services(tester, AppMode.ultra);
    await _pump(tester, s);

    // Segundo dropdown da barra é "Categoria" (o primeiro é "Origem").
    await tester.tap(find.byType(DropdownButtonFormField<String?>).at(1));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Alimentação').last);
    await tester.pumpAndSettle();
    expect(find.text('Restaurante'), findsOneWidget);
    expect(find.text('Feira'), findsOneWidget);
    expect(find.text('Uber'), findsNothing);

    await tester.tap(find.byType(DropdownButtonFormField<String?>).at(1));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Alimentação › Mercado X').last);
    await tester.pumpAndSettle();
    expect(find.text('Restaurante'), findsNothing);
    expect(find.text('Feira'), findsOneWidget);
    expect(find.text('Uber'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Ultra: filtro de tags marca, soma e limpa', (tester) async {
    final s = await _services(tester, AppMode.ultra);
    await _pump(tester, s);

    await _tagMenu(tester, 'viagem');
    expect(find.text('Tags (1)'), findsOneWidget);
    expect(find.text('Feira'), findsOneWidget);
    expect(find.text('Restaurante'), findsNothing);
    expect(find.text('Uber'), findsNothing);

    await _tagMenu(tester, 'Trabalho');
    expect(find.text('Tags (2)'), findsOneWidget);
    expect(find.text('Feira'), findsOneWidget);
    expect(find.text('Uber'), findsOneWidget);
    expect(find.text('Restaurante'), findsNothing);

    await tester.tap(find.byKey(const Key('filter-tags')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Limpar tags'));
    await tester.pumpAndSettle();
    expect(find.text('Tags'), findsOneWidget);
    expect(find.text('Restaurante'), findsOneWidget);
    expect(find.text('Feira'), findsOneWidget);
    expect(find.text('Uber'), findsOneWidget);
  });

  testWidgets('Ultra: busca casa a tag e a linha mostra as tags', (
    tester,
  ) async {
    final s = await _services(tester, AppMode.ultra);
    await _pump(tester, s);

    expect(find.text('#viagem'), findsOneWidget);

    await tester.enterText(
      find.byWidgetPredicate(
        (w) =>
            w is TextField &&
            w.decoration?.hintText == 'Buscar descrição ou notas',
      ),
      'trabalho',
    );
    await tester.pumpAndSettle();
    expect(find.text('Uber'), findsOneWidget);
    expect(find.text('Feira'), findsNothing);
    expect(find.text('Restaurante'), findsNothing);
  });

  testWidgets('Simples: sem filtro de tags e sem #tag na linha', (
    tester,
  ) async {
    final s = await _services(tester, AppMode.simple);
    await _pump(tester, s);

    expect(find.byKey(const Key('filter-tags')), findsNothing);
    expect(find.text('#viagem'), findsNothing);
    expect(find.text('Feira'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('TransactionRow: rótulo substitui o nome; tags só no Ultra', (
    tester,
  ) async {
    final s = (await tester.runAsync(
      () => bootstrap(
        storeFactory: (_) => MemoryRecordStore(),
        clock: () => DateTime(2026, 11, 15),
      ),
    ))!;
    Future<void> row({required bool ultra}) async {
      await tester.pumpWidget(
        AppScope(
          services: s,
          child: MaterialApp(
            theme: AppTheme.light(),
            home: Scaffold(
              body: SizedBox(
                width: 1000,
                child: TransactionRow(
                  transaction: _b,
                  ultra: ultra,
                  past: false,
                  category: _mercadoX,
                  categoryLabel: 'Alimentação › Mercado X',
                  onAction: (_) {},
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pump();
    }

    await row(ultra: true);
    expect(find.text('Alimentação › Mercado X'), findsOneWidget);
    expect(find.text('#viagem'), findsOneWidget);

    await row(ultra: false);
    expect(find.text('Alimentação › Mercado X'), findsOneWidget);
    expect(find.text('#viagem'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
