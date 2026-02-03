import 'package:flutter/material.dart';
import 'constants.dart';

ThemeData buildLightTheme() {
  final colorScheme = ColorScheme.fromSeed(
    seedColor: kPrimaryGreen,
    brightness: Brightness.light,
  );
  return ThemeData(
    colorScheme: colorScheme,
    useMaterial3: true,
    appBarTheme: const AppBarTheme(centerTitle: true),
    scaffoldBackgroundColor: colorScheme.surface,
    inputDecorationTheme: const InputDecorationTheme(
      border: OutlineInputBorder(),
    ),
  );
}

ThemeData buildDarkTheme() {
  final colorScheme = ColorScheme.fromSeed(
    seedColor: kPrimaryGreen,
    brightness: Brightness.dark,
  );
  return ThemeData(
    colorScheme: colorScheme,
    useMaterial3: true,
    appBarTheme: const AppBarTheme(centerTitle: true),
    scaffoldBackgroundColor: colorScheme.surface,
    inputDecorationTheme: const InputDecorationTheme(
      border: OutlineInputBorder(),
    ),
  );
}
