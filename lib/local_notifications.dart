import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

class LocalNotificationService {
  static final _notificationsPlugin = FlutterLocalNotificationsPlugin();
  
  // Initialize notifications plugin
  static void initialize() {
    const AndroidInitializationSettings androidSettings = AndroidInitializationSettings("@drawable/ic_launcher");
    const DarwinInitializationSettings iosSettings = DarwinInitializationSettings();
    const WindowsInitializationSettings windowsSettings = WindowsInitializationSettings(
      appName: 'Chorewars',
      appUserModelId: '8e0f7a12-bfb3-4fe8-b9a5-48fd50a15a9a',
      guid: 'ad0dbfaa-c7ea-4f5e-8bbe-caf269b4170c',
    );
    
    InitializationSettings initializationSettingsAndroid = const InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
      windows: windowsSettings,
    );
    
    // Initialize plugin with settings and a callback for when notifications are tapped
    _notificationsPlugin.initialize(
      initializationSettingsAndroid,
      onDidReceiveNotificationResponse: (details) {
        if (details.input != null) {}
      },
    );
    tz.initializeTimeZones();
  }

  // Schedules task reminder notification
  static Future<void> scheduleTaskReminder(String taskId, String taskName, DateTime dueDate, int leadTimeDays) async {
    // Check if the platform is web and show a snackbar instead of a notification
    if (kIsWeb) {
      print('[Web Stub] schedule reminder for task: $taskName, due in $leadTimeDays days');
      return;
    }

    final scheduledTime = tz.TZDateTime.from(dueDate.subtract(Duration(days: leadTimeDays)), tz.local);
    await _notificationsPlugin.zonedSchedule(
      taskId.hashCode, 
      'Task Reminder', 
      'Your task "$taskName" is due in $leadTimeDays days(s)!', 
      scheduledTime, 
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'task_reminders', 
          'Task Reminders',
          channelDescription: 'Reminder notifications for tasks',
          importance: Importance.max,
          priority: Priority.high,
        ),
        iOS: DarwinNotificationDetails(),
        windows: WindowsNotificationDetails(),
      ),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      payload: taskId, 
    );
  }

  // Cancels a scheduled task reminder
  static void cancelTaskReminder(String taskId) {
    // Check if the platform is web and show a snackbar instead of a notification
    if (kIsWeb) {
      print('[Web Stub] cancel reminder for task: $taskId');
      return;
    }

    int notificationId = taskId.hashCode;
    _notificationsPlugin.cancel(notificationId);
  }

  // Shows expense notification
  static Future<void> sendExpenseNotification(double amount, String category) async {
    if (kIsWeb) {
      // Show a snackbar instead of a notification
      print('[Web Notification] Expense Added: \$$amount in $category');
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ScaffoldMessenger.maybeOf(navigatorKey.currentContext!)
            ?.showSnackBar(SnackBar(
              content: Text('Expense Added: \$${amount.toStringAsFixed(2)} in $category'),
              duration: const Duration(seconds: 3),
            ));
      });
      return;
    }
    await _notificationsPlugin.show(
      0, 
      'Expense Added',  // title
      'An expense of \$${amount.toStringAsFixed(2)} was added in $category.', 
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'expense_updates',  // channel id
          'Expense Updates',  // channel name
          channelDescription: 'Notifications for new expenses',
          importance: Importance.high,
          priority: Priority.high,
        ),
        iOS: DarwinNotificationDetails(),
      ),
      payload: 'expense_update',  // helps handle notification tap
    );
  }

  // Shows task notification
  static Future<void> sendTaskNotification({
    required String title,
    required String body,
    String? payload,
  }) async {
    // Check if the platform is web and show a snackbar instead of a notification
    if (kIsWeb) {
      // Show a snackbar instead of a notification
      print('[Web Notification] $title: $body');
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ScaffoldMessenger.maybeOf(navigatorKey.currentContext!)
            ?.showSnackBar(SnackBar(
              content: Text('$title: $body'),
              duration: const Duration(seconds: 3),
            ));
      });
      return;
    }

    await _notificationsPlugin.show(
      title.hashCode,  // unique id for the notification
      title,  // title of the notification
      body,  // body of the notification
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'task_events',  // channel id
          'Task Events',  // channel name
          channelDescription: "Notifications for task events",
          importance: Importance.high,
          priority: Priority.high,
        ),
        iOS: DarwinNotificationDetails(),
        windows: WindowsNotificationDetails(),
      ),
      payload: payload,  // helps handle notification tap
    );
  }

  // Schedule shopping reminders - daily shopping list summary
  static Future<void> scheduleShoppingReminder({
    required String householdID,
    required String userID,
    required int hour,
    required int minute,
  }) async {
    if (kIsWeb) {
      print('[Web Stub] schedule shopping reminder for household: $householdID, user: $userID at $hour:$minute');
      return;
    }

    final snap = await FirebaseFirestore.instance
        .collection('household')
        .doc(householdID)
        .collection('members')
        .doc(userID)
        .collection('shopping_list')
        .where('done', isEqualTo: false)
        .get();
    final count =snap.docs.length;

    final now = tz.TZDateTime.now(tz.local);
    var scheduledTime = tz.TZDateTime(
      tz.local,
      now.year,
      now.month,
      now.day,
      hour,
      minute,
    );
    if (scheduledTime.isBefore(now)) {
      scheduledTime = scheduledTime.add(const Duration(days: 1));
    }

    await _notificationsPlugin.zonedSchedule(
      1000, 
      'Shopping Reminder', 
      count > 0 
        ? 'You have $count items in your shopping list.' 
        : 'Your shopping list is empty.', 
      scheduledTime, 
      NotificationDetails(
        android: AndroidNotificationDetails(
          'shopping_reminders', 
          'Shopping Reminders',
          channelDescription: 'Notifications for shopping reminders',
          importance: Importance.max,
          priority: Priority.high,
        ),
        iOS: DarwinNotificationDetails(),
        windows: WindowsNotificationDetails(),
      ),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      matchDateTimeComponents: DateTimeComponents.time,
      payload: 'shopping_reminder',
    );
  }

  // Cancel shopping reminders
  static Future<void> cancelShoppingReminder() async {
    if (kIsWeb) {
      print('[Web Stub] cancel shopping reminder');
      return;
    }
    await _notificationsPlugin.cancel(1000);
  }

  // Notification for shopping list item added
  static Future<void> sendShoppingItemAddedNotification(String itemName) async {
    if (kIsWeb) {
      print('[Web Stub] Shopping item added: $itemName');
      return;
    }

    await _notificationsPlugin.show(
      // Use the hash of the name so each item gets a unique ID
      itemName.hashCode,
      'Item Added',
      'You added "$itemName" to your shopping list.',
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'shopping_item_added', 
          'Shopping Item Added',
          channelDescription: 'Notifications when you add a new shopping item',
          importance: Importance.high,
          priority: Priority.high,
        ),
        iOS: DarwinNotificationDetails(),
        windows: WindowsNotificationDetails(),
      ),
      payload: 'shopping_added',
    );
  }
}

