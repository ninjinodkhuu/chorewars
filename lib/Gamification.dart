import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cw/task_history.dart';

class Gamification extends StatelessWidget {
  const Gamification({super.key});

  // Function to calculate and update total points for all members
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
          totalPoints += (taskDoc['points'] as int?) ?? 0;
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
        future: updateTotalPoints(householdID), // Update points before displaying leaderboard
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

              return Column(
                children: [
                  // Leaderboard Container
                  Container(
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
                          child: Center( 
                            child: Text(
                              'Leaderboard',
                              style: const TextStyle(
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
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
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
                                      const SizedBox(width: 13), // Space between name and points
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
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  }
}
