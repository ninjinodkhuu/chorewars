import 'package:cloud_firestore/cloud_firestore.dart';

class TaskService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  static Future<void> completeTask({
    required String householdId,
    required String memberId,
    required String taskId,
    required int points,
    required int timeSpentMinutes,
  }) async {
    try {
      // Update the task
      await _firestore
          .collection('household')
          .doc(householdId)
          .collection('members')
          .doc(memberId)
          .collection('tasks')
          .doc(taskId)
          .update({
        'done': true,
        'completed_at': FieldValue.serverTimestamp(),
        'points': points,
        'timeSpent': timeSpentMinutes,
      });

      // Update member's total points
      DocumentSnapshot memberDoc = await _firestore
          .collection('household')
          .doc(householdId)
          .collection('members')
          .doc(memberId)
          .get();

      int currentPoints = memberDoc.exists
          ? (memberDoc.data() as Map<String, dynamic>)['totalPoints'] ?? 0
          : 0;
      await _firestore
          .collection('household')
          .doc(householdId)
          .collection('members')
          .doc(memberId)
          .set({
        'totalPoints': currentPoints + points,
      }, SetOptions(merge: true));

      // Update household stats
      await updateHouseholdStats(householdId);
    } catch (e) {
      print('Error completing task: $e');
      rethrow;
    }
  }

  static Future<void> updateHouseholdStats(String householdId) async {
    try {
      // Get all members
      final membersSnapshot = await _firestore
          .collection('household')
          .doc(householdId)
          .collection('members')
          .get();

      int totalTasks = 0;
      int completedTasks = 0;
      int totalPoints = 0;
      int totalTimeMinutes = 0;

      // Aggregate stats from all members
      for (var member in membersSnapshot.docs) {
        final tasksSnapshot = await _firestore
            .collection('household')
            .doc(householdId)
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

      // Calculate averages
      double completionRate =
          totalTasks > 0 ? (completedTasks / totalTasks) * 100 : 0.0;
      double avgPoints =
          completedTasks > 0 ? totalPoints / completedTasks : 0.0;
      int avgTimeMinutes =
          completedTasks > 0 ? totalTimeMinutes ~/ completedTasks : 0;

      // Update household stats
      await _firestore.collection('household').doc(householdId).set({
        'completionRate': completionRate,
        'avgPoints': avgPoints,
        'avgTimeMinutes': avgTimeMinutes,
        'lastUpdated': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (e) {
      print('Error updating household stats: $e');
      rethrow;
    }
  }

  static Future<void> addTask({
    required String householdId,
    required String memberId,
    required String name,
    required String category,
    required DateTime dueDate,
  }) async {
    try {
      await _firestore
          .collection('household')
          .doc(householdId)
          .collection('members')
          .doc(memberId)
          .collection('tasks')
          .add({
        'name': name,
        'category': category,
        'dueDate': Timestamp.fromDate(dueDate),
        'done': false,
        'points': 0,
        'timeSpent': 0,
        'created_at': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      print('Error adding task: $e');
      rethrow;
    }
  }
}
