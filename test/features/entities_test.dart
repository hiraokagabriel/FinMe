import 'package:finme/core/utils/date_utils.dart';
import 'package:finme/core/utils/enum_utils.dart';
import 'package:finme/features/accounts/domain/account.dart';
import 'package:finme/features/cards/domain/payment_card.dart';
import 'package:finme/features/categories/domain/transaction_category.dart';
import 'package:finme/features/recurring/domain/recurring_rule.dart';
import 'package:finme/features/transactions/domain/transaction.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('parseDateKey', () {
    test('round-trip com dateKey', () {
      expect(parseDateKey('20261114'), DateTime(2026, 11, 14));
      expect(dateKey(parseDateKey('20240229')), '20240229');
    });

    test('rejeita formato e datas inexistentes', () {
      for (final bad in [
        '2026111',
        '2026-11-14',
        'abcdefgh',
        '20261301',
        '20260230',
        '20260001',
      ]) {
        expect(() => parseDateKey(bad), throwsFormatException, reason: bad);
      }
    });
  });

  group('enumByName', () {
    test('nome desconhecido ou nulo → primeiro valor', () {
      expect(enumByName(CardKind.values, 'xyz'), CardKind.credit);
      expect(enumByName(CardKind.values, null), CardKind.credit);
      expect(enumByName(CardKind.values, 'debit'), CardKind.debit);
    });
  });

  group('Account', () {
    final full = const Account(
      id: 'a1',
      name: 'Conta corrente',
      bankName: 'Banco Alfa',
      type: AccountType.savings,
      initialBalanceCents: -1234,
      colorValue: 0xFF42A5F5,
      archived: true,
    );

    test('round-trip e defaults', () {
      expect(Account.fromMap(full.toMap()), full);
      final minimal = Account.fromMap({
        'id': 'a2',
        'name': 'Carteira',
        'bankName': '',
        'type': 'nope',
        'initialBalanceCents': 0,
        'colorValue': 1,
      });
      expect(minimal.type, AccountType.checking);
      expect(minimal.archived, isFalse);
      expect(minimal.copyWith(archived: true).archived, isTrue);
    });

    test('== e hashCode', () {
      expect(full.hashCode, Account.fromMap(full.toMap()).hashCode);
      expect(full == full.copyWith(name: 'Outro'), isFalse);
    });
  });

  group('PaymentCard', () {
    final credit = const PaymentCard(
      id: 'c1',
      name: 'Platinum',
      bankName: 'Banco Beta',
      brand: CardBrand.mastercard,
      kind: CardKind.credit,
      last4: '1234',
      limitCents: 500000,
      closingDay: 25,
      dueDay: 5,
      paymentAccountId: 'a1',
      colorValue: 0xFF000000,
    );

    test('round-trip de crédito', () {
      expect(PaymentCard.fromMap(credit.toMap()), credit);
    });

    test('round-trip sem conta de pagamento e limite default 0', () {
      final debit = PaymentCard.fromMap({
        'id': 'c2',
        'name': 'Débito',
        'bankName': 'Banco Beta',
        'brand': 'visa',
        'kind': 'debit',
        'last4': '0001',
        'closingDay': 1,
        'dueDay': 1,
        'colorValue': 2,
      });
      expect(debit.paymentAccountId, isNull);
      expect(debit.limitCents, 0);
      expect(PaymentCard.fromMap(debit.toMap()), debit);
      expect(debit == credit, isFalse);
    });
  });

  group('TransactionCategory', () {
    test('round-trip com e sem orçamento', () {
      const withBudget = TransactionCategory(
        id: 'k1',
        name: 'Mercado',
        kind: CategoryKind.expense,
        iconCodePoint: 0xe59c,
        colorValue: 3,
        monthlyBudgetCents: 80000,
      );
      const noBudget = TransactionCategory(
        id: 'k2',
        name: 'Salário',
        kind: CategoryKind.income,
        iconCodePoint: 0xe227,
        colorValue: 4,
      );
      expect(TransactionCategory.fromMap(withBudget.toMap()), withBudget);
      final back = TransactionCategory.fromMap(noBudget.toMap());
      expect(back, noBudget);
      expect(back.monthlyBudgetCents, isNull);
    });
  });

  group('Transaction', () {
    final full = Transaction(
      id: 't1',
      type: TransactionType.expense,
      amountCents: 3334,
      date: DateTime(2026, 11, 14),
      description: 'Notebook',
      categoryId: 'k1',
      cardId: 'c1',
      status: TransactionStatus.planned,
      isBoleto: true,
      installmentGroupId: 'g1',
      installmentIndex: 2,
      installmentCount: 3,
      recurringId: 'r1',
      notes: 'nota',
    );

    test('round-trip completo e getters', () {
      expect(Transaction.fromMap(full.toMap()), full);
      expect(full.isPlanned, isTrue);
      expect(full.isInstallment, isTrue);
    });

    test('round-trip mínimo, defaults e data normalizada', () {
      final map = {
        'id': 't2',
        'type': 'transfer',
        'amountCents': 100,
        'date': '20261114',
        'description': 'Pix',
        'accountId': 'a1',
        'toAccountId': 'a2',
      };
      final tx = Transaction.fromMap(map);
      expect(tx.status, TransactionStatus.paid);
      expect(tx.isBoleto, isFalse);
      expect(tx.isPlanned, isFalse);
      expect(tx.isInstallment, isFalse);
      expect(tx.categoryId, isNull);
      expect(tx.date, DateTime(2026, 11, 14));
      expect(Transaction.fromMap(tx.toMap()), tx);
    });

    test('enum desconhecido → primeiro valor', () {
      final tx = Transaction.fromMap({
        'id': 't3',
        'type': 'alien',
        'amountCents': 1,
        'date': '20261114',
        'description': '',
        'status': '???',
      });
      expect(tx.type, TransactionType.expense);
      expect(tx.status, TransactionStatus.paid);
    });

    test('construtor normaliza date para meia-noite', () {
      final tx = Transaction(
        id: 't4',
        type: TransactionType.expense,
        amountCents: 1,
        date: DateTime(2026, 11, 14, 18, 30),
        description: '',
      );
      expect(tx.date, DateTime(2026, 11, 14));
    });

    test('copyWith e ==/hashCode', () {
      final changed = full.copyWith(amountCents: 999);
      expect(changed.amountCents, 999);
      expect(changed == full, isFalse);
      expect(full.copyWith() == full, isTrue);
      expect(full.hashCode, Transaction.fromMap(full.toMap()).hashCode);
    });
  });

  group('RecurringRule', () {
    final rule = RecurringRule(
      id: 'r1',
      description: 'Streaming',
      type: TransactionType.expense,
      amountCents: 4590,
      cardId: 'c1',
      frequency: Frequency.monthly,
      startDate: DateTime(2026, 1, 31),
      endDate: DateTime(2027, 12, 31),
      isSubscription: true,
    );

    test('round-trip completo', () {
      expect(RecurringRule.fromMap(rule.toMap()), rule);
    });

    test('defaults: active true, flags false, endDate null', () {
      final back = RecurringRule.fromMap({
        'id': 'r2',
        'description': 'Salário',
        'type': 'income',
        'amountCents': 500000,
        'accountId': 'a1',
        'frequency': 'bad',
        'startDate': '20260105',
      });
      expect(back.type, TransactionType.income);
      expect(back.frequency, Frequency.weekly);
      expect(back.active, isTrue);
      expect(back.isSubscription, isFalse);
      expect(back.isBoleto, isFalse);
      expect(back.endDate, isNull);
      expect(RecurringRule.fromMap(back.toMap()), back);
      expect(back.copyWith(active: false) == back, isFalse);
    });

    test('materializedUntil: round-trip, normalização, copyWith e ==', () {
      final marked = rule.copyWith(
        materializedUntil: DateTime(2026, 11, 14, 9),
      );
      expect(marked.materializedUntil, DateTime(2026, 11, 14));
      expect(marked.toMap()['materializedUntil'], '20261114');
      expect(RecurringRule.fromMap(marked.toMap()), marked);
      expect(rule.materializedUntil, isNull);
      expect(RecurringRule.fromMap(rule.toMap()).materializedUntil, isNull);
      expect(marked == rule, isFalse);
      expect(marked.hashCode, RecurringRule.fromMap(marked.toMap()).hashCode);
    });
  });
}
