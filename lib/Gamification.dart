import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'task_history.dart';

class Gamification extends StatelessWidget {
  const Gamification({super.key});

  Future<String> _getHouseholdId() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      throw Exception('User not logged in');
    }

    final userDoc = await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .get();

    if (userDoc.exists) {
      return userDoc.get('household_id') ?? '';
    }
    return '';
  }

  // Optimized method to fetch household stats
  Stream<Map<String, dynamic>> streamHouseholdStats(String householdID) {
    // Trigger an update of household stats when this page is viewed
    _updateHouseholdStats(householdID);

    return FirebaseFirestore.instance
        .collection('households') // Fixed collection name
        .doc(householdID)
        .snapshots()
        .map((snapshot) {
      if (!snapshot.exists) {
        return {
          'completionRate': 0.0,
          'avgPoints': 0.0,
          'avgTimeMinutes': 0,
        };
      }

      final data = snapshot.data()!;
      return {
        'completionRate': data['completionRate'] ?? 0.0,
        'avgPoints': data['avgPoints'] ?? 0.0,
        'avgTimeMinutes': data['avgTimeMinutes'] ?? 0,
      };
    });
  }

  // Method to update household stats after task changes
  Future<void> _updateHouseholdStats(String householdID) async {
    try {
      final membersSnapshot = await FirebaseFirestore.instance
          .collection('households')
          .doc(householdID)
          .collection('members')
          .get();

      double totalCompletionRate = 0.0;
      int memberCount = 0;

      for (var member in membersSnapshot.docs) {
        // Get all tasks for this member
        final tasksSnapshot = await FirebaseFirestore.instance
            .collection('households')
            .doc(householdID)
            .collection('members')
            .doc(member.id)
            .collection('tasks')
            .get();

        int memberCompletedTasks = 0;
        int memberTotalTasks = 0;
        int memberTotalPoints = 0;
        int memberTimeMinutes = 0;

        // Calculate member stats from tasks
        for (var task in tasksSnapshot.docs) {
          final taskData = task.data();
          memberTotalTasks++;

          if (taskData['done'] == true && taskData['completed_at'] != null) {
            memberCompletedTasks++;
            // Sum up points only from completed tasks
            memberTotalPoints += (taskData['points'] ?? 0) as int;
            memberTimeMinutes += (taskData['timeSpent'] ?? 0) as int;
          }
        }

        // Only update stats if member has tasks
        if (memberTotalTasks > 0) {
          memberCount++;
          totalCompletionRate += memberTotalTasks > 0
              ? (memberCompletedTasks / memberTotalTasks) * 100
              : 0.0;

          // Update member document with recalculated stats
          await FirebaseFirestore.instance
              .collection('households')
              .doc(householdID)
              .collection('members')
              .doc(member.id)
              .set({
            'totalPoints': memberTotalPoints,
            'completedTasks': memberCompletedTasks,
            'totalTasks': memberTotalTasks,
            'totalTimeMinutes': memberTimeMinutes,
          }, SetOptions(merge: true));
        }
      }

      // Calculate and update household averages
      double completionRate =
          memberCount > 0 ? totalCompletionRate / memberCount : 0.0;

      await FirebaseFirestore.instance
          .collection('households')
          .doc(householdID)
          .set({
        'completionRate': completionRate,
        'lastUpdated': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (e) {
      print('Error updating household stats: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<String>(
      future: _getHouseholdId(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return const Center(child: Text('No household found'));
        }

        final householdID = snapshot.data!;

        return Scaffold(
          backgroundColor: Colors.blue[50],
          appBar: AppBar(
            backgroundColor: Colors.transparent,
            elevation: 0,
          ),
          body: SingleChildScrollView(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('households') // Fixed collection name
                  .doc(householdID)
                  .collection('members')
                  .orderBy('totalPoints', descending: true)
                  .snapshots(),
              builder: (context, membersSnapshot) {
                if (membersSnapshot.connectionState ==
                    ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (!membersSnapshot.hasData ||
                    membersSnapshot.data!.docs.isEmpty) {
                  return const Center(child: Text('No members found'));
                }

                final users = membersSnapshot.data!.docs;

                return Column(
                  children: [
                    // Leaderboard Container
                    Container(
                      margin: const EdgeInsets.only(
                          left: 16, right: 16, top: 16, bottom: 8),
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
                            padding: const EdgeInsets.symmetric(
                                vertical: 12, horizontal: 16),
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
                          ListView.builder(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: users.length,
                            itemBuilder: (context, index) {
                              final userData =
                                  users[index].data() as Map<String, dynamic>;
                              final memberID = users[index].id;
                              final name = userData['name'] ?? 'Unknown';
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
                                            ? Colors.grey[400]
                                            : rank == 3
                                                ? Colors.brown[300]
                                                : Colors.blue[200],
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
                                    icon: const Icon(Icons.arrow_forward_ios,
                                        size: 20),
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
                        ],
                      ),
                    ),

                    // Analytical Insights Container
                    StreamBuilder<Map<String, dynamic>>(
                      stream: streamHouseholdStats(householdID),
                      builder: (context, statsSnapshot) {
                        if (statsSnapshot.connectionState ==
                            ConnectionState.waiting) {
                          return const Center(
                              child: CircularProgressIndicator());
                        }

                        final stats = statsSnapshot.data ??
                            {
                              'completionRate': 0.0,
                              'avgPoints': 0.0,
                              'avgTimeMinutes': 0,
                            };

                        return Container(
                          margin: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 8),
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
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  _buildInsightCard(
                                    icon: Icons.check_circle,
                                    color: Colors.green,
                                    label: 'Completion Rate',
                                    value:
                                        '${(stats['completionRate'] as double).toStringAsFixed(1)}%',
                                  ),
                                  _buildInsightCard(
                                    icon: Icons.trending_up,
                                    color: Colors.orange,
                                    label: 'Avg. Points',
                                    value: (stats['avgPoints'] as double)
                                        .toStringAsFixed(1),
                                  ),
                                  _buildInsightCard(
                                    icon: Icons.timer,
                                    color: Colors.purple,
                                    label: 'Avg. Time',
                                    value:
                                        '${(stats['avgTimeMinutes'] as num).toInt()}m',
                                  ),
                                ],
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ],
                );
              },
            ),
          ),
        );
      },
    );
  }

  Widget _buildInsightCard({
    required IconData icon,
    required Color color,
    required String label,
    required String value,
  }) {
    return Column(
      children: [
        CircleAvatar(
          radius: 25,
          backgroundColor: color.withOpacity(0.2),
          child: Icon(icon, color: color, size: 25),
        ),
        const SizedBox(height: 8),
        Text(
          label,
          style: TextStyle(
            fontSize: 14,
            color: Colors.grey[600],
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }
}
