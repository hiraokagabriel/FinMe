import 'package:finme/features/categories/domain/transaction_category.dart';
import 'package:finme/features/rules/domain/rule_engine.dart';
import 'package:finme/features/rules/domain/transaction_rule.dart';
import 'package:finme/features/transactions/domain/transaction.dart';
import 'package:flutter_test/flutter_test.dart';

const _mercado = TransactionCategory(
  id: 'cat_mercado',
  name: 'Mercado',
  kind: CategoryKind.expense,
  iconCodePoint: 0,
  colorValue: 0,
);

const _salario = TransactionCategory(
  id: 'cat_salario',
  name: 'Salário',
  kind: CategoryKind.income,
  iconCodePoint: 0,
  colorValue: 0,
);

final _categories = {_mercado.id: _mercado, _salario.id: _salario};

Transaction _tx(
  String id, {
  String description = 'LOJA EXEMPLO',
  TransactionType type = TransactionType.expense,
  String? categoryId,
  String? importedDescription,
}) => Transaction(
  id: id,
  type: type,
  amountCents: 1000,
  date: DateTime(2026, 11, 14),
  description: description,
  categoryId: categoryId,
  importedDescription: importedDescription,
);

void main() {
  group('TransactionRule', () {
    test('round-trip fromMap/toMap', () {
      const r = TransactionRule(
        id: 'r1',
        pattern: 'uber',
        matchType: RuleMatchType.startsWith,
        categoryId: 'cat_mercado',
        renameTo: 'Uber',
        priority: 3,
        active: false,
      );
      expect(TransactionRule.fromMap(r.toMap()), r);
    });

    test('mapa mínimo usa padrões', () {
      final r = TransactionRule.fromMap({'id': 'r', 'pattern': 'x'});
      expect(r.matchType, RuleMatchType.contains);
      expect(r.priority, 0);
      expect(r.active, isTrue);
      expect(r.categoryId, isNull);
      expect(r.renameTo, isNull);
    });

    test('enum desconhecido vira contains', () {
      final r = TransactionRule.fromMap({
        'id': 'r',
        'pattern': 'x',
        'matchType': 'nope',
      });
      expect(r.matchType, RuleMatchType.contains);
    });

    test('copyWith(categoryId: null) limpa; omitido mantém', () {
      const r = TransactionRule(
        id: 'r',
        pattern: 'x',
        categoryId: 'cat_mercado',
        renameTo: 'Y',
      );
      expect(r.copyWith(categoryId: null).categoryId, isNull);
      expect(r.copyWith(categoryId: null).renameTo, 'Y');
      expect(r.copyWith().categoryId, 'cat_mercado');
    });
  });

  group('CompiledRule.matches', () {
    test('contains ignora acento e caixa', () {
      final c = CompiledRule(
        const TransactionRule(id: 'r', pattern: 'farmácia'),
      );
      expect(c.matches('FARMACIA SAO JOAO'), isTrue);
    });

    test('startsWith', () {
      final c = CompiledRule(
        const TransactionRule(
          id: 'r',
          pattern: 'uber',
          matchType: RuleMatchType.startsWith,
        ),
      );
      expect(c.matches('UBER *TRIP'), isTrue);
      expect(c.matches('PAG UBER'), isFalse);
    });

    test('regex é case-insensitive', () {
      final c = CompiledRule(
        const TransactionRule(
          id: 'r',
          pattern: r'^uber\s',
          matchType: RuleMatchType.regex,
        ),
      );
      expect(c.matches('Uber trip'), isTrue);
    });

    test('regex inválida nunca casa e não lança', () {
      const rule = TransactionRule(
        id: 'r',
        pattern: '(',
        matchType: RuleMatchType.regex,
      );
      expect(isValidRulePattern('(', RuleMatchType.regex), isFalse);
      expect(CompiledRule(rule).matches('('), isFalse);
      expect(CompiledRule(rule).matches('qualquer coisa'), isFalse);
    });

    test('padrão em branco nunca casa', () {
      for (final type in RuleMatchType.values) {
        final c = CompiledRule(
          TransactionRule(id: 'r', pattern: '  ', matchType: type),
        );
        expect(c.matches('LOJA EXEMPLO'), isFalse, reason: type.name);
      }
      expect(isValidRulePattern('  ', RuleMatchType.contains), isFalse);
    });
  });

  group('compileRules / reorderRules', () {
    test('exclui inativas; prioridade asc e empate por id', () {
      final compiled = compileRules(const [
        TransactionRule(id: 'b', pattern: 'x'),
        TransactionRule(id: 'a', pattern: 'x'),
        TransactionRule(id: 'c', pattern: 'x', priority: -1),
        TransactionRule(id: 'z', pattern: 'x', active: false),
      ]);
      expect(compiled.map((c) => c.rule.id).toList(), ['c', 'a', 'b']);
    });

    test('reorderRules numera pela ordem dada', () {
      const r1 = TransactionRule(id: 'r1', pattern: 'x', priority: 5);
      const r2 = TransactionRule(id: 'r2', pattern: 'x', priority: 7);
      const r3 = TransactionRule(id: 'r3', pattern: 'x', priority: 9);
      final out = reorderRules([r3, r1, r2]);
      expect(out.map((r) => r.id).toList(), ['r3', 'r1', 'r2']);
      expect(out.map((r) => r.priority).toList(), [0, 1, 2]);
    });
  });

  group('matchingTransactions', () {
    test('ignora transfer/invoicePayment e inclui regra inativa', () {
      const rule = TransactionRule(id: 'r', pattern: 'exemplo', active: false);
      final txs = [
        _tx('t1'),
        _tx('t2', type: TransactionType.transfer),
        _tx('t3', type: TransactionType.invoicePayment),
        _tx('t4', type: TransactionType.income),
        _tx('t5', description: 'OUTRA'),
      ];
      final out = matchingTransactions(rule, txs);
      expect(out.map((t) => t.id).toList(), ['t1', 't4']);
    });

    test(
      'casa pelo importedDescription (assunto), não pela descrição renomeada',
      () {
        const rule = TransactionRule(id: 'r', pattern: 'ifood');
        final txs = [
          _tx('t1', description: 'Restaurante', importedDescription: 'IFOOD X'),
        ];
        expect(matchingTransactions(rule, txs).length, 1);
      },
    );
  });

  group('reapplyRules', () {
    test('despesa sem categoria recebe a da regra', () {
      final compiled = compileRules(const [
        TransactionRule(id: 'r', pattern: 'exemplo', categoryId: 'cat_mercado'),
      ]);
      final out = reapplyRules(compiled, [
        _tx('t1'),
      ], categoriesById: _categories);
      expect(out.length, 1);
      expect(out.single.categoryId, 'cat_mercado');
    });

    test('despesa categorizada só muda com overwriteCategory', () {
      final compiled = compileRules(const [
        TransactionRule(id: 'r', pattern: 'exemplo', categoryId: 'cat_mercado'),
      ]);
      final txs = [_tx('t1', categoryId: 'outra')];
      expect(reapplyRules(compiled, txs, categoriesById: _categories), isEmpty);
      final over = reapplyRules(
        compiled,
        txs,
        categoriesById: _categories,
        overwriteCategory: true,
      );
      expect(over.single.categoryId, 'cat_mercado');
    });

    test('regra com categoria de receita não toca despesa', () {
      final compiled = compileRules(const [
        TransactionRule(id: 'r', pattern: 'exemplo', categoryId: 'cat_salario'),
      ]);
      expect(
        reapplyRules(compiled, [_tx('t1')], categoriesById: _categories),
        isEmpty,
      );
    });

    test('renomear grava descrição nova e guarda a original', () {
      final compiled = compileRules(const [
        TransactionRule(id: 'r', pattern: 'exemplo', renameTo: 'Mercadinho'),
      ]);
      final out = reapplyRules(compiled, [
        _tx('t1'),
      ], categoriesById: _categories);
      expect(out.single.description, 'Mercadinho');
      expect(out.single.importedDescription, 'LOJA EXEMPLO');
    });

    test('é idempotente: segunda aplicação não muda nada', () {
      final compiled = compileRules(const [
        TransactionRule(
          id: 'r',
          pattern: 'exemplo',
          categoryId: 'cat_mercado',
          renameTo: 'Mercadinho',
        ),
      ]);
      for (final overwrite in [false, true]) {
        final first = reapplyRules(
          compiled,
          [_tx('t1')],
          categoriesById: _categories,
          overwriteCategory: overwrite,
        );
        final second = reapplyRules(
          compiled,
          first,
          categoriesById: _categories,
          overwriteCategory: overwrite,
        );
        expect(second, isEmpty, reason: 'overwrite=$overwrite');
      }
    });

    test('ignora transfer e retorna só as transações que mudam', () {
      final compiled = compileRules(const [
        TransactionRule(id: 'r', pattern: 'exemplo', categoryId: 'cat_mercado'),
      ]);
      final out = reapplyRules(compiled, [
        _tx('t1'),
        _tx('t2', type: TransactionType.transfer),
        _tx('t3', categoryId: 'cat_mercado'),
      ], categoriesById: _categories);
      expect(out.map((t) => t.id).toList(), ['t1']);
    });
  });
}
