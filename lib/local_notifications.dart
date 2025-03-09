import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz;

class LocalNotificationService {
  static final _notificationsPlugin = FlutterLocalNotificationsPlugin();
  
  // Initialize notifications plugin
  static void initialize() {
    InitializationSettings initializationSettingsAndroid = const InitializationSettings(
      android: AndroidInitializationSettings("@drawable/ic_launcher"),
      iOS: DarwinInitializationSettings(),
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
      ),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      payload: taskId, 
      uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
    );
  }

  // Cancels a scheduled task reminder
  static void cancelTaskReminder(String taskId) {
    int notificationId = taskId.hashCode;
    _notificationsPlugin.cancel(notificationId);
  }

  // Shows expense notification
  static Future<void> sendExpenseNotification(double amount, String category) async {
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
}

