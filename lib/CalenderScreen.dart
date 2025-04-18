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

  Future<void> _addTask(Task task) async {
    User? user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      String uid = user.uid;
      await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('tasks')
          .add(task.toFirestore());

      _loadTasks();
    }
  }

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

      _loadTasks();
    }
  }

  List<Task> _getTasksForDay(DateTime day) {
    List<Task> tasksForDay =
    tasks.where((task) => isSameDay(task.date, day)).toList();
    tasksForDay.sort((a, b) {
      if (a.done != b.done) return a.done ? 1 : -1;
      return b.priority.compareTo(a.priority); // Higher priority first
    });
    return tasksForDay;
  }

  Future<void> _showAddTaskDialog() async {
    TextEditingController categoryController = TextEditingController();
    TextEditingController nameController = TextEditingController();
    TextEditingController pointsController = TextEditingController();
    TextEditingController commentsController = TextEditingController();
    TextEditingController priorityController = TextEditingController();
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
                TextField(
                  controller: commentsController,
                  decoration: InputDecoration(labelText: 'Comments'),
                ),
                TextField(
                  controller: priorityController,
                  decoration: InputDecoration(labelText: 'Priority (1-5)'),
                  keyboardType: TextInputType.number,
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: Text('Cancel'),
              ),
              TextButton(
                onPressed: () async {
                  if (categoryController.text.isNotEmpty &&
                      nameController.text.isNotEmpty &&
                      pointsController.text.isNotEmpty &&
                      priorityController.text.isNotEmpty) {
                    int points = int.tryParse(pointsController.text) ?? 1;
                    int priority = int.tryParse(priorityController.text) ?? 1;
                    Task newTask = Task(
                      id: '',
                      category: categoryController.text,
                      name: nameController.text,
                      date: selectedDate,
                      points: points,
                      comments: commentsController.text,
                      priority: priority,
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

  @override
  Widget build(BuildContext context) {
    final DateFormat formatter = DateFormat('MMMM d, yyyy');
    final String formattedDate = formatter.format(_selectedDay);

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
            selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
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
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (task.comments.isNotEmpty) Text(task.comments),
                Text('Category: ${task.category}'),
                Text('Priority: ${task.priority}'),
              ],
            ),
          )),
        ],
      ),
    );
  }
}
