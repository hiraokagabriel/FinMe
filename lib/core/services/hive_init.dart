import 'package:hive_flutter/hive_flutter.dart';

import '../../features/transactions/data/transaction_model.dart';
import '../../features/categories/data/category_model.dart';
import '../../features/cards/data/card_model.dart';

class HiveInit {
  static const String transactionsBoxName = 'transactions';
  static const String categoriesBoxName   = 'categories';
  static const String cardsBoxName        = 'cards';
  static const String goalsBoxName        = 'goals';

  static Future<void> init() async {
    await Hive.initFlutter();

    Hive.registerAdapter(TransactionModelAdapter());
    Hive.registerAdapter(CategoryModelAdapter());
    Hive.registerAdapter(CardModelAdapter());

    final transactionsBox =
        await Hive.openBox<TransactionModel>(transactionsBoxName);
    final categoriesBox =
        await Hive.openBox<CategoryModel>(categoriesBoxName);
    final cardsBox   = await Hive.openBox<CardModel>(cardsBoxName);
    // goals usa Box dinâmica (Map) – sem adapter gerado
    await Hive.openBox(goalsBoxName);

    if (categoriesBox.isEmpty) {
      final seedCategories = [
        CategoryModel(
          id: 'cat_food',
          name: 'Alimentação',
          kindIndex: 0,
          colorValue: 0xFFF44336,
        ),
        CategoryModel(
          id: 'cat_transport',
          name: 'Transporte',
          kindIndex: 0,
          colorValue: 0xFF2196F3,
        ),
        CategoryModel(
          id: 'cat_subscriptions',
          name: 'Assinaturas',
          kindIndex: 0,
          colorValue: 0xFF607D8B,
        ),
        CategoryModel(
          id: 'cat_salary',
          name: 'Salário',
          kindIndex: 1,
          colorValue: 0xFF43A047,
        ),
      ];
      await categoriesBox.putAll({
        for (final c in seedCategories) c.id: c,
      });
    }

    if (cardsBox.isEmpty) {
      final seedCards = [
        CardModel(
          id: 'card_1',
          name: 'Cartão Principal',
          bankName: 'Banco A',
          typeIndex: 0,
          dueDay: 10,
          limit: 10000,
        ),
        CardModel(
          id: 'card_2',
          name: 'Cartão Secundário',
          bankName: 'Banco B',
          typeIndex: 0,
          dueDay: 20,
          limit: 5000,
        ),
      ];
      await cardsBox.putAll({
        for (final c in seedCards) c.id: c,
      });
    }

    if (transactionsBox.isEmpty) {
      final now = DateTime.now();
      final seedTransactions = [
        TransactionModel(
          id: 'tx_1',
          amount: 120.50,
          currency: 'BRL',
          date: now.subtract(const Duration(days: 1)),
          typeIndex: 1,
          paymentMethodIndex: 0,
          description: 'Supermercado',
          categoryId: 'cat_food',
          cardId: 'card_1',
          isBoleto: false,
          isProvisioned: false,
        ),
        TransactionModel(
          id: 'tx_2',
          amount: 45.00,
          currency: 'BRL',
          date: now.subtract(const Duration(days: 2)),
          typeIndex: 1,
          paymentMethodIndex: 1,
          description: 'Uber',
          categoryId: 'cat_transport',
          cardId: 'card_2',
          isBoleto: false,
          isProvisioned: false,
        ),
        TransactionModel(
          id: 'tx_3',
          amount: 29.90,
          currency: 'BRL',
          date: now.subtract(const Duration(days: 5)),
          typeIndex: 1,
          paymentMethodIndex: 0,
          description: 'Streaming',
          categoryId: 'cat_subscriptions',
          cardId: 'card_1',
          isBoleto: false,
          isProvisioned: false,
        ),
        TransactionModel(
          id: 'tx_4',
          amount: 5000.00,
          currency: 'BRL',
          date: now.subtract(const Duration(days: 10)),
          typeIndex: 0,
          paymentMethodIndex: 5,
          description: 'Salário',
          categoryId: 'cat_salary',
          cardId: null,
          isBoleto: false,
          isProvisioned: false,
        ),
      ];
      await transactionsBox.putAll({
        for (final t in seedTransactions) t.id: t,
      });
    }
  }
}
