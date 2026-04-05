import '../../../core/models/date_range.dart';
import '../domain/transaction_entity.dart';
import '../domain/payment_method.dart';
import '../domain/transaction_type.dart';
import '../../../core/models/money.dart';

abstract class TransactionsRepository {
  Future<List<TransactionEntity>> getAll();
  Future<List<TransactionEntity>> getByRange(DateRange range);
}

class InMemoryTransactionsRepository implements TransactionsRepository {
  InMemoryTransactionsRepository();

  final List<TransactionEntity> _transactions = [
    TransactionEntity(
      id: 'tx_1',
      amount: Money(120.50),
      date: DateTime.now().subtract(const Duration(days: 1)),
      type: TransactionType.expense,
      paymentMethod: PaymentMethod.creditCard,
      description: 'Supermercado',
      categoryId: 'cat_food',
      cardId: 'card_1',
    ),
    TransactionEntity(
      id: 'tx_2',
      amount: Money(45.00),
      date: DateTime.now().subtract(const Duration(days: 2)),
      type: TransactionType.expense,
      paymentMethod: PaymentMethod.debitCard,
      description: 'Uber',
      categoryId: 'cat_transport',
      cardId: 'card_2',
    ),
    TransactionEntity(
      id: 'tx_3',
      amount: Money(29.90),
      date: DateTime.now().subtract(const Duration(days: 5)),
      type: TransactionType.expense,
      paymentMethod: PaymentMethod.creditCard,
      description: 'Streaming',
      categoryId: 'cat_subscriptions',
      cardId: 'card_1',
      isBoleto: false,
      isProvisioned: false,
    ),
    TransactionEntity(
      id: 'tx_4',
      amount: Money(5000.00),
      date: DateTime.now().subtract(const Duration(days: 10)),
      type: TransactionType.income,
      paymentMethod: PaymentMethod.other,
      description: 'Salário',
      categoryId: 'cat_salary',
    ),
  ];

  @override
  Future<List<TransactionEntity>> getAll() async {
    return _transactions;
  }

  @override
  Future<List<TransactionEntity>> getByRange(DateRange range) async {
    return _transactions
        .where((tx) => range.contains(tx.date))
        .toList(growable: false);
  }
}
