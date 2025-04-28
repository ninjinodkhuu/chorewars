import 'auth_page.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  FirebaseOptions options = const FirebaseOptions(
    apiKey: "AIzaSyA_9SV39BIwuOQULX_mUp0w3c2KdEU5oJ8",
    appId: "1:13701743979:android:1b0281e61059ce0eb0b82e",
    projectId: "flutter-expense-tracker-a6400",
    messagingSenderId: "13701743979",
    storageBucket: "flutter-expense-tracker-a6400.firebasestorage.app",
  );
  await Firebase.initializeApp(options: options);
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      themeMode: ThemeMode.system, // Use system theme mode to switch between light and dark themes
      theme: ThemeData(
        brightness: Brightness.light,
        primarySwatch: Colors.blue,
        scaffoldBackgroundColor: Colors.blue[25],
        cardColor: Colors.white,
        dividerColor: Colors.grey[300],
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.transparent,
          elevation: 0,
        ),
        textTheme: const TextTheme(
          bodyLarge: TextStyle(color: Colors.black),
          bodyMedium: TextStyle(color: Colors.black87),
          bodySmall: TextStyle(color: Colors.black54),
        ),
      ),
      darkTheme: ThemeData(
        brightness: Brightness.dark,
        primarySwatch: Colors.blue,
        scaffoldBackgroundColor: const Color.fromARGB(255, 49, 34, 82),
        cardColor: const Color.fromARGB(255, 159, 132, 186),
        dividerColor: Colors.grey,
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.transparent,
          elevation: 0,
        ),
        textTheme: const TextTheme(
          bodyLarge: TextStyle(color: Color.fromARGB(255, 255, 255, 255)),
          bodyMedium: TextStyle(color: Color.fromARGB(179, 255, 255, 255)),
          bodySmall: TextStyle(color: Color.fromARGB(134, 255, 255, 255)),
        ),
      ),
      home: const AuthPage(),
    );
  }
}
