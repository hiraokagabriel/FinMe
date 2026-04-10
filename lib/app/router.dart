import 'package:flutter/material.dart';

import '../features/dashboard/presentation/dashboard_page.dart';
import '../features/transactions/presentation/transactions_page.dart';
import '../features/cards/presentation/cards_page.dart';
import '../features/settings/presentation/settings_page.dart';
import '../features/goals/presentation/goals_page.dart';
import '../features/reports/presentation/reports_page.dart';
import '../features/accounts/presentation/accounts_page.dart';
import '../features/transfer/presentation/transfer_page.dart';
import '../features/onboarding/presentation/onboarding_page.dart';
import '../features/budget/presentation/budget_page.dart';
import '../features/auth/presentation/login_page.dart';
import '../features/auth/presentation/profile_picker_page.dart';

class AppRouter {
  static const String onboarding   = '/onboarding';
  static const String login        = '/login';
  static const String profilePick  = '/profile-pick';
  static const String dashboard    = '/';
  static const String transactions = '/transactions';
  static const String cards        = '/cards';
  static const String settings     = '/settings';
  static const String goals        = '/goals';
  static const String reports      = '/reports';
  static const String accounts     = '/accounts';
  static const String transfer     = '/transfer';
  static const String budget       = '/budget';

  static final Map<String, WidgetBuilder> routes = {
    onboarding:   (context) => const OnboardingPage(),
    login:        (context) => const LoginPage(),
    profilePick:  (context) => const ProfilePickerPage(),
    dashboard:    (context) => const DashboardPage(),
    transactions: (context) => const TransactionsPage(),
    cards:        (context) => const CardsPage(),
    settings:     (context) => const SettingsPage(),
    goals:        (context) => const GoalsPage(),
    reports:      (context) => const ReportsPage(),
    accounts:     (context) => const AccountsPage(),
    transfer:     (context) => const TransferPage(),
    budget:       (context) => const BudgetPage(),
  };

  static Route<dynamic> onGenerateRoute(RouteSettings settings) {
    final builder = routes[settings.name];

    if (builder == null) {
      return MaterialPageRoute(
        settings: settings,
        builder: (_) => const DashboardPage(),
      );
    }

    return PageRouteBuilder(
      settings: settings,
      pageBuilder: (context, animation, secondaryAnimation) =>
          builder(context),
      transitionsBuilder:
          (context, animation, secondaryAnimation, child) {
        const begin = Offset(1.0, 0.0);
        const end = Offset.zero;
        final tween = Tween(begin: begin, end: end).chain(
          CurveTween(curve: Curves.easeOutCubic),
        );
        return SlideTransition(
          position: animation.drive(tween),
          child: child,
        );
      },
    );
  }
}
