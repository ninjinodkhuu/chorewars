import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class HouseholdShoppingService {
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

  // Stream shopping list items
  static Stream<QuerySnapshot> streamShoppingList(String householdId) {
    return _firestore
        .collection('households')
        .doc(householdId)
        .collection('shopping_list')
        .orderBy('timestamp', descending: true)
        .snapshots();
  }

  // Add shopping list item
  static Future<void> addItem({
    required String householdId,
    required String item,
    required String category,
    int quantity = 1,
    String unit = '',
    double price = 0.0,
    required String addedBy,
  }) async {
    await _firestore
        .collection('households')
        .doc(householdId)
        .collection('shopping_list')
        .add({
      'item': item,
      'category': category,
      'quantity': quantity,
      'unit': unit,
      'price': price,
      'done': false,
      'added_by': addedBy,
      'timestamp': FieldValue.serverTimestamp(),
    });
  }

  // Update shopping list item
  static Future<void> updateItem({
    required String householdId,
    required String itemId,
    required Map<String, dynamic> updates,
  }) async {
    await _firestore
        .collection('households')
        .doc(householdId)
        .collection('shopping_list')
        .doc(itemId)
        .update(updates);
  }

  // Delete shopping list item
  static Future<void> deleteItem({
    required String householdId,
    required String itemId,
  }) async {
    await _firestore
        .collection('households')
        .doc(householdId)
        .collection('shopping_list')
        .doc(itemId)
        .delete();
  }

  // Toggle item completion
  static Future<void> toggleItemDone({
    required String householdId,
    required String itemId,
    required bool currentStatus,
    required String completedBy,
  }) async {
    await _firestore
        .collection('households')
        .doc(householdId)
        .collection('shopping_list')
        .doc(itemId)
        .update({
      'done': !currentStatus,
      'completed_by': completedBy,
      'completed_at': FieldValue.serverTimestamp(),
    });
  }

  // Convert shopping list item to expense
  static Future<void> convertToExpense({
    required String householdId,
    required String itemId,
    required String category,
    required double amount,
    required String addedBy,
  }) async {
    final batch = _firestore.batch();

    // Add the expense
    DocumentReference expenseRef = _firestore
        .collection('households')
        .doc(householdId)
        .collection('expenses')
        .doc();

    batch.set(expenseRef, {
      'category': category,
      'amount': amount,
      'added_by': addedBy,
      'source': 'shopping_list',
      'shopping_item_id': itemId,
      'timestamp': FieldValue.serverTimestamp(),
    });

    // Delete the shopping list item
    DocumentReference itemRef = _firestore
        .collection('households')
        .doc(householdId)
        .collection('shopping_list')
        .doc(itemId);

    batch.delete(itemRef);

    await batch.commit();
  }
}
