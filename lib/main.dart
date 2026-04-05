import 'package:flutter/material.dart';

import 'app/app.dart';
import 'core/services/hive_init.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await HiveInit.init();
  runApp(const FinMeApp());
}
