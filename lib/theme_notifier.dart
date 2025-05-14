import 'package:flutter/material.dart';
import 'app_theme.dart';

class ThemeNotifier extends ChangeNotifier {
  static const Color _greenThemeColor = Color.fromARGB(255, 112, 169, 114);

  ThemeData _currentTheme = AppTheme.blueTheme;

  ThemeData get currentTheme => _currentTheme;

  void setTheme(String theme) {
    if (theme == 'Blue') {
      _currentTheme = ThemeData(
        primaryColor: AppTheme.primaryBlue,
        scaffoldBackgroundColor: AppTheme.backgroundColor,
        fontFamily: 'Roboto',
        textTheme: AppTheme.baseTextTheme,
        appBarTheme: AppBarTheme(
          backgroundColor: Colors.transparent,
          elevation: 0,
          titleTextStyle: TextStyle(fontFamily: 'Roboto', color: AppTheme.primaryTextColor),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: AppTheme.primaryBlue,
            foregroundColor: Colors.white,
          ),
        ),
      );
    } else if (theme == 'Green') {
      _currentTheme = ThemeData(
        primaryColor: _greenThemeColor,
        scaffoldBackgroundColor: AppTheme.backgroundColor,
        fontFamily: 'Roboto',
        textTheme: AppTheme.baseTextTheme,
        appBarTheme: AppBarTheme(
          backgroundColor: Colors.transparent,
          elevation: 0,
          titleTextStyle: TextStyle(fontFamily: 'Roboto', color: AppTheme.primaryTextColor),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.green[900],
            foregroundColor: Colors.white,
          ),
        ),
      );
    }
    notifyListeners();
  }

  // Load theme from preferences
  static String getThemeName(ThemeData theme) {
    if (theme.primaryColor == _greenThemeColor) {
      return 'Green';
    }
    return 'Blue'; // Default theme
  }
}
