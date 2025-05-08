import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class TaskHistory extends StatelessWidget {
  final String householdID;
  final String memberID;

  const TaskHistory({
    super.key,
    required this.householdID,
    required this.memberID,
  });

  Future<Map<String, dynamic>> fetchMemberStats() async {
    try {
      // First, update the household stats to ensure they're current
      await updateHouseholdStats(householdID);

      final tasksSnapshot = await FirebaseFirestore.instance
          .collection('households') // Changed from 'household' to 'households'
          .doc(householdID)
          .collection('members')
          .doc(memberID)
          .collection('tasks')
          .orderBy('completed_at', descending: true)
          .get();

      print('Found ${tasksSnapshot.docs.length} total tasks');

      int totalTasks = 0;
      int completedTasks = 0;
      int totalPoints = 0;

      for (var task in tasksSnapshot.docs) {
        Map<String, dynamic> data = task.data();
        print('Processing task: $data');

        if (data['completed_at'] != null) {
          totalTasks++;
          if (data['done'] == true) {
            completedTasks++;
            // Safely convert points to int, handling both String and num types
            var pointsValue = data['points'];
            if (pointsValue != null) {
              if (pointsValue is String) {
                totalPoints += int.tryParse(pointsValue) ?? 0;
              } else if (pointsValue is num) {
                totalPoints += pointsValue.toInt();
              }
            }
          }
        }
      }

      print('Completed tasks: $completedTasks, Total points: $totalPoints');

      double averagePoints =
          completedTasks > 0 ? totalPoints / completedTasks : 0;

      final stats = {
        'totalTasks': totalTasks,
        'completedTasks': completedTasks,
        'completionRate': totalTasks > 0
            ? '${((completedTasks / totalTasks) * 100).toStringAsFixed(1)}%'
            : '0%',
        'averagePoints': averagePoints.toStringAsFixed(1),
      };

      print('Calculated stats: $stats');
      return stats;
    } catch (e) {
      print('Error fetching member stats: $e');
      return {
        'totalTasks': 0,
        'completedTasks': 0,
        'completionRate': '0%',
        'averagePoints': '0.0',
      };
    }
  }

  // Method to update household stats after task changes
  Future<void> updateHouseholdStats(String householdID) async {
    try {
      final membersSnapshot = await FirebaseFirestore.instance
          .collection('households') // Changed from 'household' to 'households'
          .doc(householdID)
          .collection('members')
          .get();

      int totalTasks = 0;
      int completedTasks = 0;
      int totalPoints = 0;
      int totalTimeMinutes = 0;

      for (var member in membersSnapshot.docs) {
        final tasksSnapshot = await FirebaseFirestore.instance
            .collection(
                'households') // Changed from 'household' to 'households'
            .doc(householdID)
            .collection('members')
            .doc(member.id)
            .collection('tasks')
            .get();

        for (var task in tasksSnapshot.docs) {
          final data = task.data();
          if (data['completed_at'] != null) {
            totalTasks++;
            if (data['done'] == true) {
              completedTasks++;
              var points = data['points'];
              if (points != null) {
                totalPoints += (points is String)
                    ? int.tryParse(points) ?? 0
                    : points as int;
              }
              var timeSpent = data['timeSpent'];
              if (timeSpent != null) {
                totalTimeMinutes += (timeSpent is String)
                    ? int.tryParse(timeSpent) ?? 0
                    : timeSpent as int;
              }
            }
          }
        }
      }

      double completionRate =
          totalTasks > 0 ? (completedTasks / totalTasks) * 100 : 0.0;
      double avgPoints =
          completedTasks > 0 ? totalPoints / completedTasks : 0.0;
      int avgTimeMinutes =
          completedTasks > 0 ? totalTimeMinutes ~/ completedTasks : 0;

      // Update the household document with the new stats
      await FirebaseFirestore.instance
          .collection('households') // Changed from 'household' to 'households'
          .doc(householdID)
          .set({
        'completionRate': completionRate,
        'avgPoints': avgPoints,
        'avgTimeMinutes': avgTimeMinutes,
        'lastUpdated': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (e) {
      print('Error updating household stats: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.blue[50],
      appBar: AppBar(
        title: const Text("Task History"),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: FutureBuilder<Map<String, dynamic>>(
        future: fetchMemberStats(),
        builder: (context, statsSnapshot) {
          if (statsSnapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (statsSnapshot.hasError || statsSnapshot.data == null) {
            return const Center(child: Text("Error loading stats"));
          }

          final stats = statsSnapshot.data!;

          return Column(
            children: [
              // Task List Section
              Expanded(
                child: StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection(
                          'households') // Changed from 'household' to 'households'
                      .doc(householdID)
                      .collection('members')
                      .doc(memberID)
                      .collection('tasks')
                      .orderBy('completed_at', descending: true)
                      .snapshots(),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                      return const Center(child: Text("No tasks found"));
                    }

                    // Filter completed tasks in memory
                    final tasks = snapshot.data!.docs.where((doc) {
                      Map<String, dynamic> data =
                          doc.data() as Map<String, dynamic>;
                      return data['done'] == true;
                    }).toList();

                    if (tasks.isEmpty) {
                      return const Center(
                          child: Text("No completed tasks found"));
                    }

                    return Container(
                      margin: const EdgeInsets.symmetric(horizontal: 16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.1),
                            blurRadius: 6,
                            spreadRadius: 2,
                          ),
                        ],
                      ),
                      child: ListView.builder(
                        shrinkWrap: true,
                        itemCount: tasks.length,
                        itemBuilder: (context, index) {
                          Map<String, dynamic> taskData =
                              tasks[index].data() as Map<String, dynamic>;

                          final taskName = taskData['name'] ?? 'Unknown Task';
                          final points = taskData['points'] ?? 0;
                          final timestamp =
                              taskData['completed_at'] as Timestamp?;
                          final DateTime? completedAt = timestamp?.toDate();

                          // Format the date
                          final String formattedDate = completedAt != null
                              ? DateFormat('MMMM d, y • h:mm a')
                                  .format(completedAt)
                              : "Unknown Date";

                          return Container(
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.only(
                                topLeft: index == 0
                                    ? const Radius.circular(16)
                                    : Radius.zero,
                                topRight: index == 0
                                    ? const Radius.circular(16)
                                    : Radius.zero,
                                bottomLeft: index == tasks.length - 1
                                    ? const Radius.circular(16)
                                    : Radius.zero,
                                bottomRight: index == tasks.length - 1
                                    ? const Radius.circular(16)
                                    : Radius.zero,
                              ),
                            ),
                            child: ListTile(
                              contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 16, vertical: 8),
                              leading: CircleAvatar(
                                radius: 20,
                                backgroundColor: Colors.green[400],
                                child: Text(
                                  '$points',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              title: Text(
                                taskName,
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              subtitle: Text(
                                formattedDate,
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.grey[600],
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    );
                  },
                ),
              ),

              // Analytical Insights Section
              Container(
                margin: const EdgeInsets.all(16),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 6,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Analytical Insights',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: Colors.blue,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        _buildInsightCard(
                          icon: Icons.task_alt,
                          color: Colors.green,
                          label: 'Total Tasks',
                          value: '${stats['totalTasks']}',
                        ),
                        _buildInsightCard(
                          icon: Icons.check_circle,
                          color: Colors.orange,
                          label: 'Completed Tasks',
                          value: '${stats['completedTasks']}',
                        ),
                        _buildInsightCard(
                          icon: Icons.percent,
                          color: Colors.purple,
                          label: 'Completion Rate',
                          value: stats['completionRate'],
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        _buildInsightCard(
                          icon: Icons.trending_up,
                          color: Colors.blue,
                          label: 'Avg. Points',
                          value: stats['averagePoints'],
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  // Helper method to build individual insight cards
  Widget _buildInsightCard({
    required IconData icon,
    required Color color,
    required String label,
    required String value,
  }) {
    return Column(
      children: [
        CircleAvatar(
          radius: 30,
          backgroundColor: color.withOpacity(0.2),
          child: Icon(icon, color: color, size: 30),
        ),
        const SizedBox(height: 8),
        Text(
          value,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: 14,
            color: Colors.grey[600],
          ),
        ),
      ],
    );
  }
}
