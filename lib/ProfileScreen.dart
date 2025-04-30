import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

// ProfileScreen is a stateful widget because it needs to manage the state of the household members and user profile.
class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  _ProfileScreenState createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  // Controller for the email input field used to invite new household members.
  final TextEditingController _inviteEmailController = TextEditingController();
  // List to store the IDs of household members.
  List<String> householdMembers = [];
  // Map to store the emails of household members.
  Map<String, String> householdMemberEmails = {};

  @override
  void initState() {
    super.initState();
    // Load household members when the widget is initialized.
    _loadHouseholdMembers();
  }

  // Method to load household members from Firestore.
  Future<void> _loadHouseholdMembers() async {
    User? user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      // Get the current user's document from Firestore.
      DocumentSnapshot snapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

      // Get the list of household member IDs from the user's document.
      List<String> memberIds =
          List<String>.from(snapshot['householdMembers'] ?? []);
      setState(() {
        householdMembers = memberIds;
      });

      // Get the email addresses of each household member.
      for (String memberId in memberIds) {
        DocumentSnapshot memberSnapshot = await FirebaseFirestore.instance
            .collection('users')
            .doc(memberId)
            .get();
        setState(() {
          householdMemberEmails[memberId] = memberSnapshot['email'];
        });
      }
    }
  }

  // Method to invite a new member to the household.
  Future<void> _inviteToHousehold() async {
    String email = _inviteEmailController.text.trim();
    if (email.isNotEmpty) {
      // Find the user by email.
      QuerySnapshot userSnapshot = await FirebaseFirestore.instance
          .collection('users')
          .where('email', isEqualTo: email)
          .get();

      if (userSnapshot.docs.isNotEmpty) {
        String invitedUserId = userSnapshot.docs.first.id;

        User? user = FirebaseAuth.instance.currentUser;
        if (user != null) {
          // Add the invited user to the current user's household.
          await FirebaseFirestore.instance
              .collection('users')
              .doc(user.uid)
              .update({
            'householdMembers': FieldValue.arrayUnion([invitedUserId])
          });

          // Add the current user to the invited user's household.
          await FirebaseFirestore.instance
              .collection('users')
              .doc(invitedUserId)
              .update({
            'householdMembers': FieldValue.arrayUnion([user.uid])
          });

          // Add the invited user to all current household members' households.
          for (String memberId in householdMembers) {
            await FirebaseFirestore.instance
                .collection('users')
                .doc(memberId)
                .update({
              'householdMembers': FieldValue.arrayUnion([invitedUserId])
            });

            // Add each household member to the invited user's household.
            await FirebaseFirestore.instance
                .collection('users')
                .doc(invitedUserId)
                .update({
              'householdMembers': FieldValue.arrayUnion([memberId])
            });
          }

          // Update the local state.
          setState(() {
            householdMembers.add(invitedUserId);
            householdMemberEmails[invitedUserId] = email;
          });

          // Close the invite dialog.
          Navigator.pop(context);
        }
      } else {
        // Show error message if user not found.
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('User not found')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // CustomScrollView allows for a scrollable view with slivers.
      body: CustomScrollView(
        key: const PageStorageKey<String>('profileScroll'),
        slivers: [
          // SliverAppBar provides a flexible app bar.
          SliverAppBar(
            expandedHeight: 200.0,
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                color: Colors.blueAccent, // Background color of the app bar.
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    // CircleAvatar to display the user's profile picture.
                    CircleAvatar(
                      radius: 50,
                      backgroundImage:
                          const AssetImage('assets/default_profile.png'),
                      onBackgroundImageError: (_, __) {
                        debugPrint('Failed to load image');
                      },
                      child: const Icon(
                        Icons.person,
                        size: 50,
                        color: Colors.white,
                      ),
                    ),
                    // Positioned widget to place the camera icon at the bottom right of the profile picture.
                    Positioned(
                      bottom: 40,
                      right: 125,
                      child: GestureDetector(
                        onTap: () {
                          // Handle changing the profile picture.
                        },
                        child: const CircleAvatar(
                          radius: 15,
                          backgroundColor: Colors.white,
                          child: Icon(
                            Icons.camera_alt,
                            size: 15,
                            color: Colors.blueAccent,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          // SliverToBoxAdapter allows for non-sliver widgets to be placed in a sliver.
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: 20),
                  // TextFormField for the username.
                  TextFormField(
                    decoration: const InputDecoration(
                      labelText: 'Username',
                      prefixIcon: Icon(Icons.person),
                    ),
                  ),
                  const SizedBox(height: 16),
                  // TextFormField for the email address.
                  TextFormField(
                    decoration: const InputDecoration(
                      labelText: 'Email Address',
                      prefixIcon: Icon(Icons.email),
                    ),
                  ),
                  const SizedBox(height: 16),
                  // DropdownButtonFormField for selecting the theme.
                  DropdownButtonFormField<String>(
                    decoration: const InputDecoration(
                      labelText: 'Theme',
                      prefixIcon: Icon(Icons.color_lens),
                    ),
                    items: const [
                      DropdownMenuItem(
                        value: 'Light',
                        child: Text('Light Theme'),
                      ),
                      DropdownMenuItem(
                        value: 'Dark',
                        child: Text('Dark Theme'),
                      ),
                    ],
                    onChanged: (value) {
                      // Handle theme change.
                    },
                  ),
                  const SizedBox(height: 24),
                  // ElevatedButton to save profile changes.
                  ElevatedButton(
                    onPressed: () {
                      // Save profile changes.
                    },
                    child: const Text('Save Changes'),
                  ),
                  const SizedBox(height: 24),
                  // Text widget to display the title "Household Members".
                  const Text(
                    'Household Members',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            ),
          ),
          SliverList(
            delegate: SliverChildBuilderDelegate(
              (context, index) {
                if (index >= householdMembers.length) return null;
                String memberId = householdMembers[index];
                String email = householdMemberEmails[memberId] ?? 'Loading...';
                return ListTile(
                  title: Text(email),
                  leading: CircleAvatar(
                    child: Text(email[0].toUpperCase()),
                  ),
                );
              },
              childCount: householdMembers.length,
            ),
          ),
        ],
      ),
      // FloatingActionButton to handle edit profile action.
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          showDialog(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text('Invite Members to Household'),
              content: TextField(
                controller: _inviteEmailController,
                decoration: const InputDecoration(labelText: 'Email Address'),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
                TextButton(
                  onPressed: _inviteToHousehold,
                  child: const Text('Invite'),
                ),
              ],
            ),
          );
        },
        child: const Icon(Icons.person_add),
      ),
    );
  }
}
