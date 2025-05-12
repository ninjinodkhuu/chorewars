import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'Data/Task.dart';
import 'services/TaskService.dart';
import 'local_notifications.dart';

class CalendarScreen extends StatefulWidget {
  const CalendarScreen({super.key});

  @override
  _CalendarScreenState createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> {  DateTime _selectedDay = DateTime.now();
  DateTime _focusedDay = DateTime.now();
  late Future<bool> _isLeaderFuture;
  late Future<String> _householdIdFuture;
  late Future<List<Map<String, dynamic>>> _householdMembersFuture;
  final user = FirebaseAuth.instance.currentUser!;
  bool _taskReminderEnabled = false;
  int _taskReminderLeadDays = 1;
  @override
  void initState() {
    super.initState();
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

  /// Checks if a task has expired (more than 7 days since acceptance)
  bool _isTaskExpired(Task task) {
    if (task.acceptedAt == null || task.done) return false;
    final DateTime now = DateTime.now();
    final DateTime expiryDate = task.acceptedAt!.add(const Duration(days: 7));
    return now.isAfter(expiryDate);
  }

  /// Handles expired task by marking it as incomplete
  Future<void> _handleExpiredTask(String householdId, Task task) async {
    if (_isTaskExpired(task) && !task.done) {
      try {
        await FirebaseFirestore.instance
            .collection('households')
            .doc(householdId)
            .collection('members')
            .doc(user.uid)
            .collection('tasks')
            .doc(task.id)
            .update({
          'done': false,
          'status': 'expired',
          'expired_at': FieldValue.serverTimestamp(),
        });
      } catch (e) {
        print('Error handling expired task: $e');
      }
    }
  }

  Stream<List<Task>> _getTasksStream() async* {
    String householdId = await _getHouseholdId();

    await for (var snapshot in FirebaseFirestore.instance
        .collection('households')
        .doc(householdId)
        .collection('members')
        .doc(user.uid)
        .collection('tasks')
        .snapshots()) {
      List<Task> tasks = snapshot.docs.map((doc) {
        Task task = Task.fromFirestore(doc);

        // Check and handle expired tasks
        _handleExpiredTask(householdId, task);

        return task;
      }).toList();
      yield tasks;
    }
  }

  List<Task> _filterTasksForDay(List<Task> tasks, DateTime day) {
    // Show tasks on their due date, excluding abandoned tasks
    return tasks
        .where(
            (task) => isSameDay(task.date, day) && task.status != 'abandoned')
        .toList();
  }

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
                }                  try {
                    final String assignedMemberId =
                        isLeader ? (selectedMemberId ?? user.uid) : user.uid;
                    final String taskName = nameController.text.trim();
                    final String taskId = '${taskName}_${DateTime.now().millisecondsSinceEpoch}';
                    
                    // Add task using TaskService
                    await TaskService.addTask(
                      householdId: householdId,
                      memberId: assignedMemberId,
                      name: taskName,
                      category: "", // Pass empty string for category
                      dueDate: selectedDate,
                      difficulty: selectedDifficulty,
                      estimatedMinutes: timeEstimate,
                    );

                    // Send notifications in a try-catch block to ensure task creation succeeds regardless
                    try {
                      await LocalNotificationService.sendTaskNotification(
                        title: 'New Task Created',
                        body: 'Task "$taskName" has been created',
                        payload: 'task_created_$taskId',
                      );

                      // Schedule reminder if enabled
                      if (_taskReminderEnabled) {
                        await LocalNotificationService.scheduleTaskReminder(
                          taskId,
                          taskName,
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

  String _formatDifficultyName(String name) {
    final words = name.split(RegExp(r'(?=[A-Z])'));
    return words
        .map((word) =>
            word.substring(0, 1).toUpperCase() +
            word.substring(1).toLowerCase())
        .join(' ');
  }

  void _showCompleteTaskDialog(Task task) async {
    final TextEditingController timeSpentController = TextEditingController();
    timeSpentController.text = task.timeEstimateMinutes.toString();
    String householdId = await _householdIdFuture;

    if (!mounted) return;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
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
            onPressed: () => Navigator.pop(context),
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
                    int.parse(timeSpentController.text.trim());                await TaskService.completeTask(
                  householdId: householdId,
                  memberId: FirebaseAuth.instance.currentUser!.uid,
                  taskId: task.id,
                  points: task.difficulty.points,
                  timeSpentMinutes: timeSpent,
                );

                // Send completion notification
                await LocalNotificationService.sendTaskNotification(
                  title: 'Task Completed',
                  body: 'You completed "${task.name}" and earned ${task.difficulty.points} points!',
                  payload: 'task_${task.id}_completed',
                );

                // Cancel any existing reminders for this task
                LocalNotificationService.cancelTaskReminder(task.id);

                if (mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                          'Task completed! You earned ${task.difficulty.points} points.'),
                      backgroundColor: Colors.green,
                    ),
                  );
                }
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Error completing task: $e'),
                    backgroundColor: Colors.red,
                  ),
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue[900],
              foregroundColor: Colors.white, // Add white text color
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

                    if (task.status == 'abandoned') {
                      taskStatus = 'Abandoned';
                      statusColor = Colors.red;
                    } else if (_isTaskExpired(task)) {
                      taskStatus = 'Expired';
                      statusColor = Colors.red;
                    } else if (task.done) {
                      taskStatus = 'Completed';
                      statusColor = Colors.green;
                    } else if (task.startedAt != null) {
                      taskStatus = 'In Progress';
                      statusColor = Colors.blue;
                    } else if (task.acceptedAt != null) {
                      // Calculate days remaining
                      int daysRemaining = 7 -
                          DateTime.now().difference(task.acceptedAt!).inDays;
                      taskStatus = 'Accepted ($daysRemaining days left)';
                      statusColor =
                          daysRemaining <= 2 ? Colors.orange : Colors.blue;
                    } else {
                      taskStatus = 'Pending';
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
                                if (!task.done &&
                                    task.status != 'abandoned' &&
                                    task.status != 'expired') ...[
                                  if (task.acceptedAt == null)
                                    ElevatedButton.icon(
                                      icon: const Icon(Icons.check, size: 16),
                                      label: const Text('Accept'),
                                      onPressed: () async {
                                        String householdId =
                                            await _getHouseholdId();
                                        try {
                                          await TaskService.acceptTask(
                                            householdId: householdId,
                                            memberId: user.uid,
                                            taskId: task.id,
                                          );
                                          if (mounted) {
                                            ScaffoldMessenger.of(context)
                                                .showSnackBar(
                                              const SnackBar(
                                                content: Text('Task accepted'),
                                                backgroundColor: Colors.green,
                                              ),
                                            );
                                          }
                                        } catch (e) {
                                          if (mounted) {
                                            ScaffoldMessenger.of(context)
                                                .showSnackBar(
                                              SnackBar(
                                                content: Text(
                                                    'Error accepting task: $e'),
                                                backgroundColor: Colors.red,
                                              ),
                                            );
                                          }
                                        }
                                      },
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.green,
                                        foregroundColor: Colors.white,
                                      ),
                                    )
                                  else if (task.startedAt == null) ...[
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
                                  ] else ...[
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
    );
  }
}
