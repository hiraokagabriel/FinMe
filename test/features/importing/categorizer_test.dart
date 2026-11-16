import 'package:finme/app/seed.dart';
import 'package:finme/features/importing/domain/category_history.dart';
import 'package:finme/features/importing/domain/categorizer.dart';
import 'package:finme/features/importing/domain/merchant_dictionary.dart';
import 'package:finme/features/rules/domain/transaction_rule.dart';
import 'package:finme/features/transactions/domain/transaction.dart';
import 'package:flutter_test/flutter_test.dart';

final _categories = defaultCategories();

Categorizer _cz({
  List<TransactionRule> rules = const [],
  CategoryHistory? history,
  List<DictionaryEntry>? dictionary,
}) => Categorizer(
  rules: rules,
  categories: _categories,
  history: history ?? CategoryHistory.empty,
  dictionary: dictionary ?? defaultDictionary(),
);

int _seq = 0;

Transaction _tx(String description, String categoryId) {
  _seq++;
  return Transaction(
    id: 't$_seq',
    type: TransactionType.expense,
    amountCents: 1000,
    date: DateTime(2026, 11, 1),
    description: description,
    categoryId: categoryId,
  );
}

void main() {
  group('regras', () {
    test('regra contains e regex com prioridade e renomeio', () {
      final cz = _cz(
        rules: const [
          TransactionRule(
            id: 'r1',
            pattern: 'IFOOD',
            categoryId: 'cat_alimentacao',
          ),
          TransactionRule(
            id: 'r2',
            pattern: '^UBER',
            matchType: RuleMatchType.regex,
            categoryId: 'cat_transporte',
            renameTo: 'Uber',
            priority: 1,
          ),
        ],
      );
      final r = cz.categorize('UBER *TRIP', isIncome: false);
      expect(r.categoryId, 'cat_transporte');
      expect(r.source, SuggestionSource.rule);
      expect(r.confidence, 1.0);
      expect(r.ruleId, 'r2');
      expect(r.renamedDescription, 'Uber');

      final f = cz.categorize('IFOOD PEDIDO', isIncome: false);
      expect(f.categoryId, 'cat_alimentacao');
      expect(f.ruleId, 'r1');
      expect(f.renamedDescription, isNull);
    });

    test('regra só com renameTo casa; categoria vem do dicionário', () {
      final cz = _cz(
        rules: const [
          TransactionRule(id: 'r', pattern: 'POSTO', renameTo: 'Posto Exemplo'),
        ],
      );
      final r = cz.categorize('POSTO EXEMPLO', isIncome: false);
      expect(r.categoryId, 'cat_transporte');
      expect(r.source, SuggestionSource.dictionary);
      expect(r.renamedDescription, 'Posto Exemplo');
    });

    test('regra com categoria de receita numa despesa é pulada', () {
      final cz = _cz(
        rules: const [
          TransactionRule(id: 'r', pattern: 'UBER', categoryId: 'cat_salario'),
        ],
      );
      final r = cz.categorize('UBER TRIP', isIncome: false);
      expect(r.categoryId, 'cat_transporte');
      expect(r.source, SuggestionSource.dictionary);
      expect(r.ruleId, isNull);
    });

    test('regra inativa não casa', () {
      final cz = _cz(
        rules: const [
          TransactionRule(
            id: 'r',
            pattern: 'XPTO',
            categoryId: 'cat_lazer',
            active: false,
          ),
        ],
      );
      expect(cz.categorize('XPTO 1', isIncome: false).categoryId, isNull);
    });
  });

  group('banco', () {
    test('mapa da coluna de categoria do banco vale 0.9', () {
      final cz = _cz();
      final r = cz.categorize(
        'XPTO 1',
        isIncome: false,
        bankCategory: 'Supermercado',
        bankCategoryMap: const {'SUPERMERCADO': 'cat_mercado'},
      );
      expect(r.categoryId, 'cat_mercado');
      expect(r.source, SuggestionSource.bank);
      expect(r.confidence, 0.9);
    });

    test('nome da categoria do banco sem mapa vale 0.7', () {
      final r = _cz().categorize(
        'XPTO 1',
        isIncome: false,
        bankCategory: 'mercado',
      );
      expect(r.categoryId, 'cat_mercado');
      expect(r.source, SuggestionSource.bank);
      expect(r.confidence, 0.7);
    });

    test('categoria do banco desconhecida segue a cascata', () {
      final r = _cz().categorize(
        'UBER TRIP',
        isIncome: false,
        bankCategory: 'Xyz',
      );
      expect(r.categoryId, 'cat_transporte');
      expect(r.source, SuggestionSource.dictionary);
    });
  });

  group('histórico', () {
    test('categoria exata mais frequente: 0.5 + 0.4 × fatia', () {
      final history = CategoryHistory.build([
        _tx('PADARIA PAO BOM 01', 'cat_alimentacao'),
        _tx('PADARIA PAO BOM 02', 'cat_alimentacao'),
        _tx('PADARIA PAO BOM 03', 'cat_alimentacao'),
        _tx('PADARIA PAO BOM 04', 'cat_mercado'),
      ]);
      final r = _cz(
        history: history,
      ).categorize('PADARIA PAO BOM 01', isIncome: false);
      expect(r.categoryId, 'cat_alimentacao');
      expect(r.source, SuggestionSource.history);
      expect(r.confidence, closeTo(0.8, 1e-9));
      expect(confidenceLabel(r.confidence), 'alta');
    });

    test('chave parecida: 0.6 × score', () {
      final history = CategoryHistory.build([
        _tx('PADARIA PAO BOM 01', 'cat_alimentacao'),
      ]);
      final r = _cz(
        history: history,
      ).categorize('PADARIA PAO BOM FILIAL', isIncome: false);
      expect(r.categoryId, 'cat_alimentacao');
      expect(r.source, SuggestionSource.history);
      expect(r.confidence, closeTo(0.45, 1e-9));
    });

    test('categoria do histórico de tipo errado é ignorada', () {
      final history = CategoryHistory.build([
        _tx('SALARIO EMPRESA', 'cat_salario'),
      ]);
      final r = _cz(
        history: history,
      ).categorize('SALARIO EMPRESA', isIncome: false);
      expect(r.categoryId, isNull);
    });
  });

  group('dicionário', () {
    test('padrão mais longo vence e respeita o tipo', () {
      final cz = _cz();
      expect(
        cz.categorize('MERCADO LIVRE*VENDEDOR', isIncome: false).categoryId,
        'cat_compras',
      );
      expect(
        cz.categorize('MERCADO DO BAIRRO', isIncome: false).categoryId,
        'cat_mercado',
      );
      expect(
        cz.categorize('POSTO EXEMPLO', isIncome: false).categoryId,
        'cat_transporte',
      );
      expect(
        cz.categorize('AMAZON PRIME', isIncome: false).categoryId,
        'cat_assinaturas',
      );
      final dict = cz.categorize('MERCADO LIVRE*VENDEDOR', isIncome: false);
      expect(dict.source, SuggestionSource.dictionary);
      expect(dict.confidence, 0.5);
    });

    test('padrão mais longo vence: UBER EATS, DROGASIL e MERCADOPAGO', () {
      final cz = _cz();
      expect(
        cz.categorize('UBER EATS*PEDIDO', isIncome: false).categoryId,
        'cat_alimentacao',
      );
      expect(
        cz.categorize('UBER *TRIP', isIncome: false).categoryId,
        'cat_transporte',
      );
      expect(
        cz.categorize('DROGASIL EXEMPLO', isIncome: false).categoryId,
        'cat_saude',
      );
      expect(
        cz.categorize('MERCADOPAGO*X', isIncome: false).categoryId,
        isNull,
      );
    });

    test('receita usa só categorias de receita', () {
      final cz = _cz();
      final income = cz.categorize('SALARIO EMPRESA', isIncome: true);
      expect(income.categoryId, 'cat_salario');
      expect(income.source, SuggestionSource.dictionary);
      expect(
        cz.categorize('SALARIO EMPRESA', isIncome: false).categoryId,
        isNull,
      );
    });
  });

  test('sem nenhum passo: categoria nula, fonte nula, confiança 0', () {
    final r = _cz().categorize('XPTO QWERTY', isIncome: false);
    expect(r.categoryId, isNull);
    expect(r.source, isNull);
    expect(r.confidence, 0);
    expect(r.renamedDescription, isNull);
  });

  test('sem categoria mas com renomeio: mantém renamedDescription', () {
    final cz = _cz(
      rules: const [
        TransactionRule(id: 'r', pattern: 'XPTO', renameTo: 'Xpto Exemplo'),
      ],
    );
    final r = cz.categorize('XPTO QWERTY', isIncome: false);
    expect(r.categoryId, isNull);
    expect(r.renamedDescription, 'Xpto Exemplo');
  });

  group('tags (Fase 10)', () {
    test('tags de todas as regras que casam, em ordem de prioridade', () {
      final cz = _cz(
        rules: const [
          TransactionRule(
            id: 'r1',
            pattern: 'UBER',
            categoryId: 'cat_transporte',
            tags: ['app'],
          ),
          TransactionRule(
            id: 'r2',
            pattern: 'TRIP',
            priority: 1,
            tags: ['viagem'],
          ),
        ],
      );
      final r = cz.categorize('UBER *TRIP', isIncome: false);
      expect(r.categoryId, 'cat_transporte');
      expect(r.source, SuggestionSource.rule);
      expect(r.tags, ['app', 'viagem']);
    });

    test('regra só com tags sem categoria: tags valem sem categoria', () {
      final cz = _cz(
        rules: const [
          TransactionRule(id: 'r', pattern: 'XPTO', tags: ['x']),
        ],
      );
      final r = cz.categorize('XPTO QWERTY', isIncome: false);
      expect(r.categoryId, isNull);
      expect(r.tags, ['x']);
    });

    test('descrição sem regra cai no dicionário com tags vazias', () {
      final cz = _cz(
        rules: const [
          TransactionRule(
            id: 'r',
            pattern: 'UBER',
            categoryId: 'cat_transporte',
            tags: ['app'],
          ),
        ],
      );
      final r = cz.categorize('PADARIA PAO BOM', isIncome: false);
      expect(r.source, SuggestionSource.dictionary);
      expect(r.tags, isEmpty);
    });
  });

  test('confidenceLabel nos limiares', () {
    expect(confidenceLabel(0.8), 'alta');
    expect(confidenceLabel(0.79), 'média');
    expect(confidenceLabel(0.5), 'média');
    expect(confidenceLabel(0.49), 'baixa');
  });
}
