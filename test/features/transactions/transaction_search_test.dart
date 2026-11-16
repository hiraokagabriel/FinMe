import 'package:finme/features/transactions/domain/transaction.dart';
import 'package:finme/features/transactions/domain/transaction_search.dart';
import 'package:flutter_test/flutter_test.dart';

Transaction _tx(
  String id, {
  required String description,
  required int amountCents,
  required DateTime date,
  String? importedDescription,
}) => Transaction(
  id: id,
  type: TransactionType.expense,
  amountCents: amountCents,
  date: date,
  description: description,
  importedDescription: importedDescription,
);

final _t1 = _tx(
  't1',
  description: 'UBER *TRIP',
  amountCents: 2315,
  date: DateTime(2026, 11, 5),
);
final _t2 = _tx(
  't2',
  description: 'Uber Eats',
  amountCents: 4590,
  date: DateTime(2026, 11, 10),
);
final _t3 = _tx(
  't3',
  description: 'Padaria Pão Bom',
  amountCents: 1250,
  date: DateTime(2026, 11, 8),
  importedDescription: 'PADARIA PAO BOM CURITIBA PR',
);
final _t4 = _tx(
  't4',
  description: 'Mercado Exemplo',
  amountCents: 2315,
  date: DateTime(2026, 11, 1),
);
final _t5 = _tx(
  't5',
  description: 'Netflix',
  amountCents: 5990,
  date: DateTime(2026, 11, 3),
);

void main() {
  final index = TransactionSearchIndex([_t1, _t2, _t3, _t4, _t5]);

  group('TransactionSearchIndex.search', () {
    test('exemplos do SPEC §5.17', () {
      expect(index.search('uber'), [_t2, _t1]);
      expect(index.search('23,15'), [_t1, _t4]);
      expect(index.search('uber 23,15'), [_t1]);
      expect(index.search('curitiba'), [_t3]);
      expect(index.search('pao'), [_t3]);
      expect(index.search('u'), isEmpty);
      expect(index.search('xyz'), isEmpty);
    });

    test('limit padrão 20', () {
      final many = TransactionSearchIndex([
        for (var i = 0; i < 30; i++)
          _tx(
            'l$i',
            description: 'LOJA $i',
            amountCents: 1000,
            date: DateTime(2026, 11, 1),
          ),
      ]);
      expect(many.search('loja').length, 20);
      expect(many.search('loja', limit: 1).length, 1);
    });

    test('query é dobrada: caixa, acento e espaços das bordas', () {
      expect(index.search('  UBER  '), index.search('uber'));
      expect(index.search('PÃO'), index.search('pao'));
    });

    test('empate de score e de data desempata por id asc', () {
      final ties = TransactionSearchIndex([
        _tx(
          'b',
          description: 'Uber B',
          amountCents: 100,
          date: DateTime(2026, 11, 2),
        ),
        _tx(
          'a',
          description: 'Uber A',
          amountCents: 100,
          date: DateTime(2026, 11, 2),
        ),
      ]);
      expect(ties.search('uber').map((t) => t.id), ['a', 'b']);
    });

    test('limit corta o ranking depois de ordenar', () {
      expect(index.search('uber', limit: 1), [_t2]);
    });

    test('valor exato dá score 4 mesmo sem casar a descrição', () {
      expect(index.search('5990'), isEmpty);
      expect(index.search('59,90'), [_t5]);
    });

    test('desempenho: 10.000 transações, índice + 50 buscas < 1 s', () {
      final big = [
        for (var i = 0; i < 10000; i++)
          _tx(
            'x$i',
            description: 'LOJA EXEMPLO ${i % 500} PARC ${i % 10}/10',
            amountCents: 1000 + i,
            date: DateTime(2026, 1, 1 + i % 28),
            importedDescription: 'LOJA EXEMPLO CURITIBA PR $i',
          ),
      ];
      final sw = Stopwatch()..start();
      final bigIndex = TransactionSearchIndex(big);
      for (var i = 0; i < 50; i++) {
        bigIndex.search('loja ex${i % 7}');
      }
      sw.stop();
      expect(sw.elapsedMilliseconds, lessThan(1000));
    });

    test('matchAmounts false: valor não casa; descrição continua casando', () {
      final hidden = TransactionSearchIndex([_t1, _t5], matchAmounts: false);
      expect(hidden.search('59,90'), isEmpty);
      expect(hidden.search('5990'), isEmpty);
      expect(hidden.search('netflix 59,90'), isEmpty);
      expect(hidden.search('uber 23,15'), isEmpty);
      expect(hidden.search('uber'), [_t1]);
      expect(hidden.search('netflix'), [_t5]);
    });
  });
}
