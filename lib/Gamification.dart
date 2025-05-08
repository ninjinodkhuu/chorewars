import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'task_history.dart';

// Prize Widget
class PrizeWidget extends StatelessWidget {
  final String householdID;

  const PrizeWidget({super.key, required this.householdID});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
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
          Center(
            child: Text(
              "PRIZE:",
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: Colors.blue[900],
              ),
            ),
          ),
          const SizedBox(height: 10),
          StreamBuilder<DocumentSnapshot>(
            stream: FirebaseFirestore.instance
                .collection('household')
                .doc(householdID)
                .collection('stake')
                .doc('prize')
                .snapshots(),
            builder: (context, snapshot) {
              final data = snapshot.data?.data() as Map<String, dynamic>?;
              final prize = data?['prize'] ?? '';
              final isPlaceholder = prize.isEmpty;

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    isPlaceholder
                        ? 'Pick a prize or punishment!'
                        : prize,
                    style: TextStyle(
                      fontSize: 16,
                      color: isPlaceholder ? Colors.grey : Colors.black87,
                      fontStyle: isPlaceholder ? FontStyle.italic : FontStyle.normal,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Center(
                    child: ElevatedButton.icon(
                      icon: const Icon(Icons.edit),
                      label: const Text('Add / Edit'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue[800],
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 12,
                        ),
                      ),
                      onPressed: () {
                        final controller = TextEditingController(text: prize);
                        showDialog(
                          context: context,
                          builder: (context) {
                            return AlertDialog(
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                              title: const Text(
                                'Set What’s at Stake',
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                              content: TextField(
                                controller: controller,
                                maxLines: 3,
                                decoration: const InputDecoration(
                                  hintText: 'Enter reward or consequence...',
                                  border: OutlineInputBorder(),
                                ),
                              ),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.pop(context),
                                  child: const Text('Cancel'),
                                ),
                                ElevatedButton(
                                  onPressed: () async {
                                    final prizeText = controller.text.trim();
                                    await FirebaseFirestore.instance
                                        .collection('household')
                                        .doc(householdID)
                                        .collection('stake')
                                        .doc('prize')
                                        .set({'prize': prizeText});
                                    Navigator.pop(context);
                                  },
                                  child: const Text('Save'),
                                ),
                              ],
                            );
                          },
                        );
                      },
                    ),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

// Leaderboard Widget
class LeaderboardWidget extends StatelessWidget {
  final String householdID;
  final List<DocumentSnapshot> users;

  const LeaderboardWidget({
    super.key,
    required this.householdID,
    required this.users,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(left: 16, right: 16, top: 0, bottom: 8),
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
        children: [
          // Custom Header Row
          Container(
            padding: const EdgeInsets.symmetric(vertical: 2, horizontal: 16),
            decoration: BoxDecoration(
              color: Colors.blue[900],
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(16),
                topRight: Radius.circular(16),
              ),
            ),
            child: const Center(
              child: Text(
                'Leaderboard',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 25,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          // Leaderboard List
          ClipRRect(
            borderRadius: const BorderRadius.only(
              bottomLeft: Radius.circular(16),
              bottomRight: Radius.circular(16),
            ),
            child: ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: users.length,
              itemBuilder: (context, index) {
                final userData = users[index];
                final memberID = userData.id;
                final name = userData['name'] ?? 'Unavailable';
                final totalPoints = userData['totalPoints'] ?? 0;
                final rank = index + 1;

                return Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    border: Border(
                      bottom: index == users.length - 1
                          ? BorderSide.none
                          : BorderSide(
                              color: Colors.grey[300]!,
                              width: 1,
                            ),
                    ),
                  ),
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 12),
                    leading: CircleAvatar(
                      radius: 20,
                      backgroundColor: rank == 1
                          ? Colors.amber
                          : rank == 2
                              ? Colors.grey
                              : rank == 3
                                  ? Colors.brown
                                  : Colors.blue,
                      child: Text(
                        '$rank',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    title: Row(
                      children: [
                        Text(
                          name,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(width: 13),
                        Text(
                          '$totalPoints points',
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                    trailing: IconButton(
                      icon: const Icon(Icons.arrow_forward_ios, size: 20),
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => TaskHistory(
                              memberID: memberID,
                              householdID: householdID,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

// Analytical Insights Widget
class AnalyticalInsightsWidget extends StatelessWidget {
  final String householdID;
  final Future<Map<String, dynamic>> statsFuture;

  const AnalyticalInsightsWidget({
    super.key,
    required this.householdID,
    required this.statsFuture,
  });

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Map<String, dynamic>>(
      future: statsFuture, // Use the passed future
      builder: (context, statsSnapshot) {
        if (statsSnapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final stats = statsSnapshot.data ??
            {
              'completionRate': 0.0,
              'avgDifficulty': 0.0,
              'avgTime': const Duration(minutes: 0),
            };

        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.blue[50],
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
                    icon: Icons.check_circle,
                    color: Colors.green,
                    label: 'Completion Rate',
                    value: '${stats['completionRate'].toStringAsFixed(1)}%',
                  ),
                  _buildInsightCard(
                    icon: Icons.trending_up,
                    color: Colors.orange,
                    label: 'Avg. Points',
                    value: '${stats['avgDifficulty'].toStringAsFixed(1)}',
                  ),
                  _buildInsightCard(
                    icon: Icons.timer,
                    color: Colors.purple,
                    label: 'Avg. Time',
                    value:
                        '${(stats['avgTime'] as Duration).inHours}h ${(stats['avgTime'] as Duration).inMinutes.remainder(60)}m',
                  ),
                ],
              ),
            ],
          ),
        );
      },
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

// Main Gamification Page
class Gamification extends StatelessWidget {
  const Gamification({super.key});

  // the updateTotalPoints method 
  Future<void> updateTotalPoints(String householdID) async {
    try {
      final membersSnapshot = await FirebaseFirestore.instance
          .collection('household')
          .doc(householdID)
          .collection('members')
          .get();

      for (final memberDoc in membersSnapshot.docs) {
        final memberID = memberDoc.id;
        final tasksSnapshot = await FirebaseFirestore.instance
            .collection('household')
            .doc(householdID)
            .collection('members')
            .doc(memberID)
            .collection('tasks')
            .get();

        int totalPoints = 0;
        for (final taskDoc in tasksSnapshot.docs) {
          var pointsValue = taskDoc['points'];
          if (pointsValue != null) {
            if (pointsValue is String) {
              totalPoints += int.tryParse(pointsValue) ?? 0;
            } else if (pointsValue is num) {
              totalPoints += pointsValue.toInt();
            }
          }
        }

        await FirebaseFirestore.instance
            .collection('household')
            .doc(householdID)
            .collection('members')
            .doc(memberID)
            .update({'totalPoints': totalPoints});
      }
    } catch (e) {
      print('Error updating total points: $e');
    }
  }

  // calculateStats method
  Future<Map<String, dynamic>> calculateStats(String householdID) async {
    try {
      final membersSnapshot = await FirebaseFirestore.instance
          .collection('household')
          .doc(householdID)
          .collection('members')
          .get();

      int totalTasks = 0;
      int completedTasksCount = 0;
      int totalPoints = 0;
      int totalTimeSpent = 0;

      for (var member in membersSnapshot.docs) {
        final tasksSnapshot = await FirebaseFirestore.instance
            .collection('household')
            .doc(householdID)
            .collection('members')
            .doc(member.id)
            .collection('tasks')
            .get();

        final tasks = tasksSnapshot.docs;

        for (var task in tasks) {
          Map<String, dynamic> data = task.data();
          print('Processing task: $data');

          if (data['completed_at'] != null) {
            totalTasks++;
            if (data['done'] == true) {
              completedTasksCount++;

              var pointsValue = data['points'];
              if (pointsValue != null) {
                if (pointsValue is String) {
                  totalPoints += int.tryParse(pointsValue) ?? 0;
                } else if (pointsValue is num) {
                  totalPoints += pointsValue.toInt();
                }
              }

              var timeValue = data['timeSpent'];
              if (timeValue != null) {
                if (timeValue is String) {
                  totalTimeSpent += int.tryParse(timeValue) ?? 0;
                } else if (timeValue is num) {
                  totalTimeSpent += timeValue.toInt();
                }
              }
            }
          }
        }
      }

      final completionRate =
          totalTasks > 0 ? (completedTasksCount / totalTasks) * 100 : 0.0;
      final avgPoints =
          completedTasksCount > 0 ? totalPoints / completedTasksCount : 0.0;
      final avgTime = completedTasksCount > 0
          ? Duration(minutes: totalTimeSpent ~/ completedTasksCount)
          : const Duration(minutes: 0);

      return {
        'completionRate': completionRate,
        'avgDifficulty': avgPoints,
        'avgTime': avgTime,
      };
    } catch (e) {
      print('Error calculating stats: $e');
      return {
        'completionRate': 0.0,
        'avgDifficulty': 0.0,
        'avgTime': const Duration(minutes: 0),
      };
    }
  }

  @override
  Widget build(BuildContext context) {
    const String householdID = '1';

    return Scaffold(
      backgroundColor: Colors.blue[25],
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: FutureBuilder<void>(
        future: updateTotalPoints(householdID),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          return StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('household')
                .doc(householdID)
                .collection('members')
                .orderBy('totalPoints', descending: true)
                .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                return const Center(child: Text('No members found'));
              }

              final users = snapshot.data!.docs;

              return SingleChildScrollView(
                child: Column(
                  children: [
                    const PrizeWidget(householdID: householdID),
                    LeaderboardWidget(householdID: householdID, users: users),
                    // Pass the future of calculateStats to the AnalyticalInsightsWidget
                    AnalyticalInsightsWidget(householdID: householdID, statsFuture: calculateStats(householdID)),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}
