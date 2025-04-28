import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class Gamification extends StatelessWidget {
  const Gamification({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Leaderboard')),
      body: StreamBuilder(
        stream: FirebaseFirestore.instance.collection('households').doc('householdId').snapshots(),
        builder: (context, AsyncSnapshot<DocumentSnapshot> snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          var householdData = snapshot.data?.data() as Map<String, dynamic>? ?? {};
          var members = householdData['members'] as Map<String, dynamic>?;

          if (members == null || members.isEmpty) {
            return _buildPlaceholderLeaderboard();
          }

          List<Map<String, dynamic>> leaderboard = members.entries.map((entry) {
            var userData = entry.value as Map<String, dynamic>;
            return {
              'name': userData['name'] ?? 'Unavailable',
              'totalPoints': userData['totalPoints'] ?? 0,
            };
          }).toList();

          leaderboard.sort((a, b) => b['totalPoints'].compareTo(a['totalPoints']));

          return ListView.builder(
            itemCount: leaderboard.length,
            itemBuilder: (context, index) {
              var user = leaderboard[index];
              return ListTile(
                title: Text('${index + 1}. ${user['name']}'),
                subtitle: Text('Total Points: ${user['totalPoints']}'),
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildPlaceholderLeaderboard() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text('No active game period', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          SizedBox(height: 10),
          Text('Leaderboard will be available once a game starts.'),
        ],
      ),
    );
  }
}
