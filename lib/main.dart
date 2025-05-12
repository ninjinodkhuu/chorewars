// This is the main entry point for the Chorewars Flutter app.
// It handles all global initialization, including Firebase, notifications, and app-wide services.
//
// Key design decisions:
// - We use a try-catch block to ensure any initialization error is surfaced to the user.
// - All async setup (Firebase, Firestore, notifications) is awaited before runApp.
// - Notification and FCM setup is separated into helper functions for clarity.
// - The app uses a global navigator key for navigation from notifications.
// - If initialization fails, a fallback error UI is shown.
//
// If you add new global services, initialize them here before runApp.

// Import the authentication page and required Flutter/Firebase packages
import 'auth_page.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'local_notifications.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:firebase_messaging/firebase_messaging.dart';

// Global navigator key for accessing navigator from anywhere
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

// Background message handler for Firebase Cloud Messaging
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // Initialize Firebase if not already initialized
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  tz.initializeTimeZones();
  LocalNotificationService.initialize();

  // If there's a notification, show it
  final notif = message.notification;
  final title = notif?.title ?? "Background Notification";
  final body = notif?.body ?? "You have a new message";

  // Local notification
  await LocalNotificationService.sendTaskNotification(
    title: title,
    body: body,
    payload: message.data['taskId'] ?? '',
  );

  // Log the message here
  print("Handling a background message: ${message.messageId}");
}

// Function to initialize FCM and subscribe to household topic
Future<void> _initFCM() async {
  await FirebaseMessaging.instance.requestPermission();
  final user = FirebaseAuth.instance.currentUser;
  if (user == null) return; // User not logged in
  final userDoc =
      await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
  if (!userDoc.exists || !userDoc.data()!.containsKey('householdID')) {
    print(
        'User document missing or householdID not set. Skipping topic subscription.');
    return;
  }
  final householdID = userDoc.get('householdID') as String;
  await FirebaseMessaging.instance.subscribeToTopic(householdID);
}

// Foreground message handling
void _initFCMListeners() {
  FirebaseMessaging.onMessage.listen((RemoteMessage message) {
    final notification = message.notification;
    final title = notification?.title ?? 'New Notification';
    final body = notification?.body ?? 'You have a new message';

    LocalNotificationService.sendTaskNotification(
      title: title,
      body: body,
      payload: message.data['taskId'] ?? '',
    );
  });
}

/// Entry point of the application
/// Initializes Firebase and starts the app
void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    FirebaseOptions options = const FirebaseOptions(
      apiKey: "AIzaSyA_9SV39BIwuOQULX_mUp0w3c2KdEU5oJ8",
      appId: "1:13701743979:android:1b0281e61059ce0eb0b82e",
      projectId: "flutter-expense-tracker-a6400",
      messagingSenderId: "13701743979",
      storageBucket: "flutter-expense-tracker-a6400.firebasestorage.app",
    );

    await Firebase.initializeApp(options: options);
    FirebaseFirestore.instance.settings =
        const Settings(persistenceEnabled: true);
    NotificationSettings settings =
        await FirebaseMessaging.instance.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      provisional: false,
    );
    print('User granted permission: ${settings.authorizationStatus}');
    await FirebaseMessaging.instance
        .setForegroundNotificationPresentationOptions(
      alert: true,
      badge: true,
      sound: true,
    );
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
    tz.initializeTimeZones();
    await LocalNotificationService.initialize();
    await _initFCM();
    _initFCMListeners();
    runApp(const MyApp());
  } catch (e, stack) {
    print('Initialization error: $e');
    print(stack);
    runApp(MaterialApp(
      home: Scaffold(
        body: Center(child: Text('Initialization failed: $e')),
      ),
    ));
  }
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
