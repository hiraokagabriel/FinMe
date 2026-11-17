import 'package:finme/core/utils/fuzzy.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('foldedWords', () {
    test('separa por não alfanumérico, sem vazios', () {
      expect(foldedWords('UBER *TRIP 8X'), ['UBER', 'TRIP', '8X']);
      expect(foldedWords(''), <String>[]);
    });
  });

  group('fuzzyTokenScore', () {
    test('prefixo do texto, prefixo de palavra, contém e subsequência', () {
      expect(fuzzyTokenScore('TRIP', 'UBER *TRIP', ['UBER', 'TRIP']), 3);
      expect(fuzzyTokenScore('UBER', 'UBER *TRIP', ['UBER', 'TRIP']), 4);
      expect(
        fuzzyTokenScore('ANSA', 'NOVA TRANSACAO', ['NOVA', 'TRANSACAO']),
        2,
      );
      expect(
        fuzzyTokenScore('NVT', 'NOVA TRANSACAO', ['NOVA', 'TRANSACAO']),
        1,
      );
      expect(
        fuzzyTokenScore('XYZ', 'NOVA TRANSACAO', ['NOVA', 'TRANSACAO']),
        isNull,
      );
    });
  });

  group('fuzzyScore', () {
    test('exemplos do SPEC §3.8', () {
      expect(fuzzyScore('', 'x'), 0);
      expect(fuzzyScore('nova', 'Nova transação'), 4);
      expect(fuzzyScore('trans', 'Nova transação'), 3);
      expect(fuzzyScore('ansa', 'Nova transação'), 2);
      expect(fuzzyScore('nvt', 'Nova transação'), 1);
      expect(fuzzyScore('nv', 'Nova transação'), isNull);
      expect(fuzzyScore('xyz', 'Nova transação'), isNull);
      expect(fuzzyScore('ir pain', 'Ir para Painel'), 7);
      expect(fuzzyScore('cafe', 'Café da manhã'), 4);
    });

    test('ignora caixa, acento e espaços extras na query', () {
      expect(fuzzyScore('  NOVA  ', 'nova transação'), 4);
    });
  });

  group('fuzzyRank', () {
    List<String> textsOf(String s) => [s];

    test('filtra por casamento e mantém a ordem em empate', () {
      final items = ['Nova recorrência', 'Nova transação', 'Ajustes'];
      expect(fuzzyRank(items, 'nova', textsOf), [
        'Nova recorrência',
        'Nova transação',
      ]);
    });

    test('ordena por score desc', () {
      final items = ['Nova recorrência', 'Nova transação', 'Ajustes'];
      expect(fuzzyRank(items, 'trans', textsOf), ['Nova transação']);
    });

    test('query vazia devolve os itens na ordem de entrada, com limit', () {
      final items = ['Nova recorrência', 'Nova transação', 'Ajustes'];
      expect(fuzzyRank(items, '', textsOf, limit: 2), [
        'Nova recorrência',
        'Nova transação',
      ]);
    });

    test('usa o maior score entre os textos do item', () {
      final items = ['Importar arquivo', 'Ajustes'];
      final ranked = fuzzyRank(
        items,
        'csv',
        (s) => s == 'Importar arquivo' ? ['Importar arquivo', 'csv'] : [s],
      );
      expect(ranked, ['Importar arquivo']);
    });
  });
}
