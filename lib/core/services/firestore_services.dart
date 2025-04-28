import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cw/models/user_model.dart';
import 'package:cw/models/household_model.dart';
import 'package:cw/models/task_model.dart';
import 'package:cw/models/gameperiod_model.dart';

class FirestoreService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Singleton pattern
  static final FirestoreService _instance = FirestoreService._internal();
  factory FirestoreService() => _instance;
  FirestoreService._internal();

  // ================== Users ==================
  Future<void> createUser(UserModel user) async {
    await _firestore.collection('users').doc(user.uid).set(user.toMap());
  }

  Stream<UserModel> getUserStream(String uid) {
    return _firestore.collection('users').doc(uid).snapshots().map(
          (snapshot) => UserModel.fromFirestore(snapshot),
        );
  }

  Future<void> updateUserPoints(String uid, int pointsToAdd) async {
    final userRef = _firestore.collection('users').doc(uid);
    await _firestore.runTransaction((transaction) async {
      final snapshot = await transaction.get(userRef);
      final currentPoints = snapshot.get('currentPeriodPoints') ?? 0;
      transaction.update(userRef, {
        'currentPeriodPoints': currentPoints + pointsToAdd,
        'totalPoints': FieldValue.increment(pointsToAdd),
      });
    });
  }

  // ================== Households ==================
  Future<String> createHousehold(String name, String adminUid) async {
    final householdRef = await _firestore.collection('households').add({
      'name': name,
      'createdBy': adminUid,
      'members': [adminUid],
      'currentGamePeriod': _getCurrentPeriodId(),
      'createdAt': FieldValue.serverTimestamp(),
    });

    // Update user's household reference
    await _firestore.collection('users').doc(adminUid).update({
      'householdId': householdRef.id,
      'isAdmin': true,
    });

    return householdRef.id;
  }

  Stream<Household> getHouseholdStream(String householdId) {
    return _firestore
        .collection('households')
        .doc(householdId)
        .snapshots()
        .map((snapshot) => Household.fromFirestore(snapshot));
  }

  // ================== Tasks ==================
  Stream<List<Task>> getHouseholdTasks(String householdId) {
    return _firestore
        .collection('tasks')
        .where('householdId', isEqualTo: householdId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) =>
            snapshot.docs.map((doc) => Task.fromFirestore(doc)).toList());
  }

  Future<void> completeTaskWithPoints(Task task) async {
    final batch = _firestore.batch();

    // Mark task as completed
    final taskRef = _firestore.collection('tasks').doc(task.id);
    batch.update(taskRef, {'isCompleted': true});

    // Award points to user
    final userRef = _firestore.collection('users').doc(task.assignedTo);
    batch.update(userRef, {
      'currentPeriodPoints': FieldValue.increment(task.points),
      'totalPoints': FieldValue.increment(task.points),
    });

    // Update leaderboard for current period
    final periodRef = _firestore
        .collection('households')
        .doc(task.householdId)
        .collection('gamePeriods')
        .doc(_getCurrentPeriodId());

    batch.set(periodRef, {
      'scores': {task.assignedTo: FieldValue.increment(task.points)},
    }, SetOptions(merge: true));

    await batch.commit();
  }

  // ================== Game Periods ==================
  Stream<List<GamePeriod>> getHouseholdGamePeriods(String householdId) {
    return _firestore
        .collection('households')
        .doc(householdId)
        .collection('gamePeriods')
        .orderBy('startDate', descending: true)
        .snapshots()
        .map((snapshot) =>
            snapshot.docs.map((doc) => GamePeriod.fromFirestore(doc)).toList());
  }

  // ================== Utilities ==================
  String _getCurrentPeriodId() {
    final now = DateTime.now();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}';
  }
}