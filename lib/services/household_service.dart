// Import required Firebase packages for authentication and database operations
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
// Import Flutter material package for UI widgets
import 'package:flutter/material.dart';

/// Service class to handle all household-related operations
class HouseholdService {
  // Initialize Firestore instance for database operations
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Stream that provides real-time updates of the household name
  /// Returns an empty string if user is not logged in
  static Stream<String> streamHouseholdName() {
    // Get current logged-in user
    User? user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return Stream.value('');
    }

    // Listen to changes in the user's document
    return _firestore.collection('users').doc(user.uid).snapshots().map((doc) {
      if (!doc.exists) {
        return 'My Household';
      }
      return doc.data()?['householdName'] ?? 'My Household';
    });
  }

  /// Provides a stream of Widget that displays the app bar title
  /// Includes 'Chore Wars' text and household name in a specific format
  static Stream<Widget> streamAppBarTitle() {
    return streamHouseholdName().map((householdName) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Main title 'Chore Wars' with specific styling
          const Text(
            'Chore Wars',
            style: TextStyle(
              color: Color(0xFF1A237E),
              fontSize: 22,
              fontWeight: FontWeight.bold,
            ),
          ),
          // Household name with slightly different styling
          Text(
            householdName,
            style: TextStyle(
              color: Colors.blue[900],
              fontSize: 16,
            ),
          ),
        ],
      );
    });
  }

  /// Gets the current household name as a one-time fetch
  /// Returns 'My Household' as default if user is not logged in or name is not set
  static Future<String> getHouseholdName() async {
    User? user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return 'My Household';
    }

    // Fetch user document from Firestore
    DocumentSnapshot doc =
        await _firestore.collection('users').doc(user.uid).get();
    return doc.data()?.toString().contains('householdName') == true
        ? (doc.data() as Map<String, dynamic>)['householdName'] ??
            'My Household'
        : 'My Household';
  }

  /// Updates the household name in Firestore
  /// Throws an exception if user is not logged in
  static Future<void> updateHouseholdName(String name) async {
    User? user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      throw Exception('Not logged in');
    }

    // Update the household name in the user's document
    await _firestore.collection('users').doc(user.uid).update({
      'householdName': name.trim(),
    });
  }
}
