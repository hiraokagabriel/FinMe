import 'package:flutter/material.dart';

import '../core/models/app_settings.dart';
import '../core/theme/app_theme.dart';
import '../features/onboarding/presentation/onboarding_page.dart';
import 'app_scope.dart';
import 'home_shell.dart';

class FinMeApp extends StatelessWidget {
  const FinMeApp({super.key, required this.services});

  final AppServices services;

  @override
  Widget build(BuildContext context) {
    return AppScope(
      services: services,
      child: ListenableBuilder(
        listenable: services.settings,
        builder: (context, _) {
          final settings = services.settings.value;
          return MaterialApp(
            debugShowCheckedModeBanner: false,
            title: 'FinMe',
            theme: AppTheme.light(),
            darkTheme: AppTheme.dark(),
            themeMode: switch (settings.theme) {
              ThemePreference.system => ThemeMode.system,
              ThemePreference.light => ThemeMode.light,
              ThemePreference.dark => ThemeMode.dark,
            },
            // Trocar `home` não reconstrói a rota inicial: o filho observa as configurações.
            home: ListenableBuilder(
              listenable: services.settings,
              builder: (context, _) => services.settings.value.onboardingDone
                  ? const HomeShell()
                  : const OnboardingPage(),
            ),
          );
        },
      ),
    );
  }
}
