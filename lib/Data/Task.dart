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
  final String id;

  Task({
    required this.category,
    required this.name,
    required this.date,
    required this.difficulty,
    required this.timeEstimateMinutes,
    this.assignedTo,
    this.acceptedAt,
    this.startedAt,
    this.id = '',
  });
}
