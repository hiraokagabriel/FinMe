import 'package:finme/app/app_scope.dart';
import 'package:finme/app/bootstrap.dart';
import 'package:finme/core/services/record_store.dart';
import 'package:finme/core/theme/app_theme.dart';
import 'package:finme/features/categories/domain/transaction_category.dart';
import 'package:finme/features/dashboard/presentation/dashboard_sections.dart';
import 'package:finme/features/dashboard/presentation/dashboard_summary.dart';
import 'package:finme/features/transactions/domain/transaction.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Categorias padrão + 'Mercado X' (filha de Alimentação) e despesas pagas em nov/2026.
Future<AppServices> _boot(WidgetTester tester) async {
  return (await tester.runAsync(() async {
    final s = await bootstrap(
      storeFactory: (_) => MemoryRecordStore(),
      clock: () => DateTime(2026, 11, 15),
    );
    await s.categories.upsert(
      TransactionCategory(
        id: 'cat_mercado_x',
        name: 'Mercado X',
        kind: CategoryKind.expense,
        iconCodePoint: Icons.shopping_cart.codePoint,
        colorValue: 0xFF42A5F5,
        parentId: 'cat_alimentacao',
      ),
    );
    final despesas = [
      ('t_padaria', 10000, 'cat_alimentacao'),
      ('t_mercado', 50000, 'cat_mercado_x'),
      ('t_onibus', 3000, 'cat_transporte'),
    ];
    for (final (id, cents, cat) in despesas) {
      await s.transactions.upsert(
        Transaction(
          id: id,
          type: TransactionType.expense,
          amountCents: cents,
          date: DateTime(2026, 11, 10),
          description: id,
          categoryId: cat,
        ),
      );
    }
    return s;
  }))!;
}

/// `MoneyText` lê o `AppScope`, então o card precisa dele acima.
Future<void> _pump(WidgetTester tester, AppServices s, {required bool ultra}) {
  final summary = DashboardSummary.of(s.ledger, ultra: ultra);
  return tester.pumpWidget(
    AppScope(
      services: s,
      child: MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(
          body: CategoriesCard(rows: summary.categories, ultra: ultra),
        ),
      ),
    ),
  );
}

void main() {
  testWidgets(
    'Ultra: raiz agrega filhas; children com gasto e sem subcategoria',
    (tester) async {
      final s = await _boot(tester);
      final summary = DashboardSummary.of(s.ledger, ultra: true);

      final first = summary.categories.first;
      expect(first.name, 'Alimentação');
      expect(first.cents, 60000);
      expect(first.children.map((c) => c.name), [
        'Mercado X',
        'Sem subcategoria',
      ]);
      expect(first.children.map((c) => c.cents), [50000, 10000]);
      expect(summary.categories[1].name, 'Transporte');
      expect(summary.categories[1].cents, 3000);
      expect(summary.categories[1].children, isEmpty);
    },
  );

  testWidgets('Simples: raiz agregada, sem children', (tester) async {
    final s = await _boot(tester);
    final summary = DashboardSummary.of(s.ledger, ultra: false);

    final first = summary.categories.first;
    expect(first.name, 'Alimentação');
    expect(first.cents, 60000);
    expect(first.children, isEmpty);
  });

  testWidgets('Simples: sem chevron e sem filha na tela', (tester) async {
    final s = await _boot(tester);
    await _pump(tester, s, ultra: false);

    expect(find.text('Alimentação'), findsOneWidget);
    expect(find.byIcon(Icons.chevron_right), findsNothing);
    expect(find.text('Mercado X'), findsNothing);
  });

  testWidgets('Ultra: filha oculta até tocar na raiz e some ao tocar de novo', (
    tester,
  ) async {
    final s = await _boot(tester);
    await _pump(tester, s, ultra: true);

    const raiz = ValueKey('category-row-cat_alimentacao');
    const filha = ValueKey('category-child-cat_mercado_x');
    const direto = ValueKey('category-child-cat_alimentacao-direct');

    expect(find.byIcon(Icons.chevron_right), findsOneWidget);
    expect(find.byKey(filha), findsNothing);
    expect(find.text('Mercado X'), findsNothing);

    await tester.tap(find.byKey(raiz));
    await tester.pumpAndSettle();
    expect(find.byKey(filha), findsOneWidget);
    expect(find.byKey(direto), findsOneWidget);
    expect(find.text('Mercado X'), findsOneWidget);
    expect(find.text('Sem subcategoria'), findsOneWidget);

    await tester.tap(find.byKey(raiz));
    await tester.pumpAndSettle();
    expect(find.byKey(filha), findsNothing);
    expect(find.text('Mercado X'), findsNothing);
  });
}
