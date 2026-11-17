import 'package:finme/core/models/year_month.dart';
import 'package:finme/features/accounts/domain/account.dart';
import 'package:finme/features/accounts/domain/balances.dart';
import 'package:finme/features/cards/domain/payment_card.dart';
import 'package:finme/features/categories/domain/category_spending.dart';
import 'package:finme/features/categories/domain/transaction_category.dart';
import 'package:finme/features/transactions/domain/transaction.dart';
import 'package:flutter_test/flutter_test.dart';

Account _account(String id, int initial) => Account(
  id: id,
  name: id,
  bankName: '',
  type: AccountType.checking,
  initialBalanceCents: initial,
  colorValue: 0,
);

PaymentCard _card(String id, CardKind kind, {String? paymentAccountId}) =>
    PaymentCard(
      id: id,
      name: id,
      bankName: '',
      brand: CardBrand.visa,
      kind: kind,
      last4: '0000',
      closingDay: 5,
      dueDay: 12,
      colorValue: 0,
      paymentAccountId: paymentAccountId,
    );

Transaction _tx(
  String id,
  TransactionType type,
  int amount, {
  String? accountId,
  String? cardId,
  String? toAccountId,
  String? categoryId,
  TransactionStatus status = TransactionStatus.paid,
  DateTime? date,
}) => Transaction(
  id: id,
  type: type,
  amountCents: amount,
  date: date ?? DateTime(2026, 11, 10),
  description: id,
  accountId: accountId,
  cardId: cardId,
  toAccountId: toAccountId,
  categoryId: categoryId,
  status: status,
);

void main() {
  final accounts = [_account('a', 1000), _account('b', 500)];
  final cards = [
    _card('debit', CardKind.debit, paymentAccountId: 'a'),
    _card('credit', CardKind.credit, paymentAccountId: 'b'),
  ];

  group('accountBalances', () {
    test('planned não afeta saldo', () {
      final balances = accountBalances(
        accounts: accounts,
        cards: cards,
        transactions: [
          _tx(
            'p',
            TransactionType.expense,
            300,
            accountId: 'a',
            status: TransactionStatus.planned,
          ),
        ],
      );
      expect(balances, {'a': 1000, 'b': 500});
    });

    test('transfer move entre contas', () {
      final balances = accountBalances(
        accounts: accounts,
        cards: cards,
        transactions: [
          _tx(
            't',
            TransactionType.transfer,
            200,
            accountId: 'a',
            toAccountId: 'b',
          ),
        ],
      );
      expect(balances, {'a': 800, 'b': 700});
    });

    test('débito afeta a conta do cartão; crédito não afeta conta', () {
      final balances = accountBalances(
        accounts: accounts,
        cards: cards,
        transactions: [
          _tx('d', TransactionType.expense, 100, cardId: 'debit'),
          _tx('c', TransactionType.expense, 400, cardId: 'credit'),
          _tx('r', TransactionType.income, 50, cardId: 'debit'),
        ],
      );
      expect(balances, {'a': 950, 'b': 500});
    });

    test('invoicePayment debita a conta de origem', () {
      final balances = accountBalances(
        accounts: accounts,
        cards: cards,
        transactions: [
          _tx(
            'ip',
            TransactionType.invoicePayment,
            250,
            accountId: 'a',
            cardId: 'credit',
          ),
        ],
      );
      expect(balances, {'a': 750, 'b': 500});
    });

    test('income em conta soma; conta desconhecida é ignorada', () {
      final balances = accountBalances(
        accounts: accounts,
        cards: cards,
        transactions: [
          _tx('i', TransactionType.income, 70, accountId: 'b'),
          _tx('x', TransactionType.expense, 90, accountId: 'zzz'),
        ],
      );
      expect(balances, {'a': 1000, 'b': 570});
    });
  });

  group('signedEffectOn', () {
    final cardsById = {for (final c in cards) c.id: c};

    test('sinal por tipo e zero quando não afeta', () {
      final expense = _tx('e', TransactionType.expense, 100, accountId: 'a');
      final income = _tx('i', TransactionType.income, 100, accountId: 'a');
      final transfer = _tx(
        't',
        TransactionType.transfer,
        100,
        accountId: 'a',
        toAccountId: 'b',
      );
      expect(signedEffectOn('a', expense, cardsById), -100);
      expect(signedEffectOn('a', income, cardsById), 100);
      expect(signedEffectOn('a', transfer, cardsById), -100);
      expect(signedEffectOn('b', transfer, cardsById), 100);
      expect(signedEffectOn('b', expense, cardsById), 0);
    });
  });

  group('spendingByCategory', () {
    const month = YearMonth(2026, 11);
    final txs = [
      _tx(
        'mercado',
        TransactionType.expense,
        300,
        accountId: 'a',
        categoryId: 'food',
      ),
      _tx(
        'cartao',
        TransactionType.expense,
        200,
        cardId: 'credit',
        categoryId: 'food',
      ),
      _tx('sem', TransactionType.expense, 50, accountId: 'a'),
      _tx(
        'outubro',
        TransactionType.expense,
        999,
        accountId: 'a',
        categoryId: 'food',
        date: DateTime(2026, 10, 31),
      ),
      _tx(
        'prov',
        TransactionType.expense,
        80,
        accountId: 'a',
        categoryId: 'food',
        status: TransactionStatus.planned,
      ),
      _tx(
        'transf',
        TransactionType.transfer,
        500,
        accountId: 'a',
        toAccountId: 'b',
        categoryId: 'food',
      ),
      _tx(
        'salario',
        TransactionType.income,
        700,
        accountId: 'a',
        categoryId: 'food',
      ),
      _tx(
        'estorno',
        TransactionType.income,
        40,
        cardId: 'credit',
        categoryId: 'food',
      ),
    ];

    test('inclui cartão, exclui transfer/income/outro mês/planned', () {
      expect(spendingByCategory(txs, month), {'food': 500, null: 50});
    });

    test('includePlanned soma provisionados', () {
      expect(spendingByCategory(txs, month, includePlanned: true), {
        'food': 580,
        null: 50,
      });
    });
  });

  group('budgetStatuses', () {
    TransactionCategory cat(String id, int? budget) => TransactionCategory(
      id: id,
      name: id,
      kind: CategoryKind.expense,
      iconCodePoint: 0,
      colorValue: 0,
      monthlyBudgetCents: budget,
    );

    test('ordena por ratio desc e ignora sem orçamento', () {
      final statuses = budgetStatuses(
        [cat('a', 1000), cat('b', null), cat('c', 200), cat('d', 0)],
        {'a': 500, 'c': 400, 'b': 9999},
      );
      expect(statuses.map((s) => s.category.id), ['c', 'a']);
      expect(statuses.first.ratio, 2.0);
      expect(statuses.first.exceeded, isTrue);
      expect(statuses.last.ratio, 0.5);
      expect(statuses.last.exceeded, isFalse);
    });

    test('categoria sem gasto tem spent 0', () {
      final statuses = budgetStatuses([cat('a', 100)], {});
      expect(statuses.single.spentCents, 0);
      expect(statuses.single.ratio, 0.0);
    });
  });
}
