import 'package:flutter/material.dart';

class AppTheme {
  // Custom color definitions
  static const Color backgroundColor = Color(0xFFFCF8F4); // #FCF8F4
  static const Color primaryBlue = Color(0xFF6994d5); // #0054C5
  static const Color primaryTextColor = Color(0xFF20201F); // #20201F

  static const TextTheme baseTextTheme = TextTheme(
    bodyLarge: TextStyle(fontFamily: 'Roboto', color: primaryTextColor),
    bodyMedium: TextStyle(fontFamily: 'Roboto', color: primaryTextColor),
    bodySmall: TextStyle(fontFamily: 'Roboto', color: primaryTextColor),
    titleLarge: TextStyle(fontFamily: 'Roboto', color: primaryTextColor, fontSize: 22, fontWeight: FontWeight.bold),
    titleMedium: TextStyle(fontFamily: 'Roboto', color: primaryTextColor, fontSize: 18, fontWeight: FontWeight.w500),
    titleSmall: TextStyle(fontFamily: 'Roboto', color: primaryTextColor, fontSize: 16, fontWeight: FontWeight.w500),
    labelLarge: TextStyle(fontFamily: 'Roboto', color: Colors.white, fontSize: 16, fontWeight: FontWeight.w500),
  );

  static final ThemeData blueTheme = ThemeData(
    primaryColor: primaryBlue,
    scaffoldBackgroundColor: backgroundColor,
    fontFamily: 'Roboto',
    textTheme: baseTextTheme,
    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.transparent,
      elevation: 0,
      titleTextStyle: TextStyle(fontFamily: 'Roboto', color: primaryTextColor),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: primaryBlue,
        foregroundColor: Colors.white,
      ),
    ),
  );

  static final ThemeData greenTheme = ThemeData(
    primaryColor: const Color.fromARGB(255, 112, 169, 114),
    scaffoldBackgroundColor: backgroundColor,
    fontFamily: 'Roboto',
    textTheme: baseTextTheme,
    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.transparent,
      elevation: 0,
      titleTextStyle: TextStyle(fontFamily: 'Roboto', color: primaryTextColor),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.green[900],
        foregroundColor: Colors.white,
      ),
    ),
  );
}