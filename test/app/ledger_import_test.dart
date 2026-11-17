import 'package:finme/app/bootstrap.dart';
import 'package:finme/core/services/record_store.dart';
import 'package:finme/features/importing/domain/categorizer.dart';
import 'package:finme/features/importing/domain/merchant_dictionary.dart';
import 'package:finme/features/rules/domain/transaction_rule.dart';
import 'package:finme/features/transactions/domain/transaction.dart';
import 'package:flutter_test/flutter_test.dart';

DateTime _now() => DateTime(2026, 11, 14);

void main() {
  test('bootstrap semeia o dicionário e não duplica no segundo boot', () async {
    final stores = <String, RecordStore>{};
    RecordStore factory(String box) =>
        stores.putIfAbsent(box, MemoryRecordStore.new);

    final first = await bootstrap(storeFactory: factory, clock: _now);
    expect(first.dictionary.all.length, kDefaultDictionary.length);
    expect(first.rules.all, isEmpty);
    expect(first.importProfiles.all, isEmpty);

    final second = await bootstrap(storeFactory: factory, clock: _now);
    expect(second.dictionary.all.length, kDefaultDictionary.length);
  });

  test('categorizer é memoizado e recriado após regra nova', () async {
    final s = await bootstrap(
      storeFactory: (_) => MemoryRecordStore(),
      clock: _now,
    );
    final first = s.ledger.categorizer;
    expect(identical(s.ledger.categorizer, first), isTrue);

    await s.rules.upsert(
      const TransactionRule(id: 'r', pattern: 'XPTO', categoryId: 'cat_lazer'),
    );
    expect(identical(s.ledger.categorizer, first), isFalse);
    expect(
      s.ledger.categorizer.categorize('XPTO 1', isIncome: false).categoryId,
      'cat_lazer',
    );
  });

  test('histórico de lançamentos vira sugestão do tipo history', () async {
    final s = await bootstrap(
      storeFactory: (_) => MemoryRecordStore(),
      clock: _now,
    );
    expect(
      s.ledger.categorizer
          .categorize('PADARIA PAO BOM 2', isIncome: false)
          .source,
      isNot(SuggestionSource.history),
    );

    await s.transactions.upsert(
      Transaction(
        id: 'hist_1',
        type: TransactionType.expense,
        amountCents: 1500,
        date: DateTime(2026, 11, 10),
        description: 'PADARIA PAO BOM',
        categoryId: 'cat_alimentacao',
      ),
    );
    expect(
      s.ledger.categorizer
          .categorize('PADARIA PAO BOM 2', isIncome: false)
          .source,
      SuggestionSource.history,
    );
  });
}
