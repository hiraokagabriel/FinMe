import 'package:finme/features/recurring/domain/recurrence.dart';
import 'package:finme/features/recurring/domain/recurring_rule.dart';
import 'package:finme/features/transactions/domain/installments.dart';
import 'package:finme/features/transactions/domain/transaction.dart';
import 'package:flutter_test/flutter_test.dart';

Transaction _base({int amountCents = 10000, DateTime? date}) => Transaction(
  id: 'base',
  type: TransactionType.expense,
  amountCents: amountCents,
  date: date ?? DateTime(2026, 1, 31),
  description: 'Notebook',
  cardId: 'card1',
  categoryId: 'tech',
);

RecurringRule _rule({
  Frequency frequency = Frequency.monthly,
  DateTime? start,
  DateTime? end,
  bool active = true,
  String? cardId,
  bool isBoleto = false,
}) => RecurringRule(
  id: 'r1',
  description: 'Streaming',
  type: TransactionType.expense,
  amountCents: 2990,
  frequency: frequency,
  startDate: start ?? DateTime(2026, 1, 31),
  endDate: end,
  active: active,
  cardId: cardId,
  isBoleto: isBoleto,
  accountId: cardId == null ? 'acc1' : null,
  categoryId: 'subs',
);

void main() {
  group('buildInstallments', () {
    test('100,00 em 3x: 33,34 + 33,33 + 33,33', () {
      final parts = buildInstallments(base: _base(), count: 3, groupId: 'g1');

      expect(parts.map((p) => p.amountCents), [3334, 3333, 3333]);
      expect(parts.fold<int>(0, (s, p) => s + p.amountCents), 10000);
      expect(parts.map((p) => p.id), ['g1_1', 'g1_2', 'g1_3']);
      expect(parts.map((p) => p.installmentIndex), [1, 2, 3]);
      expect(parts.map((p) => p.installmentCount), [3, 3, 3]);
      expect(parts.every((p) => p.installmentGroupId == 'g1'), isTrue);
      expect(parts.every((p) => p.description == 'Notebook'), isTrue);
      expect(parts.every((p) => p.cardId == 'card1'), isTrue);
      expect(parts.every((p) => p.categoryId == 'tech'), isTrue);
    });

    test('datas a partir de 31/01 sem deslizar', () {
      final parts = buildInstallments(base: _base(), count: 4, groupId: 'g1');

      expect(parts.map((p) => p.date), [
        DateTime(2026, 1, 31),
        DateTime(2026, 2, 28),
        DateTime(2026, 3, 31),
        DateTime(2026, 4, 30),
      ]);
    });

    test('soma das parcelas == valor base para vários cenários', () {
      for (final amount in [10000, 10001, 9999, 123457]) {
        for (var n = 1; n <= 12; n++) {
          final parts = buildInstallments(
            base: _base(amountCents: amount),
            count: n,
            groupId: 'g',
          );
          final sum = parts.fold<int>(0, (s, p) => s + p.amountCents);
          expect(sum, amount, reason: 'amount=$amount count=$n');
          expect(parts.length, n);
        }
      }
    });
  });

  group('buildInstallments validação', () {
    test('count < 1 ou count > amountCents lança ArgumentError', () {
      expect(
        () => buildInstallments(base: _base(), count: 0, groupId: 'g'),
        throwsArgumentError,
      );
      expect(
        () => buildInstallments(
          base: _base(amountCents: 2),
          count: 3,
          groupId: 'g',
        ),
        throwsArgumentError,
      );
      expect(
        buildInstallments(
          base: _base(amountCents: 3),
          count: 3,
          groupId: 'g',
        ).map((p) => p.amountCents),
        [1, 1, 1],
      );
    });
  });

  group('occurrencesBetween', () {
    test('monthly com início dia 31 → 31/01, 28/02, 31/03, 30/04', () {
      expect(
        occurrencesBetween(
          _rule(),
          DateTime(2026, 1, 1),
          DateTime(2026, 4, 30),
        ),
        [
          DateTime(2026, 1, 31),
          DateTime(2026, 2, 28),
          DateTime(2026, 3, 31),
          DateTime(2026, 4, 30),
        ],
      );
    });

    test('monthly em janela posterior começa do mês certo', () {
      expect(
        occurrencesBetween(
          _rule(),
          DateTime(2026, 3, 1),
          DateTime(2026, 4, 30),
        ),
        [DateTime(2026, 3, 31), DateTime(2026, 4, 30)],
      );
    });

    test('weekly: start + 7k', () {
      expect(
        occurrencesBetween(
          _rule(frequency: Frequency.weekly, start: DateTime(2026, 1, 1)),
          DateTime(2026, 1, 15),
          DateTime(2026, 1, 31),
        ),
        [DateTime(2026, 1, 15), DateTime(2026, 1, 22), DateTime(2026, 1, 29)],
      );
    });

    test('weekly em janela muito posterior (pulo eficiente)', () {
      expect(
        occurrencesBetween(
          _rule(frequency: Frequency.weekly, start: DateTime(2026, 1, 1)),
          DateTime(2026, 11, 1),
          DateTime(2026, 11, 30),
        ),
        [
          DateTime(2026, 11, 5),
          DateTime(2026, 11, 12),
          DateTime(2026, 11, 19),
          DateTime(2026, 11, 26),
        ],
      );
    });

    test('yearly 29/02/2024 → 28/02 em não-bissexto', () {
      expect(
        occurrencesBetween(
          _rule(frequency: Frequency.yearly, start: DateTime(2024, 2, 29)),
          DateTime(2024, 1, 1),
          DateTime(2028, 12, 31),
        ),
        [
          DateTime(2024, 2, 29),
          DateTime(2025, 2, 28),
          DateTime(2026, 2, 28),
          DateTime(2027, 2, 28),
          DateTime(2028, 2, 29),
        ],
      );
    });

    test('endDate respeitado (inclusivo)', () {
      expect(
        occurrencesBetween(
          _rule(end: DateTime(2026, 2, 28)),
          DateTime(2026, 1, 1),
          DateTime(2026, 12, 31),
        ),
        [DateTime(2026, 1, 31), DateTime(2026, 2, 28)],
      );
      expect(
        occurrencesBetween(
          _rule(
            frequency: Frequency.weekly,
            start: DateTime(2026, 1, 1),
            end: DateTime(2026, 1, 22),
          ),
          DateTime(2026, 1, 1),
          DateTime(2026, 2, 28),
        ),
        [
          DateTime(2026, 1, 1),
          DateTime(2026, 1, 8),
          DateTime(2026, 1, 15),
          DateTime(2026, 1, 22),
        ],
      );
    });

    test('limites from/to inclusivos e from > to → []', () {
      expect(
        occurrencesBetween(
          _rule(),
          DateTime(2026, 1, 31),
          DateTime(2026, 1, 31),
        ),
        [DateTime(2026, 1, 31)],
      );
      expect(
        occurrencesBetween(_rule(), DateTime(2026, 4, 1), DateTime(2026, 3, 1)),
        isEmpty,
      );
    });

    test('antes do startDate → []', () {
      expect(
        occurrencesBetween(
          _rule(),
          DateTime(2025, 1, 1),
          DateTime(2025, 12, 31),
        ),
        isEmpty,
      );
    });

    test('active=false → []', () {
      expect(
        occurrencesBetween(
          _rule(active: false),
          DateTime(2026, 1, 1),
          DateTime(2026, 12, 31),
        ),
        isEmpty,
      );
    });
  });

  group('occurrenceTransactions', () {
    test('sem cartão: planned, copia campos, recurringId e id', () {
      final txs = occurrenceTransactions(
        _rule(),
        DateTime(2026, 2, 1),
        DateTime(2026, 2, 28),
        const <String>{},
        forProjection: true,
      );

      expect(txs, hasLength(1));
      final t = txs.single;
      expect(t.id, 'r1_20260228');
      expect(t.recurringId, 'r1');
      expect(t.status, TransactionStatus.planned);
      expect(t.type, TransactionType.expense);
      expect(t.amountCents, 2990);
      expect(t.date, DateTime(2026, 2, 28));
      expect(t.description, 'Streaming');
      expect(t.categoryId, 'subs');
      expect(t.accountId, 'acc1');
      expect(t.cardId, isNull);
      expect(t.isBoleto, isFalse);
    });

    test('com cartão: status paid', () {
      final txs = occurrenceTransactions(
        _rule(cardId: 'card1'),
        DateTime(2026, 2, 1),
        DateTime(2026, 2, 28),
        const <String>{},
        forProjection: false,
      );

      expect(txs.single.status, TransactionStatus.paid);
      expect(txs.single.cardId, 'card1');
      expect(txs.single.accountId, isNull);
    });

    test('status materializada: passado não-boleto → paid', () {
      final txs = occurrenceTransactions(
        _rule(),
        DateTime(2026, 1, 1),
        DateTime(2026, 2, 28),
        const <String>{},
        forProjection: false,
      );

      expect(txs.map((t) => t.date), [
        DateTime(2026, 1, 31),
        DateTime(2026, 2, 28),
      ]);
      expect(txs.first.status, TransactionStatus.paid);
    });

    test('status materializada: date == to → planned', () {
      final txs = occurrenceTransactions(
        _rule(),
        DateTime(2026, 1, 1),
        DateTime(2026, 2, 28),
        const <String>{},
        forProjection: false,
      );

      expect(txs.last.date, DateTime(2026, 2, 28));
      expect(txs.last.status, TransactionStatus.planned);
    });

    test('status materializada: passado boleto → planned', () {
      final txs = occurrenceTransactions(
        _rule(isBoleto: true),
        DateTime(2026, 1, 1),
        DateTime(2026, 2, 28),
        const <String>{},
        forProjection: false,
      );

      expect(txs.map((t) => t.isBoleto), [true, true]);
      expect(txs.map((t) => t.status), [
        TransactionStatus.planned,
        TransactionStatus.planned,
      ]);
    });

    test('status projeção: conta passada → planned; cartão → paid', () {
      final conta = occurrenceTransactions(
        _rule(),
        DateTime(2026, 1, 1),
        DateTime(2026, 2, 28),
        const <String>{},
        forProjection: true,
      );
      expect(conta.map((t) => t.status), [
        TransactionStatus.planned,
        TransactionStatus.planned,
      ]);

      final cartao = occurrenceTransactions(
        _rule(cardId: 'card1'),
        DateTime(2026, 1, 1),
        DateTime(2026, 2, 28),
        const <String>{},
        forProjection: true,
      );
      expect(cartao.map((t) => t.status), [
        TransactionStatus.paid,
        TransactionStatus.paid,
      ]);
    });

    test('pula ids já existentes', () {
      final txs = occurrenceTransactions(
        _rule(),
        DateTime(2026, 1, 1),
        DateTime(2026, 3, 31),
        {'r1_20260131', 'r1_20260331'},
        forProjection: false,
      );

      expect(txs.map((t) => t.id), ['r1_20260228']);
    });

    test('regra inativa → []', () {
      expect(
        occurrenceTransactions(
          _rule(active: false),
          DateTime(2026, 1, 1),
          DateTime(2026, 12, 31),
          const <String>{},
          forProjection: true,
        ),
        isEmpty,
      );
    });
  });

  test('occurrenceId = ruleId_yyyyMMdd', () {
    expect(occurrenceId(_rule(), DateTime(2026, 1, 31)), 'r1_20260131');
  });
}
