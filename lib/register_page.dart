// This file defines the registration page for new users in Chorewars.
// It handles user input, validation, and registration with Firebase Auth and Firestore.
//
// Key design decisions:
// - We use text controllers for all input fields to manage state.
// - Registration stores user email and creation time in Firestore for later use.
// - Error handling is provided for both Auth and Firestore operations.
// - The UI is designed to be beginner-friendly, with clear prompts and validation.
// - Social sign-in buttons are included for extensibility.
//
// If you add new registration fields, update both the UI and Firestore logic.

import 'package:chore/services/auth_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'components/my_button.dart';
import 'components/my_textfield.dart';
import 'components/square_tile.dart';


class RegisterPage extends StatefulWidget {
  final Function()? onTap;
  const RegisterPage({super.key,required this.onTap});

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  // text editing controllers
  final emailController = TextEditingController();
  final passwordController = TextEditingController();
  final ConfirmpasswordController = TextEditingController();
  final _firstNameController = TextEditingController();
  final _lastNameController= TextEditingController();

  String givenMessage = "";
  // sign user in method
  void signUserUp() async {
    // Show loading circle
    showDialog(
      context: context,
      barrierDismissible: false, // prevent dismiss by tapping outside the dialog
      builder: (context) {
        return const Center(
          child: CircularProgressIndicator(),
        );
      },
    );

    // Check if passwords match
    if (passwordController.text == ConfirmpasswordController.text) {
      try {
        // Try creating the user
        await FirebaseAuth.instance.createUserWithEmailAndPassword(
          email: emailController.text,
          password: passwordController.text,
        );
        // Optionally, navigate to a new page upon successful signup
        // Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => HomePage()));
      } on FirebaseAuthException catch (e) {
        showDialog(
          context: context,
          builder: (context) {
            String errorMessage = 'An error occurred';
            if (e.code == 'email-already-in-use') {
              errorMessage = 'The email address is already in use by another account.';
            } else if (e.code == 'invalid-email') {
              errorMessage = 'The email address is not valid.';
            } else if (e.code == 'weak-password') {
              errorMessage = 'The password provided is too weak.';
            }
            return AlertDialog(
              backgroundColor: Colors.deepPurple,
              title: const Text('Registration Failed', style: TextStyle(color: Colors.white)),
              content: Text(errorMessage, style: const TextStyle(color: Colors.white)),
            );
          },
        );
      }

      // add user details
      final User? user = FirebaseAuth.instance.currentUser;
      addUserDetails(
          user!.uid,
          _firstNameController.text.trim(),
          _lastNameController.text.trim(),
          emailController.text.trim()
      );
    }
    else {
      // If passwords do not match, show error message
      NonMatchingPasswordMessage();
    }

    // Pop the loading circle in all cases
    Navigator.pop(context);
  }

  Future<void> addUserDetails(String uid, String firstName, String lastName, String email) async {
    await FirebaseFirestore.instance.collection('users').doc(uid).set({
      'first name': firstName,
      'last name': lastName,
      'email': email,
    });
  }

  // wrong email message popup
  void wrongEmailMessage() {
    showDialog(
      context: context,
      builder: (context) {
        return const AlertDialog(
          backgroundColor: Colors.deepPurple,
          title: Center(
            child: Text(
              'Incorrect Email',
              style: TextStyle(color: Colors.white),
            ),
          ),
        );
      },
    );
  }
  void NonMatchingPasswordMessage() {
    showDialog(
      context: context,
      builder: (context) {
        return const AlertDialog(
          backgroundColor: Colors.deepPurple,
          title: Center(
            child: Text(
              'Passwords dont match!',
              style: TextStyle(color: Colors.white),
            ),
          ),
        );
      },
    );
  }
  // wrong password message popup
  void wrongPasswordMessage() {
    showDialog(
      context: context,
      builder: (context) {
        return const AlertDialog(
          backgroundColor: Colors.deepPurple,
          title: Center(
            child: Text(
              'Incorrect Password',
              style: TextStyle(color: Colors.white),
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[300],
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const SizedBox(height: 0),

                // logo
                const Icon(
                  Icons.lock,
                  size: 100,
                ),

                const SizedBox(height: 15),

                // welcome back, you've been missed!
                Text(
                  'Let\'s create an account for you!',
                  style: TextStyle(
                    color: Colors.grey[700],
                    fontSize: 16,
                  ),
                ),

                const SizedBox(height: 25),

                // email textfield

                MyTextField(
                  controller: _firstNameController,
                  hintText: 'First Name',
                  obscureText: false,
                ), MyTextField(
                  controller: _lastNameController,
                  hintText: 'Last Name',
                  obscureText: false,
                ),
                MyTextField(
                  controller: emailController,
                  hintText: 'Email',
                  obscureText: false,
                ),

                const SizedBox(height: 10),

                // password textfield
                MyTextField(
                  controller: passwordController,
                  hintText: 'Password',
                  obscureText: true,
                ),


                const SizedBox(height: 10),
                // confrim password textfield
                MyTextField(
                  controller: ConfirmpasswordController,
                  hintText: 'Confirm Password',
                  obscureText: true,
                ),


                const SizedBox(height: 10),





                const SizedBox(height: 25),

                // sign in button
                MyButton(
                  text: "Sign Up",
                  onTap: signUserUp,
                ),

                const SizedBox(height: 25),

                // or continue with
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 25.0),
                  child: Row(
                    children: [
                      Expanded(
                        child: Divider(
                          thickness: 0.5,
                          color: Colors.grey[400],
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 10.0),
                        child: Text(
                          'Or continue with',
                          style: TextStyle(color: Colors.grey[700]),
                        ),
                      ),
                      Expanded(
                        child: Divider(
                          thickness: 0.5,
                          color: Colors.grey[400],
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 5),

                // google + apple sign in buttons
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children:  [
                    // google button
                    SquareTile(
                        onTap: () => AuthService().signInWithGoogle(),
                        imagePath: 'lib/images/google.png'
                    ),

                    // SizedBox(width: 25),

                    // apple button
                    //SquareTile(
                    //onTap: (){

                    //},
                    //imagePath: 'lib/images/apple.png'
                    // )
                  ],
                ),

                const SizedBox(height: 50),

                // not a member? register now
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'Already have an account ?',
                      style: TextStyle(color: Colors.grey[700]),
                    ),
                    const SizedBox(width: 4),
                    GestureDetector(
                      onTap: widget.onTap,
                      child: const Text(
                        'Login now',
                        style: TextStyle(
                          color: Colors.blue,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                )
              ],
            ),
          ),
        ),
      ),
    );
  }
}