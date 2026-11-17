import 'package:finme/app/app_scope.dart';
import 'package:finme/app/bootstrap.dart';
import 'package:finme/core/services/record_store.dart';
import 'package:finme/core/theme/app_theme.dart';
import 'package:finme/features/accounts/domain/account.dart';
import 'package:finme/features/categories/domain/transaction_category.dart';
import 'package:finme/features/debts/domain/debt.dart';
import 'package:finme/features/debts/presentation/debt_dialogs.dart';
import 'package:finme/features/transactions/domain/transaction.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Conta Alfa (ativa, saldo 200000) e Conta Velha (arquivada); `withAccount: false` deixa só a arquivada.
Future<AppServices> _setup(
  WidgetTester tester, {
  bool withAccount = true,
  List<Debt> debts = const [],
  List<Transaction> transactions = const [],
  List<TransactionCategory> categories = const [],
  RecordStore Function(String box)? storeFactory,
}) async {
  return (await tester.runAsync(() async {
    final s = await bootstrap(
      storeFactory: storeFactory ?? (_) => MemoryRecordStore(),
      clock: () => DateTime(2026, 11, 15),
    );
    await s.accounts.upsertAll([
      if (withAccount)
        const Account(
          id: 'alfa',
          name: 'Conta Alfa',
          bankName: 'Banco Alfa',
          type: AccountType.checking,
          initialBalanceCents: 200000,
          colorValue: 0xFF42A5F5,
        ),
      const Account(
        id: 'velha',
        name: 'Conta Velha',
        bankName: '',
        type: AccountType.checking,
        initialBalanceCents: 0,
        colorValue: 0xFF42A5F5,
        archived: true,
      ),
    ]);
    await s.categories.upsertAll(categories);
    await s.debts.upsertAll(debts);
    await s.transactions.upsertAll(transactions);
    return s;
  }))!;
}

/// Abre o diálogo pelo botão 'abrir' (`open` recebe o context da página).
Future<void> _pump(
  WidgetTester tester,
  AppServices s,
  Future<void> Function(BuildContext) open,
) async {
  await tester.binding.setSurfaceSize(const Size(900, 1000));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(
    AppScope(
      services: s,
      child: MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () => open(context),
              child: const Text('abrir'),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('abrir'));
  await tester.pumpAndSettle();
}

Future<void> _tap(WidgetTester tester, String label) async {
  await tester.tap(find.widgetWithText(FilledButton, label));
  await tester.pumpAndSettle();
}

Future<void> _type(WidgetTester tester, Finder field, String text) async {
  await tester.enterText(field, text);
  // Troca de helper/erro anima (fade): espera o fim para não contar o texto antigo.
  await tester.pumpAndSettle();
}

/// Texto do controller do campo (o `find.text` não enxerga o conteúdo digitado).
String _fieldText(WidgetTester tester, Finder field) => tester
    .widget<EditableText>(
      find.descendant(of: field, matching: find.byType(EditableText)),
    )
    .controller
    .text;

/// Escolhe um dia no date picker aberto a partir do campo que mostra [current].
Future<void> _pickDay(WidgetTester tester, String current, String day) async {
  await tester.tap(find.text(current));
  await tester.pumpAndSettle();
  await tester.tap(
    find.descendant(
      of: find.byType(DatePickerDialog),
      matching: find.text(day),
    ),
  );
  await tester.tap(find.text('OK'));
  await tester.pumpAndSettle();
}

/// Delete falha: simula a transação que não pode ser apagada.
class _NoDeleteStore extends MemoryRecordStore {
  @override
  Future<void> delete(String id) async => throw StateError('disco cheio');
}

FilledButton _confirm(WidgetTester tester) =>
    tester.widget<FilledButton>(find.widgetWithText(FilledButton, 'Confirmar'));

final _amountField = find.widgetWithText(TextFormField, 'Valor');
final _settleAmount = find.byKey(const Key('settle-amount'));
final _person = find.byKey(const Key('debt-person'));

final _ana = Debt(
  id: 'd1',
  person: 'Ana',
  direction: DebtDirection.owedToMe,
  amountCents: 50000,
  date: DateTime(2026, 10, 1),
  dueDate: DateTime(2026, 11, 30),
  description: 'Show',
);

final _bruno = Debt(
  id: 'b1',
  person: 'Bruno',
  direction: DebtDirection.iOwe,
  amountCents: 80000,
  date: DateTime(2026, 9, 20),
  dueDate: DateTime(2026, 12, 1),
);

void main() {
  testWidgets(
    'form: pessoa vazia e valor vazio mostram erro e nada é gravado',
    (tester) async {
      final s = await _setup(tester);
      await _pump(tester, s, (c) async {
        await showDebtForm(c);
      });
      await _tap(tester, 'Salvar');
      expect(find.text('Informe a pessoa'), findsOneWidget);
      expect(find.text('Informe um valor maior que zero'), findsOneWidget);
      expect(s.debts.all, isEmpty);
    },
  );

  testWidgets('form: vencimento antes da data mostra erro e não salva', (
    tester,
  ) async {
    final s = await _setup(
      tester,
      debts: [
        Debt(
          id: 'd9',
          person: 'Carla',
          direction: DebtDirection.iOwe,
          amountCents: 5000,
          date: DateTime(2026, 11, 15),
          dueDate: DateTime(2026, 11, 10),
        ),
      ],
    );
    await _pump(tester, s, (c) async {
      await showDebtForm(c, initial: s.debts.byId('d9'));
    });
    expect(find.text('Vencimento antes da data'), findsOneWidget);
    await _tap(tester, 'Salvar');
    expect(s.debts.byId('d9')!.dueDate, DateTime(2026, 11, 10));
  });

  testWidgets('form: salvar grava dívida "me devem" com centavos', (
    tester,
  ) async {
    final s = await _setup(tester);
    Debt? saved;
    await _pump(tester, s, (c) async {
      saved = await showDebtForm(c);
    });
    await _type(tester, _person, 'Ana');
    await _type(tester, _amountField, '500,00');
    await _tap(tester, 'Salvar');
    final debt = s.debts.all.single;
    expect(debt.person, 'Ana');
    expect(debt.direction, DebtDirection.owedToMe);
    expect(debt.amountCents, 50000);
    expect(saved?.id, debt.id);
  });

  testWidgets('pessoa: digitar "bru" sugere Bruno', (tester) async {
    final s = await _setup(tester, debts: [_bruno]);
    await _pump(tester, s, (c) async {
      await showDebtForm(c);
    });
    await _type(tester, _person, 'bru');
    await tester.pumpAndSettle();
    expect(find.text('Bruno'), findsOneWidget);
  });

  testWidgets(
    'editar com pagamento: direção travada e valor abaixo do já pago é erro',
    (tester) async {
      final paid = _ana.withPayment(
        DebtPayment(id: 'p1', date: DateTime(2026, 11, 1), amountCents: 20000),
      );
      final s = await _setup(tester, debts: [paid]);
      await _pump(tester, s, (c) async {
        await showDebtForm(c, initial: paid);
      });
      expect(find.text('Dívida com pagamentos'), findsOneWidget);
      expect(
        tester
            .widget<SegmentedButton<DebtDirection>>(
              find.byKey(const Key('debt-direction')),
            )
            .onSelectionChanged,
        isNull,
      );
      await _type(tester, _amountField, '100,00');
      await _tap(tester, 'Salvar');
      expect(find.text('Já pago: R\$ 200,00'), findsOneWidget);
      expect(s.debts.byId('d1')!.amountCents, 50000);
    },
  );

  testWidgets('form: dívida excluída com o diálogo aberto não é regravada', (
    tester,
  ) async {
    final s = await _setup(tester, debts: [_ana]);
    await _pump(tester, s, (c) async {
      await showDebtForm(c, initial: _ana);
    });
    await tester.runAsync(() => s.debts.delete('d1'));
    await _tap(tester, 'Salvar');
    expect(find.text('Esta dívida foi excluída.'), findsOneWidget);
    expect(s.debts.all, isEmpty);
  });

  testWidgets(
    'quitação parcial grava transação e mantém o diálogo; acima do restante bloqueia; total fecha',
    (tester) async {
      final s = await _setup(tester, debts: [_ana]);
      await _pump(tester, s, (c) => showSettleDebtDialog(c, _ana));
      expect(find.text('Receber de Ana'), findsOneWidget);

      await _type(tester, _settleAmount, '200,00');
      await _tap(tester, 'Confirmar');

      expect(s.transactions.all, hasLength(1));
      final tx = s.transactions.all.single;
      expect(tx.type, TransactionType.income);
      expect(tx.amountCents, 20000);
      expect(tx.description, 'Recebido de Ana · Show');
      expect(tx.accountId, 'alfa');
      expect(s.debts.byId('d1')!.remainingCents, 30000);
      expect(s.ledger.accountBalances['alfa'], 220000);
      expect(
        find.text('Pagamento registrado · transação criada em Conta Alfa'),
        findsOneWidget,
      );
      // Mesmo SnackBar fica na fila; limpa para o próximo aparecer.
      ScaffoldMessenger.of(
        tester.element(find.byType(Scaffold).first),
      ).clearSnackBars();
      await tester.pumpAndSettle();
      expect(_settleAmount, findsOneWidget);

      await _type(tester, _settleAmount, '300,01');
      expect(find.text('Restante: R\$ 300,00'), findsOneWidget);
      expect(_confirm(tester).onPressed, isNull);
      expect(s.transactions.all, hasLength(1));
      expect(s.debts.byId('d1')!.remainingCents, 30000);

      await _type(tester, _settleAmount, '300,00');
      await _tap(tester, 'Confirmar');

      expect(s.debts.byId('d1')!.settled, isTrue);
      expect(s.transactions.all, hasLength(2));
      expect(
        find.text('Dívida quitada · transação criada em Conta Alfa'),
        findsOneWidget,
      );
      expect(_settleAmount, findsNothing);
    },
  );

  testWidgets('quitar "devo" com categoria grava despesa com a categoria', (
    tester,
  ) async {
    const mercado = TransactionCategory(
      id: 'cat-presentes',
      name: 'Presentes',
      kind: CategoryKind.expense,
      iconCodePoint: 0xe25a,
      colorValue: 0xFF42A5F5,
    );
    final s = await _setup(tester, debts: [_bruno], categories: [mercado]);
    await _pump(tester, s, (c) => showSettleDebtDialog(c, _bruno));
    expect(find.text('Pagar a Bruno'), findsOneWidget);

    await tester.tap(find.byKey(const Key('settle-category')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Presentes').last);
    await tester.pumpAndSettle();
    await _tap(tester, 'Confirmar');

    final tx = s.transactions.all.single;
    expect(tx.type, TransactionType.expense);
    expect(tx.categoryId, 'cat-presentes');
    expect(tx.description, 'Pago a Bruno');
    expect(tx.amountCents, 80000);
    expect(s.debts.byId('b1')!.settled, isTrue);
  });

  testWidgets('quitar: dropdown de conta não lista conta arquivada', (
    tester,
  ) async {
    final s = await _setup(tester, debts: [_ana]);
    await _pump(tester, s, (c) => showSettleDebtDialog(c, _ana));
    await tester.tap(find.byKey(const Key('settle-account')));
    await tester.pumpAndSettle();
    expect(find.text('Conta Velha'), findsNothing);
    expect(find.text('Conta Alfa'), findsWidgets);
  });

  testWidgets('quitar sem conta ativa: aviso e Confirmar desabilitado', (
    tester,
  ) async {
    final s = await _setup(tester, withAccount: false, debts: [_ana]);
    await _pump(tester, s, (c) => showSettleDebtDialog(c, _ana));
    expect(
      find.text('Cadastre uma conta para registrar o pagamento.'),
      findsOneWidget,
    );
    expect(_confirm(tester).onPressed, isNull);
  });

  testWidgets(
    'pagamentos: desfazer com confirmação remove o pagamento e a transação',
    (tester) async {
      final paid = _ana.withPayment(
        DebtPayment(
          id: 'p1',
          date: DateTime(2026, 11, 10),
          amountCents: 20000,
          transactionId: 't1',
        ),
      );
      final s = await _setup(
        tester,
        debts: [paid],
        transactions: [
          Transaction(
            id: 't1',
            type: TransactionType.income,
            amountCents: 20000,
            date: DateTime(2026, 11, 10),
            description: 'Recebido de Ana',
            accountId: 'alfa',
          ),
        ],
      );
      await _pump(tester, s, (c) => showDebtPayments(c, paid));
      expect(find.text('Recebido de Ana'), findsOneWidget);

      await tester.tap(find.byTooltip('Desfazer'));
      await tester.pumpAndSettle();
      expect(find.text('Desfazer pagamento?'), findsOneWidget);
      await _tap(tester, 'Desfazer');

      expect(s.debts.byId('d1')!.payments, isEmpty);
      expect(s.transactions.byId('t1'), isNull);
    },
  );

  testWidgets(
    'pagamentos: transação apagada mostra "Transação excluída"; desfazer só tira o pagamento',
    (tester) async {
      final paid = _ana.withPayment(
        DebtPayment(
          id: 'p1',
          date: DateTime(2026, 11, 10),
          amountCents: 20000,
          transactionId: 'gone',
        ),
      );
      final s = await _setup(tester, debts: [paid]);
      await _pump(tester, s, (c) => showDebtPayments(c, paid));
      expect(find.text('Transação excluída'), findsOneWidget);

      await tester.tap(find.byTooltip('Desfazer'));
      await tester.pumpAndSettle();
      await _tap(tester, 'Desfazer');

      expect(s.debts.byId('d1')!.payments, isEmpty);
      expect(s.transactions.all, isEmpty);
    },
  );

  testWidgets('ocultos: restante e acima do restante ficam mascarados', (
    tester,
  ) async {
    final s = await _setup(tester, debts: [_ana]);
    await tester.runAsync(
      () => s.settings.update((c) => c.copyWith(hideValues: true)),
    );
    await _pump(tester, s, (c) => showSettleDebtDialog(c, _ana));
    expect(_fieldText(tester, _settleAmount), '');

    await _type(tester, _settleAmount, '200,00');
    expect(find.text('Restante: R\$ ••••'), findsOneWidget);

    await _type(tester, _settleAmount, '600,00');
    expect(find.text('Restante: R\$ ••••'), findsOneWidget);
    expect(find.textContaining('500,00'), findsNothing);
    expect(s.transactions.all, isEmpty);
  });

  testWidgets('ocultos: "Já pago" e pré-preenchido do form ficam mascarados', (
    tester,
  ) async {
    final paid = _ana.withPayment(
      DebtPayment(id: 'p1', date: DateTime(2026, 11, 1), amountCents: 20000),
    );
    final s = await _setup(tester, debts: [paid]);
    await tester.runAsync(
      () => s.settings.update((c) => c.copyWith(hideValues: true)),
    );
    await _pump(tester, s, (c) => showDebtForm(c, initial: paid));
    expect(_fieldText(tester, _amountField), '');

    await _type(tester, _amountField, '100,00');
    await _tap(tester, 'Salvar');
    expect(find.text('Já pago: R\$ ••••'), findsOneWidget);
    expect(find.textContaining('200,00'), findsNothing);
  });

  testWidgets('ocultos: confirmação de desfazer mascara o valor do pagamento', (
    tester,
  ) async {
    final paid = _ana.withPayment(
      DebtPayment(id: 'p1', date: DateTime(2026, 11, 10), amountCents: 20000),
    );
    final s = await _setup(tester, debts: [paid]);
    await tester.runAsync(
      () => s.settings.update((c) => c.copyWith(hideValues: true)),
    );
    await _pump(tester, s, (c) => showDebtPayments(c, paid));
    await tester.tap(find.byTooltip('Desfazer'));
    await tester.pumpAndSettle();
    expect(find.textContaining('O pagamento de R\$ ••••'), findsOneWidget);
    expect(find.textContaining('200,00'), findsNothing);
  });

  testWidgets(
    'edição: data posterior ao primeiro pagamento bloqueia o salvar',
    (tester) async {
      final paid = Debt(
        id: 'd1',
        person: 'Ana',
        direction: DebtDirection.owedToMe,
        amountCents: 50000,
        date: DateTime(2026, 11, 1),
        payments: [
          DebtPayment(
            id: 'p1',
            date: DateTime(2026, 11, 5),
            amountCents: 10000,
          ),
        ],
      );
      final s = await _setup(tester, debts: [paid]);
      await _pump(tester, s, (c) => showDebtForm(c, initial: paid));
      await _pickDay(tester, '01/11/2026', '10');
      expect(find.text('Há pagamento antes desta data'), findsOneWidget);
      await _tap(tester, 'Salvar');
      expect(s.debts.byId('d1')!.date, DateTime(2026, 11, 1));
    },
  );

  testWidgets('form: data da dívida no futuro bloqueia o salvar', (
    tester,
  ) async {
    final s = await _setup(tester);
    await _pump(tester, s, (c) => showDebtForm(c));
    await _pickDay(tester, '15/11/2026', '16');
    expect(find.text('A data não pode ser futura'), findsOneWidget);
    await _type(tester, _person, 'Ana');
    await _type(tester, _amountField, '100,00');
    await _tap(tester, 'Salvar');
    expect(s.debts.all, isEmpty);
  });

  testWidgets(
    'edição: ao salvar usa os pagamentos relidos, não os do momento de abrir',
    (tester) async {
      final s = await _setup(tester, debts: [_ana]);
      await _pump(tester, s, (c) => showDebtForm(c, initial: _ana));
      await tester.runAsync(
        () => s.debts.upsert(
          _ana.withPayment(
            DebtPayment(
              id: 'p1',
              date: DateTime(2026, 11, 5),
              amountCents: 10000,
            ),
          ),
        ),
      );
      await _type(tester, _amountField, '600,00');
      await _tap(tester, 'Salvar');
      final saved = s.debts.byId('d1')!;
      expect(saved.amountCents, 60000);
      expect(saved.payments.map((p) => p.id), ['p1']);
    },
  );

  testWidgets(
    'desfazer: dívida é gravada sem o pagamento antes; falha ao apagar a transação avisa',
    (tester) async {
      final paid = _ana.withPayment(
        DebtPayment(
          id: 'p1',
          date: DateTime(2026, 11, 10),
          amountCents: 20000,
          transactionId: 't1',
        ),
      );
      final s = await _setup(
        tester,
        debts: [paid],
        transactions: [
          Transaction(
            id: 't1',
            type: TransactionType.income,
            amountCents: 20000,
            date: DateTime(2026, 11, 10),
            description: 'Recebido de Ana',
            accountId: 'alfa',
          ),
        ],
        storeFactory: (box) =>
            box == 'fm_transactions' ? _NoDeleteStore() : MemoryRecordStore(),
      );
      await _pump(tester, s, (c) => showDebtPayments(c, paid));
      await tester.tap(find.byTooltip('Desfazer'));
      await tester.pumpAndSettle();
      await _tap(tester, 'Desfazer');

      expect(s.debts.byId('d1')!.payments, isEmpty);
      expect(
        find.text(
          'Pagamento desfeito, mas a transação não foi apagada; apague-a em Transações.',
        ),
        findsOneWidget,
      );
    },
  );
}
