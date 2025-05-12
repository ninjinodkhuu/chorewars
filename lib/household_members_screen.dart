import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'services/household_service.dart';

class HouseholdMembersScreen extends StatefulWidget {
  const HouseholdMembersScreen({super.key});

  @override
  _HouseholdMembersScreenState createState() => _HouseholdMembersScreenState();
}

class _HouseholdMembersScreenState extends State<HouseholdMembersScreen> {
  final TextEditingController _inviteEmailController = TextEditingController();
  final TextEditingController _householdNameController =
      TextEditingController();
  List<String> householdMembers = [];
  Map<String, String> householdMemberEmails = {};
  String householdName = '';
  String leaderId = '';

  @override
  void initState() {
    super.initState();
    _loadHouseholdName();
    _fetchHouseholdMembers();
    _initializeLeaderId(); // Add this line to load the leader ID when the screen initializes
  }

  // Method to load household name from Firestore
  Future<void> _loadHouseholdName() async {
    String name = await HouseholdService.getHouseholdName();
    setState(() {
      householdName = name;
      _householdNameController.text = name;
    });
  }

  // Method to fetch household members from Firestore
  Future<List<Map<String, dynamic>>> _fetchHouseholdMembers() async {
    try {
      User? user = FirebaseAuth.instance.currentUser;
      print('Current user: ${user?.email}');

      if (user != null) {
        // Get the user's document
        DocumentSnapshot snapshot = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .get();

        print('User document exists: ${snapshot.exists}');
        print('User document data: ${snapshot.data()}');

        // Check if householdMembers exists and is in the correct format
        var data = snapshot.data() as Map<String, dynamic>?;
        List<String> memberIds = [];

        if (!snapshot.exists ||
            data == null ||
            !data.containsKey('householdMembers') ||
            data['householdMembers'] is String) {
          // Handle case where it's stored as string
          print('Reinitializing householdMembers as array');
          // Initialize/reinitialize as array with current user
          await FirebaseFirestore.instance
              .collection('users')
              .doc(user.uid)
              .set({
            'email': user.email,
            'householdMembers': [user.uid]
          }, SetOptions(merge: true));

          memberIds = [user.uid];
        } else {
          // Try to get householdMembers as array
          var members = data['householdMembers'];
          if (members is List) {
            memberIds = members.map((m) => m.toString()).toList();
          } else {
            // If somehow not a list, reinitialize
            memberIds = [user.uid];
            await FirebaseFirestore.instance
                .collection('users')
                .doc(user.uid)
                .set({'householdMembers': memberIds}, SetOptions(merge: true));
          }
        }

        // Ensure current user is in the list
        if (!memberIds.contains(user.uid)) {
          memberIds.add(user.uid);
          await FirebaseFirestore.instance
              .collection('users')
              .doc(user.uid)
              .update({'householdMembers': memberIds});
        }

        List<Map<String, dynamic>> members = [];
        for (String memberId in memberIds) {
          DocumentSnapshot memberSnapshot = await FirebaseFirestore.instance
              .collection('users')
              .doc(memberId)
              .get();

          if (memberSnapshot.exists) {
            var memberData = memberSnapshot.data() as Map<String, dynamic>;
            String? email = memberData['email'] as String?;
            if (email != null) {
              members.add({
                'id': memberId,
                'email': email,
              });
            }
          }
        }

        householdMembers = memberIds;
        householdMemberEmails = {
          for (var member in members) member['id']: member['email']
        };
        return members;
      }
    } catch (e, stackTrace) {
      print('Error in _fetchHouseholdMembers: $e');
      print('Stack trace: $stackTrace');
      rethrow;
    }
    return [];
  }

  // Method to invite a new member to the household
  Future<void> _inviteToHousehold() async {
    String email = _inviteEmailController.text.trim();
    if (email.isNotEmpty) {
      QuerySnapshot userSnapshot = await FirebaseFirestore.instance
          .collection('users')
          .where('email', isEqualTo: email)
          .get();

      if (userSnapshot.docs.isNotEmpty) {
        String invitedUserId = userSnapshot.docs.first.id;

        User? user = FirebaseAuth.instance.currentUser;
        if (user != null) {
          String householdId = await _getHouseholdId();

          // Add the invited user as a household member with proper initialization
          await FirebaseFirestore.instance
              .collection('households')
              .doc(householdId)
              .collection('members')
              .doc(invitedUserId)
              .set({
            'name': email, // Use email as name for consistency
            'email': email,
            'joinedAt': FieldValue.serverTimestamp(),
            'isLeader': false,
            'totalPoints': 0,
            'completedTasks': 0,
            'totalTasks': 0
          });

          // Update user's profile with household ID
          await FirebaseFirestore.instance
              .collection('users')
              .doc(invitedUserId)
              .set({
            'household_id': householdId,
            'email': email,
            'lastUpdated': FieldValue.serverTimestamp()
          }, SetOptions(merge: true));

          // Add to household_members collection
          await FirebaseFirestore.instance.collection('household_members').add({
            'memberId': invitedUserId,
            'householdId': householdId,
            'joinedAt': FieldValue.serverTimestamp()
          });

          await FirebaseFirestore.instance
              .collection('users')
              .doc(user.uid)
              .update({
            'householdMembers': FieldValue.arrayUnion([invitedUserId])
          });

          await FirebaseFirestore.instance
              .collection('users')
              .doc(invitedUserId)
              .update({
            'householdMembers': FieldValue.arrayUnion([user.uid])
          });

          for (String memberId in householdMembers) {
            await FirebaseFirestore.instance
                .collection('users')
                .doc(memberId)
                .update({
              'householdMembers': FieldValue.arrayUnion([invitedUserId])
            });

            await FirebaseFirestore.instance
                .collection('users')
                .doc(invitedUserId)
                .update({
              'householdMembers': FieldValue.arrayUnion([memberId])
            });
          }

          setState(() {
            householdMembers.add(invitedUserId);
            householdMemberEmails[invitedUserId] = email;
          });

          Navigator.pop(context);
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('User not found')),
        );
      }
    }
  }

  // Method to update household name in Firestore
  Future<void> _updateHouseholdName() async {
    String name = _householdNameController.text.trim();
    if (name.isNotEmpty) {
      User? user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .update({'householdName': name});
        setState(() {
          householdName = name;
        });
      }
    }
  }

  // Method to fetch the current household ID
  Future<String> _getHouseholdId() async {
    User? user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      DocumentSnapshot snapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();
      return snapshot['household_id'] ?? '1';
    }
    return '1';
  }

  // Method to assign leader to a member
  Future<void> _assignLeader(String memberId) async {
    try {
      User? user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        String householdId = await _getHouseholdId();

        // Update the household document with the new leader
        await FirebaseFirestore.instance
            .collection('household')
            .doc(householdId)
            .set({
          'leaderId': memberId,
          'lastUpdated': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));

        // Update the local state
        setState(() {
          leaderId = memberId;
        });

        // Show success message
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('New household leader assigned'),
              backgroundColor: Colors.green,
            ),
          );
        }
      }
    } catch (e) {
      print('Error assigning leader: $e');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Error assigning leader'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // Method to initialize leader ID from Firestore
  Future<void> _initializeLeaderId() async {
    try {
      String householdId = await _getHouseholdId();
      DocumentSnapshot householdDoc = await FirebaseFirestore.instance
          .collection('household')
          .doc(householdId)
          .get();

      if (householdDoc.exists) {
        setState(() {
          leaderId = householdDoc['leaderId'] ?? '';
        });
      }
    } catch (e) {
      print('Error initializing leader ID: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.blue[50],
      appBar: AppBar(
        title: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.home, color: Colors.blue[900]),
            const SizedBox(width: 8),
            Text(
              householdName.isEmpty ? 'My Household' : householdName,
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.blue[900],
              ),
            ),
            const SizedBox(width: 8),
            IconButton(
              icon: const Icon(Icons.edit),
              color: Colors.blue[900],
              onPressed: () {
                showDialog(
                  context: context,
                  builder: (context) => AlertDialog(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(15),
                    ),
                    title: const Text('Edit Household Name'),
                    content: TextField(
                      controller: _householdNameController,
                      decoration: InputDecoration(
                        labelText: 'Household Name',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        filled: true,
                        fillColor: Colors.grey[100],
                      ),
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: Text('Cancel',
                            style: TextStyle(color: Colors.grey[600])),
                      ),
                      ElevatedButton(
                        onPressed: () async {
                          try {
                            await HouseholdService.updateHouseholdName(
                                _householdNameController.text);
                            if (mounted) {
                              Navigator.pop(context);
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text(
                                      'Household name updated successfully'),
                                  backgroundColor: Colors.green,
                                ),
                              );
                            }
                          } catch (e) {
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                      'Failed to update household name: $e'),
                                  backgroundColor: Colors.red,
                                ),
                              );
                            }
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue[900],
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        child: const Text('Save'),
                      ),
                    ],
                  ),
                );
              },
            ),
          ],
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
      ),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _fetchHouseholdMembers(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          } else if (snapshot.hasError) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.error_outline, size: 64, color: Colors.red[300]),
                  const SizedBox(height: 16),
                  Text(
                    'Error fetching members',
                    style: TextStyle(
                      fontSize: 18,
                      color: Colors.red[300],
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  ElevatedButton(
                    onPressed: () {
                      setState(() {}); // Retry loading
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue[900],
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    child: const Text('Retry'),
                  ),
                ],
              ),
            );
          } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.group_outlined,
                    size: 84,
                    color: Colors.blue[200],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Your household is empty',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.blue[900],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Start by inviting family members or roommates',
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 24),
                  _buildInviteButton(context),
                ],
              ),
            );
          } else {
            List<Map<String, dynamic>> members = snapshot.data!;
            return Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 16),
                  Row(
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
                  const SizedBox(height: 16),
                  Expanded(
                    child: ListView.builder(
                      itemCount: members.length,
                      itemBuilder: (context, index) {
                        String memberId = members[index]['id'];
                        return Card(
                          elevation: 2,
                          margin: const EdgeInsets.symmetric(vertical: 8),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: ListTile(
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 8,
                            ),
                            leading: CircleAvatar(
                              backgroundColor: Colors.blue[100],
                              child: Text(
                                members[index]['email'][0].toUpperCase(),
                                style: TextStyle(
                                  color: Colors.blue[900],
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            title: Text(
                              members[index]['email'],
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            trailing: memberId == leaderId
                                ? Chip(
                                    label: const Text('Leader'),
                                    backgroundColor: Colors.blue[100],
                                    labelStyle: TextStyle(
                                      color: Colors.blue[900],
                                      fontWeight: FontWeight.bold,
                                    ),
                                  )
                                : TextButton.icon(
                                    onPressed: () => _assignLeader(memberId),
                                    icon: const Icon(Icons.star_border),
                                    label: const Text('Make Leader'),
                                    style: TextButton.styleFrom(
                                      foregroundColor: Colors.blue[900],
                                    ),
                                  ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            );
          }
        },
      ),
    );
  }

  Widget _buildInviteButton(BuildContext context) {
    return ElevatedButton.icon(
      onPressed: () {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(15),
            ),
            title: const Text('Invite to Household'),
            content: TextField(
              controller: _inviteEmailController,
              decoration: InputDecoration(
                labelText: 'Email Address',
                prefixIcon: const Icon(Icons.email),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                filled: true,
                fillColor: Colors.grey[100],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child:
                    Text('Cancel', style: TextStyle(color: Colors.grey[600])),
              ),
              ElevatedButton(
                onPressed: () {
                  _inviteToHousehold();
                  _inviteEmailController.clear();
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue[900],
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                child: const Text('Invite'),
              ),
            ],
          ),
        );
      },
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.blue[900],
        foregroundColor: Colors.white, // Changed text color to white
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
      ),
      icon: const Icon(Icons.person_add),
      label: const Text('Invite'),
    );
  }
}
