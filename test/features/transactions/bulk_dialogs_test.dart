import 'package:finme/app/seed.dart';
import 'package:finme/core/theme/app_colors.dart';
import 'package:finme/core/theme/app_theme.dart';
import 'package:finme/features/transactions/presentation/bulk_action_bar.dart';
import 'package:finme/features/transactions/presentation/bulk_dialogs.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Abre o diálogo a partir de um botão; o resultado fica em `pending` (await após interagir).
Future<void> _host(
  WidgetTester tester,
  void Function(BuildContext) open,
) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.light(),
      home: Scaffold(
        body: Builder(
          builder: (ctx) => TextButton(
            onPressed: () => open(ctx),
            child: const Text('abrir'),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('abrir'));
  await tester.pumpAndSettle();
}

ButtonStyleButton _button(WidgetTester tester, String text) =>
    tester.widget<ButtonStyleButton>(
      find.ancestor(
        of: find.text(text),
        matching: find.bySubtype<ButtonStyleButton>(),
      ),
    );

void main() {
  group('showBulkCategoryDialog', () {
    final categories = defaultCategories();

    testWidgets('escolher Mercado e confirmar devolve a categoria', (
      tester,
    ) async {
      late Future<CategoryChoice?> pending;
      await _host(
        tester,
        (ctx) => pending = showBulkCategoryDialog(
          ctx,
          count: 3,
          categories: categories,
        ),
      );
      expect(find.text('Recategorizar 3'), findsOneWidget);
      expect(_button(tester, 'Confirmar').onPressed, isNull);

      await tester.tap(find.byType(DropdownButton<String>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Mercado').last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Confirmar'));
      await tester.pumpAndSettle();

      final choice = await pending;
      expect(choice?.category?.id, 'cat_mercado');
    });

    testWidgets('Sem categoria devolve category null', (tester) async {
      late Future<CategoryChoice?> pending;
      await _host(
        tester,
        (ctx) => pending = showBulkCategoryDialog(
          ctx,
          count: 2,
          categories: categories,
        ),
      );
      await tester.tap(find.byType(DropdownButton<String>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Sem categoria'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Confirmar'));
      await tester.pumpAndSettle();

      final choice = await pending;
      expect(choice, isNotNull);
      expect(choice!.category, isNull);
    });

    testWidgets('receitas aparecem com sufixo (receita)', (tester) async {
      late Future<CategoryChoice?> pending;
      await _host(
        tester,
        (ctx) => pending = showBulkCategoryDialog(
          ctx,
          count: 1,
          categories: categories,
        ),
      );
      await tester.tap(find.byType(DropdownButton<String>));
      await tester.pumpAndSettle();
      // Menu rola: receitas ficam abaixo das despesas, fora da viewport inicial.
      await tester.scrollUntilVisible(
        find.text('Salário (receita)'),
        80,
        scrollable: find.byType(Scrollable).last,
      );
      await tester.tap(find.text('Salário (receita)'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Confirmar'));
      await tester.pumpAndSettle();

      expect((await pending)?.category?.id, 'cat_salario');
    });

    testWidgets('Cancelar devolve null', (tester) async {
      late Future<CategoryChoice?> pending;
      await _host(
        tester,
        (ctx) => pending = showBulkCategoryDialog(
          ctx,
          count: 1,
          categories: categories,
        ),
      );
      await tester.tap(find.text('Cancelar'));
      await tester.pumpAndSettle();

      expect(await pending, isNull);
    });
  });

  group('showBulkConfirmDialog', () {
    testWidgets('confirmar sem mudar a data devolve a data inicial', (
      tester,
    ) async {
      late Future<DateTime?> pending;
      await _host(
        tester,
        (ctx) => pending = showBulkConfirmDialog(
          ctx,
          count: 2,
          initialDate: DateTime(2026, 11, 14),
        ),
      );
      expect(find.text('Confirmar 2 provisionados'), findsOneWidget);
      await tester.tap(find.text('Confirmar'));
      await tester.pumpAndSettle();

      expect(await pending, DateTime(2026, 11, 14));
    });

    testWidgets('Cancelar devolve null', (tester) async {
      late Future<DateTime?> pending;
      await _host(
        tester,
        (ctx) => pending = showBulkConfirmDialog(
          ctx,
          count: 2,
          initialDate: DateTime(2026, 11, 14),
        ),
      );
      await tester.tap(find.text('Cancelar'));
      await tester.pumpAndSettle();

      expect(await pending, isNull);
    });
  });

  group('showBulkDeleteDialog', () {
    testWidgets('sem parcelas: Excluir devolve selected', (tester) async {
      late Future<BulkDeleteScope?> pending;
      await _host(
        tester,
        (ctx) => pending = showBulkDeleteDialog(
          ctx,
          count: 3,
          groups: 0,
          wholeGroupsCount: 0,
        ),
      );
      expect(find.text('Excluir 3 transações?'), findsOneWidget);
      await tester.tap(find.text('Excluir'));
      await tester.pumpAndSettle();

      expect(await pending, BulkDeleteScope.selected);
    });

    testWidgets('sem parcelas: Cancelar devolve null', (tester) async {
      late Future<BulkDeleteScope?> pending;
      await _host(
        tester,
        (ctx) => pending = showBulkDeleteDialog(
          ctx,
          count: 3,
          groups: 0,
          wholeGroupsCount: 0,
        ),
      );
      await tester.tap(find.text('Cancelar'));
      await tester.pumpAndSettle();

      expect(await pending, isNull);
    });

    testWidgets('com parcelas: só as selecionadas devolve selected', (
      tester,
    ) async {
      late Future<BulkDeleteScope?> pending;
      await _host(
        tester,
        (ctx) => pending = showBulkDeleteDialog(
          ctx,
          count: 2,
          groups: 1,
          wholeGroupsCount: 4,
        ),
      );
      expect(find.text('1 grupo de parcelas na seleção.'), findsOneWidget);
      await tester.tap(find.text('Só as 2 selecionadas'));
      await tester.pumpAndSettle();

      expect(await pending, BulkDeleteScope.selected);
    });

    testWidgets('com parcelas: grupos inteiros devolve wholeGroups', (
      tester,
    ) async {
      late Future<BulkDeleteScope?> pending;
      await _host(
        tester,
        (ctx) => pending = showBulkDeleteDialog(
          ctx,
          count: 2,
          groups: 1,
          wholeGroupsCount: 4,
        ),
      );
      await tester.tap(find.text('Grupos inteiros (4 lançamentos)'));
      await tester.pumpAndSettle();

      expect(await pending, BulkDeleteScope.wholeGroups);
    });
  });

  group('BulkActionBar', () {
    testWidgets('mostra contagem, ações, tooltip e chama onClear', (
      tester,
    ) async {
      var cleared = false;
      var recategorized = false;
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: Scaffold(
            body: BulkActionBar(
              count: 3,
              onClear: () => cleared = true,
              actions: [
                BulkAction(
                  label: 'Recategorizar',
                  icon: Icons.category_outlined,
                  onPressed: () => recategorized = true,
                ),
                const BulkAction(
                  label: 'Confirmar pagamento',
                  icon: Icons.event_available,
                  onPressed: null,
                ),
                const BulkAction(
                  label: 'Excluir',
                  icon: Icons.delete_outline,
                  onPressed: _noop,
                  destructive: true,
                ),
              ],
            ),
          ),
        ),
      );

      expect(find.text('3 selecionadas'), findsOneWidget);
      expect(find.text('Recategorizar'), findsOneWidget);
      expect(find.text('Confirmar pagamento'), findsOneWidget);
      expect(_button(tester, 'Confirmar pagamento').onPressed, isNull);

      final excluir = tester.widget<TextButton>(
        find.ancestor(
          of: find.text('Excluir'),
          matching: find.bySubtype<TextButton>(),
        ),
      );
      final context = tester.element(find.byType(BulkActionBar));
      expect(
        excluir.style!.foregroundColor!.resolve(<WidgetState>{}),
        context.colors.danger,
      );

      await tester.tap(find.text('Recategorizar'));
      expect(recategorized, isTrue);

      expect(find.byTooltip('Limpar seleção (Esc)'), findsOneWidget);
      await tester.tap(find.byIcon(Icons.close));
      expect(cleared, isTrue);
    });
  });
}

void _noop() {}
