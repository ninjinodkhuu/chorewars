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
  factory Task.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    final dueDate = data['dueDate'];
    final acceptedAt = data['acceptedAt'];
    final startedAt = data['startedAt'];
    final completedAt = data['completed_at'];
    final bool done = data['done'] ?? false;

    // Default to veryEasy if no difficulty is specified
    TaskDifficulty difficulty = TaskDifficulty.veryEasy;

    // Try to determine difficulty from the data
    if (data['difficulty'] != null) {
      String difficultyStr = data['difficulty'].toString().toLowerCase().trim();
      try {
        difficulty = TaskDifficulty.values.firstWhere(
          (d) => d.name.toLowerCase() == difficultyStr,
          orElse: () => TaskDifficulty.veryEasy,
        );
      } catch (e) {
        print('Error parsing difficulty string: $e');
      }
    } else if (data['points'] != null) {
      try {
        int points = (data['points'] is num)
            ? (data['points'] as num).toInt()
            : int.tryParse(data['points'].toString()) ?? 1;
        difficulty = TaskDifficulty.fromValue(points);
      } catch (e) {
        print('Error parsing points: $e');
      }
    }

    return Task(
      id: doc.id,
      category: data['category'] ?? '',
      name: data['name'] ?? '',
      date: dueDate != null ? (dueDate as Timestamp).toDate() : DateTime.now(),
      difficulty: difficulty,
      timeEstimateMinutes: data['timeEstimate'] ?? 0,
      assignedTo: data['assignedTo'],
      acceptedAt:
          acceptedAt != null ? (acceptedAt as Timestamp).toDate() : null,
      startedAt: startedAt != null ? (startedAt as Timestamp).toDate() : null,
      completedAt:
          completedAt != null ? (completedAt as Timestamp).toDate() : null,
      done: done,
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
  });
}
