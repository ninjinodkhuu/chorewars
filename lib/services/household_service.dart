// Import required Firebase packages for authentication and database operations
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
// Import Flutter material package for UI widgets
import 'package:flutter/material.dart';
import '../local_notifications.dart';

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

  /// Updates the household name
  static Future<void> updateHouseholdName(String newName) async {
    User? user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      await _firestore
          .collection('users')
          .doc(user.uid)
          .update({'householdName': newName});

      // Send notification about the name change
      await LocalNotificationService.sendHouseholdUpdateNotification(
        'Household Name Updated',
        'The household name has been changed to "$newName"',
      );
    }
  }

  /// Invites a new member to the household
  static Future<void> inviteMember(String email) async {
    User? user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      // Existing invitation logic...

      // Send notification about new member
      await LocalNotificationService.sendHouseholdUpdateNotification(
        'New Member Invited',
        'An invitation has been sent to $email',
      );
    }
  }

  /// Updates household statistics and triggers a weekly report
  static Future<void> updateHouseholdStats(String householdId) async {
    try {
      // Existing stats update logic...

      // Schedule weekly household report
      await LocalNotificationService.scheduleWeeklyHouseholdReport(householdId);
    } catch (e) {
      print('Error updating household stats: $e');
      rethrow;
    }
  }
}
