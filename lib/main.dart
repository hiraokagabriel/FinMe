import 'package:flutter/material.dart';

import 'app/app.dart';
import 'core/services/hive_init.dart';
import 'core/services/app_mode_controller.dart';
import 'core/services/theme_controller.dart';
import 'core/services/recurrence_service.dart';
import 'core/services/profile_service.dart';
import 'core/services/default_seed_service.dart';
import 'core/services/auth_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 1. Registra adapters, abre boxes globais e executa migrações
  await HiveInit.init();

  // 2. Restaura sessão de login (sem abrir boxes de dados ainda)
  await AuthService.instance.loadFromStorage();

  // 3. Só abre boxes e inicializa repositórios se houver login ativo
  if (AuthService.instance.isAuthenticated) {
    await ProfileService.instance.loadFromStorage();
    await DefaultSeedService.instance.seedIfEmpty();
    await Future.wait([
      AppModeController.instance.loadFromStorage(),
      ThemeController.instance.loadFromStorage(),
      RecurrenceService.generatePending(),
    ]);
  } else {
    // Carrega preferências mesmo sem login (tema, modo)
    await Future.wait([
      AppModeController.instance.loadFromStorage(),
      ThemeController.instance.loadFromStorage(),
    ]);
  }

  // 4. Onboarding
  final showOnboarding = !HiveInit.isOnboardingDone();

  runApp(FinMeApp(showOnboarding: showOnboarding));
}
