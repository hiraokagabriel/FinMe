import 'package:finme/features/importing/domain/import_profile.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const base = ImportProfile(id: 'p', name: 'X', accountId: 'acc_1');

  test('round-trip fromMap(toMap(p)) == p com débito/crédito e mapa', () {
    const p = ImportProfile(
      id: 'p',
      name: 'Extrato Alfa',
      accountId: 'acc_1',
      delimiter: ',',
      skipRows: 2,
      amountColumn: null,
      debitColumn: 3,
      creditColumn: 4,
      categoryColumn: 5,
      dateOrder: DateOrder.ymd,
      decimalMark: DecimalMark.dot,
      invertSign: true,
      installmentDateMode: InstallmentDateMode.purchase,
      categoryMap: {'SUPERMERCADO': 'cat_mercado'},
    );
    final back = ImportProfile.fromMap(p.toMap());
    expect(back, p);
    expect(back.amountColumn, isNull);
    expect(back.categoryMap, {'SUPERMERCADO': 'cat_mercado'});
  });

  test('fromMap mínimo usa todos os padrões do SPEC', () {
    final p = ImportProfile.fromMap({'id': 'p', 'name': 'X'});
    expect(p.format, ImportFormat.csv);
    expect(p.delimiter, ';');
    expect(p.skipRows, 1);
    expect(p.dateColumn, 0);
    expect(p.descriptionColumn, 1);
    expect(p.amountColumn, 2);
    expect(p.debitColumn, isNull);
    expect(p.creditColumn, isNull);
    expect(p.categoryColumn, isNull);
    expect(p.dateOrder, DateOrder.dmy);
    expect(p.decimalMark, DecimalMark.comma);
    expect(p.invertSign, isFalse);
    expect(p.installmentDateMode, InstallmentDateMode.posting);
    expect(p.categoryMap, isEmpty);
  });

  test('mappingError: destino ausente ou duplo', () {
    const msg = 'Escolha a conta ou o cartão';
    expect(const ImportProfile(id: 'p', name: 'X').mappingError, msg);
    expect(
      const ImportProfile(
        id: 'p',
        name: 'X',
        accountId: 'a',
        cardId: 'c',
      ).mappingError,
      msg,
    );
  });

  test('mappingError: valor único XOR débito/crédito', () {
    const msg = 'Use valor único ou débito/crédito';
    expect(base.copyWith(debitColumn: 3).mappingError, msg);
    expect(base.copyWith(amountColumn: null).mappingError, msg);
  });

  test('mappingError: colunas repetidas, separador e linhas', () {
    expect(
      base.copyWith(descriptionColumn: 0).mappingError,
      'Colunas repetidas ou inválidas',
    );
    expect(
      base.copyWith(dateColumn: -1).mappingError,
      'Colunas repetidas ou inválidas',
    );
    expect(base.copyWith(delimiter: ';;').mappingError, 'Separador inválido');
    expect(
      base.copyWith(skipRows: -1).mappingError,
      'Linhas a pular inválidas',
    );
    expect(base.mappingError, isNull);
  });

  test('mappingError: OFX valida só o destino', () {
    final ofx = base.copyWith(format: ImportFormat.ofx, descriptionColumn: 0);
    expect(ofx.mappingError, isNull);
    expect(
      ofx.copyWith(accountId: null, cardId: null).mappingError,
      'Escolha a conta ou o cartão',
    );
  });

  test('learnBankCategories acrescenta só chaves novas', () {
    const p = ImportProfile(
      id: 'p',
      name: 'X',
      accountId: 'a',
      categoryMap: {'SUPERMERCADO': 'cat_mercado'},
    );
    final learned = p.learnBankCategories({'A': 'x', 'SUPERMERCADO': 'y'});
    expect(learned.categoryMap, {'SUPERMERCADO': 'cat_mercado', 'A': 'x'});
    expect(learned.id, 'p');
  });

  test('copyWith limpa um campo e define o outro', () {
    final p = base.copyWith(amountColumn: null, debitColumn: 3);
    expect(p.amountColumn, isNull);
    expect(p.debitColumn, 3);
    expect(p.accountId, 'acc_1');
    expect(base.copyWith().amountColumn, 2);
  });
}
