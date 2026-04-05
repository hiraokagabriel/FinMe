import 'package:flutter/material.dart';

import '../features/dashboard/presentation/dashboard_page.dart';
import '../features/transactions/presentation/transactions_page.dart';
import '../features/cards/presentation/cards_page.dart';
import '../features/settings/presentation/settings_page.dart';
import '../features/goals/presentation/goals_page.dart';
import '../features/reports/presentation/reports_page.dart';
import '../features/accounts/presentation/accounts_page.dart';
import '../features/transfer/presentation/transfer_page.dart';

class AppRouter {
  static const String dashboard    = '/';
  static const String transactions = '/transactions';
  static const String cards        = '/cards';
  static const String settings     = '/settings';
  static const String goals        = '/goals';
  static const String reports      = '/reports';
  static const String accounts     = '/accounts';
  static const String transfer     = '/transfer';

  static final Map<String, WidgetBuilder> routes = {
    dashboard:    (context) => const DashboardPage(),
    transactions: (context) => const TransactionsPage(),
    cards:        (context) => const CardsPage(),
    settings:     (context) => const SettingsPage(),
    goals:        (context) => const GoalsPage(),
    reports:      (context) => const ReportsPage(),
    accounts:     (context) => const AccountsPage(),
    transfer:     (context) => const TransferPage(),
  };
}
