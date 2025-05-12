// =========================
// LoginOrRegisterPage.dart
// =========================
// This file provides a simple toggle between the login and registration screens for Chorewars.
//
// Key design decisions:
// - Uses a boolean state to switch between LoginPage and RegisterPage widgets.
// - Designed for clarity and ease of navigation for new users.
//
// Contributor notes:
// - If you add new authentication flows, update the toggle logic here.
// - Keep comments up to date for onboarding new contributors.

import 'register_page.dart';
import 'package:flutter/material.dart';
import 'login_page.dart';

class LoginOrRegisterPage extends StatefulWidget {
  const LoginOrRegisterPage({super.key});

  @override
  State<LoginOrRegisterPage> createState() => _LoginOrRegisterPageState();
}

class _LoginOrRegisterPageState extends State<LoginOrRegisterPage> {
  //initially show login page
  bool showLoginPage = true;
  void togglePages() {
    setState(() {
      showLoginPage = !showLoginPage;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (showLoginPage) {
      return LoginPage(
        onTap: togglePages,
      );
    } else {
      return RegisterPage(
        onTap: togglePages,
      );
    }
  }
}
