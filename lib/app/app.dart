import 'package:flutter/material.dart';

import '../core/theme/app_theme.dart';
import 'router.dart';

class FinMeApp extends StatelessWidget {
  const FinMeApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'FinMe',
      debugShowCheckedModeBanner: false,
      theme: finMeLightTheme(),
      initialRoute: AppRouter.dashboard,
      routes: AppRouter.routes,
    );
  }
}
