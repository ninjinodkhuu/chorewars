import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'Data/Task.dart';
import 'services/TaskService.dart';
import 'local_notifications.dart';

// =========================
// CalenderScreen.dart
// =========================
// This file handles the calendar screen, including task management, notifications, and user/household logic.
// Comments are added throughout to show the structure and process for your professor.

class CalendarScreen extends StatefulWidget {
  const CalendarScreen({super.key});

  @override
  _CalendarScreenState createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> {
  // State variables for selected and focused days
  DateTime _selectedDay = DateTime.now();
  DateTime _focusedDay = DateTime.now();
  // Futures for leader status, household ID, and members
  late Future<bool> _isLeaderFuture;
  late Future<String> _householdIdFuture;
  late Future<List<Map<String, dynamic>>> _householdMembersFuture;
  // Current user
  final user = FirebaseAuth.instance.currentUser!;
  // Notification settings
  bool _taskReminderEnabled = false;
  int _taskReminderLeadDays = 1;
  @override
  void initState() {
    super.initState();
    // Initialize household and notification settings
    _householdIdFuture = _getHouseholdId();
    _isLeaderFuture =
        _householdIdFuture.then((householdId) => _checkIfLeader());
    _householdMembersFuture =
        _householdIdFuture.then((householdId) => _getHouseholdMembers());
    _loadNotificationPreferences();
  }

  // Load notification preferences from Firestore
  Future<void> _loadNotificationPreferences() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('settings')
          .doc('notifications')
          .get();

      if (doc.exists) {
        setState(() {
          _taskReminderEnabled = doc.data()?['taskReminders'] ?? false;
          _taskReminderLeadDays = doc.data()?['notificationLeadTime'] ?? 1;
        });
      }
    } catch (e) {
      print('Error loading notification preferences: $e');
    }
  }

  // Helper method to get household ID
  Future<String> _getHouseholdId() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      throw Exception('User not logged in');
    }

    try {
      // First check household_members collection
      final membersSnapshot = await FirebaseFirestore.instance
          .collection('household_members')
          .where('memberId', isEqualTo: user.uid)
          .limit(1)
          .get();

      // If found in household_members, verify the household exists
      if (membersSnapshot.docs.isNotEmpty) {
        String householdId = membersSnapshot.docs.first.data()['householdId'];
        DocumentSnapshot householdDoc = await FirebaseFirestore.instance
            .collection('households')
            .doc(householdId)
            .get();

        if (householdDoc.exists) {
          return householdId;
        }
      }

      // If not found or household doesn't exist, create a new one
      print('Creating new household for user ${user.uid}...');

      // Create a new household document with proper structure
      DocumentReference householdRef =
          await FirebaseFirestore.instance.collection('households').add({
        'name': 'My Household',
        'leaderId': user.uid, // Set current user as leader
        'createdAt': FieldValue.serverTimestamp(),
        'members': [user.uid], // Initialize members array
        'completionRate': 0.0,
        'avgPoints': 0.0,
        'avgTimeMinutes': 0
      });

      String newHouseholdId = householdRef.id;
      print('Created new household with ID: $newHouseholdId');

      // Update user's profile
      await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
        'household_id': newHouseholdId,
        'email': user.email,
        'displayName': user.displayName,
        'lastUpdated': FieldValue.serverTimestamp()
      }, SetOptions(merge: true));

      // Add user as household member with proper initialization
      await FirebaseFirestore.instance
          .collection('households')
          .doc(newHouseholdId)
          .collection('members')
          .doc(user.uid)
          .set({
        'name': user.email ?? 'User', // Use email as name for consistency
        'email': user.email ?? '',
        'joinedAt': FieldValue.serverTimestamp(),
        'isLeader': true,
        'totalPoints': 0,
        'completedTasks': 0,
        'totalTasks': 0
      });

      // Add to household_members collection
      await FirebaseFirestore.instance.collection('household_members').add({
        'memberId': user.uid,
        'householdId': newHouseholdId,
        'joinedAt': FieldValue.serverTimestamp()
      });

      return newHouseholdId;
    } catch (e) {
      print('Error in _getHouseholdId: $e');
      throw Exception('Failed to get or create household: $e');
    }
  }

  // Check if the current user is the household leader
  Future<bool> _checkIfLeader() async {
    try {
      // Get household ID directly instead of using the Future
      String householdId = await _getHouseholdId();

      DocumentSnapshot householdDoc = await FirebaseFirestore.instance
          .collection('households')
          .doc(householdId)
          .get();

      if (!householdDoc.exists) {
        print('Creating new household for user...');
        return true;
      }

      Map<String, dynamic> data = householdDoc.data() as Map<String, dynamic>;
      String leaderId = data['leaderId'] ?? user.uid;
      print(
          'Checking leader status: current user=${user.uid}, leader=$leaderId');
      return leaderId == user.uid;
    } catch (e) {
      print('Error in _checkIfLeader: $e');
      // If there's an error, we'll let them add tasks
      return true;
    }
  }

  // Get the list of household members
  Future<List<Map<String, dynamic>>> _getHouseholdMembers() async {
    String householdId = await _getHouseholdId();
    QuerySnapshot membersSnapshot = await FirebaseFirestore.instance
        .collection('households')
        .doc(householdId)
        .collection('members')
        .get();

    return membersSnapshot.docs.map((doc) {
      return {
        'id': doc.id,
        'name': (doc.data() as Map<String, dynamic>)['name'] ?? 'Unknown',
        'email': (doc.data() as Map<String, dynamic>)['email'] ?? 'No email'
      };
    }).toList();
  }

  // Stream of tasks for the current user only (per-user view)
  Stream<List<Task>> _getTasksStream() async* {
    String householdId = await _getHouseholdId();
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      yield [];
      return;
    }
    // Listen to tasks collection directly as a stream
    yield* FirebaseFirestore.instance
        .collection('households')
        .doc(householdId)
        .collection('members')
        .doc(user.uid)
        .collection('tasks')
        .snapshots()
        .map((snapshot) =>
            snapshot.docs.map((doc) => Task.fromFirestore(doc)).toList());
  }

  // Filter tasks for a specific day
  List<Task> _filterTasksForDay(List<Task> tasks, DateTime day) {
    List<Task> filtered = tasks.where((task) {
      bool sameDay = isSameDay(task.date, day);
      bool isValid = task.status != 'abandoned';
      return sameDay && isValid;
    }).toList();
    return filtered;
  }

  // Show dialog to add a new task
  void _showAddTaskDialog() async {
    final TextEditingController nameController = TextEditingController();
    final TextEditingController timeEstimateController =
        TextEditingController();
    String? selectedMemberId;
    TaskDifficulty selectedDifficulty = TaskDifficulty.veryEasy;
    DateTime selectedDate = _selectedDay;
    bool isLeader = await _isLeaderFuture;
    List<Map<String, dynamic>> members = await _householdMembersFuture;
    String householdId = await _householdIdFuture;

    if (!mounted) return;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Add New Task'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(
                    labelText: 'Task Name',
                    hintText: 'Enter task name',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<TaskDifficulty>(
                  value: selectedDifficulty,
                  decoration: const InputDecoration(
                    labelText: 'Difficulty',
                    border: OutlineInputBorder(),
                  ),
                  items: TaskDifficulty.values
                      .map((difficulty) => DropdownMenuItem<TaskDifficulty>(
                            value: difficulty,
                            child: Text(
                                '${_formatDifficultyName(difficulty.name)} (${difficulty.points} points)'),
                          ))
                      .toList(),
                  onChanged: (value) {
                    setState(() {
                      selectedDifficulty = value ?? TaskDifficulty.veryEasy;
                    });
                  },
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: timeEstimateController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Estimated Time (minutes)',
                    hintText: 'Enter estimated completion time',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                if (isLeader) ...[
                  DropdownButtonFormField<String>(
                    value: selectedMemberId,
                    decoration: const InputDecoration(
                      labelText: 'Assign to',
                      border: OutlineInputBorder(),
                    ),
                    hint: const Text('Select member'),
                    items: members.map<DropdownMenuItem<String>>((member) {
                      return DropdownMenuItem<String>(
                        value: member['id'] as String,
                        child: Text(member['email'] as String),
                      );
                    }).toList(),
                    onChanged: (value) {
                      setState(() {
                        selectedMemberId = value;
                      });
                    },
                  ),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                // Validate inputs
                if (nameController.text.trim().isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Please enter a task name')),
                  );
                  return;
                }

                if (timeEstimateController.text.trim().isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                        content: Text('Please enter estimated time')),
                  );
                  return;
                }

                // Validate time estimate is a valid number
                int? timeEstimate;
                try {
                  timeEstimate = int.parse(timeEstimateController.text.trim());
                  if (timeEstimate <= 0) {
                    throw const FormatException('Time must be positive');
                  }
                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text(
                          'Please enter a valid positive number for estimated time'),
                    ),
                  );
                  return;
                }
                try {
                  // Always use the current user's UID unless assigning to another member
                  final String assignedMemberId = (selectedMemberId == null ||
                          (selectedMemberId?.isEmpty ?? true))
                      ? FirebaseAuth.instance.currentUser!.uid
                      : selectedMemberId!;

                  // DEBUG: Print the householdId and assignedMemberId before creating the task
                  print('[CalendarScreen] Creating task with householdId: '
                      '[32m$householdId[0m, memberId: '
                      '[34m$assignedMemberId[0m');

                  await TaskService.addTask(
                    householdId: householdId,
                    memberId: assignedMemberId,
                    name: nameController.text.trim(),
                    category: "", // Pass empty string for category
                    dueDate: selectedDate,
                    difficulty: selectedDifficulty,
                    estimatedMinutes: timeEstimate,
                  );

                  // Send notifications in a try-catch block to ensure task creation succeeds regardless
                  try {
                    await LocalNotificationService.sendTaskNotification(
                      title: 'New Task Created',
                      body:
                          'Task "${nameController.text.trim()}" has been created',
                      payload:
                          'task_created_${nameController.text.trim()}_${DateTime.now().millisecondsSinceEpoch}',
                    );

                    // Schedule reminder if enabled
                    if (_taskReminderEnabled) {
                      await LocalNotificationService.scheduleTaskReminder(
                        '${nameController.text.trim()}_${DateTime.now().millisecondsSinceEpoch}',
                        nameController.text.trim(),
                        selectedDate,
                        _taskReminderLeadDays,
                      );
                    }
                  } catch (notificationError) {
                    print('Error sending notification: $notificationError');
                    // Continue execution as task was created successfully
                  }

                  if (mounted) {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Task added successfully'),
                        backgroundColor: Colors.green,
                      ),
                    );
                  }
                } catch (e) {
                  print('Detailed error when adding task: $e');
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Error adding task: $e'),
                        backgroundColor: Colors.red,
                      ),
                    );
                  }
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue[900],
                foregroundColor: Colors.white, // Add white text color
              ),
              child: const Text('Add Task'),
            ),
          ],
        ),
      ),
    );
  }

  // Format the difficulty name for display
  String _formatDifficultyName(String name) {
    final words = name.split(RegExp(r'(?=[A-Z])'));
    return words
        .map((word) =>
            word.substring(0, 1).toUpperCase() +
            word.substring(1).toLowerCase())
        .join(' ');
  }

  // Show dialog to complete a task
  void _showCompleteTaskDialog(Task task) async {
    final TextEditingController timeSpentController = TextEditingController();
    timeSpentController.text = task.timeEstimateMinutes.toString();
    String householdId = await _householdIdFuture;

    if (!mounted) return;

    showDialog(
      context: context,
      barrierDismissible: false, // Prevent dismissing by tapping outside
      builder: (dialogContext) => AlertDialog(
        // Use separate context for dialog
        title: const Text('Complete Task'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Task: ${task.name}',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Difficulty: ${_formatDifficultyName(task.difficulty.name)} (${task.difficulty.points} points)',
                style: const TextStyle(fontSize: 14),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: timeSpentController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Actual Time Spent (minutes)',
                  hintText: 'Enter how long it took to complete',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              // Validate input
              if (timeSpentController.text.trim().isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Please enter time spent')),
                );
                return;
              }

              try {
                final int timeSpent =
                    int.parse(timeSpentController.text.trim());
                await TaskService.completeTask(
                  householdId: householdId,
                  memberId: FirebaseAuth.instance.currentUser!.uid,
                  taskId: task.id,
                  points: task.difficulty.points,
                  timeSpentMinutes: timeSpent,
                );

                // Close dialog first
                Navigator.of(dialogContext).pop();

                if (mounted) {
                  // Then show success message
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                          'Task completed! You earned ${task.difficulty.points} points.'),
                      backgroundColor: Colors.green,
                    ),
                  );
                }

                // Cancel any existing reminders for this task
                LocalNotificationService.cancelTaskReminder(task.id);
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Error completing task: $e'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue[900],
              foregroundColor: Colors.white,
            ),
            child: const Text('Complete Task'),
          ),
        ],
      ),
    );
  }

  /// Shows a confirmation dialog before abandoning a task
  void _showAbandonTaskDialog(Task task) async {
    String householdId = await _householdIdFuture;

    if (!mounted) return;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Abandon Task'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Are you sure you want to abandon "${task.name}"?',
              style: const TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 16),
            const Text(
              'This will count as an incomplete task and affect your stats.',
              style: TextStyle(
                color: Colors.red,
                fontSize: 14,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              try {
                await TaskService.abandonTask(
                  householdId: householdId,
                  memberId: user.uid,
                  taskId: task.id,
                );

                if (mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Task abandoned'),
                      backgroundColor: Colors.orange,
                    ),
                  );
                }
              } catch (e) {
                if (mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Error abandoning task: $e'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Abandon Task'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final DateFormat formatter = DateFormat('MMMM d, yyyy');
    final String formattedDate = formatter.format(DateTime.now());

    return Scaffold(
      backgroundColor: Colors.blue[50],
      body: Column(
        children: [
          // Header Section
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.blue[900],
              borderRadius: const BorderRadius.only(
                bottomLeft: Radius.circular(16),
                bottomRight: Radius.circular(16),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  formattedDate,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),

          // Calendar Section
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TableCalendar(
              firstDay: DateTime.utc(2020, 1, 1),
              lastDay: DateTime.utc(2030, 12, 31),
              focusedDay: _focusedDay,
              selectedDayPredicate: (day) {
                return isSameDay(_selectedDay, day);
              },
              onDaySelected: (selectedDay, focusedDay) {
                setState(() {
                  _selectedDay = selectedDay;
                  _focusedDay = focusedDay;
                });
              },
              calendarFormat: CalendarFormat.week,
              calendarStyle: CalendarStyle(
                selectedDecoration: const BoxDecoration(
                  color: Colors.amber,
                  shape: BoxShape.circle,
                ),
                todayDecoration: BoxDecoration(
                  color: Colors.blue[300],
                  shape: BoxShape.circle,
                ),
                defaultTextStyle: const TextStyle(
                  fontSize: 16,
                  color: Colors.black,
                ),
                weekendTextStyle: const TextStyle(
                  fontSize: 16,
                  color: Colors.red,
                ),
              ),
              headerStyle: const HeaderStyle(
                formatButtonVisible: false,
                titleCentered: true,
                titleTextStyle: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.black,
                ),
              ),
            ),
          ),

          // Task List Section
          Expanded(
            child: StreamBuilder<List<Task>>(
              stream: _getTasksStream(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (snapshot.hasError) {
                  return Center(child: Text('Error: ${snapshot.error}'));
                }

                final tasks = snapshot.data ?? [];
                final tasksForDay = _filterTasksForDay(tasks, _selectedDay);

                return ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: tasksForDay.length + 1,
                  itemBuilder: (context, index) {
                    if (index == tasksForDay.length) {
                      return Card(
                        margin: const EdgeInsets.symmetric(vertical: 8),
                        elevation: 4,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        color: Colors.white, // Set white background explicitly
                        child: ListTile(
                          contentPadding: const EdgeInsets.all(16),
                          leading: CircleAvatar(
                            backgroundColor: Colors.blue[900],
                            child: const Icon(
                              Icons.add,
                              color: Colors.white,
                            ),
                          ),
                          title: Text(
                            "Add Task",
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.blue[
                                  900], // Change text color to match the theme
                            ),
                          ),
                          onTap: () {
                            print("Add Task tapped"); // Debug print
                            _showAddTaskDialog();
                          },
                        ),
                      );
                    }

                    final task = tasksForDay[index];

                    // Define task status indicators
                    String taskStatus;
                    Color statusColor;

                    // Only use new status logic
                    if (task.status == 'abandoned') {
                      taskStatus = 'Abandoned';
                      statusColor = Colors.red;
                    } else if (task.status == 'expired') {
                      taskStatus = 'Expired';
                      statusColor = Colors.red;
                    } else if (task.done || task.status == 'completed') {
                      taskStatus = 'Completed';
                      statusColor = Colors.green;
                    } else if (task.startedAt != null) {
                      taskStatus = 'In Progress';
                      statusColor = Colors.blue;
                    } else if (task.status == 'assigned') {
                      taskStatus = 'Assigned';
                      statusColor = Colors.grey;
                    } else {
                      taskStatus = task.status;
                      statusColor = Colors.grey;
                    }

                    return Card(
                      margin: const EdgeInsets.symmetric(vertical: 8),
                      elevation: 4,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        children: [
                          ListTile(
                            contentPadding: const EdgeInsets.all(16),
                            leading: CircleAvatar(
                              backgroundColor: Colors.blue[900],
                              child: Text(
                                '${task.difficulty.points}',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            title: Text(
                              task.name,
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    Icon(Icons.upcoming,
                                        size: 16, color: Colors.grey[600]),
                                    const SizedBox(width: 4),
                                    Text(
                                      '${_formatDifficultyName(task.difficulty.name)} • ${task.timeEstimateMinutes} mins',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.grey[600],
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 8, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: statusColor.withOpacity(0.2),
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(color: statusColor),
                                      ),
                                      child: Text(
                                        taskStatus,
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: statusColor,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.only(
                                left: 16, right: 16, bottom: 16),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                // Show delete button for completed tasks
                                if (task.status == 'completed' ||
                                    task.done) ...[
                                  ElevatedButton.icon(
                                    icon: const Icon(Icons.delete_outline,
                                        size: 16),
                                    label: const Text('Delete'),
                                    onPressed: () async {
                                      String householdId =
                                          await _householdIdFuture;
                                      // Show confirmation dialog
                                      showDialog(
                                        context: context,
                                        barrierDismissible: false,
                                        builder: (dialogContext) => AlertDialog(
                                          title: const Text('Delete Task'),
                                          content: Text(
                                              'Are you sure you want to delete "${task.name}"?\nThis action cannot be undone.'),
                                          actions: [
                                            TextButton(
                                              onPressed: () =>
                                                  Navigator.of(dialogContext)
                                                      .pop(),
                                              child: const Text('Cancel'),
                                            ),
                                            ElevatedButton(
                                              onPressed: () async {
                                                try {
                                                  await TaskService
                                                      .deleteTaskAndUpdateStats(
                                                    householdId: householdId,
                                                    memberId: user.uid,
                                                    taskId: task.id,
                                                  );

                                                  // Close dialog first
                                                  Navigator.of(dialogContext)
                                                      .pop();

                                                  if (mounted) {
                                                    ScaffoldMessenger.of(
                                                            context)
                                                        .showSnackBar(
                                                      const SnackBar(
                                                        content: Text(
                                                            'Task deleted successfully'),
                                                        backgroundColor:
                                                            Colors.green,
                                                      ),
                                                    );
                                                  }
                                                } catch (e) {
                                                  print(
                                                      'Error deleting task: $e');
                                                  if (mounted) {
                                                    Navigator.of(dialogContext)
                                                        .pop();
                                                    ScaffoldMessenger.of(
                                                            context)
                                                        .showSnackBar(
                                                      SnackBar(
                                                        content: Text(
                                                            'Error deleting task: $e'),
                                                        backgroundColor:
                                                            Colors.red,
                                                      ),
                                                    );
                                                  }
                                                }
                                              },
                                              style: ElevatedButton.styleFrom(
                                                backgroundColor: Colors.red,
                                                foregroundColor: Colors.white,
                                              ),
                                              child: const Text('Delete'),
                                            ),
                                          ],
                                        ),
                                      );
                                    },
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.grey[700],
                                      foregroundColor: Colors.white,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                ],
                                // Existing task action buttons
                                if (!task.done &&
                                    task.status != 'abandoned' &&
                                    task.status != 'expired') ...[
                                  if (task.status == 'assigned' &&
                                      task.startedAt == null) ...[
                                    ElevatedButton.icon(
                                      icon: const Icon(Icons.play_arrow,
                                          size: 16),
                                      label: const Text('Start'),
                                      onPressed: () async {
                                        String householdId =
                                            await _getHouseholdId();
                                        try {
                                          await TaskService.startTask(
                                            householdId: householdId,
                                            memberId: user.uid,
                                            taskId: task.id,
                                          );
                                          if (mounted) {
                                            ScaffoldMessenger.of(context)
                                                .showSnackBar(
                                              const SnackBar(
                                                content: Text('Task started'),
                                                backgroundColor: Colors.blue,
                                              ),
                                            );
                                          }
                                        } catch (e) {
                                          if (mounted) {
                                            ScaffoldMessenger.of(context)
                                                .showSnackBar(
                                              SnackBar(
                                                content: Text(
                                                    'Error starting task: $e'),
                                                backgroundColor: Colors.red,
                                              ),
                                            );
                                          }
                                        }
                                      },
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.blue,
                                        foregroundColor: Colors.white,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    ElevatedButton.icon(
                                      icon: const Icon(Icons.cancel_outlined,
                                          size: 16),
                                      label: const Text('Abandon'),
                                      onPressed: () =>
                                          _showAbandonTaskDialog(task),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.red,
                                        foregroundColor: Colors.white,
                                      ),
                                    ),
                                  ] else if (task.startedAt != null &&
                                      !task.done) ...[
                                    ElevatedButton.icon(
                                      icon:
                                          const Icon(Icons.done_all, size: 16),
                                      label: const Text('Complete'),
                                      onPressed: () {
                                        _showCompleteTaskDialog(task);
                                      },
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.purple,
                                        foregroundColor: Colors.white,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    ElevatedButton.icon(
                                      icon: const Icon(Icons.cancel_outlined,
                                          size: 16),
                                      label: const Text('Abandon'),
                                      onPressed: () =>
                                          _showAbandonTaskDialog(task),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.red,
                                        foregroundColor: Colors.white,
                                      ),
                                    ),
                                  ],
                                ],
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          // Force-create a task for the current user
          await TaskService.addTask(
            householdId: '4taVtdDejjWPL3Vd4GAO',
            memberId: 'BC3RQtXJ6GR1FjkPDBeCu1dlbhg1',
            name: 'Force Created Task',
            category: 'General',
            dueDate: DateTime.now().add(const Duration(days: 1)),
            difficulty: TaskDifficulty.easy,
            estimatedMinutes: 15,
          );
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                  content: Text('Force-created task for your user!')),
            );
          }
        },
        tooltip: 'Force Create Task',
        child: const Icon(Icons.bolt),
      ),
    );
  }
}
