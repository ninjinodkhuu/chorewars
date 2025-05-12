// =========================
// auth_page.dart
// =========================
// This file handles user authentication state and routes users to the correct page.
// If the user is logged in, it shows the HomePage. If not, it shows the login/register page.

// Import required packages and pages
import 'home_page.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'LoginOrRegisterPage.dart';

// AuthPage checks if the user is logged in or not
class AuthPage extends StatelessWidget {
  const AuthPage({super.key});

  @override
  Widget build(BuildContext context) {
    // Use StreamBuilder to listen for auth state changes
    return Scaffold(
      body: StreamBuilder<User?>(
        // Listen to authentication state changes
        stream: FirebaseAuth.instance.authStateChanges(),
        builder: (context, snapshot) {
          // If user is logged in (auth state has data)
          if (snapshot.hasData) {
            return const HomePage();
          }
          // If user is NOT logged in (no auth data)
          else {
            return const LoginOrRegisterPage();
          }
        },
      ),
    );
  }
}
// End of auth_page.dart
