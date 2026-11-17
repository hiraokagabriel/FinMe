import 'package:finme/app/app_scope.dart';
import 'package:finme/app/bootstrap.dart';
import 'package:finme/core/models/app_settings.dart';
import 'package:finme/core/services/record_store.dart';
import 'package:finme/core/theme/app_colors.dart';
import 'package:finme/core/theme/app_theme.dart';
import 'package:finme/core/widgets/widgets.dart';
import 'package:finme/features/accounts/domain/account.dart';
import 'package:finme/features/accounts/presentation/accounts_page.dart';
import 'package:finme/features/goals/domain/goal.dart';
import 'package:finme/features/goals/presentation/goal_dialogs.dart';
import 'package:finme/features/goals/presentation/goals_section.dart';
import 'package:finme/features/transactions/domain/transaction.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

final _light = AppTheme.light().extension<AppColors>()!;

/// Conta Alfa (ativa, saldo 200000), opcionalmente sem conta.
Future<AppServices> _setup(
  WidgetTester tester, {
  bool withAccount = true,
  List<Goal> goals = const [],
  List<Transaction> transactions = const [],
  bool ultra = false,
}) async {
  return (await tester.runAsync(() async {
    final s = await bootstrap(
      storeFactory: (_) => MemoryRecordStore(),
      clock: () => DateTime(2026, 11, 15),
    );
    if (withAccount) {
      await s.accounts.upsert(
        const Account(
          id: 'alfa',
          name: 'Conta Alfa',
          bankName: 'Banco Alfa',
          type: AccountType.checking,
          initialBalanceCents: 200000,
          colorValue: 0xFF42A5F5,
        ),
      );
    }
    await s.goals.upsertAll(goals);
    await s.transactions.upsertAll(transactions);
    if (ultra) {
      await s.settings.update((x) => x.copyWith(mode: AppMode.ultra));
    }
    return s;
  }))!;
}

Future<void> _pump(
  WidgetTester tester,
  AppServices s,
  Widget page, {
  Size size = const Size(1200, 900),
}) async {
  // MediaQuery lê tester.view; setSurfaceSize não atualiza essa fonte.
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = size;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(const SizedBox());
  await tester.pumpWidget(
    AppScope(
      services: s,
      child: MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(body: page),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

const _section = SingleChildScrollView(child: GoalsSection());

/// `FilledButton.icon` tem tipo de runtime próprio: `find.byType` não o acha.
Iterable<FilledButton> _filledButtons(WidgetTester tester) => tester
    .widgetList<FilledButton>(find.byWidgetPredicate((w) => w is FilledButton));

GoalMovement _aporte(String id, DateTime date, int cents) =>
    GoalMovement(id: id, date: date, amountCents: cents);

final _viagem = Goal(
  id: 'g1',
  name: 'Viagem',
  accountId: 'alfa',
  targetCents: 600000,
  targetDate: DateTime(2027, 5, 15),
  movements: [_aporte('m1', DateTime(2026, 11, 1), 120000)],
);

void main() {
  testWidgets(
    'sem metas: estado vazio; sem conta ativa, Nova meta desabilitado',
    (tester) async {
      final s = await _setup(tester, withAccount: false);
      await _pump(tester, s, _section);
      expect(find.byType(EmptyState), findsOneWidget);
      final buttons = _filledButtons(tester);
      expect(buttons, hasLength(2));
      for (final b in buttons) {
        expect(b.onPressed, isNull);
      }
    },
  );

  testWidgets(
    'sem metas com conta: Nova meta habilitado no cabeçalho e no vazio',
    (tester) async {
      final s = await _setup(tester);
      await _pump(tester, s, _section);
      expect(find.byType(EmptyState), findsOneWidget);
      final buttons = _filledButtons(tester);
      expect(buttons, hasLength(2));
      for (final b in buttons) {
        expect(b.onPressed, isNotNull);
      }
    },
  );

  testWidgets('Simples: progresso e aporte; sem menu nem aporte mensal', (
    tester,
  ) async {
    final s = await _setup(tester, goals: [_viagem]);
    await _pump(tester, s, _section);
    expect(find.text('Viagem'), findsOneWidget);
    expect(find.text('R\$ 1.200,00'), findsOneWidget);
    expect(find.text('R\$ 6.000,00'), findsOneWidget);
    expect(find.text('20,0%'), findsOneWidget);
    expect(find.byTooltip('Aportar'), findsOneWidget);
    expect(find.byTooltip('Ações da meta'), findsNothing);
    expect(find.textContaining('Aporte mensal'), findsNothing);
  });

  testWidgets('Ultra: aporte mensal, data-alvo passou e meta atingida', (
    tester,
  ) async {
    final s = await _setup(
      tester,
      ultra: true,
      goals: [
        _viagem,
        Goal(
          id: 'g2',
          name: 'Atrasada',
          accountId: 'alfa',
          targetCents: 600000,
          targetDate: DateTime(2026, 10, 10),
          movements: [_aporte('m2', DateTime(2026, 11, 1), 120000)],
        ),
        Goal(
          id: 'g3',
          name: 'Pronta',
          accountId: 'alfa',
          targetCents: 100000,
          targetDate: DateTime(2027, 1, 1),
          movements: [_aporte('m3', DateTime(2026, 11, 1), 100000)],
        ),
      ],
    );
    await _pump(tester, s, _section);
    expect(find.text('Aporte mensal necessário: R\$ 800,00'), findsOneWidget);
    expect(find.text('Data-alvo passou'), findsOneWidget);
    expect(find.text('Meta atingida'), findsOneWidget);
    expect(find.byTooltip('Ações da meta'), findsNWidgets(3));
  });

  testWidgets(
    'Ultra: gasto que derruba o saldo mostra reserva acima e caption em warning',
    (tester) async {
      final s = await _setup(
        tester,
        ultra: true,
        goals: [_viagem],
        transactions: [
          Transaction(
            id: 't1',
            type: TransactionType.expense,
            amountCents: 120000,
            date: DateTime(2026, 11, 10),
            description: 'Compra',
            accountId: 'alfa',
          ),
        ],
      );
      await _pump(tester, s, const AccountsPage(), size: const Size(1400, 900));
      expect(
        find.text('Reserva maior que o saldo da conta: faltam R\$ 400,00'),
        findsOneWidget,
      );
      final caption = tester.widget<Text>(find.text('R\$ 1.200,00 reservado'));
      expect(caption.style?.color, _light.warning);
    },
  );

  testWidgets(
    'Ultra: arquivar some da lista; Mostrar arquivadas reaparece em textSecondary',
    (tester) async {
      final antiga = Goal(
        id: 'g2',
        name: 'Antiga',
        accountId: 'alfa',
        targetCents: 100000,
        archived: true,
      );
      final s = await _setup(tester, ultra: true, goals: [_viagem, antiga]);
      await _pump(tester, s, _section);
      expect(find.text('Antiga'), findsNothing);

      await tester.tap(find.byTooltip('Ações da meta'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Arquivar'));
      await tester.pumpAndSettle();
      expect(s.goals.byId('g1')!.archived, isTrue);
      expect(find.text('Viagem'), findsNothing);

      await tester.tap(find.text('Mostrar arquivadas'));
      await tester.pumpAndSettle();
      expect(
        tester.widget<Text>(find.text('Viagem')).style?.color,
        _light.textSecondary,
      );
      expect(
        tester.widget<Text>(find.text('Antiga')).style?.color,
        _light.textSecondary,
      );
    },
  );

  testWidgets(
    'Ultra: meta arquivada não oferece Aportar (nem botão nem menu)',
    (tester) async {
      final antiga = Goal(
        id: 'g2',
        name: 'Antiga',
        accountId: 'alfa',
        targetCents: 600000,
        archived: true,
        movements: [_aporte('m2', DateTime(2026, 11, 1), 120000)],
      );
      final s = await _setup(tester, ultra: true, goals: [antiga]);
      await _pump(tester, s, _section);
      await tester.tap(find.text('Mostrar arquivadas'));
      await tester.pumpAndSettle();

      expect(find.text('Antiga'), findsOneWidget);
      expect(find.byTooltip('Aportar'), findsNothing);
      await tester.tap(find.byTooltip('Ações da meta'));
      await tester.pumpAndSettle();
      expect(find.text('Aportar'), findsNothing);
      expect(find.text('Desarquivar'), findsOneWidget);
    },
  );

  testWidgets(
    'Ultra: desarquivar meta com reserva acima do saldo mostra aviso',
    (tester) async {
      final antiga = Goal(
        id: 'g2',
        name: 'Antiga',
        accountId: 'alfa',
        targetCents: 600000,
        archived: true,
        movements: [_aporte('m2', DateTime(2026, 11, 1), 120000)],
      );
      final s = await _setup(
        tester,
        ultra: true,
        goals: [antiga],
        transactions: [
          Transaction(
            id: 't1',
            type: TransactionType.expense,
            amountCents: 120000,
            date: DateTime(2026, 11, 10),
            description: 'Compra',
            accountId: 'alfa',
          ),
        ],
      );
      await _pump(tester, s, _section);
      await tester.tap(find.text('Mostrar arquivadas'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Ações da meta'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Desarquivar'));
      await tester.pumpAndSettle();

      expect(s.goals.byId('g2')!.archived, isFalse);
      // O badge da meta repete o texto: o aviso precisa vir do SnackBar.
      expect(
        find.descendant(
          of: find.byType(SnackBar),
          matching: find.text(
            'Reserva maior que o saldo da conta: faltam R\$ 400,00',
          ),
        ),
        findsOneWidget,
      );
    },
  );

  testWidgets('Ultra: desarquivar com saldo que cobre a reserva não avisa', (
    tester,
  ) async {
    final antiga = Goal(
      id: 'g2',
      name: 'Antiga',
      accountId: 'alfa',
      targetCents: 600000,
      archived: true,
      movements: [_aporte('m2', DateTime(2026, 11, 1), 120000)],
    );
    final s = await _setup(tester, ultra: true, goals: [antiga]);
    await _pump(tester, s, _section);
    await tester.tap(find.text('Mostrar arquivadas'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Ações da meta'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Desarquivar'));
    await tester.pumpAndSettle();

    expect(s.goals.byId('g2')!.archived, isFalse);
    expect(find.textContaining('Reserva maior que o saldo'), findsNothing);
  });

  testWidgets('Ultra: excluir meta pede confirmação e a remove', (
    tester,
  ) async {
    final s = await _setup(tester, ultra: true, goals: [_viagem]);
    await _pump(tester, s, _section);
    await tester.tap(find.byTooltip('Ações da meta'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Excluir'));
    await tester.pumpAndSettle();
    expect(
      find.text('A reserva de R\$ 1.200,00 volta a ficar livre.'),
      findsOneWidget,
    );
    await tester.tap(find.widgetWithText(FilledButton, 'Excluir'));
    await tester.pumpAndSettle();
    expect(s.goals.byId('g1'), isNull);
    expect(find.text('Viagem'), findsNothing);
  });

  testWidgets('aporte em meta excluída não grava e avisa', (tester) async {
    final s = await _setup(tester, goals: [_viagem]);
    await _pump(
      tester,
      s,
      Center(
        child: Builder(
          builder: (context) => TextButton(
            onPressed: () => showGoalMovementDialog(context, _viagem),
            child: const Text('abrir'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('abrir'));
    await tester.pumpAndSettle();

    await tester.runAsync(() => s.goals.delete('g1'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextFormField).at(0), '1000,00');
    await tester.tap(find.widgetWithText(FilledButton, 'Salvar'));
    await tester.pumpAndSettle();
    expect(find.text('Esta meta foi excluída.'), findsOneWidget);
    expect(s.goals.all, isEmpty);
  });

  testWidgets('excluir conta com meta é bloqueado com SnackBar', (
    tester,
  ) async {
    final s = await _setup(tester, goals: [_viagem]);
    await _pump(tester, s, const AccountsPage(), size: const Size(1400, 900));
    await tester.tap(find.byTooltip('Ações da conta').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Excluir'));
    await tester.pumpAndSettle();
    expect(
      find.text(
        'Conta usada por lançamentos, cartões, recorrências ou metas. Arquive em vez de excluir.',
      ),
      findsOneWidget,
    );
    expect(s.accounts.byId('alfa'), isNotNull);
  });
}
