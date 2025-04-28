class UserModel {
  final String uid;
  final String email;
  final String name;
  final String? householdId;
  final bool isAdmin;
  final int totalPoints;
  final int currentPeriodPoints;
  final String? avatarUrl;

  UserModel({
    required this.uid,
    required this.email,
    required this.name,
    this.householdId,
    this.isAdmin = false,
    this.totalPoints = 0,
    this.currentPeriodPoints = 0,
    this.avatarUrl,
  });

  // Convert to Firestore Map
  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'email': email,
      'name': name,
      'householdId': householdId,
      'isAdmin': isAdmin,
      'totalPoints': totalPoints,
      'currentPeriodPoints': currentPeriodPoints,
      'avatarUrl': avatarUrl,
    };
  }

  // Create from Firestore Document
  factory UserModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return UserModel(
      uid: doc.id,
      email: data['email'] ?? '',
      name: data['name'] ?? '',
      householdId: data['householdId'],
      isAdmin: data['isAdmin'] ?? false,
      totalPoints: data['totalPoints'] ?? 0,
      currentPeriodPoints: data['currentPeriodPoints'] ?? 0,
      avatarUrl: data['avatarUrl'],
    );
  }
}