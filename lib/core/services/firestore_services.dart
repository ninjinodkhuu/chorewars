import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cw/models/user_model.dart'; // Adjust import paths

class FirestoreService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Singleton pattern (optional but recommended)
  static final FirestoreService _instance = FirestoreService._internal();
  factory FirestoreService() => _instance;
  FirestoreService._internal();

  // ========== User Operations ==========
  Future<void> createUser(UserModel user) async {
    await _firestore.collection('users').doc(user.uid).set(user.toMap());
  }

  Stream<UserModel> getUser(String uid) {
    return _firestore.collection('users').doc(uid).snapshots().map(
        (snapshot) => UserModel.fromFirestore(snapshot));
  }

  // ========== Household Operations ==========
  Future<void> createHousehold(String name, String adminUid) async {
    final householdRef = await _firestore.collection('households').add({
      'name': name,
      'createdBy': adminUid,
      'members': [adminUid],
      'createdAt': FieldValue.serverTimestamp(),
    });
    
    // Update user's household reference
    await _firestore.collection('users').doc(adminUid).update({
      'householdId': householdRef.id,
    });
  }

  // ========== Task Operations ==========
  Stream<List<Task>> getHouseholdTasks(String householdId) {
    return _firestore
        .collection('tasks')
        .where('householdId', isEqualTo: householdId)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => Task.fromFirestore(doc))
            .toList());
  }

  // Add more methods as needed...
}