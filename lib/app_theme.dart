import 'package:flutter/material.dart';
import 'constants.dart'; // Import constants file

abstract final class AppTheme {
  // The light mode ThemeData.
  static ThemeData light = ThemeData(
    brightness: Brightness.light,
    primaryColor: lightPrimaryColor,
    primaryColorLight: lightPrimaryLightColor,
    primaryColorDark: lightPrimaryDarkColor,
    colorScheme: const ColorScheme.light(
      primary: lightPrimaryColor,
      secondary: lightSecondaryColor,
      onPrimary: lightButtonTextColor,
      onSecondary: lightIconColor,
      surface: lightBackgroundColor,
      onSurface: lightHeaderColor,
      
    ),
    scaffoldBackgroundColor: lightBackgroundColor,
    buttonTheme: const ButtonThemeData(
      buttonColor: lightButtonColor,
      textTheme: ButtonTextTheme.primary,
    ),
    iconTheme: const IconThemeData(color: lightIconColor),
    textTheme: const TextTheme(

    ),
    inputDecorationTheme: const InputDecorationTheme(
      border: OutlineInputBorder(
        borderSide: BorderSide(color: lightBorderColor),
      ),
    ),
    dividerTheme: const DividerThemeData(
      color: lightBorderColor,
    ),
    cardColor: lightPrimaryLightColor, // Card background coloror color defined here
    appBarTheme: const AppBarTheme(
      backgroundColor: lightPrimaryColor,
      titleTextStyle: lightHeaderTextStyle,
    ),
  );

  // The dark mode ThemeData.
  static ThemeData dark = ThemeData(
    brightness: Brightness.dark,
    primaryColor: darkPrimaryColor,
    primaryColorLight: darkPrimaryLightColor,
    primaryColorDark: darkPrimaryDarkColor,
    colorScheme: const ColorScheme.dark(
      primary: darkPrimaryColor,
      secondary: darkSecondaryColor,
      onPrimary: darkButtonTextColor,
      onSecondary: darkIconColor,
      surface: darkBackgroundColor,
      onSurface: darkHeaderColor,
    ),
    scaffoldBackgroundColor: darkBackgroundColor,
    buttonTheme: const ButtonThemeData(
      buttonColor: darkButtonColor,
      textTheme: ButtonTextTheme.primary,
    ),
    iconTheme: const IconThemeData(color: darkIconColor),
    textTheme: const TextTheme(

    ),
    inputDecorationTheme: const InputDecorationTheme(
      border: OutlineInputBorder(
        borderSide: BorderSide(color: darkBorderColor),
      ),
    ),
    dividerTheme: const DividerThemeData(
      color: darkBorderColor,
    ),
    cardColor: darkPrimaryDarkColor, // Card background colo
    appBarTheme: const AppBarTheme(
      backgroundColor: darkPrimaryColor,
      titleTextStyle: darkHeaderTextStyle,
    ),
  );
}
