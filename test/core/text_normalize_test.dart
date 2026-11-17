import 'package:finme/core/utils/text_normalize.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('foldText', () {
    test('maiúsculas, sem acento, espaços colapsados e trim', () {
      expect(foldText('  Ação  São\tJoão '), 'ACAO SAO JOAO');
      expect(foldText('café'), 'CAFE');
      expect(foldText('a  b'), 'A B');
    });

    test('mantém pontuação', () {
      expect(foldText('apple.com/bill'), 'APPLE.COM/BILL');
    });
  });

  group('normalizeDescription', () {
    test('exemplos do SPEC §3.7', () {
      expect(
        normalizeDescription('UBER *TRIP 8X7Y2 SAO PAULO BR'),
        'UBER TRIP',
      );
      expect(
        normalizeDescription('IFOOD*RESTAURANTE 12/11'),
        'IFOOD RESTAURANTE',
      );
      expect(
        normalizeDescription('Farmácia São João 0412'),
        'FARMACIA SAO JOAO',
      );
      expect(normalizeDescription('LOJA EXEMPLO PARC 03/10'), 'LOJA EXEMPLO');
      expect(normalizeDescription('LOJA EXEMPLO 03 DE 10'), 'LOJA EXEMPLO');
      expect(
        normalizeDescription('PADARIA PAO BOM CURITIBA PR'),
        'PADARIA PAO BOM',
      );
      expect(normalizeDescription('123456'), '');
      expect(normalizeDescription('SP'), 'SP');
    });

    test('não esvazia a lista ao remover cidade/UF', () {
      expect(normalizeDescription('SAO PAULO SP'), 'SAO PAULO');
    });
  });

  group('descriptionTokens', () {
    test('remove curtos e stop tokens', () {
      expect(descriptionTokens('PAG LOJA DE X EXEMPLO'), {'LOJA', 'EXEMPLO'});
    });
  });

  group('jaccard', () {
    test('índice e conjuntos vazios', () {
      expect(jaccard({'A', 'B'}, {'B', 'C'}), closeTo(1 / 3, 1e-9));
      expect(jaccard({}, {}), 0.0);
    });
  });

  group('similarDescriptions', () {
    test('iguais após normalização, contenção e chaves vazias', () {
      expect(
        similarDescriptions('IFOOD*RESTAURANTE X', 'IFOOD RESTAURANTE X 12/11'),
        isTrue,
      );
      expect(similarDescriptions('LOJA', 'LOJA EXEMPLO'), isTrue);
      expect(similarDescriptions('UBER TRIP', '99 POP'), isFalse);
      expect(similarDescriptions('123', '456'), isFalse);
    });

    test(
      'contenção só por token inteiro e Jaccard mais rígido com 4+ tokens',
      () {
        expect(similarDescriptions('LOJA', 'LOJAMERICA'), isFalse);
        expect(
          similarDescriptions(
            'TRANSFERENCIA ENVIADA PELO PIX FULANO',
            'TRANSFERENCIA ENVIADA PELO PIX CICLANO',
          ),
          isFalse,
        );
      },
    );
  });
}
