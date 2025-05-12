// =========================
// test_notifications.dart
// =========================
// This file provides a simple UI for testing local notification features in Chorewars.
// It allows developers to trigger various notification types for testing purposes.
//
// Key design decisions:
// - Integrates with LocalNotificationService for scheduling and sending notifications.
// - Each test function triggers a different notification scenario (reminder, assignment, completion, etc.).
//
// Contributor notes:
// - This file is for development/testing only and not part of the main app flow.
// - Use as a reference for notification logic and integration.
// - Keep comments up to date for onboarding new contributors.

import 'package:flutter/material.dart';
import 'local_notifications.dart';

class TestNotifications extends StatelessWidget {
  const TestNotifications({super.key});

  Future<void> _testTaskReminder() async {
    await LocalNotificationService.scheduleTaskReminder('test_task_1',
        'Test Task', DateTime.now().add(const Duration(seconds: 5)), 1);
  }

  Future<void> _testTaskAssignment() async {
    await LocalNotificationService.sendTaskNotification(
        title: 'New Task Assignment',
        body: 'You have been assigned a new task: Test Task',
        payload: 'task_assigned');
  }

  Future<void> _testTaskCompletion() async {
    await LocalNotificationService.sendTaskNotification(
        title: 'Task Completed',
        body: 'A household member completed: Test Task',
        payload: 'task_completed');
  }

  Future<void> _testPointUpdate() async {
    await LocalNotificationService.sendTaskPointsNotification('Test Task', 100);
  }

  Future<void> _testTaskExpiration() async {
    await LocalNotificationService.sendTaskNotification(
        title: 'Task Expiring Soon',
        body: 'Task "Test Task" will expire in 1 day',
        payload: 'task_expiring');
  }

  Future<void> _testHouseholdUpdate() async {
    await LocalNotificationService.sendHouseholdUpdateNotification(
        'Household Update', 'New member joined the household');
  }

  Future<void> _testWeeklyReport() async {
    await LocalNotificationService.scheduleWeeklyHouseholdReport(
        'test_household');
  }

  Future<void> _testChatMessage() async {
    await LocalNotificationService.sendChatMessageNotification(
        'Test User', 'Hello! This is a test message');
  }

  Future<void> _testShoppingUpdate() async {
    await LocalNotificationService.sendShoppingItemAddedNotification(
        'Test Item');
  }

  Future<void> _testExpenseUpdate() async {
    await LocalNotificationService.sendExpenseNotification(50.0, 'Groceries');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Test Notifications'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          ElevatedButton(
            onPressed: _testTaskReminder,
            child: const Text('Test Task Reminder'),
          ),
          const SizedBox(height: 8),
          ElevatedButton(
            onPressed: _testTaskAssignment,
            child: const Text('Test Task Assignment'),
          ),
          const SizedBox(height: 8),
          ElevatedButton(
            onPressed: _testTaskCompletion,
            child: const Text('Test Task Completion'),
          ),
          const SizedBox(height: 8),
          ElevatedButton(
            onPressed: _testPointUpdate,
            child: const Text('Test Point Update'),
          ),
          const SizedBox(height: 8),
          ElevatedButton(
            onPressed: _testTaskExpiration,
            child: const Text('Test Task Expiration'),
          ),
          const SizedBox(height: 8),
          ElevatedButton(
            onPressed: _testHouseholdUpdate,
            child: const Text('Test Household Update'),
          ),
          const SizedBox(height: 8),
          ElevatedButton(
            onPressed: _testWeeklyReport,
            child: const Text('Test Weekly Report'),
          ),
          const SizedBox(height: 8),
          ElevatedButton(
            onPressed: _testChatMessage,
            child: const Text('Test Chat Message'),
          ),
          const SizedBox(height: 8),
          ElevatedButton(
            onPressed: _testShoppingUpdate,
            child: const Text('Test Shopping Update'),
          ),
          const SizedBox(height: 8),
          ElevatedButton(
            onPressed: _testExpenseUpdate,
            child: const Text('Test Expense Update'),
          ),
        ],
      ),
    );
  }
}
