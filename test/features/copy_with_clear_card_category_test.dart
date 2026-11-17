import 'package:finme/features/cards/domain/payment_card.dart';
import 'package:finme/features/categories/domain/transaction_category.dart';
import 'package:flutter_test/flutter_test.dart';

PaymentCard _card({
  String? paymentAccountId = 'acc_a',
  List<CardCycle> history = const [],
}) => PaymentCard(
  id: 'card_1',
  name: 'Cartão',
  bankName: 'Banco',
  brand: CardBrand.visa,
  kind: CardKind.credit,
  last4: '1234',
  closingDay: 5,
  dueDay: 12,
  colorValue: 0xFF000000,
  paymentAccountId: paymentAccountId,
  cycleHistory: history,
);

TransactionCategory _category({int? monthlyBudgetCents = 50000}) =>
    TransactionCategory(
      id: 'cat_1',
      name: 'Mercado',
      kind: CategoryKind.expense,
      iconCodePoint: 0xe000,
      colorValue: 0xFF000000,
      monthlyBudgetCents: monthlyBudgetCents,
    );

void main() {
  final history = [
    CardCycle(until: DateTime(2026, 12, 1), closingDay: 5, dueDay: 12),
  ];

  group('PaymentCard.copyWith com sentinela', () {
    test('omitido mantém paymentAccountId', () {
      expect(_card().copyWith().paymentAccountId, 'acc_a');
    });

    test('null explícito limpa paymentAccountId', () {
      expect(_card().copyWith(paymentAccountId: null).paymentAccountId, isNull);
    });

    test('valor troca paymentAccountId', () {
      expect(
        _card().copyWith(paymentAccountId: 'acc_x').paymentAccountId,
        'acc_x',
      );
    });

    test('cycleHistory preservado em todos os casos', () {
      final card = _card(history: history);
      expect(card.copyWith().cycleHistory, history);
      expect(card.copyWith(paymentAccountId: null).cycleHistory, history);
      expect(card.copyWith(paymentAccountId: 'acc_x').cycleHistory, history);
    });

    test('withCycleChange preserva paymentAccountId e acrescenta ciclo', () {
      final card = _card().withCycleChange(
        closingDay: 20,
        dueDay: 27,
        effectiveFrom: DateTime(2026, 11, 15),
      );
      expect(card.paymentAccountId, 'acc_a');
      expect(card.cycleHistory, hasLength(1));
      expect(card.cycleHistory.single.closingDay, 5);
    });
  });

  group('TransactionCategory.copyWith com sentinela', () {
    test('omitido mantém monthlyBudgetCents', () {
      expect(_category().copyWith().monthlyBudgetCents, 50000);
    });

    test('null explícito remove o orçamento', () {
      expect(
        _category().copyWith(monthlyBudgetCents: null).monthlyBudgetCents,
        isNull,
      );
    });

    test('valor troca monthlyBudgetCents', () {
      expect(
        _category().copyWith(monthlyBudgetCents: 90000).monthlyBudgetCents,
        90000,
      );
    });
  });
}
