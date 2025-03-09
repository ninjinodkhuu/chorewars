import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz;

class LocalNotificationService {
  static final _notificationsPlugin = FlutterLocalNotificationsPlugin();
  
  static void initialize() {
    InitializationSettings initializationSettingsAndroid = const InitializationSettings(
      android: AndroidInitializationSettings("@drawable/ic_launcher"),
      iOS: DarwinInitializationSettings(),
    );
    
    _notificationsPlugin.initialize(
      initializationSettingsAndroid,
      onDidReceiveNotificationResponse: (details) {
        if (details.input != null) {}
      },
    );
    tz.initializeTimeZones();
  }

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

  static void cancelTaskReminder(String taskId) {
    int notificationId = taskId.hashCode;
    _notificationsPlugin.cancel(notificationId);
  }

  static Future<void> sendExpenseNotification(double amount, String category) async {
    await _notificationsPlugin.show(
      0, 
      'Expense Added', 
      'An expense of \$${amount.toStringAsFixed(2)} was added in $category.', 
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'expense_updates', 
          'Expense Updates',
          channelDescription: 'Notifications for new expenses',
          importance: Importance.high,
          priority: Priority.high,
        ),
        iOS: DarwinNotificationDetails(),
      ),
      payload: 'expense_update', 
    );
  }
}

