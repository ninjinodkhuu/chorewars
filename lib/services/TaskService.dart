import 'package:cloud_firestore/cloud_firestore.dart';
import '../Data/Task.dart';

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
      // First check if the task is already completed
      final taskDoc = await _firestore
          .collection('households')
          .doc(householdId)
          .collection('members')
          .doc(memberId)
          .collection('tasks')
          .doc(taskId)
          .get();

      if (!taskDoc.exists) {
        throw Exception('Task not found');
      }

      final taskData = taskDoc.data()!;
      if (taskData['done'] == true) {
        throw Exception('Task is already completed');
      }

      // Get the member document to update their stats
      DocumentSnapshot memberDoc = await _firestore
          .collection('households')
          .doc(householdId)
          .collection('members')
          .doc(memberId)
          .get();

      // Get current stats, defaulting to 0 if not set
      Map<String, dynamic> memberData =
          memberDoc.exists ? memberDoc.data() as Map<String, dynamic> : {};
      int currentPoints = memberData['totalPoints'] ?? 0;
      int completedTasks = memberData['completedTasks'] ?? 0;
      int totalTasks = memberData['totalTasks'] ?? 0;

      // Update the member's stats
      await _firestore
          .collection('households')
          .doc(householdId)
          .collection('members')
          .doc(memberId)
          .set({
        'totalPoints': currentPoints + points,
        'completedTasks': completedTasks + 1,
        'totalTasks': totalTasks + 1,
      }, SetOptions(merge: true));

      // Update the task
      await _firestore
          .collection('households')
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

      // Update household stats
      await updateHouseholdStats(householdId);
    } catch (e) {
      print('Error completing task: $e');
      rethrow;
    }
  }

  static Future<void> updateHouseholdStats(String householdId) async {
    try {
      // Get all users with this household_id
      final usersSnapshot = await _firestore
          .collection('users')
          .where('household_id', isEqualTo: householdId)
          .get();

      double totalCompletionRate = 0.0;
      double totalAvgPoints = 0.0;
      int totalAvgTimeMinutes = 0;
      int memberCount = 0;

      // Calculate meta-averages from member stats
      for (var userDoc in usersSnapshot.docs) {
        final tasksSnapshot = await _firestore
            .collection(
                'households') // Changed from 'household' to 'households'
            .doc(householdId)
            .collection('members')
            .doc(userDoc.id)
            .collection('tasks')
            .get();

        int memberTotalTasks = 0;
        int memberCompletedTasks = 0;
        int memberTotalPoints = 0;
        int memberTotalTimeMinutes = 0;

        // Calculate individual member stats
        for (var task in tasksSnapshot.docs) {
          final data = task.data();
          if (data['completed_at'] != null) {
            memberTotalTasks++;
            if (data['done'] == true) {
              memberCompletedTasks++;
              var points = data['points'];
              if (points != null) {
                memberTotalPoints += (points is String)
                    ? int.tryParse(points) ?? 0
                    : points as int;
              }
              var timeSpent = data['timeSpent'];
              if (timeSpent != null) {
                memberTotalTimeMinutes += (timeSpent is String)
                    ? int.tryParse(timeSpent) ?? 0
                    : timeSpent as int;
              }
            }
          }
        }

        // Only include members who have tasks
        if (memberTotalTasks > 0) {
          memberCount++;
          // Add this member's rates to the totals
          totalCompletionRate += memberTotalTasks > 0
              ? (memberCompletedTasks / memberTotalTasks) * 100
              : 0.0;
          totalAvgPoints += memberCompletedTasks > 0
              ? memberTotalPoints / memberCompletedTasks
              : 0.0;
          totalAvgTimeMinutes += memberCompletedTasks > 0
              ? memberTotalTimeMinutes ~/ memberCompletedTasks
              : 0;
        }
      }

      // Calculate final household averages (average of member averages)
      double completionRate =
          memberCount > 0 ? totalCompletionRate / memberCount : 0.0;
      double avgPoints = memberCount > 0 ? totalAvgPoints / memberCount : 0.0;
      int avgTimeMinutes =
          memberCount > 0 ? totalAvgTimeMinutes ~/ memberCount : 0;

      // Update household stats
      await _firestore.collection('households').doc(householdId).set({
        // Changed from 'household' to 'households'
        'completionRate': completionRate,
        'avgPoints': avgPoints,
        'avgTimeMinutes': avgTimeMinutes,
        'lastUpdated': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      print(
          'Updated household stats - completionRate: $completionRate, avgPoints: $avgPoints, avgTime: $avgTimeMinutes');
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
    required TaskDifficulty difficulty,
    required int estimatedMinutes,
  }) async {
    try {
      print('Adding task with parameters:');
      print('householdId: $householdId');
      print('memberId: $memberId');
      print('name: $name');
      print('category: $category');
      print('dueDate: $dueDate');
      print('difficulty: ${difficulty.name}');
      print('estimatedMinutes: $estimatedMinutes');

      DocumentReference taskRef = await _firestore
          .collection('households')
          .doc(householdId)
          .collection('members')
          .doc(memberId)
          .collection('tasks')
          .add({
        'name': name,
        'category': category,
        'dueDate': Timestamp.fromDate(dueDate),
        'done': false,
        'points': difficulty.points,
        'timeEstimate': estimatedMinutes,
        'difficulty': difficulty.name,
        'created_at': FieldValue.serverTimestamp(),
      });

      print('Task added successfully with ID: ${taskRef.id}');
    } catch (e) {
      print('Error adding task: $e');
      rethrow;
    }
  }

  static Future<void> acceptTask({
    required String householdId,
    required String memberId,
    required String taskId,
  }) async {
    try {
      // Update the task with acceptance time and 7-day expiration date
      await _firestore
          .collection('households')
          .doc(householdId)
          .collection('members')
          .doc(memberId)
          .collection('tasks')
          .doc(taskId)
          .update({
        'acceptedAt': FieldValue.serverTimestamp(),
        'status': 'accepted',
        'expiryDate': Timestamp.fromDate(
          DateTime.now().add(const Duration(days: 7)),
        ),
      });
    } catch (e) {
      print('Error accepting task: $e');
      rethrow;
    }
  }

  static Future<void> startTask({
    required String householdId,
    required String memberId,
    required String taskId,
  }) async {
    try {
      await _firestore
          .collection('households') // Changed from 'household' to 'households'
          .doc(householdId)
          .collection('members')
          .doc(memberId)
          .collection('tasks')
          .doc(taskId)
          .update({
        'startedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      print('Error starting task: $e');
      rethrow;
    }
  }

  /// Marks a task as expired and updates relevant statistics
  static Future<void> expireTask({
    required String householdId,
    required String memberId,
    required String taskId,
  }) async {
    try {
      // Get the member document to update their stats
      DocumentSnapshot memberDoc = await _firestore
          .collection('households')
          .doc(householdId)
          .collection('members')
          .doc(memberId)
          .get();

      // Get current stats, defaulting to 0 if not set
      Map<String, dynamic> memberData =
          memberDoc.exists ? memberDoc.data() as Map<String, dynamic> : {};
      int totalTasks = memberData['totalTasks'] ?? 0;
      int expiredTasks = memberData['expiredTasks'] ?? 0;

      // Update the member's stats
      await _firestore
          .collection('households')
          .doc(householdId)
          .collection('members')
          .doc(memberId)
          .set({
        'totalTasks': totalTasks + 1,
        'expiredTasks': expiredTasks + 1,
      }, SetOptions(merge: true));

      // Update the task
      await _firestore
          .collection('households')
          .doc(householdId)
          .collection('members')
          .doc(memberId)
          .collection('tasks')
          .doc(taskId)
          .update({
        'done': false,
        'status': 'expired',
        'expired_at': FieldValue.serverTimestamp(),
      });

      // Update household stats
      await updateHouseholdStats(householdId);
    } catch (e) {
      print('Error expiring task: $e');
      rethrow;
    }
  }

  /// Abandons a task and marks it as incomplete
  static Future<void> abandonTask({
    required String householdId,
    required String memberId,
    required String taskId,
  }) async {
    try {
      // Get the member document to update their stats
      DocumentSnapshot memberDoc = await _firestore
          .collection('households')
          .doc(householdId)
          .collection('members')
          .doc(memberId)
          .get();

      // Get current stats, defaulting to 0 if not set
      Map<String, dynamic> memberData =
          memberDoc.exists ? memberDoc.data() as Map<String, dynamic> : {};
      int totalTasks = memberData['totalTasks'] ?? 0;
      int abandonedTasks = memberData['abandonedTasks'] ?? 0;

      // Update the member's stats
      await _firestore
          .collection('households')
          .doc(householdId)
          .collection('members')
          .doc(memberId)
          .set({
        'totalTasks': totalTasks + 1,
        'abandonedTasks': abandonedTasks + 1,
      }, SetOptions(merge: true));

      // Update the task status
      await _firestore
          .collection('households')
          .doc(householdId)
          .collection('members')
          .doc(memberId)
          .collection('tasks')
          .doc(taskId)
          .update({
        'done': false,
        'status': 'abandoned',
        'abandoned_at': FieldValue.serverTimestamp(),
      });

      // Update household stats
      await updateHouseholdStats(householdId);
    } catch (e) {
      print('Error abandoning task: $e');
      rethrow;
    }
  }
}
