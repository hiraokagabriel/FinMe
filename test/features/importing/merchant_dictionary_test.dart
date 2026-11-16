import 'package:finme/app/seed.dart';
import 'package:finme/core/utils/text_normalize.dart';
import 'package:finme/features/categories/domain/transaction_category.dart';
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

    test('nome inteiro com > sem espaços é categoria, não caminho', () {
      final ab = [
        const TransactionCategory(
          id: 'ab',
          name: 'A>B',
          kind: CategoryKind.expense,
          iconCodePoint: 0,
          colorValue: 0,
        ),
      ];
      expect(resolveCategoryByName('A>B', ab), 'ab');
      expect(resolveCategoryByName('A > B', ab), isNull);
    });

    group('com subcategorias', () {
      // Sem a raiz 'Outros' do seed: o contrato pede 2 filhas homônimas sem raiz.
      final sub = [
        ...categories.where((c) => c.id != 'cat_outros'),
        const TransactionCategory(
          id: 'mer2',
          name: 'Mercado',
          kind: CategoryKind.expense,
          iconCodePoint: 0,
          colorValue: 0,
          parentId: 'cat_alimentacao',
        ),
        const TransactionCategory(
          id: 'out1',
          name: 'Outros',
          kind: CategoryKind.expense,
          iconCodePoint: 0,
          colorValue: 0,
          parentId: 'cat_alimentacao',
        ),
        const TransactionCategory(
          id: 'out2',
          name: 'Outros',
          kind: CategoryKind.expense,
          iconCodePoint: 0,
          colorValue: 0,
          parentId: 'cat_transporte',
        ),
      ];

      test('caminho com › ou > resolve a filha', () {
        expect(resolveCategoryByName('Alimentação › Mercado', sub), 'mer2');
        expect(resolveCategoryByName('alimentacao > mercado', sub), 'mer2');
      });

      test('nome simples: raiz vence a filha homônima', () {
        expect(resolveCategoryByName('Mercado', sub), 'cat_mercado');
      });

      test('duas filhas homônimas sem raiz são ambíguas', () {
        expect(resolveCategoryByName('Outros', sub), isNull);
        expect(resolveCategoryByName('Transporte › Outros', sub), 'out2');
      });

      test('caminho com filha inexistente cai no nome da filha', () {
        expect(resolveCategoryByName('Transporte › Inexistente', sub), isNull);
      });

      test('filha única sem raiz homônima resolve', () {
        final semRaiz = sub.where((c) => c.id != 'cat_mercado').toList();
        expect(resolveCategoryByName('Mercado', semRaiz), 'mer2');
      });

      test('fallback Combustível continua indo para Transporte', () {
        expect(resolveCategoryByName('Combustível', sub), 'cat_transporte');
      });
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
