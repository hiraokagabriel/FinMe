import 'package:flutter/widgets.dart';

import 'app/app.dart';
import 'app/boot_screen.dart';
import 'app/bootstrap.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const BootScreen());
  try {
    final services = await bootstrap();
    runApp(FinMeApp(services: services));
  } catch (e) {
    runApp(BootErrorScreen(error: e));
  }
}
