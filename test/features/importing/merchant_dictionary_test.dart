import 'package:finme/app/seed.dart';
import 'package:finme/core/utils/text_normalize.dart';
import 'package:finme/features/importing/domain/merchant_dictionary.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('dictionaryPatternMatches', () {
    test('casa no início de palavra e rejeita sufixo/prefixo colado', () {
      expect(dictionaryPatternMatches('DROGA', 'DROGA RAIA X'), isTrue);
      expect(dictionaryPatternMatches('DROGA', 'DROGASIL EXEMPLO'), isFalse);
      expect(dictionaryPatternMatches('RAIA', 'DROGA RAIA'), isTrue);
      expect(dictionaryPatternMatches('99', '1990 LOJA'), isFalse);
      expect(dictionaryPatternMatches('99APP', '99APP *CORRIDA'), isTrue);
      expect(dictionaryPatternMatches('MERCADO', 'SUPERMERCADO X'), isFalse);
      expect(dictionaryPatternMatches('MERCADO', 'MERCADOPAGO X'), isFalse);
      expect(dictionaryPatternMatches('MERCADO', 'MERCADO*X'), isTrue);
      expect(dictionaryPatternMatches('MERCADO', 'MERCADOPAGO *LOJA'), isFalse);
    });

    test('aceita S final opcional antes do fim de palavra', () {
      expect(
        dictionaryPatternMatches('SUPERMERCADO', 'SUPERMERCADOS X'),
        isTrue,
      );
      expect(dictionaryPatternMatches('FARMACIA', 'FARMACIAS X'), isTrue);
      expect(dictionaryPatternMatches('CURSO', 'CURSOSX'), isFalse);
      expect(dictionaryPatternMatches('STEAM', 'STEAMGAMES'), isFalse);
    });

    test('padrão vazio nunca casa', () {
      expect(dictionaryPatternMatches('', 'QUALQUER'), isFalse);
    });
  });

  group('resolveCategoryByName', () {
    final categories = defaultCategories();

    test('ignora caixa e acento', () {
      expect(
        resolveCategoryByName('alimentacao', categories),
        'cat_alimentacao',
      );
    });

    test('fallback Combustível -> Transporte', () {
      expect(
        resolveCategoryByName('Combustível', categories),
        'cat_transporte',
      );
    });

    test('nome desconhecido -> null', () {
      expect(resolveCategoryByName('Inexistente', categories), isNull);
    });
  });

  group('defaultDictionary', () {
    final entries = defaultDictionary();
    final categories = defaultCategories();

    test('tem todas as entradas do SPEC na ordem', () {
      expect(kDefaultDictionary.length, 127);
      expect(entries.length, kDefaultDictionary.length);
      expect(entries.first.pattern, 'UBER');
      expect(entries.first.categoryName, 'Transporte');
      expect(entries.last.pattern, 'DIVIDENDOS');
      expect(entries.last.categoryName, 'Rendimentos');
    });

    test('ids únicos começando com dict_', () {
      final ids = entries.map((e) => e.id).toSet();
      expect(ids.length, entries.length);
      expect(entries.every((e) => e.id.startsWith('dict_')), isTrue);
      expect(
        entries.firstWhere((e) => e.pattern == 'PAO DE ACUCAR').id,
        'dict_pao_de_acucar',
      );
    });

    test('marcas coladas casam só pela própria entrada', () {
      List<String> casam(String desc) => [
        for (final e in entries)
          if (dictionaryPatternMatches(e.pattern, desc)) e.categoryName,
      ];
      expect(casam('HBOMAX *ASSINATURA'), ['Assinaturas']);
      expect(casam('SUPERMERCADOS X'), ['Mercado']);
      expect(casam('MERCADOPAGO *LOJA'), isEmpty);
    });

    test('padrões já em foldText e categorias resolvem', () {
      for (final e in entries) {
        expect(e.pattern, foldText(e.pattern), reason: e.pattern);
        expect(
          resolveCategoryByName(e.categoryName, categories),
          isNotNull,
          reason: e.categoryName,
        );
      }
    });
  });

  test('DictionaryEntry round-trip, copyWith e igualdade', () {
    const e = DictionaryEntry(
      id: 'dict_uber',
      pattern: 'UBER',
      categoryName: 'Transporte',
    );
    expect(DictionaryEntry.fromMap(e.toMap()), e);
    expect(e.copyWith(), e);
    expect(e.copyWith(categoryName: 'Lazer').categoryName, 'Lazer');
    expect(e == e.copyWith(pattern: 'OUTRO'), isFalse);
  });
}
