import 'package:flutter/material.dart';

import '../features/dashboard/presentation/dashboard_page.dart';
import '../features/transactions/presentation/transactions_page.dart';

class AppRouter {
  static const String dashboard = '/';
  static const String transactions = '/transactions';

  static final Map<String, WidgetBuilder> routes = {
    dashboard: (context) => const DashboardPage(),
    transactions: (context) => const TransactionsPage(),
  };
}
