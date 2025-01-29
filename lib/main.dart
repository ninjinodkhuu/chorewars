import 'package:expenses_tracker/auth_page.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  FirebaseOptions options = FirebaseOptions(
    apiKey: "AIzaSyA_9SV39BIwuOQULX_mUp0w3c2KdEU5oJ8",
    appId: "1:13701743979:android:1b0281e61059ce0eb0b82e",
    projectId: "flutter-expense-tracker-a6400",
    messagingSenderId: "13701743979",
    storageBucket: "flutter-expense-tracker-a6400.firebasestorage.app",
  );
  await Firebase.initializeApp(options: options);
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: AuthPage(),
    );
  }
}
