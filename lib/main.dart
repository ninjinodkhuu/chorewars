import 'package:expenses_tracker/auth_page.dart';
import 'package:expenses_tracker/local_notifications.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:firebase_messaging/firebase_messaging.dart';

// This function will be called when a background message is received
Future<void> _initFCM() async {
  // Ask for user permission to receive notifications
  await FirebaseMessaging.instance.requestPermission();
  // Determine user householdID
  final user = FirebaseAuth.instance.currentUser;
  if (user == null) return; // User is not logged in
  final userDoc = await FirebaseFirestore.instance
      .collection('users')
      .doc(user.uid)
      .get();
  final householdID = userDoc.get('householdID') as String;

  // Subscribe THIS device to the “householdID” topic
  await FirebaseMessaging.instance.subscribeToTopic(householdID);}

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

  // Enable Firestore offline persistence
  FirebaseFirestore.instance.settings = const Settings(persistenceEnabled: true);
  
  tz.initializeTimeZones();
  LocalNotificationService.initialize();
  await _initFCM();
  
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
