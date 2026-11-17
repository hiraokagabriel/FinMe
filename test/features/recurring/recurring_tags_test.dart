import 'package:finme/features/recurring/domain/recurrence.dart';
import 'package:finme/features/recurring/domain/recurring_rule.dart';
import 'package:finme/features/transactions/domain/transaction.dart';
import 'package:flutter_test/flutter_test.dart';

RecurringRule _rule({List<String> tags = const []}) => RecurringRule(
  id: 'r1',
  description: 'Aluguel',
  type: TransactionType.expense,
  amountCents: 150000,
  frequency: Frequency.monthly,
  startDate: DateTime(2026, 1, 5),
  tags: tags,
);

void main() {
  test('tags são normalizadas no construtor', () {
    final r = _rule(tags: ['#Casa', 'casa', 'fixo']);
    expect(r.tags, ['Casa', 'fixo']);
  });

  test('toMap omite tags quando vazia e inclui quando não', () {
    expect(_rule().toMap().containsKey('tags'), isFalse);
    expect(_rule(tags: ['fixo']).toMap()['tags'], ['fixo']);
  });

  test('fromMap tolera ausência, nulo e não-lista', () {
    final base = _rule().toMap();
    expect(RecurringRule.fromMap(base).tags, isEmpty);
    expect(RecurringRule.fromMap({...base, 'tags': null}).tags, isEmpty);
    expect(RecurringRule.fromMap({...base, 'tags': 'casa'}).tags, isEmpty);
    expect(
      RecurringRule.fromMap({
        ...base,
        'tags': ['a', 1],
      }).tags,
      ['a'],
    );
  });

  test('toMap/fromMap ida e volta preserva tags', () {
    final r = _rule(tags: ['Casa', 'fixo']);
    expect(RecurringRule.fromMap(r.toMap()), r);
  });

  test('copyWith() mantém tags e copyWith(tags:) troca', () {
    final r = _rule(tags: ['casa']);
    expect(r.copyWith().tags, ['casa']);
    expect(r.copyWith(tags: ['fixo']).tags, ['fixo']);
    expect(r.copyWith(tags: []).tags, isEmpty);
  });

  test('== difere com tags diferentes e iguala com tags iguais', () {
    expect(_rule(tags: ['a']) == _rule(tags: ['b']), isFalse);
    expect(_rule(tags: ['a']) == _rule(tags: ['a']), isTrue);
    expect(_rule(tags: ['a']).hashCode == _rule(tags: ['a']).hashCode, isTrue);
  });

  test('occurrenceTransactions (projeção e materialização) copia tags', () {
    final r = _rule(tags: ['Casa', 'fixo']);
    final from = DateTime(2026, 1, 1);
    final to = DateTime(2026, 3, 31);

    final projected = occurrenceTransactions(
      r,
      from,
      to,
      const {},
      forProjection: true,
    );
    final materialized = occurrenceTransactions(
      r,
      from,
      to,
      const {},
      forProjection: false,
    );

    expect(projected, hasLength(3));
    expect(materialized, hasLength(3));
    for (final t in [...projected, ...materialized]) {
      expect(t.tags, ['Casa', 'fixo']);
    }
  });
}
