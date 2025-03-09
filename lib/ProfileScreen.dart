import 'package:expenses_tracker/local_notifications.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  _ProfileScreenState createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final TextEditingController _inviteEmailController = TextEditingController();
  List<String> householdMembers = [];
  Map<String, String> householdMemberEmails = {};

  // Notification preferences
  bool taskReminderEnabled = true;
  bool expenseUpdateEnabled = true;
  int notificationLeadTime = 1;
  int expenseLeadTime = 1;

  @override
  void initState() {
    super.initState();
    _loadHouseholdMembers();
    _loadNotificationSettings();
  }

  Future<void> _loadHouseholdMembers() async {
    User? user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      DocumentSnapshot snapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

      List<String> memberIds =
          List<String>.from(snapshot['householdMembers'] ?? []);
      setState(() {
        householdMembers = memberIds;
      });

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

  Future<void> _loadNotificationSettings() async {
    User? user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      DocumentSnapshot snapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();
      final data = snapshot.data() as Map<String, dynamic>?;
      final notificationSettings = data?['notificationSettings'] as Map<String, dynamic>?;
      setState(() {
        taskReminderEnabled = notificationSettings?['taskReminders'] ?? true;
        expenseUpdateEnabled = notificationSettings?['expenseUpdates'] ?? true;
        notificationLeadTime = notificationSettings?['notificationLeadTime'] ?? 1;
        expenseLeadTime = notificationSettings?['expenseLeadTime'] ?? 1;
      });
    }
  }

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
          SnackBar(content: Text('User not found')),
        );
      }
    }
  }

  Future<void> _saveNotificationSettings() async {
    User? user = FirebaseAuth.instance.currentUser;
    if (user != null) {
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
          /*if (taskReminderEnabled) {
            // schedule task reminders
            LocalNotificationService.scheduleTaskReminder(taskId, taskName, taskDueDate, notificationLeadTime);
          } else {
            // cancel scheduled task reminders
            LocalNotificationService.cancelTaskReminder(taskId);
          }
          if (expenseUpdateEnabled) {
            // setup expense update notification
            LocalNotificationService.sendExpenseNotification(amount, selectedCategory);
          } else {
            // cancel expense update notifications
          }*/
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Notification settings updated!')),
      );
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
                            AssetImage('assets/default_profile.png'),
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
                          child: CircleAvatar(
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
                  Divider(),
                  const SizedBox(height: 10),
                  Text(
                    'Notification Preferences',
                    style: TextStyle(
                      fontSize: 18, 
                      fontWeight: FontWeight.bold
                    ),
                  ),
                  SwitchListTile(
                    title: Text('Task Reminders'),
                    value: taskReminderEnabled, 
                    onChanged: (bool value) {
                      setState(() {
                        taskReminderEnabled = value;
                      });
                    },
                  ),
                  if (taskReminderEnabled)
                    DropdownButtonFormField<int>(
                      decoration: InputDecoration(
                        labelText: 'Remind me of tasks:',
                        prefixIcon: Icon(Icons.notifications_active),
                      ),
                      value: notificationLeadTime,
                      items: [
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
                  SwitchListTile(
                    title: Text('Expense Updates'),
                    value: expenseUpdateEnabled, 
                    onChanged: (bool value) {
                      setState(() {
                        expenseUpdateEnabled = value;
                      });
                    },
                  ),
                  if (expenseUpdateEnabled)
                    DropdownButtonFormField<int>(
                      decoration: InputDecoration(
                        labelText: 'Remind me of expenses:',
                        prefixIcon: Icon(Icons.attach_money),
                      ),
                      value: expenseLeadTime,
                      items: [
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
                    child: Text('Save Notification Preferences'),
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
                    items: [
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
                  Text(
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
                            title: Text('Invite Members to Household'),
                            content: TextField(
                              controller: _inviteEmailController,
                              decoration: InputDecoration(
                                labelText: 'Email Address',
                              ),
                            ),
                            actions: [
                              TextButton(
                                onPressed: () {
                                  Navigator.pop(context);
                                },
                                child: Text('Cancel'),
                              ),
                              TextButton(
                                onPressed: _inviteToHousehold,
                                child: Text('Invite'),
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
