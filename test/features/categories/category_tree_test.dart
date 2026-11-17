import 'package:finme/features/categories/domain/category_spending.dart';
import 'package:finme/features/categories/domain/category_tree.dart';
import 'package:finme/features/categories/domain/transaction_category.dart';
import 'package:flutter_test/flutter_test.dart';

TransactionCategory cat(
  String id,
  String name, {
  CategoryKind kind = CategoryKind.expense,
  String? parent,
  int? budget,
}) => TransactionCategory(
  id: id,
  name: name,
  kind: kind,
  iconCodePoint: 0xe000,
  colorValue: 0xFF000000,
  monthlyBudgetCents: budget,
  parentId: parent,
);

// ali Alimentação (raiz), mer Mercado (filha de ali), res Restaurante (filha de ali),
// tra Transporte (raiz), sal Salário (receita), x Órfã (pai inexistente → raiz),
// y Neta (pai é filha → vínculo inválido → raiz).
final List<TransactionCategory> sample = [
  cat('ali', 'Alimentação'),
  cat('mer', 'Mercado', parent: 'ali'),
  cat('res', 'Restaurante', parent: 'ali'),
  cat('tra', 'Transporte'),
  cat('sal', 'Salário', kind: CategoryKind.income),
  cat('x', 'Órfã', parent: 'zzz'),
  cat('y', 'Neta', parent: 'mer'),
];

void main() {
  group('TransactionCategory.parentId', () {
    test('round-trip com e sem parentId', () {
      final child = cat('mer', 'Mercado', parent: 'ali');
      final root = cat('ali', 'Alimentação');
      expect(TransactionCategory.fromMap(child.toMap()), child);
      expect(TransactionCategory.fromMap(root.toMap()), root);
      expect(TransactionCategory.fromMap(child.toMap()).parentId, 'ali');
    });

    test('fromMap sem a chave, nula ou não-string → null', () {
      final base = cat('a', 'A').toMap();
      expect(TransactionCategory.fromMap(base).parentId, isNull);
      expect(
        TransactionCategory.fromMap({...base, 'parentId': 42}).parentId,
        isNull,
      );
    });

    test('toMap omite a chave quando parentId é null', () {
      expect(cat('a', 'A').toMap().containsKey('parentId'), isFalse);
      expect(cat('m', 'M', parent: 'a').toMap()['parentId'], 'a');
    });

    test('copyWith: omitido mantém, null explícito limpa, valor troca', () {
      final child = cat('mer', 'Mercado', parent: 'ali', budget: 500);
      expect(child.copyWith(name: 'Super').parentId, 'ali');
      expect(child.copyWith(parentId: null).parentId, isNull);
      expect(child.copyWith(parentId: null).monthlyBudgetCents, 500);
      expect(child.copyWith(parentId: 'tra').parentId, 'tra');
      expect(child.copyWith(monthlyBudgetCents: null).parentId, 'ali');
    });

    test('== e hashCode consideram parentId', () {
      final a = cat('mer', 'Mercado', parent: 'ali');
      final same = cat('mer', 'Mercado', parent: 'ali');
      final other = cat('mer', 'Mercado', parent: 'tra');
      expect(a, same);
      expect(a.hashCode, same.hashCode);
      expect(a == other, isFalse);
    });
  });

  group('CategoryTree', () {
    final tree = CategoryTree(sample);

    test('rótulos (§5.20)', () {
      expect(tree.label('mer'), 'Alimentação › Mercado');
      expect(tree.label('ali'), 'Alimentação');
      expect(tree.label('x'), 'Órfã');
      expect(tree.label('y'), 'Neta');
      expect(tree.label('nada'), '');
      expect(CategoryTree.empty.label('x'), '');
    });

    test('options(expense) na ordem do dropdown (§5.20)', () {
      expect(tree.options(CategoryKind.expense).map((c) => c.id), [
        'ali',
        'mer',
        'res',
        'y',
        'x',
        'tra',
      ]);
      expect(tree.options(CategoryKind.income).map((c) => c.id), ['sal']);
    });

    test('roots, childrenOf, hasChildren, parentOf, rootOf, isRoot', () {
      expect(tree.roots(CategoryKind.expense).map((c) => c.id), [
        'ali',
        'y',
        'x',
        'tra',
      ]);
      expect(tree.childrenOf('ali').map((c) => c.id), ['mer', 'res']);
      expect(tree.childrenOf('tra'), const <TransactionCategory>[]);
      expect(tree.hasChildren('ali'), isTrue);
      expect(tree.hasChildren('tra'), isFalse);
      expect(tree.parentOf('mer'), 'ali');
      expect(tree.parentOf('y'), isNull);
      expect(tree.rootOf('mer'), 'ali');
      expect(tree.rootOf('nada'), 'nada');
      expect(tree.isRoot('y'), isTrue);
      expect(tree.isRoot('mer'), isFalse);
      expect(tree.byId('mer')?.name, 'Mercado');
    });

    test('rollUp agrega no pai e preserva a soma (§5.20)', () {
      final rolled = tree.rollUp({
        'mer': 5000,
        'res': 3000,
        'ali': 1000,
        'tra': 200,
        null: 50,
        'apagada': 10,
      });
      expect(rolled, {'ali': 9000, 'tra': 200, null: 50, 'apagada': 10});
      expect(rolled.values.reduce((a, b) => a + b), 9260);
    });

    test('categoryParentError (§5.20)', () {
      String? err(String? id, String? parentId, CategoryKind kind) =>
          categoryParentError(
            id: id,
            kind: kind,
            parentId: parentId,
            categories: sample,
          );
      expect(
        err('ali', 'tra', CategoryKind.expense),
        'Esta categoria tem subcategorias e não pode virar subcategoria',
      );
      expect(
        err('tra', 'mer', CategoryKind.expense),
        'A categoria pai não pode ser uma subcategoria',
      );
      expect(
        err('tra', 'sal', CategoryKind.expense),
        'A categoria pai precisa ser do mesmo tipo',
      );
      expect(err('tra', 'ali', CategoryKind.expense), isNull);
      expect(err(null, 'ali', CategoryKind.expense), isNull);
      expect(
        err('tra', 'tra', CategoryKind.expense),
        'Uma categoria não pode ser pai dela mesma',
      );
      expect(
        err('tra', 'zzz', CategoryKind.expense),
        'Categoria pai não encontrada',
      );
    });
  });

  group('budgetStatuses com subcategorias (§5.6)', () {
    final cats = [
      cat('ali', 'Alimentação', budget: 100000),
      cat('mer', 'Mercado', parent: 'ali', budget: 60000),
      cat('res', 'Restaurante', parent: 'ali'),
    ];
    final spending = <String?, int>{'ali': 10000, 'mer': 50000, 'res': 30000};

    test('orçamento de raiz cobre filhas; filha usa gasto próprio', () {
      final statuses = budgetStatuses(cats, spending, tree: CategoryTree(cats));
      expect(statuses.map((s) => s.category.id), ['ali', 'mer']);
      expect(statuses[0].spentCents, 90000);
      expect(statuses[0].ratio, closeTo(0.9, 1e-9));
      expect(statuses[1].spentCents, 50000);
      expect(statuses[1].ratio, closeTo(0.8333, 1e-3));
    });

    test('sem tree mantém o comportamento anterior', () {
      final statuses = budgetStatuses(cats, spending);
      final ali = statuses.firstWhere((s) => s.category.id == 'ali');
      expect(ali.spentCents, 10000);
      expect(statuses.map((s) => s.category.id), ['mer', 'ali']);
    });
  });
}
