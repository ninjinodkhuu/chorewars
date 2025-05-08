import 'package:expenses_tracker/local_notifications.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'Data/Task.dart';
import 'services/points_service.dart';

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
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
    );

    if (selectedDate != null) {
      showDialog(
        context: context,
        builder: (context) {
          return AlertDialog(
            title: Text('Add Task'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: categoryController,
                  decoration: InputDecoration(labelText: 'Category'),
                ),
                TextField(
                  controller: nameController,
                  decoration: InputDecoration(labelText: 'Task Name'),
                ),
                TextField(
                  controller: pointsController,
                  decoration: InputDecoration(labelText: 'Task Points'),
                  keyboardType: TextInputType.number,
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
      body: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: Text(
                  formattedDate,
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
