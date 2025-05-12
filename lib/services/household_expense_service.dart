import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class HouseholdExpenseService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Get current user's household ID
  static Future<String?> getCurrentHouseholdId() async {
    User? user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      DocumentSnapshot userDoc =
          await _firestore.collection('users').doc(user.uid).get();

      if (userDoc.exists) {
        Map<String, dynamic> data = userDoc.data() as Map<String, dynamic>;
        return data['household_id'] as String?;
      }
    }
    return null;
  }

  // Stream household budget
  static Stream<DocumentSnapshot> streamHouseholdBudget(String householdId) {
    return _firestore.collection('households').doc(householdId).snapshots();
  }

  // Stream household expenses
  static Stream<QuerySnapshot> streamHouseholdExpenses(String householdId) {
    return _firestore
        .collection('households')
        .doc(householdId)
        .collection('expenses')
        .orderBy('timestamp', descending: true)
        .snapshots();
  }

  // Add expense to household
  static Future<void> addExpense({
    required String householdId,
    required String category,
    required double amount,
    required String addedBy,
  }) async {
    await _firestore
        .collection('households')
        .doc(householdId)
        .collection('expenses')
        .add({
      'category': category,
      'amount': amount,
      'timestamp': FieldValue.serverTimestamp(),
      'added_by': addedBy,
    });
  }

  // Get household budget
  static Future<double> getHouseholdBudget(String householdId) async {
    DocumentSnapshot doc =
        await _firestore.collection('households').doc(householdId).get();

    if (doc.exists) {
      var data = doc.data() as Map<String, dynamic>;
      return (data['monthly_budget'] as num?)?.toDouble() ?? 0.0;
    }
    return 0.0;
  }

  // Update household budget
  static Future<void> updateHouseholdBudget({
    required String householdId,
    required double monthlyBudget,
    required String updatedBy,
  }) async {
    await _firestore.collection('households').doc(householdId).set({
      'monthly_budget': monthlyBudget,
      'last_budget_update': {
        'by': updatedBy,
        'at': FieldValue.serverTimestamp(),
      }
    }, SetOptions(merge: true));
  }

  // Get total expenses by category for current month
  static Future<Map<String, double>> getMonthlyExpensesByCategory(
      String householdId) async {
    final now = DateTime.now();
    final startOfMonth = DateTime(now.year, now.month, 1);

    QuerySnapshot snapshot = await _firestore
        .collection('households')
        .doc(householdId)
        .collection('expenses')
        .where('timestamp', isGreaterThanOrEqualTo: startOfMonth)
        .get();

    Map<String, double> expenses = {};
    for (var doc in snapshot.docs) {
      var data = doc.data() as Map<String, dynamic>;
      String category = data['category'] as String;
      double amount = (data['amount'] as num).toDouble();
      expenses.update(
        category,
        (value) => value + amount,
        ifAbsent: () => amount,
      );
    }
    return expenses;
  }

  // Get expense history
  static Future<List<Map<String, dynamic>>> getExpenseHistory(
      String householdId) async {
    QuerySnapshot snapshot = await _firestore
        .collection('households')
        .doc(householdId)
        .collection('expenses')
        .orderBy('timestamp', descending: true)
        .limit(100)
        .get();

    return snapshot.docs.map((doc) {
      var data = doc.data() as Map<String, dynamic>;
      return {
        'id': doc.id,
        ...data,
      };
    }).toList();
  }
}
