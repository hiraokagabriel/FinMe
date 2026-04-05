import 'package:flutter/material.dart';

import '../features/dashboard/presentation/dashboard_page.dart';
import 'router.dart';

class FinMeApp extends StatelessWidget {
  const FinMeApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'FinMe',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      initialRoute: AppRouter.dashboard,
      routes: AppRouter.routes,
    );
  }
}
