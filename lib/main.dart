import 'package:flutter/material.dart';

import 'screens/home_screen.dart';
import 'services/db_init.dart';

void main() {
  initDatabaseFactory();
  runApp(const EasyVorratApp());
}

class EasyVorratApp extends StatelessWidget {
  const EasyVorratApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'EasyVorrat',
      theme: ThemeData(
        brightness: Brightness.dark,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF39FF6A),
          brightness: Brightness.dark,
        ),
        scaffoldBackgroundColor: const Color(0xFF07090A),
      ),
      home: const HomeScreen(),
    );
  }
}
