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

  /// Gets the current household ID
  static Future<String> getHouseholdId() async {
    User? user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      throw Exception('User not logged in');
    }

    DocumentSnapshot doc =
        await _firestore.collection('users').doc(user.uid).get();
    String? householdId =
        doc.data()?.toString().contains('household_id') == true
            ? (doc.data() as Map<String, dynamic>)['household_id']
            : null;

    if (householdId == null) {
      // Create a new household for the user
      DocumentReference householdRef =
          await _firestore.collection('households').add({
        'createdAt': FieldValue.serverTimestamp(),
        'leaderId': user.uid,
      });

      // Update user document with new household ID
      await _firestore.collection('users').doc(user.uid).set({
        'household_id': householdRef.id,
      }, SetOptions(merge: true));

      return householdRef.id;
    }

    return householdId;
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

  /// Stream that provides real-time updates of pending invites for current user
  static Stream<List<Map<String, dynamic>>> streamPendingInvites() {
    User? user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return Stream.value([]);
    }

    return _firestore
        .collection('household_invitations')
        .where('invitedUserId', isEqualTo: user.uid)
        .where('status', isEqualTo: 'pending')
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => {
                  'id': doc.id,
                  'householdId': doc.data()['householdId'],
                  'invitedBy': doc.data()['invitedBy'],
                  'householdName': doc.data()['householdName'],
                  'timestamp': doc.data()['timestamp'],
                })
            .toList());
  }

  /// Accept a household invitation
  static Future<void> acceptInvitation(String invitationId) async {
    User? user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      throw Exception('Not logged in');
    }

    // Get the invitation document
    DocumentSnapshot inviteDoc = await _firestore
        .collection('household_invitations')
        .doc(invitationId)
        .get();

    if (!inviteDoc.exists) {
      throw Exception('Invitation not found');
    }

    String householdId = inviteDoc.get('householdId');
    String householdName = inviteDoc.get('householdName');

    // Start a batch write
    WriteBatch batch = _firestore.batch();

    // Add user to household members
    batch.set(
      _firestore
          .collection('households')
          .doc(householdId)
          .collection('members')
          .doc(user.uid),
      {
        'email': user.email,
        'joinedAt': FieldValue.serverTimestamp(),
        'isLeader': false,
        'totalPoints': 0,
        'completedTasks': 0,
        'totalTasks': 0
      },
    );

    // Update user's profile
    batch.set(
      _firestore.collection('users').doc(user.uid),
      {
        'household_id': householdId,
        'householdName': householdName,
        'lastUpdated': FieldValue.serverTimestamp()
      },
      SetOptions(merge: true),
    );

    // Update invitation status
    batch.update(
      _firestore.collection('household_invitations').doc(invitationId),
      {'status': 'accepted', 'acceptedAt': FieldValue.serverTimestamp()},
    );

    // Commit the batch
    await batch.commit();
  }

  /// Decline a household invitation
  static Future<void> declineInvitation(String invitationId) async {
    User? user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      throw Exception('Not logged in');
    }

    await _firestore
        .collection('household_invitations')
        .doc(invitationId)
        .update({
      'status': 'declined',
      'declinedAt': FieldValue.serverTimestamp(),
    });
  }

  /// Check if user has any pending invites
  static Stream<bool> hasPendingInvites() {
    return streamPendingInvites().map((invites) => invites.isNotEmpty);
  }
}
