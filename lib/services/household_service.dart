import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class HouseholdService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  static Stream<String> streamHouseholdName() {
    User? user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return Stream.value('');
    }

    return _firestore.collection('users').doc(user.uid).snapshots().map((doc) {
      if (!doc.exists) {
        return 'My Household';
      }
      return doc.data()?['householdName'] ?? 'My Household';
    });
  }

  static Stream<Widget> streamAppBarTitle() {
    return streamHouseholdName().map((householdName) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Chore Wars',
            style: TextStyle(
              color: Color(0xFF1A237E),
              fontSize: 22,
              fontWeight: FontWeight.bold,
            ),
          ),
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

  static Future<String> getHouseholdName() async {
    User? user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return 'My Household';
    }

    DocumentSnapshot doc =
        await _firestore.collection('users').doc(user.uid).get();
    return doc.data()?.toString().contains('householdName') == true
        ? (doc.data() as Map<String, dynamic>)['householdName'] ??
            'My Household'
        : 'My Household';
  }

  static Future<void> updateHouseholdName(String name) async {
    User? user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      throw Exception('Not logged in');
    }

    await _firestore.collection('users').doc(user.uid).update({
      'householdName': name.trim(),
    });
  }
}
