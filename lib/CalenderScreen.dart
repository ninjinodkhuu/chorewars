import 'package:expenses_tracker/local_notifications.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'Data/Task.dart';
import 'services/points_service.dart';
import 'services/TaskService.dart';

class CalendarScreen extends StatefulWidget {
  const CalendarScreen({super.key});

  @override
  _CalendarScreenState createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> {
  String? householdID;
  DateTime _selectedDay = DateTime.now();
  DateTime _focusedDay = DateTime.now();
  List<Task> tasks = [];
  //--------- NOTIFICATION SETTINGS START HERE -----------
  bool _taskReminderEnabled = false;
  int _taskReminderLeadDays = 1;
  late Future<bool> _isLeaderFuture;
  late Future<String> _householdIdFuture;
  late Future<List<Map<String, dynamic>>> _householdMembersFuture;
  final user = FirebaseAuth.instance.currentUser!;

  @override
  void initState() {
    super.initState();
    _loadHouseholdID();
    _loadNotificationPrefs();
  }

  // Loads notification preferences from Firestore
  Future<void> _loadNotificationPrefs() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    // Fetch user document from Firestore
    final userDoc = await FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('notificationSettings')
        .doc('global')
        .get();
    final data = userDoc.data() ?? {};
    setState(() {
      _taskReminderEnabled = data['taskRemindersEnabled'] as bool? ?? false;
      _taskReminderLeadDays = data['taskReminderLeadDays'] as int? ?? 1;
    });
  }

  //--------- NOTIFICATION SETTINGS END HERE -----------

  // Loads the household ID from Firestore
  Future<void> _loadHouseholdID() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    final userDoc = await FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .get();
    setState(() {
      householdID = userDoc['householdID'] as String;
    });
    _loadTasks();
  }

  // Loads tasks for the current user from Firestore
  Future<void> _loadTasks() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null || householdID == null) return;

    final base = FirebaseFirestore.instance
        .collection('household')
        .doc(householdID!)
        .collection('members')
        .doc(user.uid)
        .collection('tasks');

    final snapshot = await base
        .orderBy('date', descending: false)
        .get();
    _householdIdFuture = _getHouseholdId();
    _isLeaderFuture =
        _householdIdFuture.then((householdId) => _checkIfLeader());
    _householdMembersFuture =
        _householdIdFuture.then((householdId) => _getHouseholdMembers());
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

    setState(() {
        tasks = snapshot.docs.map((doc) => Task.fromFirestore(doc)).toList();
    });
  }

  // Adds a new task to Firestore and schedules a notification if enabled
  Future<void> _addTask(Task task) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null || householdID == null) {
      print(' _addTask aborted: user or householdID is null');
      return;
    }

    final uid = user.uid;
    final hid = householdID!;
    print('Adding task $task for user: $uid, household: $hid');

    // Build base path to tasks collection
    final base = FirebaseFirestore.instance
        .collection('household')
        .doc(hid)
        .collection('members')
        .doc(uid);

    // Write task to Firestore
    final DocumentReference taskRef = await base
        .collection('tasks')
        .add(task.toFirestore());
    print('[CalendarScreen] added task with ID: ${taskRef.id}');
    
  //--------- NOTIFICATION SETTINGS START HERE -----------

    // Fire task created notification
    await LocalNotificationService.sendTaskNotification(
      title: 'New Task Created',
      body: 'A new task "${task.name}" has been created.',
      payload: taskRef.id,
    );

    final taskReminderEnabled = _taskReminderEnabled;
    final notificationLeadTime = _taskReminderLeadDays;
    
    // Schedule a task reminder if notifications are enabled
    if (taskReminderEnabled) {
      await LocalNotificationService.scheduleTaskReminder(
        taskRef.id, 
        task.name, 
        task.date, 
        notificationLeadTime,
      );
    } else {
      LocalNotificationService.cancelTaskReminder(taskRef.id);
      print('Cancelled reminder for task: ${task.name}');
    }
    print('Task added: ${task.toFirestore()}');
    _loadTasks();
  }

  // Updates an existing task and schedules/cancels notification based on updated settings
  Future<void> _updateTask(Task task) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null || householdID == null) return;

    final uid = user.uid;
    final hid = householdID!;

    final base = FirebaseFirestore.instance
        .collection('household')
        .doc(hid)
        .collection('members')
        .doc(uid);

    await base
        .collection('tasks')
        .doc(task.id)
        .update(task.toFirestore());
    print('[CalendarScreen] updated task with ID: ${task.id}');

    // Fire task updated notification
    await LocalNotificationService.sendTaskNotification(
      title: 'Task Updated',
      body: 'The task "${task.name}" has been updated.',
      payload: task.id,
    );
    
    final taskReminders = _taskReminderEnabled;
    final leadTime = _taskReminderLeadDays;

    // If reminders are enabled and task is not marked done
    if (taskReminders && !task.done) {
      // Schedule a notification
      await LocalNotificationService.scheduleTaskReminder(
        task.id, 
        task.name, 
        task.date, 
        leadTime
      );
      print('Reschedule reminder');
    } else {
      LocalNotificationService.cancelTaskReminder(task.id);
      print('Cancelled reminder for task: ${task.name}');
    }
    _loadTasks();
  }

    //--------- NOTIFICATION SETTINGS END HERE -----------

  // Filters tasks for the selected day
  List<Task> _getTasksForDay(DateTime day) {
    List<Task> tasksForDay =
        tasks.where((task) => isSameDay(task.date, day)).toList();
    tasksForDay.sort((a, b) {
      if (a.done == b.done) {
        return a.date.compareTo(b.date);
      } else if (a.done) {
        return 1;
      } else {
        return -1;
      }
    });
    return tasksForDay;
  }

  // Shows dialog to add a new task
  Future<void> _showAddTaskDialog() async {
    TextEditingController categoryController = TextEditingController();
    TextEditingController nameController = TextEditingController();
    TextEditingController pointsController = TextEditingController();
    
    // Ask user to select a date for the new task
    DateTime? selectedDate = await showDatePicker(
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

      // Update user's profile with both household ID and name
      await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
        'household_id': newHouseholdId,
        'householdName': 'My Household', // Add the name here too
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

  // We'll no longer need this method since its logic is now in _getHouseholdId
  Future<void> _createOrJoinHousehold() async {
    try {
      // This method is now included in _getHouseholdId
      // Keeping it as a placeholder to prevent breaking existing code
      print(
          'Using _createOrJoinHousehold is deprecated, functionality moved to _getHouseholdId');
    } catch (e) {
      print('Error in _createOrJoinHousehold: $e');
      rethrow;
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
        var data = doc.data();
        final dueDate = data['dueDate'];
        final acceptedAt = data['acceptedAt'];
        final startedAt = data['startedAt'];
        final completedAt = data['completed_at'];
        final bool done = data['done'] ?? false;

        // Default to veryEasy if no difficulty is specified
        TaskDifficulty difficulty = TaskDifficulty.veryEasy;

        // Try to determine difficulty from the data
        if (data['difficulty'] != null) {
          String difficultyStr =
              data['difficulty'].toString().toLowerCase().trim();
          try {
            difficulty = TaskDifficulty.values.firstWhere(
              (d) => d.name.toLowerCase() == difficultyStr,
              orElse: () => TaskDifficulty.veryEasy,
            );
          } catch (e) {
            print('Error parsing difficulty string: $e');
          }
        } else if (data['points'] != null) {
          try {
            int points = (data['points'] is num)
                ? (data['points'] as num).toInt()
                : int.tryParse(data['points'].toString()) ?? 1;
            difficulty = TaskDifficulty.fromValue(points);
          } catch (e) {
            print('Error parsing points: $e');
          }
        }

        return Task(
          id: doc.id,
          category: data['category'] ?? '',
          name: data['name'] ?? '',
          date: dueDate != null
              ? (dueDate as Timestamp).toDate()
              : DateTime.now(),
          difficulty: difficulty,
          timeEstimateMinutes: data['timeEstimate'] ?? 0,
          assignedTo: data['assignedTo'],
          acceptedAt:
              acceptedAt != null ? (acceptedAt as Timestamp).toDate() : null,
          startedAt:
              startedAt != null ? (startedAt as Timestamp).toDate() : null,
          completedAt:
              completedAt != null ? (completedAt as Timestamp).toDate() : null,
          done: done,
        );
      }).toList();
      yield tasks;
    }
  }

  List<Task> _filterTasksForDay(List<Task> tasks, DateTime day) {
    // Always show tasks on their due date, regardless of completion status
    return tasks.where((task) => isSameDay(task.date, day)).toList();
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
                }

                try {
                  final String assignedMemberId =
                      isLeader ? (selectedMemberId ?? user.uid) : user.uid;

                  await TaskService.addTask(
                    householdId: householdId,
                    memberId: assignedMemberId,
                    name: nameController.text.trim(),
                    category: "", // Pass empty string for category
                    dueDate: selectedDate,
                    difficulty: selectedDifficulty,
                    estimatedMinutes: timeEstimate,
                  );

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
                    int.parse(timeSpentController.text.trim());

                await TaskService.completeTask(
                  householdId: householdId,
                  memberId: FirebaseAuth.instance.currentUser!.uid,
                  taskId: task.id,
                  points: task.difficulty.points,
                  timeSpentMinutes: timeSpent,
                );

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
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop();
                },
                child: Text('Cancel'),
              ),
              TextButton(
                onPressed: () async {
                  if (categoryController.text.isNotEmpty &&
                      nameController.text.isNotEmpty &&
                      pointsController.text.isNotEmpty) {
                    int points = int.parse(pointsController.text);
                    Task newTask = Task(
                      id: '', // Firestore will generate the ID
                      householdID: householdID!,
                      category: categoryController.text,
                      name: nameController.text,
                      date: selectedDate,
                      points: points,
                    );
                    await _addTask(newTask);
                    Navigator.of(context).pop();
                  }
                },
                child: Text('Add'),
              ),
            ],
          );
        },
      );
    }
  }

  //--------- POINTS CUSTOMIZATION STARTS HERE -----------

  // Shows error dialog for invalid input
  void _showErrorDialog(String title, String message) {
    showDialog(
      context: context, 
      builder: (context) {
        return AlertDialog(
          title: Text(title),
          content: Text(message),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),  // Closes dialog
              child: Text('OK'),
            ),
          ],
        );
      },
    );
  }

  // Shows confirmation dialog before updating task points
  void _showConfirmationDialog(int oldPoints, int newPoints, Task task) {
    // Calculate current and updated total points
    final int currentTotal = _calculateCurrentTotal();
    final int updatedTotal = (currentTotal - oldPoints) + newPoints;
    
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('Confirm Points Change'),
          content: Text('Change points from $oldPoints to $newPoints?\n\n'
          'Your total will change from $currentTotal to $updatedTotal.',),
          actions: [
            // no button
            TextButton(
              onPressed: () {
                // Close dialog without saving
                Navigator.of(context).pop();
              },
              child: Text('No'),
            ),

            // yes button - update points
            TextButton(
              onPressed: () async {
                setState(() {
                  task.points = newPoints;
                });
                await _updateTask(task);
                await PointsService.recalcHouseholdPoints(task.householdID);
                Navigator.of(context).pop();
                Navigator.of(context).pop();
              },
              child: Text('Yes'),
            ),
          ],
        );
      },
    );
  }

  // Calculates the current total points for all tasks
  int _calculateCurrentTotal() {
    // Adds up points for all tasks
    return tasks.fold(0, (sum, t) => sum + t.points);
  }

  // Shows dialog to edit task points
  void _showEditTaskDialog(Task task) {
    final int oldPoints = task.points;
    // Controller to hold the new points value
    final TextEditingController pointsController = TextEditingController(
      text: task.points.toString()
    );

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('Edit Task Points'),
          // User can input new points value
          content: TextField(
            controller: pointsController,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(labelText: 'Points'),
          ),
          actions: [
            // Cancel button
            TextButton(
              onPressed: () {
                // Close diLog without saving
                Navigator.of(context).pop();
              },
              child: Text('Cancel'),
            ),
            // Save button
            TextButton(
              onPressed: () async {
                // Convert user input to int
                int? newPoints = int.tryParse(pointsController.text);
                
                // Check if invalid input like letters or blank
                if (newPoints == null) {
                  _showErrorDialog('Invalid points value!', 'Please enter a valid number');
                  return;
                }

                // Check if input is negative
                if (newPoints < 0) {
                  _showErrorDialog('Invalid points value!', 'Points cannot be negative');
                  return;
                }

                // Cap at 10 points
                if (newPoints > 10) {
                  _showErrorDialog('Invalid points value!', 'Points cannot exceed 10');
                  return;
                }

                // Update task points
                _showConfirmationDialog(oldPoints, newPoints, task);
              },
              child: Text('Save'),
            )
          ],
        );
      },
    );
  }

  //--------- POINTS CUSTOMIZATION START HERE -----------

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

                    if (task.done) {
                      taskStatus = 'Completed';
                      statusColor = Colors.green;
                    } else if (task.startedAt != null) {
                      taskStatus = 'In Progress';
                      statusColor = Colors.blue;
                    } else if (task.acceptedAt != null) {
                      taskStatus = 'Accepted';
                      statusColor = Colors.orange;
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
                                if (!task.done) ...[
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
                                  else if (task.startedAt == null)
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
                                    )
                                  else
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
                                ]
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
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: ElevatedButton(
                  onPressed: _showAddTaskDialog,
                  child: Text('Add Task'),
                ),
              ),
            ],
          ),
          TableCalendar(
            firstDay: DateTime.utc(2020, 1, 1),
            lastDay: DateTime.utc(2030, 12, 31),
            calendarFormat: CalendarFormat.week,
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
          ),
          ..._getTasksForDay(_selectedDay).map((task) => ListTile(
                leading: IconButton(
                  icon: Icon(
                    task.done
                        ? Icons.check_circle
                        : Icons.radio_button_unchecked,
                    color: task.done ? Colors.green : null,
                  ),
                  onPressed: () async {
                    setState(() {
                      task.done = !task.done;
                    });
                    await _updateTask(task);
                  },
                ),
                title: Text(task.name),
                subtitle: Text(task.category),
                trailing: IconButton(
                  icon: Icon(Icons.edit),
                  onPressed: () {
                    // Show dialog to edit task
                    _showEditTaskDialog(task);
                  }
                )
              )),
        ],
      ),
    );
  }
}
