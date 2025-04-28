class GamePeriod {
  final String id;
  final DateTime startDate;
  final DateTime endDate;
  final Map<String, int> scores; // {userId: points}

  GamePeriod({
    required this.id,
    required this.startDate,
    required this.endDate,
    required this.scores,
  });

  factory GamePeriod.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return GamePeriod(
      id: doc.id,
      startDate: (data['startDate'] as Timestamp).toDate(),
      endDate: (data['endDate'] as Timestamp).toDate(),
      scores: Map<String, int>.from(data['scores'] ?? {}),
    );
  }
}