import 'package:hive/hive.dart';

import '../../features/transactions/data/transaction_model.dart';
import '../../features/transactions/data/hive_transactions_repository.dart';
import '../../features/transactions/data/transactions_repository.dart';
import '../../features/categories/data/category_model.dart';
import '../../features/categories/data/hive_categories_repository.dart';
import '../../features/categories/data/categories_repository.dart';
import '../../features/cards/data/card_model.dart';
import '../../features/cards/data/hive_cards_repository.dart';
import '../../features/cards/data/cards_repository.dart';
import '../../features/goals/data/goals_repository.dart';
import 'hive_init.dart';

class RepositoryLocator {
  RepositoryLocator._();

  static final RepositoryLocator instance = RepositoryLocator._();

  late final TransactionsRepository transactions =
      HiveTransactionsRepository(
    Hive.box<TransactionModel>(HiveInit.transactionsBoxName),
  );

  late final CategoriesRepository categories = HiveCategoriesRepository(
    Hive.box<CategoryModel>(HiveInit.categoriesBoxName),
  );

  late final CardsRepository cards = HiveCardsRepository(
    Hive.box<CardModel>(HiveInit.cardsBoxName),
  );

  late final GoalsRepository goals = GoalsRepository(
    Hive.box(HiveInit.goalsBoxName),
  );
}
