import 'package:finme/features/recurring/domain/recurring_rule.dart';
import 'package:finme/features/transactions/domain/transaction.dart';
import 'package:flutter_test/flutter_test.dart';

/// Omitido mantém (`copyWith()` == original); `null` limpa; valor troca.
void _checkNullable<T>(
  T full,
  T Function(T, Object?) apply,
  Object? Function(T) read,
  Object value,
) {
  expect(read(apply(full, value)), value);
  expect(read(apply(full, null)), isNull);
}

Transaction _fullTransaction() => Transaction(
  id: 't1',
  type: TransactionType.transfer,
  amountCents: 1000,
  date: DateTime(2026, 11, 14),
  description: 'Pix',
  categoryId: 'cat',
  accountId: 'acc',
  cardId: 'card',
  toAccountId: 'acc2',
  invoiceKey: '2026-11',
  installmentGroupId: 'grp',
  installmentIndex: 1,
  installmentCount: 3,
  recurringId: 'rec',
  notes: 'nota',
);

RecurringRule _fullRule() => RecurringRule(
  id: 'r1',
  description: 'Academia',
  type: TransactionType.expense,
  amountCents: 9900,
  frequency: Frequency.monthly,
  startDate: DateTime(2026, 1, 5),
  categoryId: 'cat',
  accountId: 'acc',
  cardId: 'card',
  endDate: DateTime(2026, 6, 5),
  materializedUntil: DateTime(2026, 3, 5),
);

void main() {
  group('Transaction.copyWith campos anuláveis', () {
    test('omitido mantém, null limpa, valor troca', () {
      final full = _fullTransaction();
      expect(full.copyWith(), full);

      _checkNullable(
        full,
        (t, v) => t.copyWith(categoryId: v),
        (t) => t.categoryId,
        'cat2',
      );
      _checkNullable(
        full,
        (t, v) => t.copyWith(accountId: v),
        (t) => t.accountId,
        'acc3',
      );
      _checkNullable(
        full,
        (t, v) => t.copyWith(cardId: v),
        (t) => t.cardId,
        'card2',
      );
      _checkNullable(
        full,
        (t, v) => t.copyWith(toAccountId: v),
        (t) => t.toAccountId,
        'acc4',
      );
      _checkNullable(
        full,
        (t, v) => t.copyWith(invoiceKey: v),
        (t) => t.invoiceKey,
        '2026-12',
      );
      _checkNullable(
        full,
        (t, v) => t.copyWith(installmentGroupId: v),
        (t) => t.installmentGroupId,
        'grp2',
      );
      _checkNullable(
        full,
        (t, v) => t.copyWith(installmentIndex: v),
        (t) => t.installmentIndex,
        2,
      );
      _checkNullable(
        full,
        (t, v) => t.copyWith(installmentCount: v),
        (t) => t.installmentCount,
        4,
      );
      _checkNullable(
        full,
        (t, v) => t.copyWith(recurringId: v),
        (t) => t.recurringId,
        'rec2',
      );
      _checkNullable(
        full,
        (t, v) => t.copyWith(notes: v),
        (t) => t.notes,
        'outra',
      );
    });

    test('limpar um campo não afeta os demais', () {
      final cleared = _fullTransaction().copyWith(notes: null);
      expect(cleared.notes, isNull);
      expect(cleared.categoryId, 'cat');
      expect(cleared.installmentCount, 3);
    });

    test('notes: null sobrevive ao round-trip toMap/fromMap', () {
      final cleared = _fullTransaction().copyWith(notes: null);
      expect(cleared.toMap()['notes'], isNull);
      expect(Transaction.fromMap(cleared.toMap()), cleared);
    });
  });

  group('RecurringRule.copyWith campos anuláveis', () {
    test('omitido mantém, null limpa, valor troca', () {
      final full = _fullRule();
      expect(full.copyWith(), full);

      _checkNullable(
        full,
        (r, v) => r.copyWith(categoryId: v),
        (r) => r.categoryId,
        'cat2',
      );
      _checkNullable(
        full,
        (r, v) => r.copyWith(accountId: v),
        (r) => r.accountId,
        'acc2',
      );
      _checkNullable(
        full,
        (r, v) => r.copyWith(cardId: v),
        (r) => r.cardId,
        'card2',
      );
      _checkNullable(
        full,
        (r, v) => r.copyWith(endDate: v),
        (r) => r.endDate,
        DateTime(2026, 12, 1),
      );
      _checkNullable(
        full,
        (r, v) => r.copyWith(materializedUntil: v),
        (r) => r.materializedUntil,
        DateTime(2026, 4, 1),
      );
    });

    test('endDate com horário é normalizada pelo construtor', () {
      final rule = _fullRule().copyWith(endDate: DateTime(2026, 12, 1, 9));
      expect(rule.endDate, DateTime(2026, 12, 1));
    });
  });
}
