import 'package:cloud_firestore/cloud_firestore.dart';

enum TaskDifficulty {
  veryEasy(1),
  easy(2),
  medium(3),
  hard(4),
  veryHard(5);

  final int points;
  const TaskDifficulty(this.points);

  // Factory method to create from point value
  static TaskDifficulty fromValue(int points) {
    return TaskDifficulty.values.firstWhere(
      (d) => d.points == points,
      orElse: () => TaskDifficulty.veryEasy,
    );
  }
}

class Task {
  final String category;
  final String name;
  final DateTime date;
  final TaskDifficulty difficulty;
  final int timeEstimateMinutes;
  final String? assignedTo;
  final DateTime? acceptedAt;
  final DateTime? startedAt;
  final DateTime? completedAt;
  final bool done;
  final String id;
  final String status;

  factory Task.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    final dueDate = data['dueDate'];
    final acceptedAt =
        data['accepted_at'] ?? data['acceptedAt']; // support both for migration
    final startedAt =
        data['started_at'] ?? data['startedAt']; // support both for migration
    final completedAt = data['completed_at']; // CHANGED from 'completedAt'
    final assignedAt =
        data['assigned_at'] ?? data['assignedAt']; // support both for migration

    // Print the Firestore document reference path for debugging
    print('[Task.fromFirestore] Firestore path: ${doc.reference.path}');
    print('[Task.fromFirestore] Processing doc: ${doc.id}');
    print('[Task.fromFirestore] Raw task data: $data');

    // Get base status from data or default to assigned
    String status = data['status']?.toString().toLowerCase() ?? 'assigned';

    // Override status based on timestamps if the current status isn't terminal
    if (status != 'abandoned' && status != 'expired') {
      if (data['abandoned_at'] != null) {
        status = 'abandoned';
      } else if (data['expired_at'] != null) {
        status = 'expired';
      } else if (completedAt != null || data['done'] == true) {
        status = 'completed';
      } else if (startedAt != null) {
        status = 'inProgress';
      } else if (assignedAt != null) {
        status = 'assigned';
      }
    }

    print('[Task.fromFirestore] Determined status: $status');
    final bool done = status == 'completed';

    print('[Task.fromFirestore] id: ${doc.id}, status: $status, done: $done');

    // Parse difficulty
    TaskDifficulty difficulty = TaskDifficulty.veryEasy;
    if (data['difficulty'] != null) {
      String difficultyStr = data['difficulty'].toString().toLowerCase().trim();
      try {
        difficulty = TaskDifficulty.values.firstWhere(
          (d) => d.name.toLowerCase() == difficultyStr,
          orElse: () => TaskDifficulty.veryEasy,
        );
      } catch (e) {
        print('[Task.fromFirestore] Error parsing difficulty: $e');
      }
    }

    return Task(
      id: doc.id,
      category: data['category'] ?? 'Uncategorized',
      name: data['name'] ?? 'Unnamed Task',
      date: (dueDate as Timestamp?)?.toDate() ?? DateTime.now(),
      difficulty: difficulty,
      // Support both timeEstimateMinutes and timeEstimate for migration/compatibility
      timeEstimateMinutes:
          data['timeEstimateMinutes'] ?? data['timeEstimate'] ?? 0,
      assignedTo: data['assignedTo'],
      acceptedAt:
          acceptedAt != null ? (acceptedAt as Timestamp).toDate() : null,
      startedAt: startedAt != null ? (startedAt as Timestamp).toDate() : null,
      completedAt:
          completedAt != null ? (completedAt as Timestamp).toDate() : null,
      done: done,
      status: status,
    );
  }

  Task({
    required this.category,
    required this.name,
    required this.date,
    required this.difficulty,
    required this.timeEstimateMinutes,
    this.assignedTo,
    this.acceptedAt,
    this.startedAt,
    this.completedAt,
    this.done = false,
    this.id = '',
    this.status = 'assigned',
  });
}
