// =========================
// home_screen.dart
// =========================
// This file implements the main home screen for Chorewars.
// It displays the user's tasks, allows filtering, and integrates with notifications.
//
// Key design decisions:
// - Integrates with Firestore and Firebase Auth for task and user data.
// - UI supports filtering tasks by status and displays them using SquareCard widgets.
// - Initializes local notifications for reminders and updates.
//
// Contributor notes:
// - If you add new task features or filters, update both the UI and Firestore logic.
// - Keep comments up to date for onboarding new contributors.

import 'Data/Task.dart';
import 'SquareCard.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'local_notifications.dart';

enum TaskFilter { accepted, inProgress, completed }

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final user = FirebaseAuth.instance.currentUser!;
  TaskFilter _selectedFilter = TaskFilter.accepted;
  String? householdID;

  @override
  void initState() {
    super.initState();
    _fetchHouseholdID();
    // Initialize notifications
    LocalNotificationService.initialize();
  }

  // Load householdID
  Future<void> _fetchHouseholdID() async {
    final userDoc = await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .get();

    if (userDoc.exists) {
      setState(() {
        householdID = userDoc.get('household_id');
      });
    }
  }

  Stream<List<Task>> _getTasksStream() async* {
    String uid = FirebaseAuth.instance.currentUser?.uid ?? '';
    final userDoc =
        await FirebaseFirestore.instance.collection('users').doc(uid).get();

    if (userDoc.exists) {
      String householdId = userDoc.get('household_id');

      await for (var snapshot in FirebaseFirestore.instance
          .collection('households')
          .doc(householdId)
          .collection('members')
          .doc(uid)
          .collection('tasks')
          .snapshots()) {
        List<Task> tasks =
            snapshot.docs.map((doc) => Task.fromFirestore(doc)).toList();
        // Send notifications for task updates
        _handleTaskUpdates(tasks);
        yield tasks;
      }
    } else {
      yield [];
    }
  }

  void _handleTaskUpdates(List<Task> tasks) {
    for (var task in tasks) {
      // Notify when task is completed
      if (task.done && task.completedAt != null) {
        LocalNotificationService.sendTaskNotification(
          title: "Task Completed",
          body: "The task '${task.name}' has been completed!",
          payload: task.id,
        );
      }
      // Notify when task is started
      else if (task.startedAt != null && !task.done) {
        LocalNotificationService.sendTaskNotification(
          title: "Task Started",
          body: "Work has begun on '${task.name}'",
          payload: task.id,
        );
      }
      // Notify when task is accepted
      else if (task.acceptedAt != null && task.startedAt == null) {
        LocalNotificationService.sendTaskNotification(
          title: "New Task Accepted",
          body: "You have accepted the task '${task.name}'",
          payload: task.id,
        );
      }
    }
  }

  List<Task> _getFilteredTasks(List<Task> tasks) {
    switch (_selectedFilter) {
      case TaskFilter.accepted:
        return tasks
            .where((task) =>
                task.acceptedAt != null &&
                task.startedAt == null &&
                task.status != 'abandoned' &&
                task.status != 'expired')
            .toList();
      case TaskFilter.inProgress:
        return tasks
            .where((task) =>
                task.startedAt != null &&
                !task.done &&
                task.status != 'abandoned' &&
                task.status != 'expired')
            .toList();
      case TaskFilter.completed:
        return tasks
            .where((task) => task.done || task.status == 'abandoned')
            .toList();
    }
  }

  void signUserOut() {
    FirebaseAuth.instance.signOut();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 40),
          // Header and filter buttons
          Padding(
            padding: const EdgeInsets.all(15.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Hello ${user.email}!',
                  style: const TextStyle(
                    color: Colors.black,
                    fontSize: 23,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Have a nice day.',
                  style: TextStyle(
                    color: Colors.black,
                    fontSize: 18,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 15),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildFilterButton('Accepted', TaskFilter.accepted),
              _buildFilterButton('In Progress', TaskFilter.inProgress),
              _buildFilterButton('Completed', TaskFilter.completed),
            ],
          ),
          const SizedBox(height: 20),
          // Filtered Tasks Section
          SizedBox(
            height: 150,
            child: StreamBuilder<List<Task>>(
              stream: _getTasksStream(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (snapshot.hasError) {
                  return Center(child: Text('Error: ${snapshot.error}'));
                }

                List<Task>? tasks = snapshot.data;
                if (tasks == null || tasks.isEmpty) {
                  return const Center(child: Text('No tasks found'));
                }
                List<Task> filteredTasks = _getFilteredTasks(tasks);

                if (filteredTasks.isEmpty) {
                  return _buildEmptyPlaceholder(
                      _selectedFilter == TaskFilter.accepted
                          ? 'Accepted'
                          : _selectedFilter == TaskFilter.inProgress
                              ? 'In Progress'
                              : 'Completed',
                      _selectedFilter == TaskFilter.accepted
                          ? Colors.orange
                          : _selectedFilter == TaskFilter.inProgress
                              ? Colors.blue
                              : Colors.green);
                }

                return SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: filteredTasks.map((task) {
                      return Container(
                        key: ObjectKey(task),
                        child: SquareCard(task: task),
                      );
                    }).toList(),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 20),
          // Household Task History
          const Expanded(
            child: TaskHistory(),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterButton(String text, TaskFilter filter) {
    final isSelected = _selectedFilter == filter;
    return Container(
      width: 100,
      height: 30,
      margin: const EdgeInsets.symmetric(horizontal: 4),
      child: Material(
        elevation: 4,
        borderRadius: BorderRadius.circular(25),
        child: InkWell(
          onTap: () {
            setState(() {
              _selectedFilter = filter;
            });
          },
          borderRadius: BorderRadius.circular(25),
          child: Container(
            decoration: BoxDecoration(
              color: isSelected ? Colors.white : Colors.blue[50],
              borderRadius: BorderRadius.circular(25),
            ),
            child: Center(
              child: Text(
                text,
                style: const TextStyle(
                  color: Colors.black,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyPlaceholder(String title, Color color) {
    return Center(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          border: Border.all(color: color.withOpacity(0.3)),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              title == 'Accepted' ? Icons.task_alt : Icons.play_circle_outline,
              color: color.withOpacity(0.5),
              size: 48,
            ),
            const SizedBox(height: 8),
            Text(
              'No ${title.toLowerCase()} tasks',
              style: TextStyle(
                color: color.withOpacity(0.7),
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class TaskHistory extends StatefulWidget {
  const TaskHistory({super.key});

  @override
  State<TaskHistory> createState() => _TaskHistoryState();
}

class _TaskHistoryState extends State<TaskHistory> {
  Stream<List<Map<String, dynamic>>> _getHouseholdTasksStream() async* {
    final user = FirebaseAuth.instance.currentUser!;
    final userDoc = await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .get();

    if (!userDoc.exists) {
      yield [];
      return;
    }

    String householdId = userDoc.get('household_id');

    // Get all household members
    final membersSnapshot = await FirebaseFirestore.instance
        .collection('households')
        .doc(householdId)
        .collection('members')
        .get();

    await for (var _ in FirebaseFirestore.instance
        .collection('households')
        .doc(householdId)
        .snapshots()) {
      List<Map<String, dynamic>> allTasks = [];

      // Fetch tasks for each member
      for (var memberDoc in membersSnapshot.docs) {
        final tasksSnapshot = await FirebaseFirestore.instance
            .collection('households')
            .doc(householdId)
            .collection('members')
            .doc(memberDoc.id)
            .collection('tasks')
            .orderBy('completed_at',
                descending: true) // Order by completion date
            .get();

        final memberEmail = memberDoc.data()['email'] ?? 'Unknown';

        // Convert tasks to maps with member info
        final memberTasks = tasksSnapshot.docs.map((doc) {
          final taskData = doc.data();
          taskData['memberId'] = memberDoc.id;
          taskData['memberEmail'] = memberEmail;
          taskData['taskId'] = doc.id;
          return taskData;
        }).toList();

        allTasks.addAll(memberTasks);
      }

      // Sort completed tasks by completion date
      allTasks.sort((a, b) {
        final aTime = a['completed_at'] as Timestamp?;
        final bTime = b['completed_at'] as Timestamp?;
        if (aTime == null || bTime == null) return 0;
        return bTime.compareTo(aTime); // Most recent first
      });

      yield allTasks;
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: _getHouseholdTasksStream(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }

        List<Map<String, dynamic>>? tasks = snapshot.data;
        if (tasks == null || tasks.isEmpty) {
          return Center(child: _buildEmptyPlaceholder('History', Colors.green));
        }

        var completedTasks = tasks.where((t) => t['done'] ?? false).toList();

        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildTaskHistoryColumn(
                  'Household History', completedTasks, Colors.green),
            ],
          ),
        );
      },
    );
  }

  // Helper methods for task card building
  Widget _buildEmptyPlaceholder(String title, Color color) {
    return Center(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          border: Border.all(color: color.withOpacity(0.3)),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.history,
              color: color.withOpacity(0.5),
              size: 48,
            ),
            const SizedBox(height: 8),
            Text(
              'No completed tasks',
              style: TextStyle(
                color: color.withOpacity(0.7),
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTaskHistoryColumn(
      String title, List<Map<String, dynamic>> tasks, Color color) {
    return Container(
      width: MediaQuery.of(context).size.width - 32,
      margin: const EdgeInsets.symmetric(horizontal: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Column header
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Row(
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${tasks.length}',
                    style: TextStyle(
                      color: color,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),
          // Task list
          Expanded(
            child: tasks.isEmpty
                ? _buildEmptyPlaceholder(title, color)
                : SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: tasks.map((task) {
                        final timeEstimate = task['timeEstimate'] ?? 0;
                        final difficulty = task['difficulty'] ?? 'veryEasy';
                        final points = TaskDifficulty.values
                            .firstWhere(
                              (d) => d.name == difficulty,
                              orElse: () => TaskDifficulty.veryEasy,
                            )
                            .points;

                        return Container(
                          width: 300,
                          margin: const EdgeInsets.symmetric(horizontal: 4),
                          child: Card(
                            child: Padding(
                              padding: const EdgeInsets.all(12),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    task['name'] ?? 'Unnamed Task',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                      'Category: ${task['category'] ?? 'Uncategorized'}'),
                                  Text('Points: $points'),
                                  Text('Est. Time: $timeEstimate mins'),
                                  Text('Assigned to: ${task['memberEmail']}'),
                                  const SizedBox(height: 8),
                                  Text(
                                    _formatTaskTimeline(task),
                                    style: TextStyle(
                                      color: Colors.grey[600],
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  String _formatTaskTimeline(Map<String, dynamic> task) {
    final List<String> timeline = [];

    if (task['created_at'] != null) {
      final createdAt = (task['created_at'] as Timestamp).toDate();
      timeline.add('Created: ${_formatDateTime(createdAt)}');
    }

    if (task['completed_at'] != null) {
      final completedAt = (task['completed_at'] as Timestamp).toDate();
      timeline.add('Completed: ${_formatDateTime(completedAt)}');
    }

    return timeline.join(' • ');
  }

  String _formatDateTime(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inMinutes < 1) {
      return 'Just now';
    } else if (difference.inHours < 1) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inDays < 1) {
      return '${difference.inHours}h ago';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}d ago';
    } else {
      return '${dateTime.day}/${dateTime.month}/${dateTime.year}';
    }
  }
}
