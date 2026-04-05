import 'package:flutter/material.dart';

import '../features/dashboard/presentation/dashboard_page.dart';

class AppRouter {
  static const String dashboard = '/';

  static final Map<String, WidgetBuilder> routes = {
    dashboard: (context) => const DashboardPage(),
  };
}
