import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cw/features/task_history.dart';

class Gamification extends StatelessWidget {
  const Gamification({super.key});

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
    final theme = Theme.of(context); 

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor, 
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: theme.textTheme.bodyLarge?.color, 
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

              return Column(
                children: [
                  // Prize section
                  Container(
                    margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: theme.cardColor, // 🌙 Themed
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.05), // 🌙 Slight
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
                            "What's at stake:",
                            style: theme.textTheme.titleLarge?.copyWith( // 🌙 Themed
                              fontWeight: FontWeight.bold,
                              color: theme.primaryColorDark,
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
                                    color: isPlaceholder
                                        ? theme.hintColor // 🌙 Themed
                                        : theme.textTheme.bodyMedium?.color,
                                    fontStyle: isPlaceholder ? FontStyle.italic : FontStyle.normal,
                                  ),
                                ),
                                const SizedBox(height: 12),
                                Center(
                                  child: ElevatedButton.icon(
                                    icon: const Icon(Icons.edit),
                                    label: const Text('Add / Edit'),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: theme.colorScheme.primary, // 🌙 Themed
                                      foregroundColor: theme.colorScheme.onPrimary, // 🌙 Themed
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
                                            backgroundColor: theme.cardColor, // 🌙 Themed
                                            shape: RoundedRectangleBorder(
                                              borderRadius: BorderRadius.circular(16),
                                            ),
                                            title: Text(
                                              'Set What’s at Stake',
                                              style: theme.textTheme.titleMedium?.copyWith(
                                                fontWeight: FontWeight.bold,
                                              ),
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
                  ),

                  // Leaderboard section
                  Container(
                    margin: const EdgeInsets.only(left: 16, right: 16, bottom: 8),
                    decoration: BoxDecoration(
                      color: theme.cardColor, // 🌙 Themed
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.05), // 🌙 Themed
                          blurRadius: 6,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        // Header
                        Container(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.primary, // 🌙 Themed
                            borderRadius: const BorderRadius.only(
                              topLeft: Radius.circular(16),
                              topRight: Radius.circular(16),
                            ),
                          ),
                          child: Center(
                            child: Text(
                              'Leaderboard',
                              style: theme.textTheme.headlineSmall?.copyWith( // 🌙 Themed
                                color: theme.colorScheme.onPrimary,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                        // List
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
                                  color: theme.cardColor, // 🌙 Themed
                                  border: Border(
                                    bottom: index == users.length - 1
                                        ? BorderSide.none
                                        : BorderSide(
                                            color: theme.dividerColor, // 🌙 Themed
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
                                                : theme.colorScheme.primary, // 🌙 Themed
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
                                        style: theme.textTheme.bodyLarge?.copyWith(
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      const SizedBox(width: 13),
                                      Text(
                                        '$totalPoints points',
                                        style: theme.textTheme.bodyMedium?.copyWith(
                                          color: theme.hintColor, // 🌙 Themed
                                        ),
                                      ),
                                    ],
                                  ),
                                  trailing: IconButton(
                                    icon: const Icon(Icons.arrow_forward_ios, size: 20),
                                    color: theme.iconTheme.color, // 🌙 Themed
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
