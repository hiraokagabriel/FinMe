import 'dart:convert';
import 'dart:io';

import 'package:finme/features/importing/domain/ofx_parser.dart';
import 'package:flutter_test/flutter_test.dart';

String _fixture(String name) =>
    latin1.decode(File('test/fixtures/import/$name').readAsBytesSync());

/// Um STMTTRN com as tags dadas, dentro de um OFX mínimo.
OfxStatement _one(String tags) =>
    parseOfx('<OFX><STMTTRN>$tags</STMTTRN></OFX>');

List<(int, DateTime, String, int, String?)> _rows(OfxStatement s) => [
  for (final l in s.result.lines)
    (l.row, l.date, l.description, l.amountCents, l.fitid),
];

List<(int, String)> _errors(OfxStatement s) => [
  for (final e in s.result.errors) (e.row, e.message),
];

void main() {
  group('extrato_conta.ofx (SGML)', () {
    final s = parseOfx(_fixture('extrato_conta.ofx'));

    test('cabeçalho: conta corrente com ACCTID', () {
      expect(s.isCreditCard, isFalse);
      expect(s.accountId, '12345-6');
    });

    test('linhas com data, valor, descrição e FITID', () {
      expect(_rows(s), [
        (1, DateTime(2026, 11, 3), 'FARMACIA EXEMPLO', -3590, 'FIT0001'),
        (2, DateTime(2026, 11, 5), 'TED RECEBIDA FICTICIA', 250000, 'FIT0002'),
        (
          3,
          DateTime(2026, 11, 6),
          'CASA & CIA COMPRA CARTAO DEBITO',
          -12000,
          'FIT0003',
        ),
      ]);
    });

    test('data inválida vira erro da linha e não para o arquivo', () {
      expect(_errors(s), [(4, 'Data inválida')]);
    });
  });

  group('fatura_cartao.ofx (XML)', () {
    final s = parseOfx(_fixture('fatura_cartao.ofx'));

    test('cabeçalho: cartão com CCSTMTRS e ACCTID', () {
      expect(s.isCreditCard, isTrue);
      expect(s.accountId, '9999');
      expect(s.result.errors, isEmpty);
    });

    test(
      'valores (vírgula decimal e ponto de milhar), descrições e FITIDs',
      () {
        expect(_rows(s), [
          (1, DateTime(2026, 11, 2), 'NETFLIX.COM', -5990, 'CC-1'),
          (2, DateTime(2026, 11, 8), 'LOJA EXEMPLO PARC 03/10', -20000, 'CC-2'),
          (3, DateTime(2026, 11, 9), 'PAGAMENTO RECEBIDO', 150000, 'CC-3'),
        ]);
      },
    );
  });

  test('caixa baixa dá as mesmas datas, valores e FITIDs', () {
    // toLowerCase() também baixa os FITIDs: comparação sem caixa neles.
    List<(DateTime, int, String?)> key(OfxStatement s) => [
      for (final l in s.result.lines)
        (l.date, l.amountCents, l.fitid?.toLowerCase()),
    ];
    final upper = parseOfx(_fixture('extrato_conta.ofx'));
    final lower = parseOfx(_fixture('extrato_conta.ofx').toLowerCase());
    expect(key(lower), key(upper));
    expect(lower.accountId, '12345-6');
  });

  test('arquivo sem <OFX> lança FormatException', () {
    expect(() => parseOfx('lixo'), throwsA(isA<FormatException>()));
  });

  test('valor zero e descrição vazia viram erro da linha', () {
    expect(_errors(_one('<DTPOSTED>20261103<TRNAMT>0.00<NAME>LOJA')), [
      (1, 'Valor zero'),
    ]);
    expect(_errors(_one('<DTPOSTED>20261103<TRNAMT>-10.00<FITID>X')), [
      (1, 'Descrição vazia'),
    ]);
  });

  test('valores: sinal, separadores e formato inválido', () {
    int? amount(String raw) {
      final s = _one('<DTPOSTED>20261103<TRNAMT>$raw<NAME>LOJA');
      return s.result.lines.isEmpty ? null : s.result.lines.single.amountCents;
    }

    expect(amount('-1.234,56'), -123456);
    expect(amount('1,234.56'), 123456);
    expect(amount('-35.9'), -3590);
    expect(amount('+7'), 700);
    expect(amount('2500,00'), 250000);
    expect(amount('abc'), isNull);
    expect(amount('1.234'), isNull);
    expect(amount('-'), isNull);
  });

  test('datas: 30/02 e mês 13 são inválidos; hora e fuso são ignorados', () {
    expect(_errors(_one('<DTPOSTED>20260230<TRNAMT>-1.00<NAME>A')), [
      (1, 'Data inválida'),
    ]);
    expect(_errors(_one('<DTPOSTED>20261301<TRNAMT>-1.00<NAME>A')), [
      (1, 'Data inválida'),
    ]);
    expect(
      _rows(_one('<DTPOSTED>20261230235959[-3:BRT]<TRNAMT>-1.00<NAME>A')),
      [(1, DateTime(2026, 12, 30), 'A', -100, null)],
    );
  });

  test('descrição: usa o mais longo quando um contém o outro', () {
    String? description(String name, String memo) {
      final s = _one('<DTPOSTED>20261103<TRNAMT>-1.00<NAME>$name<MEMO>$memo');
      return s.result.lines.single.description;
    }

    expect(description('LOJA', 'LOJA EXEMPLO'), 'LOJA EXEMPLO');
    expect(description('loja exemplo', 'LOJA'), 'loja exemplo');
    expect(description('ALFA', 'BETA'), 'ALFA BETA');
  });
}
