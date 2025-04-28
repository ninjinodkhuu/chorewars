import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  _ProfileScreenState createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  // Controller for inviting household members via email
  final TextEditingController _inviteEmailController = TextEditingController();
  List<String> householdMembers = [];
  Map<String, String> householdMemberEmails = {};

  // Notification preferences 
  bool taskReminderEnabled = true;  // toggle for task reminders
  bool expenseUpdateEnabled = true;
  int notificationLeadTime = 1;  // dropdown for task reminder
  int expenseLeadTime = 1;

  @override
  void initState() {
    super.initState();
    _loadHouseholdMembers();
    _loadNotificationSettings();  // loads notification preferences from firestore
  }

  // Loads household members for the current user from Firestore
  Future<void> _loadHouseholdMembers() async {
    User? user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      // Get current user document
      DocumentSnapshot snapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();
      
      // Extract household member IDs
      List<String> memberIds =
          List<String>.from(snapshot['householdMembers'] ?? []);
      setState(() {
        householdMembers = memberIds;
      });

      // Load each member's email address
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

  // Loads the user's notification preferences from Firestore
  Future<void> _loadNotificationSettings() async {
    User? user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      // Get user document data
      DocumentSnapshot snapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();
      final data = snapshot.data() as Map<String, dynamic>?;
      // Extract notification settings from the document
      final notificationSettings = data?['notificationSettings'] as Map<String, dynamic>?;
      
      setState(() {
        taskReminderEnabled = notificationSettings?['taskReminders'] ?? true;
        expenseUpdateEnabled = notificationSettings?['expenseUpdates'] ?? true;
        notificationLeadTime = notificationSettings?['notificationLeadTime'] ?? 1;
        expenseLeadTime = notificationSettings?['expenseLeadTime'] ?? 1;
      });
    }
  }

  // Invites a new household member using their email address
  Future<void> _inviteToHousehold() async {
    String email = _inviteEmailController.text.trim();
    if (email.isNotEmpty) {
      // Find the user by email
      QuerySnapshot userSnapshot = await FirebaseFirestore.instance
          .collection('users')
          .where('email', isEqualTo: email)
          .get();

      if (userSnapshot.docs.isNotEmpty) {
        String invitedUserId = userSnapshot.docs.first.id;

        User? user = FirebaseAuth.instance.currentUser;
        if (user != null) {
          // Add the invited user to the current user's household
          await FirebaseFirestore.instance
              .collection('users')
              .doc(user.uid)
              .update({
            'householdMembers': FieldValue.arrayUnion([invitedUserId])
          });

          // Add the current user to the invited user's household
          await FirebaseFirestore.instance
              .collection('users')
              .doc(invitedUserId)
              .update({
            'householdMembers': FieldValue.arrayUnion([user.uid])
          });

          // Add the invited user to all current household members' households
          for (String memberId in householdMembers) {
            await FirebaseFirestore.instance
                .collection('users')
                .doc(memberId)
                .update({
              'householdMembers': FieldValue.arrayUnion([invitedUserId])
            });

            // Add each household member to the invited user's household
            await FirebaseFirestore.instance
                .collection('users')
                .doc(invitedUserId)
                .update({
              'householdMembers': FieldValue.arrayUnion([memberId])
            });
          }

          // Update the local state
          setState(() {
            householdMembers.add(invitedUserId);
            householdMemberEmails[invitedUserId] = email;
          });

          Navigator.pop(context);
        }
      } else {
        // Show error message if user not found
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('User not found')),
        );
      }
    }
  }

  // Saves notification preferences to Firestore when "save" button is pressed
  Future<void> _saveNotificationSettings() async {
    User? user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      // Save settings under the user's document
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .set({
            'notificationSettings': {
              'taskReminders': taskReminderEnabled,
              'expenseUpdates': expenseUpdateEnabled,
              'notificationLeadTime': notificationLeadTime,
              'expenseLeadTime': expenseLeadTime,
            },
          }, SetOptions(merge: true));
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Notification settings updated!')),
      );
      // Reload settings
      await _loadNotificationSettings();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 200.0,
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                color: Colors.blueAccent,
                child: Align(
                  alignment: Alignment.bottomCenter,
                  child: Stack(
                    children: [
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
                      Positioned(
                        bottom: 0,
                        right: 0,
                        child: GestureDetector(
                          onTap: () {
                            // Handle changing the profile picture
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
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  const SizedBox(height: 20),
                  TextFormField(
                    decoration: const InputDecoration(
                      labelText: 'Username',
                      prefixIcon: Icon(Icons.person),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Divider(),
                  const SizedBox(height: 10),
                  // Header for notification preferences section
                  const Text(
                    'Notification Preferences',
                    style: TextStyle(
                      fontSize: 18, 
                      fontWeight: FontWeight.bold
                    ),
                  ),
                  // Toggle for task reminders
                  SwitchListTile(
                    title: const Text('Task Reminders'),
                    value: taskReminderEnabled, 
                    onChanged: (bool value) {
                      setState(() {
                        taskReminderEnabled = value;
                      });
                    },
                  ),
                  // Dropdown for tasks when reminders are enabled
                  if (taskReminderEnabled)
                    DropdownButtonFormField<int>(
                      decoration: const InputDecoration(
                        labelText: 'Remind me of tasks:',
                        prefixIcon: Icon(Icons.notifications_active),
                      ),
                      value: notificationLeadTime,
                      items: const [
                        DropdownMenuItem(value: 1, child: Text('1 day before')),
                        DropdownMenuItem(value: 2, child: Text('2 day before')),
                        DropdownMenuItem(value: 3, child: Text('3 day before')),
                      ], 
                      onChanged: (value) {
                        setState(() {
                          notificationLeadTime = value!;
                        });
                      },
                    ),
                  // Toggle for expense updates notification
                  SwitchListTile(
                    title: const Text('Expense Updates'),
                    value: expenseUpdateEnabled, 
                    onChanged: (bool value) {
                      setState(() {
                        expenseUpdateEnabled = value;
                      });
                    },
                  ),
                  // Dropdown for expenses when reminders are enabled
                  if (expenseUpdateEnabled)
                    DropdownButtonFormField<int>(
                      decoration: const InputDecoration(
                        labelText: 'Remind me of expenses:',
                        prefixIcon: Icon(Icons.attach_money),
                      ),
                      value: expenseLeadTime,
                      items: const [
                        DropdownMenuItem(value: 1, child: Text('1 day before')),
                        DropdownMenuItem(value: 2, child: Text('2 day before')),
                        DropdownMenuItem(value: 3, child: Text('3 day before')),
                      ], 
                      onChanged: (value) {
                        setState(() {
                          expenseLeadTime = value!;
                        });
                      },
                    ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: _saveNotificationSettings, 
                    child: const Text('Save Notification Preferences'),
                  ),
                  TextFormField(
                    decoration: const InputDecoration(
                      labelText: 'Email Address',
                      prefixIcon: Icon(Icons.email),
                    ),
                  ),
                  const SizedBox(height: 16),
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
                      // Handle theme change
                    },
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () {
                      // Save profile changes
                    },
                    child: const Text('Save Changes'),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Household Members',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 1),
                  ListView.builder(
                    shrinkWrap: true,
                    itemCount: householdMembers.length,
                    itemBuilder: (context, index) {
                      String memberId = householdMembers[index];
                      String email =
                          householdMemberEmails[memberId] ?? 'Loading...';
                      return ListTile(
                        title: Text(email),
                      );
                    },
                  ),
                  const SizedBox(height: 2),
                  ElevatedButton(
                    onPressed: () {
                      showDialog(
                        context: context,
                        builder: (context) {
                          return AlertDialog(
                            title: const Text('Invite Members to Household'),
                            content: TextField(
                              controller: _inviteEmailController,
                              decoration: const InputDecoration(
                                labelText: 'Email Address',
                              ),
                            ),
                            actions: [
                              TextButton(
                                onPressed: () {
                                  Navigator.pop(context);
                                },
                                child: const Text('Cancel'),
                              ),
                              TextButton(
                                onPressed: _inviteToHousehold,
                                child: const Text('Invite'),
                              ),
                            ],
                          );
                        },
                      );
                    },
                    child: const Text('Invite Members to Household'),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          // Handle edit profile action
        },
        child: const Icon(Icons.edit),
      ),
    );
  }
}