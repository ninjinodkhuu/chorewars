import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
void restoreTestExpenses() async {
  User? user = FirebaseAuth.instance.currentUser;
  if (user != null) {
    CollectionReference expensesRef = FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('expenses');

    List<Map<String, dynamic>> sampleExpenses = [
      {
        'name': 'Groceries',
        'category': 'Food',
        'amount': 50.0,
        'timestamp': FieldValue.serverTimestamp(),
      },
      {
        'name': 'Uber Ride',
        'category': 'Transport',
        'amount': 15.0,
        'timestamp': FieldValue.serverTimestamp(),
      },
      {
        'name': 'Netflix Subscription',
        'category': 'Entertainment',
        'amount': 10.0,
        'timestamp': FieldValue.serverTimestamp(),
      },
    ];

    for (var expense in sampleExpenses) {
      await expensesRef.add(expense);
    }

    print("✅ Sample expenses added!");
  }
}
