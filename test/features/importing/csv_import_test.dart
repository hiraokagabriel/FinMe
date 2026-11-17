import 'dart:convert';
import 'dart:io';

import 'package:finme/features/importing/domain/csv_import.dart';
import 'package:finme/features/importing/domain/import_profile.dart';
import 'package:finme/features/importing/domain/imported_line.dart';
import 'package:flutter_test/flutter_test.dart';

String _fixture(String name) =>
    decodeText(File('test/fixtures/import/$name').readAsBytesSync());

ImportParseResult _parse(String text, ImportProfile p) =>
    parseCsvLines(readCsv(text, delimiter: p.delimiter), p);

List<int> _cents(ImportParseResult r) => [
  for (final l in r.lines) l.amountCents,
];

void main() {
  final extrato = const ImportProfile(
    id: 'p',
    name: 'Extrato',
    accountId: 'acc_1',
    delimiter: ';',
    skipRows: 2,
    dateColumn: 0,
    descriptionColumn: 1,
    amountColumn: 2,
    categoryColumn: 3,
    dateOrder: DateOrder.dmy,
    decimalMark: DecimalMark.comma,
  );
  final fatura = const ImportProfile(
    id: 'f',
    name: 'Fatura',
    cardId: 'card_1',
    delimiter: ',',
    skipRows: 1,
    dateOrder: DateOrder.ymd,
    decimalMark: DecimalMark.dot,
    invertSign: true,
  );

  group('parseAmountCell', () {
    test('exemplos do SPEC', () {
      expect(parseAmountCell('-1.234,56', DecimalMark.comma), -123456);
      expect(parseAmountCell('1,234.56', DecimalMark.dot), 123456);
      expect(parseAmountCell('(10,00)', DecimalMark.comma), -1000);
      expect(parseAmountCell('45,9 D', DecimalMark.comma), -4590);
      expect(parseAmountCell('R\$ 7', DecimalMark.comma), 700);
      expect(parseAmountCell('12,345', DecimalMark.comma), isNull);
      expect(parseAmountCell('1.234,5678', DecimalMark.comma), isNull);
      expect(parseAmountCell('abc', DecimalMark.comma), isNull);
      expect(parseAmountCell('', DecimalMark.dot), isNull);
    });

    test('sinais, crédito C e fração de 1 dígito', () {
      expect(parseAmountCell('-12,50', DecimalMark.comma), -1250);
      expect(parseAmountCell('10,00C', DecimalMark.comma), 1000);
      expect(parseAmountCell('5.000,00', DecimalMark.comma), 500000);
      expect(parseAmountCell('5,5', DecimalMark.comma), 550);
      expect(parseAmountCell('1,2,3', DecimalMark.comma), isNull);
    });
  });

  group('parseDateCell', () {
    test('formatos e validação', () {
      final expected = DateTime(2026, 11, 5);
      expect(parseDateCell('05/11/2026', DateOrder.dmy), expected);
      expect(parseDateCell('11/05/2026', DateOrder.mdy), expected);
      expect(parseDateCell('2026-11-05 10:30', DateOrder.ymd), expected);
      expect(parseDateCell('2026-11-05T10:30:00', DateOrder.ymd), expected);
      expect(parseDateCell('05.11.26', DateOrder.dmy), expected);
      expect(parseDateCell('31/02/2026', DateOrder.dmy), isNull);
      expect(parseDateCell('xx', DateOrder.dmy), isNull);
    });
  });

  group('decodeText', () {
    test('Latin-1 quando não é UTF-8 válido', () {
      expect(decodeText(latin1.encode('Descrição;Café')), 'Descrição;Café');
    });

    test('remove BOM UTF-8', () {
      expect(decodeText([0xEF, 0xBB, 0xBF, ...utf8.encode('Olá')]), 'Olá');
    });
  });

  group('guessDelimiter', () {
    test('arquivos e casos de borda', () {
      expect(guessDelimiter(_fixture('extrato_conta.csv')), ';');
      expect(guessDelimiter(_fixture('fatura_cartao.csv')), ',');
      expect(guessDelimiter('a\tb\tc\n1\t2\t3'), '\t');
      expect(guessDelimiter(''), ';');
    });
  });

  group('extrato_conta.csv', () {
    test('linhas válidas e erros', () {
      final result = _parse(_fixture('extrato_conta.csv'), extrato);

      expect(_cents(result), [-1250, -123456, 500000, -80000, -15000]);
      expect([for (final l in result.lines) l.row], [3, 4, 5, 6, 9]);
      expect(result.lines[1].description, 'MERCADO EXEMPLO; FILIAL 2');
      expect(result.lines[0].bankCategory, 'Alimentação');
      expect(result.lines[2].bankCategory, isNull);
      expect(
        [for (final e in result.errors) (e.row, e.message)],
        [(7, 'Data inválida'), (8, 'Valor inválido')],
      );
    });

    test('CRLF dá o mesmo resultado', () {
      final text = _fixture('extrato_conta.csv').replaceAll('\n', '\r\n');
      final result = _parse(text, extrato);

      expect(_cents(result), [-1250, -123456, 500000, -80000, -15000]);
      expect([for (final l in result.lines) l.row], [3, 4, 5, 6, 9]);
      expect([for (final e in result.errors) e.row], [7, 8]);
    });
  });

  group('fatura_cartao.csv', () {
    test('sinal invertido e descrição com vírgula', () {
      final result = _parse(_fixture('fatura_cartao.csv'), fatura);

      expect(_cents(result), [-4590, -2315, -9999, 150000, 1000]);
      expect(result.lines.first.description, 'IFOOD *RESTAURANTE, CENTRO');
      expect(result.errors, isEmpty);
    });
  });

  group('débito e crédito', () {
    const text =
        'Data;Descricao;Debito;Credito\n'
        '01/11/2026;TARIFA PACOTE;29,90;\n'
        '02/11/2026;PIX RECEBIDO FICTICIO;;150,00\n'
        '03/11/2026;AJUSTE;10,00;25,00\n'
        '04/11/2026;VAZIO;;';
    final profile = const ImportProfile(
      id: 'p',
      name: 'Débito/crédito',
      accountId: 'acc_1',
      amountColumn: null,
      debitColumn: 2,
      creditColumn: 3,
    );

    test('débito negativo, crédito positivo, ambos = crédito − débito', () {
      final result = _parse(text, profile);

      expect(_cents(result), [-2990, 15000, 1500]);
      expect(
        [for (final e in result.errors) (e.row, e.message)],
        [(5, 'Valor inválido')],
      );
    });
  });

  group('erros de linha', () {
    test('linha curta e valor zero', () {
      final result = _parse(
        '05/11/2026;SO DUAS\n06/11/2026;ZERO;0,00',
        const ImportProfile(
          id: 'p',
          name: 'X',
          accountId: 'acc_1',
          skipRows: 0,
        ),
      );

      expect(
        [for (final e in result.errors) (e.row, e.message)],
        [(1, 'Coluna ausente'), (2, 'Valor zero')],
      );
    });
  });
}
