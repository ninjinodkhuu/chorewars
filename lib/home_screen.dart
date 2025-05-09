import 'package:cw/Data/Task.dart';
import 'package:cw/SquareCard.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
class HomeScreen extends StatelessWidget {
  final user = FirebaseAuth.instance.currentUser!;
  List<Task> tasks = [
    Task(
      id: 'task_1',
      category: "Work",
      name: "Task 1",
      date: DateTime.now(),
      difficulty: TaskDifficulty.medium,  // Add difficulty here
      timeEstimateMinutes: 30,
    ),
    Task(
      id: 'task_2',
      category: "Home",
      name: "Task 2",
      date: DateTime.now().add(const Duration(days: 1)),
      difficulty: TaskDifficulty.easy,  // Add difficulty here
      timeEstimateMinutes: 45,
    ),
    Task(
      id: 'task_3',
      category: "Personal",
      name: "Task 3",
      date: DateTime.now().add(const Duration(days: 2)),
      difficulty: TaskDifficulty.hard,  // Add difficulty here
      timeEstimateMinutes: 60,
    ),
  ];


  HomeScreen({super.key});

  // sign user out method
  void signUserOut() {
    FirebaseAuth.instance.signOut();
  }

  @override
  Widget build(BuildContext context) {
    // Get theme colors, safely unwrapping nullable colors
    final theme = Theme.of(context);
    final primaryColor = theme.primaryColor;
    final backgroundColor = theme.scaffoldBackgroundColor;
    final textColor = theme.textTheme.bodyMedium!.color ?? Colors.black; // Fallback to black if null
    final unselectedColor = theme.unselectedWidgetColor ?? Colors.grey; // Fallback to grey if null

    return Container(
      color: backgroundColor,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 40),
          Padding(
            padding: const EdgeInsets.all(15.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "${'Hello ${user.email!}'}!",
                  style: TextStyle(
                    color: textColor,
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
            children: [
              const SizedBox(width: 5),
              _buildContainer(
                label: 'My Tasks',
                labelColor: textColor,
                backgroundColor: theme.cardColor,
              ),
              _buildContainer(
                label: 'In progress',
                labelColor: textColor,
                backgroundColor: theme.colorScheme.secondaryContainer,
              ),
              _buildContainer(
                label: 'Completed',
                labelColor: textColor,
                backgroundColor: theme.colorScheme.secondaryContainer,
              ),
              _buildContainer(
                label: 'Finances',
                labelColor: textColor,
                backgroundColor: theme.colorScheme.secondaryContainer,
              ),
            ],
          ),
          const SizedBox(height: 20),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: tasks
                  .map((task) => Container(
                        child: SquareCard(task: task),
                      ))
                  .toList(),
            ),
          ),
          const SizedBox(height: 50),
          Padding(
            padding: const EdgeInsets.only(left: 15.0),
            child: Text(
              'Progress',
              style: TextStyle(
                color: textColor,
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(15.0),
            child: Container(
              height: 65,
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: theme.cardColor,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        const SizedBox(width: 10),
                        _buildIconContainer(
                          icon: Icons.calendar_today,
                          backgroundColor: primaryColor,
                        ),
                        const SizedBox(width: 30),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              "Clean bathroom",
                              style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 18,
                                  color: Colors.black),
                            ),
                            const SizedBox(height: 0),
                            Text('2 days ago',
                                style: TextStyle(
                                  fontWeight: FontWeight.normal,
                                  fontSize: 15,
                                  color: theme.disabledColor,
                                ))
                          ],
                        ),
                      ],
                    ),
                  ]),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(top: 1.0, left: 15, right: 15),
            child: Container(
              height: 65,
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: theme.cardColor,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        const SizedBox(width: 10),
                        _buildIconContainer(
                          icon: Icons.calendar_today,
                          backgroundColor: primaryColor,
                        ),
                        const SizedBox(width: 30),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              "Buy Food",
                              style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 18,
                                  color: Colors.black),
                            ),
                            const SizedBox(height: 0),
                            Text('2 days ago',
                                style: TextStyle(
                                  fontWeight: FontWeight.normal,
                                  fontSize: 15,
                                  color: theme.disabledColor,
                                ))
                          ],
                        ),
                      ],
                    ),
                  ]),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContainer({
    required String label,
    required Color labelColor,
    required Color backgroundColor,
  }) {
    return Container(
      width: 100,
      height: 30,
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(25),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.5),
            blurRadius: 6,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Center(
        child: Text(
          label,
          style: TextStyle(
            color: labelColor,
            fontSize: 10,
            fontWeight: FontWeight.bold,
          ),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }

  Widget _buildIconContainer({
    required IconData icon,
    required Color backgroundColor,
  }) {
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Icon(
        icon,
        color: Colors.white,
        size: 20,
      ),
    );
  }
}
