import 'package:finme/app/app_scope.dart';
import 'package:finme/app/bootstrap.dart';
import 'package:finme/core/services/record_store.dart';
import 'package:finme/core/theme/app_theme.dart';
import 'package:finme/features/accounts/domain/account.dart';
import 'package:finme/features/goals/domain/goal.dart';
import 'package:finme/features/goals/presentation/goal_dialogs.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Conta Alfa (ativa, saldo 200000) e Conta Velha (arquivada).
Future<AppServices> _setup(
  WidgetTester tester, {
  List<Goal> goals = const [],
}) async {
  return (await tester.runAsync(() async {
    final s = await bootstrap(
      storeFactory: (_) => MemoryRecordStore(),
      clock: () => DateTime(2026, 11, 15),
    );
    await s.accounts.upsertAll(const [
      Account(
        id: 'alfa',
        name: 'Conta Alfa',
        bankName: '',
        type: AccountType.checking,
        initialBalanceCents: 200000,
        colorValue: 0xFF42A5F5,
      ),
      Account(
        id: 'velha',
        name: 'Conta Velha',
        bankName: '',
        type: AccountType.checking,
        initialBalanceCents: 0,
        colorValue: 0xFF42A5F5,
        archived: true,
      ),
    ]);
    await s.goals.upsertAll(goals);
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
  await _reopen(tester);
}

Future<void> _reopen(WidgetTester tester) async {
  await tester.tap(find.text('abrir'));
  await tester.pumpAndSettle();
}

Future<void> _tapSalvar(WidgetTester tester) async {
  await tester.tap(find.widgetWithText(FilledButton, 'Salvar'));
  await tester.pumpAndSettle();
}

final _viagem = Goal(
  id: 'g1',
  name: 'Viagem',
  accountId: 'alfa',
  targetCents: 600000,
);

void main() {
  testWidgets('form: nome vazio e alvo zero mostram erro', (tester) async {
    final s = await _setup(tester);
    await _pump(tester, s, (c) => showGoalForm(c));
    await tester.enterText(find.byType(TextFormField).at(1), '0');
    await _tapSalvar(tester);
    expect(find.text('Informe o nome'), findsOneWidget);
    expect(find.text('Informe um alvo maior que zero'), findsOneWidget);
    expect(s.goals.all, isEmpty);
  });

  testWidgets('form: dropdown de conta não traz conta arquivada', (
    tester,
  ) async {
    final s = await _setup(tester);
    await _pump(tester, s, (c) => showGoalForm(c));
    await tester.tap(find.byType(DropdownButtonFormField<String>));
    await tester.pumpAndSettle();
    expect(find.text('Conta Alfa'), findsWidgets);
    expect(find.text('Conta Velha'), findsNothing);
  });

  testWidgets('form: salvar sem data grava meta e devolve a meta', (
    tester,
  ) async {
    final s = await _setup(tester);
    Goal? saved;
    await _pump(tester, s, (c) async {
      saved = await showGoalForm(c);
    });
    await tester.enterText(find.byType(TextFormField).at(0), 'Viagem');
    await tester.enterText(find.byType(TextFormField).at(1), '6.000,00');
    await _tapSalvar(tester);
    expect(saved, isNotNull);
    expect(saved!.targetCents, 600000);
    expect(saved!.targetDate, isNull);
    expect(saved!.accountId, 'alfa');
    expect(s.goals.byId(saved!.id)?.name, 'Viagem');
  });

  testWidgets('form: meta com movimentos trava a conta', (tester) async {
    final goal = Goal(
      id: 'g1',
      name: 'Viagem',
      accountId: 'alfa',
      targetCents: 600000,
      movements: [
        GoalMovement(id: 'm1', date: DateTime(2026, 11, 1), amountCents: 10000),
      ],
    );
    final s = await _setup(tester, goals: [goal]);
    await _pump(tester, s, (c) => showGoalForm(c, initial: goal));
    expect(find.text('Meta com movimentos'), findsOneWidget);
    final dropdown = tester.widget<DropdownButtonFormField<String>>(
      find.byType(DropdownButtonFormField<String>),
    );
    expect(dropdown.onChanged, isNull);
  });

  testWidgets(
    'movimento: aporte, saldo livre, retirada e limite do reservado',
    (tester) async {
      final s = await _setup(tester, goals: [_viagem]);
      await _pump(tester, s, (c) => showGoalMovementDialog(c, _viagem));

      // Aporte de R$ 1.500,00 cabe no saldo de R$ 2.000,00.
      await tester.enterText(find.byType(TextFormField).at(0), '1500,00');
      await _tapSalvar(tester);
      expect(s.goals.byId('g1')!.reservedCents, 150000);

      // Só sobram R$ 500,00 livres na conta.
      await _reopen(tester);
      await tester.enterText(find.byType(TextFormField).at(0), '600,00');
      await _tapSalvar(tester);
      expect(find.text('Saldo livre na conta: R\$ 500,00'), findsOneWidget);
      expect(s.goals.byId('g1')!.reservedCents, 150000);

      // Retirada acima do reservado nesta meta.
      await tester.tap(find.text('Retirada'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextFormField).at(0), '2000,00');
      await _tapSalvar(tester);
      expect(find.text('Reservado nesta meta: R\$ 1.500,00'), findsOneWidget);

      await tester.enterText(find.byType(TextFormField).at(0), '500,00');
      await _tapSalvar(tester);
      expect(s.goals.byId('g1')!.reservedCents, 100000);
      expect(s.transactions.all, isEmpty);
    },
  );

  testWidgets(
    'histórico: mais recente primeiro; exclusões respeitam o reservado',
    (tester) async {
      final goal = Goal(
        id: 'g1',
        name: 'Viagem',
        accountId: 'alfa',
        targetCents: 600000,
        movements: [
          GoalMovement(
            id: 'm1',
            date: DateTime(2026, 11, 10),
            amountCents: 150000,
          ),
          GoalMovement(
            id: 'm2',
            date: DateTime(2026, 11, 12),
            amountCents: -50000,
            note: 'Passagem',
          ),
        ],
      );
      final s = await _setup(tester, goals: [goal]);
      await _pump(tester, s, (c) => showGoalHistory(c, goal));

      final newer = tester.getTopLeft(find.text('12/11/2026')).dy;
      final older = tester.getTopLeft(find.text('10/11/2026')).dy;
      expect(newer, lessThan(older));
      expect(find.text('Passagem'), findsOneWidget);

      // Linha 1 (índice 1) é o aporte de 150000: sem ele a retirada de 50000 ficaria sem lastro.
      await tester.tap(find.byTooltip('Excluir movimento').at(1));
      await tester.pumpAndSettle();
      expect(
        find.text(
          'Sem este aporte, as retiradas ficariam maiores que o reservado',
        ),
        findsOneWidget,
      );
      expect(s.goals.byId('g1')!.reservedCents, 100000);

      // Excluir a retirada libera a reserva de volta.
      await tester.tap(find.byTooltip('Excluir movimento').at(0));
      await tester.pumpAndSettle();
      expect(s.goals.byId('g1')!.reservedCents, 150000);
      expect(s.transactions.all, isEmpty);
    },
  );

  testWidgets('histórico sem movimentos mostra o estado vazio', (tester) async {
    final s = await _setup(tester, goals: [_viagem]);
    await _pump(tester, s, (c) => showGoalHistory(c, _viagem));
    expect(find.text('Nenhum movimento ainda.'), findsOneWidget);
  });
}
