import 'package:finme/core/services/collection_repository.dart';
import 'package:finme/core/services/record_store.dart';
import 'package:finme/features/goals/domain/goal.dart';
import 'package:finme/features/goals/domain/goal_math.dart';
import 'package:flutter_test/flutter_test.dart';

final _today = DateTime(2026, 11, 15);

GoalMovement aporte(String id, DateTime date, int cents, {String? note}) =>
    GoalMovement(id: id, date: date, amountCents: cents, note: note);

/// Meta do SPEC §5.22: alvo 600000; aportes 100000 (01/10) e 50000 (01/11); retirada −30000 (05/11).
Goal viagem({DateTime? targetDate, bool archived = false}) => Goal(
  id: 'g1',
  name: 'Viagem',
  accountId: 'A',
  targetCents: 600000,
  targetDate: targetDate,
  archived: archived,
  movements: [
    aporte('m1', DateTime(2026, 10, 1), 100000),
    aporte('m2', DateTime(2026, 11, 1), 50000),
    aporte('m3', DateTime(2026, 11, 5), -30000),
  ],
);

Goal meta({
  required String id,
  required String accountId,
  required List<int> amounts,
  bool archived = false,
}) => Goal(
  id: id,
  name: id,
  accountId: accountId,
  targetCents: 1000000,
  archived: archived,
  movements: [
    for (var i = 0; i < amounts.length; i++)
      aporte('$id-$i', DateTime(2026, 11, 1), amounts[i]),
  ],
);

void main() {
  group('Goal — reserva e progresso', () {
    test('exemplo de §5.22', () {
      final g = viagem();
      expect(g.reservedCents, 120000);
      expect(g.remainingCents, 480000);
      expect(g.progress, 0.2);
      expect(g.reached, isFalse);
    });

    test('reserva corrompida (negativa) vira zero', () {
      final g = meta(id: 'x', accountId: 'A', amounts: [-500]);
      expect(g.rawReservedCents, -500);
      expect(g.reservedCents, 0);
      expect(g.progress, 0.0);
    });

    test('movimentos fora de ordem são ordenados por (data, id)', () {
      final g = Goal(
        id: 'g',
        name: 'n',
        accountId: 'A',
        targetCents: 100,
        movements: [
          aporte('b', DateTime(2026, 11, 2), 10),
          aporte('a', DateTime(2026, 11, 2), 10),
          aporte('c', DateTime(2026, 10, 1), 10),
        ],
      );
      expect(g.movements.map((m) => m.id).toList(), ['c', 'a', 'b']);
    });

    test('withMovement e withoutMovement devolvem instâncias novas', () {
      final original = viagem();
      final plus = original.withMovement(
        aporte('m4', DateTime(2026, 11, 10), 1000),
      );
      expect(plus.reservedCents, 121000);
      expect(original.reservedCents, 120000);

      final minus = original.withoutMovement('m2');
      expect(minus.reservedCents, 70000);
      expect(identical(minus, original), isFalse);
      expect(original.movements.length, 3);

      expect(original.withoutMovement('inexistente'), original);
    });

    test('reached quando reserva atinge o alvo', () {
      final g = meta(id: 'x', accountId: 'A', amounts: [1000000]);
      expect(g.reached, isTrue);
      expect(g.remainingCents, 0);
      expect(g.progress, 1.0);
    });
  });

  group('Goal — serialização', () {
    test('round-trip com data-alvo e movimento com nota', () {
      final g = viagem(targetDate: DateTime(2027, 5, 15)).copyWith(
        movements: [
          aporte('m1', DateTime(2026, 10, 1), 100000, note: 'salário'),
          aporte('m2', DateTime(2026, 11, 1), 50000),
        ],
      );
      final map = g.toMap();
      expect(map['targetDate'], '20270515');
      expect(Goal.fromMap(map), g);
      expect(Goal.fromMap(map).hashCode, g.hashCode);
    });

    test(
      'toMap sem targetDate não tem a chave; movimento sem nota não tem note',
      () {
        final map = viagem().toMap();
        expect(map.containsKey('targetDate'), isFalse);
        final primeiro = (map['movements'] as List).first as Map;
        expect(primeiro.containsKey('note'), isFalse);
      },
    );

    test('fromMap sem movements/archived → [] e false', () {
      final map = viagem().toMap()
        ..remove('movements')
        ..remove('archived');
      final g = Goal.fromMap(map);
      expect(g.movements, isEmpty);
      expect(g.archived, isFalse);
    });

    test('movimento inválido (sem amountCents) é ignorado', () {
      final map = viagem().toMap();
      (map['movements'] as List).add({'id': 'ruim', 'date': '20261101'});
      final g = Goal.fromMap(map);
      expect(g.movements.length, 3);
      expect(g.reservedCents, 120000);
    });

    test('fromMap com alvo ≤ 0 lança FormatException', () {
      for (final alvo in [0, -100]) {
        final map = viagem().toMap()..['targetCents'] = alvo;
        expect(() => Goal.fromMap(map), throwsFormatException);
      }
    });

    test('registro com alvo 0 em fm_goals é pulado no boot', () async {
      final store = MemoryRecordStore();
      await store.put('g1', viagem().toMap());
      await store.put(
        'ruim',
        viagem().toMap()
          ..['id'] = 'ruim'
          ..['targetCents'] = 0,
      );
      final repo = CollectionRepository<Goal>(
        store: store,
        fromMap: Goal.fromMap,
        toMap: (g) => g.toMap(),
        idOf: (g) => g.id,
      );
      expect(repo.all.map((g) => g.id), ['g1']);
    });

    test('copyWith: targetDate omitido mantém, null limpa', () {
      final g = viagem(targetDate: DateTime(2027, 5, 15));
      expect(g.copyWith(name: 'Casa').targetDate, DateTime(2027, 5, 15));
      expect(g.copyWith(targetDate: null).targetDate, isNull);
    });

    test('igualdade compara movimentos elemento a elemento', () {
      expect(viagem(), viagem());
      expect(viagem().withoutMovement('m1') == viagem(), isFalse);
    });
  });

  group('goal_math', () {
    test('reservedByAccount ignora arquivada e omite conta com 0', () {
      final goals = [
        meta(id: 'a', accountId: 'A', amounts: [120000]),
        meta(id: 'b', accountId: 'A', amounts: [50000]),
        meta(id: 'arq', accountId: 'A', amounts: [999], archived: true),
        meta(id: 'zero', accountId: 'B', amounts: [-100]),
      ];
      expect(reservedByAccount(goals), {'A': 170000});
    });

    test('availableToReserve desconta metas ativas da conta', () {
      final goals = [
        meta(id: 'a', accountId: 'A', amounts: [120000]),
        meta(id: 'b', accountId: 'A', amounts: [50000]),
        meta(id: 'arq', accountId: 'A', amounts: [999], archived: true),
      ];
      expect(
        availableToReserve(
          accountId: 'A',
          accountBalanceCents: 200000,
          goals: goals,
        ),
        30000,
      );
      expect(
        availableToReserve(
          accountId: 'A',
          accountBalanceCents: -5000,
          goals: goals,
        ),
        0,
      );
    });

    test('contributionError', () {
      expect(
        contributionError(amountCents: 30001, availableCents: 30000),
        'Saldo livre na conta: R\$ 300,00',
      );
      expect(
        contributionError(amountCents: 0, availableCents: 30000),
        'Informe um valor maior que zero',
      );
      expect(
        contributionError(amountCents: 30000, availableCents: 30000),
        isNull,
      );
    });

    test('withdrawalError', () {
      final g = viagem();
      expect(
        withdrawalError(amountCents: 120001, goal: g),
        'Reservado nesta meta: R\$ 1.200,00',
      );
      expect(
        withdrawalError(amountCents: -1, goal: g),
        'Informe um valor maior que zero',
      );
      expect(withdrawalError(amountCents: 120000, goal: g), isNull);
    });

    test('removeMovementError', () {
      final g = viagem();
      expect(removeMovementError(g, 'm1'), isNull);
      expect(removeMovementError(g, 'm2'), isNull);

      final apenasAporte = meta(
        id: 'x',
        accountId: 'A',
        amounts: [10000, -10000],
      );
      expect(
        removeMovementError(apenasAporte, 'x-0'),
        'Sem este aporte, as retiradas ficariam maiores que o reservado',
      );
    });

    test('overReservedCents', () {
      expect(
        overReservedCents(accountBalanceCents: 80000, reservedCents: 120000),
        40000,
      );
      expect(
        overReservedCents(accountBalanceCents: -1000, reservedCents: 5000),
        5000,
      );
      expect(
        overReservedCents(accountBalanceCents: 200000, reservedCents: 120000),
        0,
      );
    });

    test('monthlyContributionNeeded', () {
      expect(
        monthlyContributionNeeded(
          viagem(targetDate: DateTime(2027, 5, 15)),
          _today,
        ),
        80000,
      );
      expect(
        monthlyContributionNeeded(
          viagem(targetDate: DateTime(2026, 11, 30)),
          _today,
        ),
        480000,
      );
      expect(
        monthlyContributionNeeded(
          viagem(targetDate: DateTime(2026, 10, 10)),
          _today,
        ),
        480000,
      );
      expect(monthlyContributionNeeded(viagem(), _today), isNull);
      expect(
        monthlyContributionNeeded(
          meta(
            id: 'x',
            accountId: 'A',
            amounts: [1000000],
          ).copyWith(targetDate: DateTime(2027, 5, 15)),
          _today,
        ),
        0,
      );
    });

    test('monthlyContributionNeeded arredonda para cima', () {
      final g = Goal(
        id: 'g',
        name: 'n',
        accountId: 'A',
        targetCents: 100,
        targetDate: DateTime(2027, 2, 1),
      );
      // remaining 100, months = 3 → ceil(100 / 3) = 34
      expect(monthlyContributionNeeded(g, _today), 34);
    });

    test('isGoalOverdue', () {
      expect(
        isGoalOverdue(viagem(targetDate: DateTime(2026, 10, 10)), _today),
        isTrue,
      );
      expect(
        isGoalOverdue(viagem(targetDate: DateTime(2026, 11, 30)), _today),
        isFalse,
      );
      expect(isGoalOverdue(viagem(), _today), isFalse);
      expect(
        isGoalOverdue(
          meta(
            id: 'x',
            accountId: 'A',
            amounts: [1000000],
          ).copyWith(targetDate: DateTime(2026, 10, 10)),
          _today,
        ),
        isFalse,
      );
    });
  });
}
