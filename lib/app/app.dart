import 'package:flutter/material.dart';

import '../core/services/theme_controller.dart';
import '../core/theme/app_theme.dart';
import 'router.dart';

class FinMeApp extends StatelessWidget {
  const FinMeApp({super.key});

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
          initialRoute: AppRouter.dashboard,
          routes: AppRouter.routes,
        );
      },
    );
  }
}
