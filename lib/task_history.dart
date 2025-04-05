import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart'; 

class TaskHistory extends StatelessWidget {
  final String householdID;
  final String memberID;

  const TaskHistory({super.key, required this.householdID, required this.memberID});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.blue[50],
      appBar: AppBar(
        title: const Text("Task History"),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('household')
            .doc(householdID)
            .collection('members')
            .doc(memberID)
            .collection('tasks')
            .orderBy('completed_at', descending: true) // Sort by latest completed task
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(child: Text("No completed tasks found"));
          }

          final tasks = snapshot.data!.docs;

          return Container(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
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
                final taskData = tasks[index];
                print('Task Data: ${taskData.data()}'); // Debugging: Print task data

                // Access fields from the document
                final taskName = taskData['name'] ?? 'Unknown Task'; // Use 'name' instead of 'task'
                final points = taskData['points'] ?? 0;
                final Timestamp? timestamp = taskData['completed_at']; // Ensure it's a Timestamp
                final DateTime? completedAt = timestamp?.toDate();
                
                // Format the date
                final String formattedDate = completedAt != null
                    ? DateFormat('MMMM d, y • h:mm a').format(completedAt)
                    : "Unknown Date";

                return Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.only(
                      topLeft: index == 0 ? const Radius.circular(16) : Radius.zero,
                      topRight: index == 0 ? const Radius.circular(16) : Radius.zero,
                      bottomLeft: index == tasks.length - 1 ? const Radius.circular(16) : Radius.zero,
                      bottomRight: index == tasks.length - 1 ? const Radius.circular(16) : Radius.zero,
                    ),
                  ),
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
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
    );
  }
}
