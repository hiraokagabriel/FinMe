import 'package:flutter/material.dart';

import '../core/services/theme_controller.dart';
import '../core/services/auth_service.dart';
import '../core/services/route_observer.dart';
import '../core/theme/app_theme.dart';
import 'router.dart';

class FinMeApp extends StatelessWidget {
  final bool showOnboarding;

  const FinMeApp({super.key, required this.showOnboarding});

  String _resolveInitialRoute() {
    if (showOnboarding) return AppRouter.onboarding;
    if (!AuthService.instance.isAuthenticated) return AppRouter.login;
    return AppRouter.dashboard;
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: ThemeController.instance,
      builder: (context, _) {
        final isDark = ThemeController.instance.isDark;
        return MaterialApp(
          title: 'FinMe',
          debugShowCheckedModeBanner: false,
          theme: finMeLightTheme(),
          darkTheme: finMeDarkTheme(),
          themeMode: isDark ? ThemeMode.dark : ThemeMode.light,
          initialRoute: _resolveInitialRoute(),
          onGenerateRoute: AppRouter.onGenerateRoute,
          navigatorObservers: [appRouteObserver],
        );
      },
    );
  }
}
