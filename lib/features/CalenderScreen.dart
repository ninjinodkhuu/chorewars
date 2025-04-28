import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:intl/intl.dart';
import '../Models/task_model.dart';

class CalendarScreen extends StatefulWidget {
  const CalendarScreen({super.key});

  @override
  _CalendarScreenState createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> {
  DateTime _selectedDay = DateTime.now();
  DateTime _focusedDay = DateTime.now();

  List<Task> tasks = [
    Task(category: "Work", name: "Task 1", date: DateTime.now()),
    Task(
        category: "Home",
        name: "Task 2",
        date: DateTime.now().add(const Duration(days: 1))),
    Task(
        category: "Personal",
        name: "Task 3",
        date: DateTime.now().add(const Duration(days: 2))),
  ];

  List<Task> _getTasksForDay(DateTime day) {
    return tasks.where((task) => isSameDay(task.date, day)).toList();
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
                  onPressed: () {
                    // Add task logic here
                  },
                  child: const Text('Add Task'),
                ),
              ),
            ],
          ),
          TableCalendar(
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
          ),
          Expanded(
            child: ListView.builder(
              itemCount: _getTasksForDay(_selectedDay).length,
              itemBuilder: (context, index) {
                final task = _getTasksForDay(_selectedDay)[index];
                return ListTile(
                  title: Text(task.name),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
