// Import the authentication page and required Flutter/Firebase packages
import 'package:chore/auth_page.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';

/// Entry point of the application
/// Initializes Firebase and starts the app
void main() async {
  // Ensure Flutter bindings are initialized
  WidgetsFlutterBinding.ensureInitialized();

  // Configure Firebase options with your project credentials
  FirebaseOptions options = const FirebaseOptions(
    apiKey: "AIzaSyA_9SV39BIwuOQULX_mUp0w3c2KdEU5oJ8",
    appId: "1:13701743979:android:1b0281e61059ce0eb0b82e",
    projectId: "flutter-expense-tracker-a6400",
    messagingSenderId: "13701743979",
    storageBucket: "flutter-expense-tracker-a6400.firebasestorage.app",
  );

  // Initialize Firebase with the specified options
  await Firebase.initializeApp(options: options);

  // Start the application by running MyApp
  runApp(const MyApp());
}

/// Root widget of the application
/// Sets up the MaterialApp and initial route
class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      debugShowCheckedModeBanner: false, // Hide debug banner
      home: AuthPage(), // Set AuthPage as the initial screen
    );
  }
}
