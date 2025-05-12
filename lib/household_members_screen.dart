// =========================
// household_members_screen.dart
// =========================
// This file implements the household members management screen for Chorewars.
// It allows users to view, invite, and manage household members and household info.
//
// Key design decisions:
// - Integrates with Firestore and Firebase Auth for household and member data.
// - UI supports inviting members, editing household name, and showing member list.
// - Uses HouseholdService for Firestore logic abstraction.
//
// Contributor notes:
// - If you add new member features, update both the UI and Firestore logic.
// - Keep comments up to date for onboarding new contributors.

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'services/household_service.dart';

class HouseholdMembersScreen extends StatefulWidget {
  const HouseholdMembersScreen({super.key});

  @override
  State<HouseholdMembersScreen> createState() => _HouseholdMembersScreenState();
}

class _HouseholdMembersScreenState extends State<HouseholdMembersScreen> {
  final TextEditingController _inviteEmailController = TextEditingController();
  final TextEditingController _householdNameController =
      TextEditingController();
  String householdName = '';
  String leaderId = '';
  String? currentHouseholdId;

  @override
  void initState() {
    super.initState();
    _loadHouseholdInfo();
  }

  Future<void> _loadHouseholdInfo() async {
    final name = await HouseholdService.getHouseholdName();
    final id = await HouseholdService.getHouseholdId();

    if (!mounted) return;

    setState(() {
      householdName = name;
      _householdNameController.text = name;
      currentHouseholdId = id;
    });

    // Get leader information
    final householdDoc =
        await FirebaseFirestore.instance.collection('households').doc(id).get();

    if (householdDoc.exists && mounted) {
      setState(() {
        leaderId = householdDoc.get('leaderId') ?? '';
      });
    }
  }

  Future<List<Map<String, dynamic>>> _fetchHouseholdMembers() async {
    if (currentHouseholdId == null) return [];

    final membersSnapshot = await FirebaseFirestore.instance
        .collection('households')
        .doc(currentHouseholdId)
        .collection('members')
        .get();

    return membersSnapshot.docs.map((doc) {
      final data = doc.data();
      return {
        'id': doc.id,
        'email': data['email'] ?? 'Unknown',
        'name': data['name'] ?? data['email'] ?? 'Unknown',
        'totalPoints': data['totalPoints'] ?? 0,
      };
    }).toList();
  }

  Future<void> _inviteToHousehold() async {
    final email = _inviteEmailController.text.trim();
    if (email.isEmpty) return;

    try {
      final userSnapshot = await FirebaseFirestore.instance
          .collection('users')
          .where('email', isEqualTo: email)
          .get();

      if (userSnapshot.docs.isEmpty) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('User not found')),
        );
        return;
      }

      final invitedUserId = userSnapshot.docs.first.id;
      final currentUser = FirebaseAuth.instance.currentUser;

      if (currentUser == null || currentHouseholdId == null) return;

      // Create invitation
      await FirebaseFirestore.instance.collection('household_invitations').add({
        'householdId': currentHouseholdId,
        'householdName': householdName,
        'invitedUserId': invitedUserId,
        'invitedBy': currentUser.uid,
        'inviterEmail': currentUser.email,
        'invitedEmail': email,
        'status': 'pending',
        'timestamp': FieldValue.serverTimestamp(),
      });

      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Invitation sent')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    }
  }

  Future<void> _assignLeader(String memberId) async {
    try {
      if (currentHouseholdId == null) return;

      await FirebaseFirestore.instance
          .collection('households')
          .doc(currentHouseholdId)
          .set({
        'leaderId': memberId,
        'lastUpdated': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      setState(() {
        leaderId = memberId;
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('New household leader assigned'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error assigning leader: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _showEditHouseholdDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit Household Name'),
        content: TextField(
          controller: _householdNameController,
          decoration: const InputDecoration(
            labelText: 'Household Name',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              try {
                await HouseholdService.updateHouseholdName(
                    _householdNameController.text);
                setState(() {
                  householdName = _householdNameController.text;
                });
                if (!mounted) return;
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                      content: Text('Household name updated successfully')),
                );
              } catch (e) {
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Error: $e')),
                );
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  Widget _buildInviteButton(BuildContext context) {
    return ElevatedButton.icon(
      onPressed: () {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Invite to Household'),
            content: TextField(
              controller: _inviteEmailController,
              decoration: const InputDecoration(
                labelText: 'Email Address',
                border: OutlineInputBorder(),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () {
                  _inviteToHousehold();
                  _inviteEmailController.clear();
                },
                child: const Text('Invite'),
              ),
            ],
          ),
        );
      },
      icon: const Icon(Icons.person_add),
      label: const Text('Invite'),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.blue[50],
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: Text(
          householdName.isEmpty ? 'My Household' : householdName,
          style: TextStyle(
            color: Colors.blue[900],
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.edit),
            color: Colors.blue[900],
            onPressed: () => _showEditHouseholdDialog(context),
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // Invitation list
            StreamBuilder<List<Map<String, dynamic>>>(
              stream: HouseholdService.streamPendingInvites(),
              builder: (context, snapshot) {
                if (!snapshot.hasData || snapshot.data!.isEmpty) {
                  return const SizedBox.shrink();
                }

                return Container(
                  margin: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 6,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: Text(
                          'Pending Invitations',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Colors.blue[900],
                          ),
                        ),
                      ),
                      ListView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: snapshot.data!.length,
                        itemBuilder: (context, index) {
                          final invite = snapshot.data![index];
                          return ListTile(
                            title: Text('Invited by ${invite['inviterEmail']}'),
                            subtitle:
                                Text('Household: ${invite['householdName']}'),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                TextButton(
                                  onPressed: () async {
                                    await HouseholdService.acceptInvitation(
                                        invite['id']);
                                    if (!mounted) return;
                                    _loadHouseholdInfo();
                                  },
                                  child: const Text('Accept'),
                                ),
                                TextButton(
                                  onPressed: () async {
                                    await HouseholdService.declineInvitation(
                                        invite['id']);
                                  },
                                  child: const Text('Decline'),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                );
              },
            ),

            // Members list
            FutureBuilder<List<Map<String, dynamic>>>(
              future: _fetchHouseholdMembers(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (snapshot.hasError) {
                  return Center(
                    child: Text('Error: ${snapshot.error}'),
                  );
                }

                final members = snapshot.data ?? [];

                return Container(
                  margin: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 6,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Members (${members.length})',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: Colors.blue[900],
                              ),
                            ),
                            _buildInviteButton(context),
                          ],
                        ),
                      ),
                      ListView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: members.length,
                        itemBuilder: (context, index) {
                          final member = members[index];
                          final isLeader = member['id'] == leaderId;

                          return Container(
                            decoration: BoxDecoration(
                              border: Border(
                                bottom: index != members.length - 1
                                    ? BorderSide(color: Colors.grey[300]!)
                                    : BorderSide.none,
                              ),
                            ),
                            child: ListTile(
                              leading: CircleAvatar(
                                backgroundColor: Colors.blue[100],
                                child: Text(
                                  member['email'][0].toUpperCase(),
                                  style: TextStyle(
                                    color: Colors.blue[900],
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              title: Text(
                                member['email'],
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              subtitle: isLeader
                                  ? Text(
                                      'Leader',
                                      style: TextStyle(
                                        color: Colors.blue[700],
                                        fontWeight: FontWeight.w500,
                                      ),
                                    )
                                  : null,
                              trailing: !isLeader
                                  ? TextButton.icon(
                                      icon: const Icon(Icons.shield),
                                      label: const Text('Make Leader'),
                                      onPressed: () =>
                                          _assignLeader(member['id']),
                                      style: TextButton.styleFrom(
                                        foregroundColor: Colors.blue[900],
                                      ),
                                    )
                                  : Icon(Icons.shield, color: Colors.blue[900]),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _inviteEmailController.dispose();
    _householdNameController.dispose();
    super.dispose();
  }
}
