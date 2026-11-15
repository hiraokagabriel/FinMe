import 'package:finme/app/app_scope.dart';
import 'package:finme/app/bootstrap.dart';
import 'package:finme/app/seed.dart';
import 'package:finme/core/services/record_store.dart';
import 'package:finme/core/utils/date_utils.dart';
import 'package:finme/features/transactions/domain/transaction.dart';
import 'package:flutter_test/flutter_test.dart';

DateTime _now() => DateTime(2026, 11, 14);

void main() {
  late AppServices s;

  setUp(() async {
    s = await bootstrap(storeFactory: (_) => MemoryRecordStore(), clock: _now);
    await seedDemo(s);
    await materializeRecurring(s);
  });

  test('categorias padrão: 12 de despesa e 4 de receita', () {
    expect(defaultCategories().length, 16);
    expect(s.categories.all.length, 16);
  });

  test('forecast é memoizado e recalcula após upsert', () async {
    final first = s.ledger.forecast;
    expect(identical(s.ledger.forecast, first), isTrue);

    await s.transactions.upsert(
      Transaction(
        id: 'extra_planned',
        type: TransactionType.expense,
        amountCents: 100,
        date: DateTime(2026, 11, 20),
        description: 'Extra',
        accountId: 'acc_alfa',
        status: TransactionStatus.planned,
      ),
    );
    final second = s.ledger.forecast;
    expect(identical(second, first), isFalse);
    expect(second.events.length, first.events.length + 1);
  });

  test('fatura de cartão de crédito não vazia; débito sem faturas', () {
    expect(s.ledger.invoicesFor('card_alfa_visa'), isNotEmpty);
    expect(s.ledger.invoicesFor('card_alfa_debito'), isEmpty);
  });

  test('materialização não duplica ao chamar duas vezes', () async {
    final count = s.transactions.all.length;
    await materializeRecurring(s);
    expect(s.transactions.all.length, count);
  });

  test('ocorrência apagada não volta após materializeRecurring', () async {
    final salary = s.transactions.all.firstWhere(
      (t) => t.recurringId == 'rec_salario',
    );
    await s.transactions.delete(salary.id);
    await materializeRecurring(s);
    expect(s.transactions.byId(salary.id), isNull);
  });

  test('upcoming inclui provisionado atrasado e boleto de 5 dias', () {
    final list = s.ledger.upcoming();
    final today = dateOnly(_now());
    expect(list.any((t) => t.isPlanned && t.date.isBefore(today)), isTrue);
    expect(
      list.any((t) => t.isBoleto && isSameDay(t.date, DateTime(2026, 11, 19))),
      isTrue,
    );
  });
}
