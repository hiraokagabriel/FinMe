import 'package:flutter/material.dart';

import '../features/dashboard/presentation/dashboard_page.dart';
import '../features/transactions/presentation/transactions_page.dart';
import '../features/cards/presentation/cards_page.dart';

class AppRouter {
  static const String dashboard = '/';
  static const String transactions = '/transactions';
  static const String cards = '/cards';

  static final Map<String, WidgetBuilder> routes = {
    dashboard: (context) => const DashboardPage(),
    transactions: (context) => const TransactionsPage(),
    cards: (context) => const CardsPage(),
  };
}
