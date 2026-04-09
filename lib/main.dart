import 'package:flutter/material.dart';

import 'app/app.dart';
import 'core/services/hive_init.dart';
import 'core/services/app_mode_controller.dart';
import 'core/services/theme_controller.dart';
import 'core/services/recurrence_service.dart';
import 'core/services/profile_service.dart';
import 'core/services/default_seed_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 1. Registra adapters e abre boxes globais (settings, preferences)
  await HiveInit.init();

  // 2. Carrega perfil ativo, abre boxes com namespace e inicializa RepositoryLocator
  await ProfileService.instance.loadFromStorage();

  // 3. Seed mínimo para o perfil default (idempotente)
  await DefaultSeedService.instance.seedIfEmpty();

  // 4. Carrega preferências + gera recorrências em paralelo
  await Future.wait([
    AppModeController.instance.loadFromStorage(),
    ThemeController.instance.loadFromStorage(),
    RecurrenceService.generatePending(),
  ]);

  // 5. Onboarding
  final showOnboarding = !HiveInit.isOnboardingDone();

  runApp(FinMeApp(showOnboarding: showOnboarding));
}
