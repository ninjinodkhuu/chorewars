import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'local_notifications.dart';
import 'test_notifications.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  List<String> householdMembers = [];
  Map<String, String> householdMemberEmails = {};
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _usernameController = TextEditingController();
  bool _isUsernameChanged = false;

  // Notification preferences
  bool _taskReminderEnabled = true;
  bool _expenseUpdateEnabled = true;
  int _notificationLeadTime = 1;
  int _expenseLeadTime = 1;

  // Additional notification preferences
  bool _taskAssignmentEnabled = true;
  bool _taskCompletionEnabled = true;
  bool _taskPointsEnabled = true;
  bool _taskExpirationEnabled = true;
  bool _householdUpdatesEnabled = true;
  bool _chatNotificationsEnabled = true;
  bool _shoppingListUpdatesEnabled = true;
  bool _weeklyReportsEnabled = true;

  @override
  void initState() {
    super.initState();
    _loadHouseholdMembers();
    _loadUserEmail();
    _loadUsername();
    _loadNotificationSettings();
  }

  @override
  void dispose() {
    _emailController.dispose();
    _usernameController.dispose();
    super.dispose();
  }

  Future<void> _loadUserEmail() async {
    final User? user = FirebaseAuth.instance.currentUser;
    if (user != null && user.email != null) {
      _emailController.text = user.email!;
    }
  }

  Future<void> _loadUsername() async {
    final User? user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

      String username = userDoc.data()?.containsKey('username') == true
          ? userDoc.get('username')
          : user.email ?? '';

      setState(() {
        _usernameController.text = username;
      });
    }
  }

  Future<void> _saveUsername() async {
    final User? user = FirebaseAuth.instance.currentUser;
    if (user != null && _isUsernameChanged) {
      try {
        await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
          'username': _usernameController.text,
        }, SetOptions(merge: true));

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Username updated successfully!'),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        );
        setState(() {
          _isUsernameChanged = false;
        });
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Failed to update username'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        );
      }
    }
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

  // Load notification preferences from Firestore
  Future<void> _loadNotificationSettings() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('settings')
          .doc('notifications')
          .get();

      if (doc.exists) {
        final data = doc.data()!;
        setState(() {
          // Existing preferences
          _taskReminderEnabled = data['taskReminders'] ?? true;
          _expenseUpdateEnabled = data['expenseUpdates'] ?? true;
          _notificationLeadTime = data['notificationLeadTime'] ?? 1;
          _expenseLeadTime = data['expenseLeadTime'] ?? 1;

          // New preferences
          _taskAssignmentEnabled = data['taskAssignmentNotifications'] ?? true;
          _taskCompletionEnabled = data['taskCompletionNotifications'] ?? true;
          _taskPointsEnabled = data['taskPointNotifications'] ?? true;
          _taskExpirationEnabled = data['taskExpirationWarnings'] ?? true;
          _householdUpdatesEnabled = data['householdUpdates'] ?? true;
          _chatNotificationsEnabled = data['chatNotifications'] ?? true;
          _shoppingListUpdatesEnabled = data['shoppingListUpdates'] ?? true;
          _weeklyReportsEnabled = data['weeklyReports'] ?? true;
        });
      }
    } catch (e) {
      print('Error loading notification settings: $e');
    }
  }

  // Save notification settings to Firestore
  Future<void> _saveNotificationSettings() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('settings')
          .doc('notifications')
          .set({
            'taskReminders': _taskReminderEnabled,
            'expenseUpdates': _expenseUpdateEnabled,
            'notificationLeadTime': _notificationLeadTime,
            'expenseLeadTime': _expenseLeadTime,
            'taskAssignmentNotifications': _taskAssignmentEnabled,
            'taskCompletionNotifications': _taskCompletionEnabled,
            'taskPointNotifications': _taskPointsEnabled,
            'taskExpirationWarnings': _taskExpirationEnabled,
            'householdUpdates': _householdUpdatesEnabled,
            'chatNotifications': _chatNotificationsEnabled,
            'shoppingListUpdates': _shoppingListUpdatesEnabled,
            'weeklyReports': _weeklyReportsEnabled,
            'updatedAt': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Notification settings saved!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error saving settings: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Widget _buildNotificationSettings() {
    return Card(
      margin: const EdgeInsets.all(16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Notification Settings',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.bug_report),
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => const TestNotifications()),
                    );
                  },
                  tooltip: 'Test Notifications',
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Tasks Section
            const Text(
              'Tasks',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.blue,
              ),
            ),
            SwitchListTile(
              title: const Text('Task Reminders'),
              subtitle: Text(_taskReminderEnabled 
                  ? 'Notify $_notificationLeadTime day(s) before due date'
                  : 'Disabled'),
              value: _taskReminderEnabled,
              onChanged: (bool value) => setState(() => _taskReminderEnabled = value),
            ),
            if (_taskReminderEnabled)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: DropdownButtonFormField<int>(
                  decoration: const InputDecoration(
                    labelText: 'Reminder Lead Time',
                  ),
                  value: _notificationLeadTime,
                  items: [1, 2, 3, 4, 5].map((int value) {
                    return DropdownMenuItem<int>(
                      value: value,
                      child: Text('$value day(s) before'),
                    );
                  }).toList(),
                  onChanged: (value) {
                    if (value != null) setState(() => _notificationLeadTime = value);
                  },
                ),
              ),
            SwitchListTile(
              title: const Text('Task Assignments'),
              subtitle: const Text('When someone assigns you a task'),
              value: _taskAssignmentEnabled,
              onChanged: (value) => setState(() => _taskAssignmentEnabled = value),
            ),
            SwitchListTile(
              title: const Text('Task Completions'),
              subtitle: const Text('When household members complete tasks'),
              value: _taskCompletionEnabled,
              onChanged: (value) => setState(() => _taskCompletionEnabled = value),
            ),
            SwitchListTile(
              title: const Text('Point Updates'),
              subtitle: const Text('When you earn points for tasks'),
              value: _taskPointsEnabled,
              onChanged: (value) => setState(() => _taskPointsEnabled = value),
            ),
            SwitchListTile(
              title: const Text('Task Expiration Warnings'),
              subtitle: const Text('When tasks are about to expire'),
              value: _taskExpirationEnabled,
              onChanged: (value) => setState(() => _taskExpirationEnabled = value),
            ),

            const Divider(height: 32),

            // Household Section
            const Text(
              'Household',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.blue,
              ),
            ),
            SwitchListTile(
              title: const Text('Household Updates'),
              subtitle: const Text('Member changes and achievements'),
              value: _householdUpdatesEnabled,
              onChanged: (value) => setState(() => _householdUpdatesEnabled = value),
            ),
            SwitchListTile(
              title: const Text('Weekly Reports'),
              subtitle: const Text('Weekly household performance summary'),
              value: _weeklyReportsEnabled,
              onChanged: (value) => setState(() => _weeklyReportsEnabled = value),
            ),

            const Divider(height: 32),

            // Communication Section
            const Text(
              'Communication',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.blue,
              ),
            ),
            SwitchListTile(
              title: const Text('Chat Notifications'),
              subtitle: const Text('Messages and @mentions'),
              value: _chatNotificationsEnabled,
              onChanged: (value) => setState(() => _chatNotificationsEnabled = value),
            ),

            const Divider(height: 32),

            // Shopping Section
            const Text(
              'Shopping',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.blue,
              ),
            ),
            SwitchListTile(
              title: const Text('Shopping List Updates'),
              subtitle: const Text('When items are added or completed'),
              value: _shoppingListUpdatesEnabled,
              onChanged: (value) => setState(() => _shoppingListUpdatesEnabled = value),
            ),
            SwitchListTile(
              title: const Text('Expense Updates'),
              subtitle: const Text('When new expenses are added'),
              value: _expenseUpdateEnabled,
              onChanged: (value) => setState(() => _expenseUpdateEnabled = value),
            ),

            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _saveNotificationSettings,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue[900],
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
                child: const Text(
                  'Save Notification Settings',
                  style: TextStyle(color: Colors.white),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: CustomScrollView(
        key: const PageStorageKey<String>('profileScroll'),
        slivers: [
          SliverAppBar(
            expandedHeight: 200.0,
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                color: Colors.blueAccent,
                child: Stack(
                  alignment: Alignment.center,
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
                      bottom: 40,
                      right: 125,
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
          SliverToBoxAdapter(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const SizedBox(height: 20),
                      TextFormField(
                        controller: _usernameController,
                        decoration: const InputDecoration(
                          labelText: 'Username',
                          prefixIcon: Icon(Icons.person),
                          helperText: 'This name will be visible to other members',
                        ),
                        onChanged: (value) {
                          setState(() {
                            _isUsernameChanged = true;
                          });
                        },
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _emailController,
                        decoration: const InputDecoration(
                          labelText: 'Email Address',
                          prefixIcon: Icon(Icons.email),
                          helperText: 'Your account email address cannot be changed',
                        ),
                        readOnly: true,
                        enabled: false,
                      ),
                      const SizedBox(height: 24),
                      ElevatedButton(
                        onPressed: _isUsernameChanged ? _saveUsername : null,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue[900],
                          disabledBackgroundColor: Colors.grey[400],
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: const Text(
                          'Save Changes',
                          style: TextStyle(color: Colors.white),
                        ),
                      ),
                      const SizedBox(height: 24),
                    ],
                  ),
                ),
                _buildNotificationSettings(),
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
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
              ],
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
    );
  }
}
