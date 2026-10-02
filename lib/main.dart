import 'package:flutter/material.dart';

import 'screens/home_screen.dart';
import 'services/db_init.dart';
import 'services/plus_service.dart';
import 'theme/easy_vorrat_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  initDatabaseFactory();
  await PlusService.instance.initialize();
  runApp(const EasyVorratApp());
}

class EasyVorratApp extends StatelessWidget {
  const EasyVorratApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'EasyVorrat',
      theme: easyVorratTheme,
      home: const HomeScreen(),
    );
  }
}
