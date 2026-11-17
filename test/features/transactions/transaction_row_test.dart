import 'package:finme/app/app_scope.dart';
import 'package:finme/app/bootstrap.dart';
import 'package:finme/core/services/record_store.dart';
import 'package:finme/core/theme/app_colors.dart';
import 'package:finme/core/theme/app_theme.dart';
import 'package:finme/core/widgets/widgets.dart';
import 'package:finme/features/categories/domain/transaction_category.dart';
import 'package:finme/features/transactions/domain/transaction.dart';
import 'package:finme/features/transactions/presentation/inline_cells.dart';
import 'package:finme/features/transactions/presentation/transaction_row.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

const _mercado = TransactionCategory(
  id: 'cat_mercado',
  name: 'Mercado',
  kind: CategoryKind.expense,
  iconCodePoint: 0,
  colorValue: 0,
);

const _salario = TransactionCategory(
  id: 'cat_salario',
  name: 'Salário',
  kind: CategoryKind.income,
  iconCodePoint: 0,
  colorValue: 0,
);

final _despesa = Transaction(
  id: 'd1',
  type: TransactionType.expense,
  amountCents: 1250,
  date: DateTime(2026, 11, 10),
  description: 'Mercado Exemplo',
  categoryId: 'cat_mercado',
);

Transaction _transferencia() => Transaction(
  id: 't1',
  type: TransactionType.transfer,
  amountCents: 5000,
  date: DateTime(2026, 11, 10),
  description: 'Reserva',
  accountId: 'acc_a',
  toAccountId: 'acc_b',
);

Transaction _provisionada() => Transaction(
  id: 'p1',
  type: TransactionType.expense,
  amountCents: 8000,
  date: DateTime(2026, 11, 20),
  description: 'Boleto',
  accountId: 'acc_a',
  status: TransactionStatus.planned,
);

/// Largura Ultra mínima + altura de linha, como na página.
Future<void> _pumpRow(
  WidgetTester tester, {
  required Transaction transaction,
  bool ultra = true,
  bool? selected,
  VoidCallback? onToggleSelect,
  List<TransactionCategory>? categoryOptions,
  ValueChanged<String?>? onCategoryChanged,
  ValueChanged<int>? onAmountChanged,
  ValueChanged<TransactionAction>? onAction,
}) async {
  // MoneyText lê hideValues via AppScope: precisa de serviços reais (em memória).
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
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: kTxUltraMinWidth,
              child: TransactionRow(
                transaction: transaction,
                ultra: ultra,
                past: false,
                category: transaction.categoryId == 'cat_mercado'
                    ? _mercado
                    : null,
                origin: 'Conta Alfa',
                selected: selected,
                onToggleSelect: onToggleSelect,
                categoryOptions: categoryOptions,
                onCategoryChanged: onCategoryChanged,
                onAmountChanged: onAmountChanged,
                onAction: onAction ?? (_) {},
              ),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pump();
}

void main() {
  test('kTxUltraMinWidth comporta a coluna de checkbox', () {
    expect(kTxUltraMinWidth, 796);
    expect(kTxSelectWidth, 36);
  });

  testWidgets('sem parâmetros novos: sem checkbox nem células inline', (
    tester,
  ) async {
    await _pumpRow(tester, transaction: _despesa);
    expect(find.byType(Checkbox), findsNothing);
    expect(find.byType(InlineCategoryCell), findsNothing);
    expect(find.byType(InlineAmountCell), findsNothing);
    expect(find.byType(MoneyText), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('selected true: checkbox marcado e fundo primarySubtle', (
    tester,
  ) async {
    await _pumpRow(
      tester,
      transaction: _provisionada(),
      selected: true,
      onToggleSelect: () {},
    );
    final box = tester.widget<Checkbox>(find.byKey(const Key('tx-select-p1')));
    expect(box.value, isTrue);

    // Fundo da linha = DecoratedBox com borda inferior (o da célula de checkbox não tem).
    final rowDecoration =
        tester
                .widget<DecoratedBox>(
                  find
                      .byWidgetPredicate(
                        (w) =>
                            w is DecoratedBox &&
                            w.decoration is BoxDecoration &&
                            (w.decoration as BoxDecoration).border != null,
                      )
                      .first,
                )
                .decoration
            as BoxDecoration;
    expect(
      rowDecoration.color,
      AppTheme.light().extension<AppColors>()!.primarySubtle,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('tocar no checkbox chama onToggleSelect e não abre a linha', (
    tester,
  ) async {
    var toggled = 0;
    final actions = <TransactionAction>[];
    await _pumpRow(
      tester,
      transaction: _despesa,
      selected: false,
      onToggleSelect: () => toggled++,
      onAction: actions.add,
    );
    await tester.tap(find.byKey(const Key('tx-select-d1')));
    await tester.pump();
    expect(toggled, 1);
    expect(actions, isEmpty);
  });

  testWidgets('tocar no resto da linha abre o formulário (edit)', (
    tester,
  ) async {
    final actions = <TransactionAction>[];
    await _pumpRow(
      tester,
      transaction: _despesa,
      selected: false,
      onToggleSelect: () {},
      onAction: actions.add,
    );
    await tester.tap(find.text('Mercado Exemplo'));
    await tester.pump();
    expect(actions, [TransactionAction.edit]);
  });

  testWidgets('despesa com opções + onCategoryChanged → InlineCategoryCell', (
    tester,
  ) async {
    String? picked = 'unset';
    await _pumpRow(
      tester,
      transaction: _despesa,
      categoryOptions: const [_mercado],
      onCategoryChanged: (v) => picked = v,
    );
    expect(find.byKey(const Key('inline-category-d1')), findsOneWidget);
    expect(find.byType(InlineCategoryCell), findsOneWidget);
    expect(picked, 'unset');
    expect(tester.takeException(), isNull);
  });

  testWidgets('transferência com os mesmos parâmetros → texto, sem dropdown', (
    tester,
  ) async {
    await _pumpRow(
      tester,
      transaction: _transferencia(),
      categoryOptions: const [_mercado, _salario],
      onCategoryChanged: (_) {},
    );
    expect(find.byType(InlineCategoryCell), findsNothing);
    expect(find.byType(DropdownButton<String?>), findsNothing);
    expect(find.text('—'), findsOneWidget);
  });

  testWidgets('onAmountChanged não nulo → InlineAmountCell; nulo → MoneyText', (
    tester,
  ) async {
    await _pumpRow(tester, transaction: _despesa, onAmountChanged: (_) {});
    expect(find.byKey(const Key('inline-amount-d1')), findsOneWidget);
    expect(find.byType(InlineAmountCell), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('clique no valor abre campo na linha e Enter grava', (
    tester,
  ) async {
    int? submitted;
    await _pumpRow(
      tester,
      transaction: _despesa,
      onAmountChanged: (v) => submitted = v,
    );
    await tester.tap(find.byKey(const Key('inline-amount-d1')));
    await tester.pump();
    expect(tester.takeException(), isNull);
    final field = find.byKey(const Key('inline-amount-field'));
    expect(field, findsOneWidget);
    expect(tester.widget<TextField>(field).controller!.text, '12,50');

    await tester.enterText(field, '99,90');
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();
    expect(submitted, 9990);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'cabeçalho selectable: checkbox tristate; tocar chama onSelectAll',
    (tester) async {
      var all = 0;
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: Scaffold(
            body: SizedBox(
              width: kTxUltraMinWidth,
              child: TransactionTableHeader(
                ultra: true,
                selectable: true,
                selectAllState: null,
                onSelectAll: () => all++,
              ),
            ),
          ),
        ),
      );
      final box = tester.widget<Checkbox>(
        find.byKey(const Key('tx-select-all')),
      );
      expect(box.tristate, isTrue);
      expect(box.value, isNull);
      await tester.tap(find.byKey(const Key('tx-select-all')));
      await tester.pump();
      expect(all, 1);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('cabeçalho sem selectable: nenhum checkbox', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: const Scaffold(
          body: SizedBox(
            width: kTxUltraMinWidth,
            child: TransactionTableHeader(ultra: true),
          ),
        ),
      ),
    );
    expect(find.byType(Checkbox), findsNothing);
  });
}
