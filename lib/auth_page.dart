// Import required packages and pages
import 'home_page.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'LoginOrRegisterPage.dart';

/// Authentication page that handles user session state
/// Routes to either HomePage or LoginOrRegisterPage based on auth state
class AuthPage extends StatelessWidget {
  const AuthPage({super.key});

  @override
  Widget build(BuildContext context) {
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
