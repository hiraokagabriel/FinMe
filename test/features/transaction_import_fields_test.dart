import 'package:finme/features/transactions/domain/transaction.dart';
import 'package:flutter_test/flutter_test.dart';

Transaction _base() => Transaction(
  id: 't1',
  type: TransactionType.expense,
  amountCents: 1500,
  date: DateTime(2026, 11, 14),
  description: 'LOJA EXEMPLO',
  accountId: 'acc1',
);

void main() {
  test('round-trip com externalId e importedDescription', () {
    final t = _base().copyWith(
      externalId: 'FITID-123',
      importedDescription: 'PAG LOJA EXEMPLO 12/11',
    );
    final back = Transaction.fromMap(t.toMap());
    expect(back, t);
    expect(back.externalId, 'FITID-123');
    expect(back.importedDescription, 'PAG LOJA EXEMPLO 12/11');
  });

  test('toMap omite as chaves quando os campos são nulos', () {
    final map = _base().toMap();
    expect(map.containsKey('externalId'), isFalse);
    expect(map.containsKey('importedDescription'), isFalse);
  });

  test('fromMap de mapa antigo deixa os dois campos null', () {
    final map = _base().toMap()
      ..remove('externalId')
      ..remove('importedDescription');
    final t = Transaction.fromMap(map);
    expect(t.externalId, isNull);
    expect(t.importedDescription, isNull);
  });

  test('copyWith com null limpa; omitido mantém', () {
    final t = _base().copyWith(externalId: 'X', importedDescription: 'Y');
    expect(t.copyWith(externalId: null).externalId, isNull);
    expect(t.copyWith(externalId: null).importedDescription, 'Y');
    expect(t.copyWith(importedDescription: null).importedDescription, isNull);
    expect(t.copyWith().externalId, 'X');
    expect(t.copyWith().importedDescription, 'Y');
  });

  test('importedDescription diferente quebra ==', () {
    final a = _base().copyWith(importedDescription: 'A');
    final b = _base().copyWith(importedDescription: 'B');
    expect(a == b, isFalse);
    expect(a.hashCode == b.hashCode, isFalse);
    expect(a == a.copyWith(), isTrue);
  });
}
