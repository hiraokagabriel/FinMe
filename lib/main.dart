import 'package:flutter/material.dart';

import 'app/app.dart';
import 'core/services/hive_init.dart';
import 'core/services/app_mode_controller.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await HiveInit.init();
  await AppModeController.instance.loadFromStorage();
  runApp(const FinMeApp());
}
