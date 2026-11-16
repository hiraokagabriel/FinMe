import 'package:finme/core/utils/date_utils.dart';
import 'package:finme/features/categories/domain/transaction_category.dart';
import 'package:finme/features/transactions/domain/transaction.dart';
import 'package:finme/features/transactions/domain/transaction_bulk.dart';
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

final _day = DateTime(2026, 11, 14);

Transaction _tx(
  String id, {
  TransactionType type = TransactionType.expense,
  String? categoryId,
  TransactionStatus status = TransactionStatus.paid,
  String? installmentGroupId,
  int? installmentIndex,
  String? toAccountId,
  String? cardId,
}) => Transaction(
  id: id,
  type: type,
  amountCents: 1000,
  date: _day,
  description: id,
  categoryId: categoryId,
  status: status,
  installmentGroupId: installmentGroupId,
  installmentIndex: installmentIndex,
  installmentCount: installmentGroupId == null ? null : 3,
  toAccountId: toAccountId,
  cardId: cardId,
);

// Fixtures do SPEC §5.18.
final a = _tx('a');
final b = _tx('b', categoryId: 'cat_mercado');
final c = _tx('c', type: TransactionType.income);
final d = _tx('d', type: TransactionType.transfer, toAccountId: 'acc_b');
final e = _tx('e', status: TransactionStatus.planned);
final f = _tx('f', status: TransactionStatus.planned);
final g = _tx('g', installmentGroupId: 'g1', installmentIndex: 1);
final h = _tx('h', installmentGroupId: 'g1', installmentIndex: 2);
final i = _tx('i', installmentGroupId: 'g1', installmentIndex: 3);

List<String> _ids(List<Transaction> list) => [for (final t in list) t.id];

void main() {
  group('bulkRecategorize', () {
    test(
      'despesa sem categoria vira cat_mercado; transferência e receita viram skipped',
      () {
        final r = bulkRecategorize([a, b, c, d], _mercado);
        expect(_ids(r.changed), ['a']);
        expect(r.changed.single.categoryId, 'cat_mercado');
        expect(r.skipped, 2);
      },
    );

    test('category null limpa a categoria sem skipped', () {
      final r = bulkRecategorize([a, b, c], null);
      expect(_ids(r.changed), ['b']);
      expect(r.changed.single.categoryId, isNull);
      expect(r.skipped, 0);
    });

    test('receita recebe categoria de receita', () {
      final r = bulkRecategorize([c], _salario);
      expect(_ids(r.changed), ['c']);
      expect(r.changed.single.categoryId, 'cat_salario');
      expect(r.skipped, 0);
    });

    test('pagamento de fatura e transferência ficam em skipped', () {
      final payment = _tx('p', type: TransactionType.invoicePayment);
      final r = bulkRecategorize([payment, d], _mercado);
      expect(r.changed, isEmpty);
      expect(r.skipped, 2);
    });

    test('changed preserva a ordem de entrada', () {
      final x = _tx('x');
      final y = _tx('y');
      final z = _tx('z');
      final r = bulkRecategorize([z, x, y], _mercado);
      expect(_ids(r.changed), ['z', 'x', 'y']);
    });
  });

  group('bulkConfirmPlanned', () {
    test('provisionados viram paid na data do dia; paid fica em skipped', () {
      final r = bulkConfirmPlanned([a, e, f], DateTime(2026, 11, 14, 15, 30));
      expect(_ids(r.changed), ['e', 'f']);
      for (final t in r.changed) {
        expect(t.status, TransactionStatus.paid);
        expect(t.date, dateOnly(DateTime(2026, 11, 14)));
      }
      expect(r.skipped, 1);
    });

    test(
      'provisionado de cartão ou parcela mantém a data; muda só o status',
      () {
        final card = _tx(
          'k',
          status: TransactionStatus.planned,
          cardId: 'card_a',
        );
        final parcel = _tx(
          'q',
          status: TransactionStatus.planned,
          installmentGroupId: 'g2',
          installmentIndex: 1,
        );
        final r = bulkConfirmPlanned([card, parcel], DateTime(2026, 11, 20));
        for (final t in r.changed) {
          expect(t.status, TransactionStatus.paid);
          expect(t.date, _day);
        }
      },
    );
  });

  group('installmentGroupsOf e bulkDeleteIds', () {
    test('installmentGroupsOf ignora itens sem grupo', () {
      expect(installmentGroupsOf([a, g]), {'g1'});
    });

    test('bulkDeleteIds sem grupos inteiros usa só a seleção', () {
      final todas = [a, b, c, d, e, f, g, h, i];
      expect(bulkDeleteIds([a, g], todas, wholeGroups: false), {'a', 'g'});
    });

    test(
      'bulkDeleteIds com grupos inteiros inclui todas as parcelas do grupo',
      () {
        final todas = [a, b, c, d, e, f, g, h, i];
        expect(bulkDeleteIds([a, g], todas, wholeGroups: true), {
          'a',
          'g',
          'h',
          'i',
        });
      },
    );
  });

  group('commonCategoryId', () {
    test('vazio, sem categoria e categorias diferentes → null', () {
      expect(commonCategoryId([]), isNull);
      expect(commonCategoryId([a]), isNull);
      expect(commonCategoryId([b, c]), isNull);
    });

    test('mesma categoria → ela', () {
      final b2 = _tx('b2', categoryId: 'cat_mercado');
      expect(commonCategoryId([b, b2]), 'cat_mercado');
    });
  });

  group('edição inline', () {
    test(
      'canEditCategoryInline: despesa e receita sim; transferência e pagamento não',
      () {
        expect(canEditCategoryInline(a), isTrue);
        expect(canEditCategoryInline(c), isTrue);
        expect(canEditCategoryInline(d), isFalse);
        expect(
          canEditCategoryInline(_tx('p', type: TransactionType.invoicePayment)),
          isFalse,
        );
      },
    );

    test('canEditAmountInline: só despesa e receita não parceladas', () {
      expect(canEditAmountInline(a), isTrue);
      expect(canEditAmountInline(c), isTrue);
      expect(canEditAmountInline(d), isFalse);
      expect(
        canEditAmountInline(_tx('p', type: TransactionType.invoicePayment)),
        isFalse,
      );
      expect(canEditAmountInline(g), isFalse);
    });

    test('parseInlineAmount aceita formatos BR e rejeita inválidos', () {
      expect(parseInlineAmount('12,50'), 1250);
      expect(parseInlineAmount('1.234,56'), 123456);
      expect(parseInlineAmount('R\$ 10'), 1000);
      expect(parseInlineAmount('0'), isNull);
      expect(parseInlineAmount('-5'), isNull);
      expect(parseInlineAmount('abc'), isNull);
    });
  });
}
