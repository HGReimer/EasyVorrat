import 'package:flutter/material.dart';

class EasyVorratColors {
  EasyVorratColors._();

  static const Color background = Color(0xFF0B0F0D);
  static const Color surface = Color(0xFF141A17);
  static const Color surfaceDark = Color(0xFF0F1411);

  static const Color green = Color(0xFF39FF6A);
  static const Color greenDim = Color(0xFF2A7A43);
  static const Color border = Color(0xFF31533C);

  static const Color textPrimary = Color(0xFFE8F5EB);
  static const Color textSecondary = Color(0xFFAAB8AE);

  static const Color warning = Color(0xFFE0B84A);
  static const Color danger = Color(0xFFFF4D4D);
}

final ThemeData easyVorratTheme = ThemeData(
  brightness: Brightness.dark,
  useMaterial3: true,
  scaffoldBackgroundColor: EasyVorratColors.background,
  colorScheme: const ColorScheme.dark(
    primary: EasyVorratColors.green,
    secondary: EasyVorratColors.greenDim,
    surface: EasyVorratColors.surface,
    error: EasyVorratColors.danger,
    onPrimary: Colors.black,
    onSurface: EasyVorratColors.textPrimary,
  ),
  appBarTheme: const AppBarTheme(
    backgroundColor: EasyVorratColors.surfaceDark,
    foregroundColor: EasyVorratColors.green,
    elevation: 0,
    centerTitle: false,
    titleTextStyle: TextStyle(
      fontSize: 21,
      fontWeight: FontWeight.bold,
      color: EasyVorratColors.green,
    ),
    shape: Border(
      bottom: BorderSide(
        color: EasyVorratColors.border,
      ),
    ),
  ),
  textTheme: const TextTheme(
    titleLarge: TextStyle(
      color: EasyVorratColors.textPrimary,
      fontWeight: FontWeight.bold,
    ),
    titleMedium: TextStyle(
      color: EasyVorratColors.textPrimary,
      fontWeight: FontWeight.w600,
    ),
    bodyLarge: TextStyle(
      color: EasyVorratColors.textPrimary,
    ),
    bodyMedium: TextStyle(
      color: EasyVorratColors.textPrimary,
    ),
    bodySmall: TextStyle(
      color: EasyVorratColors.textSecondary,
    ),
  ),
  cardTheme: CardThemeData(
    color: EasyVorratColors.surface,
    elevation: 0,
    margin: const EdgeInsets.symmetric(
      horizontal: 10,
      vertical: 5,
    ),
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(6),
      side: const BorderSide(
        color: EasyVorratColors.border,
      ),
    ),
  ),
  elevatedButtonTheme: ElevatedButtonThemeData(
    style: ElevatedButton.styleFrom(
      backgroundColor: EasyVorratColors.surface,
      foregroundColor: EasyVorratColors.green,
      padding: const EdgeInsets.symmetric(
        horizontal: 20,
        vertical: 14,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(6),
        side: const BorderSide(
          color: EasyVorratColors.greenDim,
        ),
      ),
    ),
  ),
  floatingActionButtonTheme: const FloatingActionButtonThemeData(
    backgroundColor: EasyVorratColors.green,
    foregroundColor: Colors.black,
  ),
  inputDecorationTheme: InputDecorationTheme(
    filled: true,
    fillColor: EasyVorratColors.surfaceDark,
    labelStyle: const TextStyle(
      color: EasyVorratColors.textSecondary,
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(6),
      borderSide: const BorderSide(
        color: EasyVorratColors.border,
      ),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(6),
      borderSide: const BorderSide(
        color: EasyVorratColors.green,
        width: 1.5,
      ),
    ),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(6),
    ),
  ),
  dividerTheme: const DividerThemeData(
    color: EasyVorratColors.border,
  ),
  iconTheme: const IconThemeData(
    color: EasyVorratColors.green,
  ),
);
