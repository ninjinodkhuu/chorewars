import 'package:cw/local_notifications.dart';
import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'Data/Task.dart';

class CalendarScreen extends StatefulWidget {
  const CalendarScreen({super.key});

  @override
  _CalendarScreenState createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> {
  DateTime _selectedDay = DateTime.now();
  DateTime _focusedDay = DateTime.now();
  List<Task> tasks = [];

  @override
  void initState() {
    super.initState();
    _loadTasks();
  }

  // Loads tasks for the current user from Firestore
  Future<void> _loadTasks() async {
    User? user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      String uid = user.uid;
      QuerySnapshot snapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('tasks')
          .orderBy('date', descending: false)
          .get();

      setState(() {
        tasks = snapshot.docs.map((doc) => Task.fromFirestore(doc)).toList();
      });
    }
  }

  // Adds a new task to Firestore and schedules a notification if enabled
  Future<void> _addTask(Task task) async {
    User? user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      String uid = user.uid;
      // Adds task and retrieves generated document ID
      DocumentReference taskRef = await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('tasks')
          .add(task.toFirestore());
      
      // Load the user's notification settings
      DocumentSnapshot userSnapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .get();

      final userData = userSnapshot.data() as Map<String, dynamic>?;
      final notificationSettings = userData?['notificationSettings'] as Map<String, dynamic>?;
      
      bool taskReminderEnabled = notificationSettings?['taskReminders'] ?? true;
      int notificationLeadTime = notificationSettings?['notificationLeadTime'] ?? 1;
      
      // Schedule a task reminder if notifications are enabled
      if (taskReminderEnabled) {
        LocalNotificationService.scheduleTaskReminder(
          taskRef.id, 
          task.name, 
          task.date, 
          notificationLeadTime,
        );
      }
      _loadTasks();
    }
  }

  // Updates an existing task and schedules/cancels notification based on updated settings
  Future<void> _updateTask(Task task) async {
    User? user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      String uid = user.uid;
      await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('tasks')
          .doc(task.id)
          .update(task.toFirestore());

      DocumentSnapshot snapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .get();

      final data = snapshot.data() as Map<String, dynamic>?;
      final notificationSettings = data?['notificationSettings'] as Map<String, dynamic>?;
      bool taskReminders = notificationSettings?['taskReminders'] ?? true;
      int leadTime = notificationSettings?['notificationLeadTime'] ?? 1;

      // If reminders are enabled and task is not marked done
      if (taskReminders && !task.done) {
        // Schedule a notification
        LocalNotificationService.scheduleTaskReminder(
          task.id, 
          task.name, 
          task.date, 
          leadTime
        );
      } else {
        LocalNotificationService.cancelTaskReminder(task.id);
      }

      _loadTasks();
    }
  }

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
            title: const Text('Add Task'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: categoryController,
                  decoration: const InputDecoration(labelText: 'Category'),
                ),
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(labelText: 'Task Name'),
                ),
                TextField(
                  controller: pointsController,
                  decoration: const InputDecoration(labelText: 'Task Points'),
                  keyboardType: TextInputType.number,
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop();
                },
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () async {
                  if (categoryController.text.isNotEmpty &&
                      nameController.text.isNotEmpty &&
                      pointsController.text.isNotEmpty) {
                    int points = int.parse(pointsController.text);
                    Task newTask = Task(
                      id: '', // Firestore will generate the ID
                      category: categoryController.text,
                      name: nameController.text,
                      date: selectedDate,
                      points: points,
                    );
                    await _addTask(newTask);
                    Navigator.of(context).pop();
                  }
                },
                child: const Text('Add'),
              ),
            ],
          );
        },
      );
    }
  }

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
              child: const Text('OK'),
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
          title: const Text('Confirm Points Change'),
          content: Text('Change points from $oldPoints to $newPoints?\n\n'
          'Your total will change from $currentTotal to $updatedTotal.',),
          actions: [
            // no button
            TextButton(
              onPressed: () {
                // Close dialog without saving
                Navigator.of(context).pop();
              },
              child: const Text('No'),
            ),

            // yes button - update points
            TextButton(
              onPressed: () async {
                setState(() {
                  task.points = newPoints;
                });
                await _updateTask(task);
                Navigator.of(context).pop();
                Navigator.of(context).pop();
              },
              child: const Text('Yes'),
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
          title: const Text('Edit Task Points'),
          // User can input new points value
          content: TextField(
            controller: pointsController,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: 'Points'),
          ),
          actions: [
            // Cancel button
            TextButton(
              onPressed: () {
                // Close diLog without saving
                Navigator.of(context).pop();
              },
              child: const Text('Cancel'),
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
              child: const Text('Save'),
            )
          ],
        );
      },
    );
  }

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
                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: ElevatedButton(
                  onPressed: _showAddTaskDialog,
                  child: const Text('Add Task'),
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
                  icon: const Icon(Icons.edit),
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
