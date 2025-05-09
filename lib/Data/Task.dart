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

  // Convert TaskDifficulty to integer points for Firestore storage
  int get pointsValue => points;

  // Convert Firestore data to TaskDifficulty from an integer value
  static TaskDifficulty fromFirestore(int points) {
    return TaskDifficulty.values.firstWhere(
      (e) => e.points == points,
      orElse: () => TaskDifficulty.veryEasy,
    );
  }
}

class Task {
  String id;
  String category;
  String name;
  DateTime date;
  bool done;
  TaskDifficulty difficulty;
  int timeEstimateMinutes;
  String? assignedTo;
  DateTime? acceptedAt;
  DateTime? startedAt;
  DateTime? completedAt;

  Task({
    required this.id,
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
  });

  // Factory method to create a Task from Firestore data
  factory Task.fromFirestore(DocumentSnapshot doc) {
    Map data = doc.data() as Map;

    // Use fromFirestore to convert integer points to TaskDifficulty
    return Task(
      id: doc.id,
      category: data['category'] ?? '',
      name: data['name'] ?? '',
      date: (data['date'] as Timestamp).toDate(),
      done: data['done'] ?? false,
      difficulty: TaskDifficulty.fromFirestore(data['difficulty'] ?? 1), // Assume 1 as default if missing
      timeEstimateMinutes: data['timeEstimateMinutes'] ?? 0,
      assignedTo: data['assignedTo'],
      acceptedAt: data['acceptedAt'] != null ? (data['acceptedAt'] as Timestamp).toDate() : null,
      startedAt: data['startedAt'] != null ? (data['startedAt'] as Timestamp).toDate() : null,
      completedAt: data['completedAt'] != null ? (data['completedAt'] as Timestamp).toDate() : null,
    );
  }

  // Convert Task to Firestore data
  Map<String, dynamic> toFirestore() {
    return {
      'category': category,
      'name': name,
      'date': date,
      'done': done,
      'difficulty': difficulty.pointsValue,  // Store as integer points
      'timeEstimateMinutes': timeEstimateMinutes,
      'assignedTo': assignedTo,
      'acceptedAt': acceptedAt,
      'startedAt': startedAt,
      'completedAt': completedAt,
    };
  }
}
