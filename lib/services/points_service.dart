import 'package:cloud_firestore/cloud_firestore.dart';

class PointsService {
  /// Recalculates and writes each member's totalPoints under
  /// /household/{householdID}/members/{memberID}/totalPoints
  static Future<void> recalcHouseholdPoints(String householdID) async {
    final membersRef = FirebaseFirestore.instance
      .collection('household')
      .doc(householdID)
      .collection('members');
    final membersSnap = await membersRef.get();

    for (final memberDoc in membersSnap.docs) {
      final memberID = memberDoc.id;

      // Sum up that member’s task points
      final tasksSnap = await membersRef
        .doc(memberID)
        .collection('tasks')
        .get();

      var total = 0;
      for (final t in tasksSnap.docs) {
        total += (t.data()['points'] as int?) ?? 0;
      }

      // Write it back
      await membersRef
        .doc(memberID)
        .update({'totalPoints': total});
    }
  }
}
