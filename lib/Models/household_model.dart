class Household {
  final String id;
  final String name;
  final String createdBy;
  final List<String> members;
  final String currentGamePeriod;
  final DateTime createdAt;

  Household({
    required this.id,
    required this.name,
    required this.createdBy,
    required this.members,
    required this.currentGamePeriod,
    required this.createdAt,
  });

  factory Household.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Household(
      id: doc.id,
      name: data['name'] ?? '',
      createdBy: data['createdBy'] ?? '',
      members: List<String>.from(data['members'] ?? []),
      currentGamePeriod: data['currentGamePeriod'] ?? _getDefaultPeriod(),
      createdAt: (data['createdAt'] as Timestamp).toDate(),
    );
  }

  static String _getDefaultPeriod() {
    final now = DateTime.now();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}';
  }
}