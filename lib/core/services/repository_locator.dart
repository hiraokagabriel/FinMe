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
import '../../features/accounts/data/account_model.dart';
import '../../features/accounts/data/hive_accounts_repository.dart';
import '../../features/accounts/data/accounts_repository.dart';
import '../../features/budget/data/budget_repository.dart';
import 'hive_init.dart';
import 'profile_service.dart';

class RepositoryLocator {
  RepositoryLocator._();
  static final RepositoryLocator instance = RepositoryLocator._();

  TransactionsRepository? _transactions;
  CategoriesRepository?   _categories;
  CardsRepository?        _cards;
  GoalsRepository?        _goals;
  AccountsRepository?     _accounts;
  BudgetRepository?       _budgets;

  TransactionsRepository get transactions => _transactions!;
  CategoriesRepository   get categories   => _categories!;
  CardsRepository        get cards        => _cards!;
  GoalsRepository        get goals        => _goals!;
  AccountsRepository     get accounts     => _accounts!;
  BudgetRepository       get budgets      => _budgets!;

  /// Chamado pelo ProfileService após abrir os boxes do perfil ativo.
  void reinit(String loginId, String profileId) {
    _transactions = HiveTransactionsRepository(
      Hive.box<TransactionModel>(
          ProfileService.boxName(HiveInit.transactionsBoxName, loginId, profileId)),
    );
    _categories = HiveCategoriesRepository(
      Hive.box<CategoryModel>(
          ProfileService.boxName(HiveInit.categoriesBoxName, loginId, profileId)),
    );
    _cards = HiveCardsRepository(
      Hive.box<CardModel>(
          ProfileService.boxName(HiveInit.cardsBoxName, loginId, profileId)),
    );
    _goals = GoalsRepository(
      Hive.box(ProfileService.boxName(HiveInit.goalsBoxName, loginId, profileId)),
    );
    _accounts = HiveAccountsRepository(
      Hive.box<AccountModel>(
          ProfileService.boxName(HiveInit.accountsBoxName, loginId, profileId)),
    );
    _budgets = BudgetRepository(
      Hive.box(ProfileService.boxName(HiveInit.budgetsBoxName, loginId, profileId)),
    );
  }
}
