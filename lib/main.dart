import 'package:flutter/material.dart';

import 'app/app.dart';
import 'core/services/hive_init.dart';
import 'core/services/app_mode_controller.dart';
import 'core/services/theme_controller.dart';
import 'core/services/recurrence_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 1. Inicializa Hive e abre todos os boxes
  await HiveInit.init();

  // 2. Carrega preferências persistidas + gera recorrências pendentes em paralelo
  await Future.wait([
    AppModeController.instance.loadFromStorage(),
    ThemeController.instance.loadFromStorage(),
    RecurrenceService.generatePending(),
  ]);

  runApp(const FinMeApp());
}
