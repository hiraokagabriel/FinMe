import 'package:finme/core/utils/text_normalize.dart';
import 'package:finme/features/rules/domain/rule_engine.dart';
import 'package:finme/features/rules/domain/rule_suggestion.dart';
import 'package:finme/features/rules/domain/transaction_rule.dart';
import 'package:flutter_test/flutter_test.dart';

/// Motor real de regras: padrão do form é `contains`.
bool _casa(String pattern, String description) => CompiledRule(
  TransactionRule(id: 'r', pattern: pattern),
).matches(description);

void main() {
  group('suggestRulePattern (SPEC §5.19)', () {
    test('exemplos do contrato', () {
      expect(
        suggestRulePattern(['UBER *TRIP 8X7Y2 SAO PAULO BR']),
        'UBER *TRIP',
      );
      expect(
        suggestRulePattern(['UBER *TRIP 8X7Y2', 'UBER *EATS 123']),
        'UBER',
      );
      expect(
        suggestRulePattern(['IFOOD*RESTAURANTE X', 'IFOOD*PADARIA']),
        'IFOOD',
      );
      expect(
        suggestRulePattern([
          'LOJA EXEMPLO PARC 03/10',
          'LOJA EXEMPLO PARC 04/10',
        ]),
        'LOJA EXEMPLO',
      );
      expect(suggestRulePattern(['MERCADO A', 'MERCADINHO B']), '');
      expect(
        suggestRulePattern(['Farmácia São João 0412']),
        'FARMACIA SAO JOAO',
      );
      expect(
        suggestRulePattern(['PADARIA PAO', 'PADARIA PAO BOM']),
        'PADARIA PAO',
      );
      expect(suggestRulePattern(['123456']), '123456');
      expect(suggestRulePattern([]), '');
    });

    test('caractere * fica no padrão e a regra casa a descrição', () {
      const s = 'IFOOD*RESTAURANTE X';
      final p = suggestRulePattern([s]);
      expect(p, 'IFOOD*RESTAURANTE X');
      expect(foldText(s).startsWith(p), isTrue);
      expect(_casa(p, s), isTrue);
    });

    test('a partir do primeiro código (dígito), cidade e UF também saem', () {
      expect(suggestRulePattern(['LOJA 123 CENTRO']), 'LOJA');
      expect(
        suggestRulePattern(['UBER *TRIP 8X7Y2 SAO PAULO BR']),
        'UBER *TRIP',
      );
    });

    test('invariante: resultado não vazio casa todos os assuntos', () {
      final cases = <List<String>>[
        ['UBER *TRIP 8X7Y2 SAO PAULO BR'],
        ['UBER *TRIP 8X7Y2', 'UBER *EATS 123'],
        ['IFOOD*RESTAURANTE X', 'IFOOD*PADARIA'],
        ['LOJA EXEMPLO PARC 03/10', 'LOJA EXEMPLO PARC 04/10'],
        ['Farmácia São João 0412'],
        ['PADARIA PAO', 'PADARIA PAO BOM'],
        ['123456'],
        ['LOJA 123 CENTRO'],
      ];
      for (final subjects in cases) {
        final p = suggestRulePattern(subjects);
        expect(p, isNotEmpty, reason: '$subjects');
        for (final s in subjects) {
          expect(_casa(p, s), isTrue, reason: '$p / $s');
        }
      }
    });
  });
}
