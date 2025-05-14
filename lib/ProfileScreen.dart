// =========================
// ProfileScreen.dart
// =========================
// This file implements the user profile screen for Chorewars.
// It allows users to view and edit their profile, manage household members, and set notification preferences.
//
// Key design decisions:
// - Integrates with Firebase Auth and Firestore for user and household data.
// - Supports editing username, inviting members, and managing notification settings.
// - Notification preferences are loaded and saved for each user.
// - UI provides feedback for actions (e.g., saving, errors) using SnackBar.
//
// Contributor notes:
// - All Firestore and notification logic is abstracted for easier updates.
// - If you add new profile fields or notification types, update both the UI and Firestore logic.
// - Keep comments up to date for onboarding new contributors.

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';
import 'test_notifications.dart';
import 'theme_notifier.dart';

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
    _loadThemePreference();
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

  Future<void> _saveThemePreference(String theme) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('settings')
          .doc('preferences')
          .set({
        'theme': theme,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Theme saved!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error saving theme: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _loadThemePreference() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('settings')
          .doc('preferences')
          .get();

      if (doc.exists) {
        final theme = doc.data()?['theme'] as String?;
        if (theme != null && mounted) {
          final themeNotifier = Provider.of<ThemeNotifier>(context, listen: false);
          themeNotifier.setTheme(theme);
        }
      }
    } catch (e) {
      print('Error loading theme preference: $e');
    }
  }

  Widget _buildNotificationSettings() {
    final textTheme = Theme.of(context).textTheme;
    return Card(
      margin: const EdgeInsets.all(16),
      color: Theme.of(context).cardColor, 
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Notification Settings',
                  style: textTheme.titleLarge?.copyWith(
                    color: Theme.of(context).primaryColor,
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.bug_report, color: Theme.of(context).primaryColor),
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (context) => const TestNotifications()),
                    );
                  },
                  tooltip: 'Test Notifications',
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Tasks Section
            Text(
              'Tasks',
              style: textTheme.titleMedium?.copyWith(
                color: Theme.of(context).primaryColor,
              ),
            ),
            SwitchListTile(
              title: Text(
                'Task Reminders',
                style: Theme.of(context).textTheme.bodyLarge,
              ),
              subtitle: Text(
                _taskReminderEnabled
                    ? 'Notify $_notificationLeadTime day(s) before due date'
                    : 'Disabled',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              value: _taskReminderEnabled,
              onChanged: (bool value) =>
                  setState(() => _taskReminderEnabled = value),
              activeColor: Theme.of(context).primaryColor,
            ),
            if (_taskReminderEnabled)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: DropdownButtonFormField<int>(
                  decoration: InputDecoration(
                    labelText: 'Reminder Lead Time',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(
                        color: Theme.of(context).primaryColor,
                      ),
                    ),
                  ),
                  value: _notificationLeadTime,
                  items: [1, 2, 3, 4, 5].map((int value) {
                    return DropdownMenuItem<int>(
                      value: value,
                      child: Text('$value day(s) before'),
                    );
                  }).toList(),
                  onChanged: (value) {
                    if (value != null) {
                      setState(() => _notificationLeadTime = value);
                    }
                  },
                ),
              ),
            SwitchListTile(
              title: Text(
                'Task Assignments',
                style: Theme.of(context).textTheme.bodyLarge,
              ),
              subtitle: Text(
                'When someone assigns you a task',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              value: _taskAssignmentEnabled,
              onChanged: (value) =>
                  setState(() => _taskAssignmentEnabled = value),
              activeColor: Theme.of(context).primaryColor,
            ),
            SwitchListTile(
              title: Text(
                'Task Completions',
                style: Theme.of(context).textTheme.bodyLarge,
              ),
              subtitle: Text(
                'When household members complete tasks',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              value: _taskCompletionEnabled,
              onChanged: (value) =>
                  setState(() => _taskCompletionEnabled = value),
              activeColor: Theme.of(context).primaryColor,
            ),
            SwitchListTile(
              title: Text(
                'Point Updates',
                style: Theme.of(context).textTheme.bodyLarge,
              ),
              subtitle: Text(
                'When you earn points for tasks',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              value: _taskPointsEnabled,
              onChanged: (value) => setState(() => _taskPointsEnabled = value),
              activeColor: Theme.of(context).primaryColor,
            ),
            SwitchListTile(
              title: Text(
                'Task Expiration Warnings',
                style: Theme.of(context).textTheme.bodyLarge,
              ),
              subtitle: Text(
                'When tasks are about to expire',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              value: _taskExpirationEnabled,
              onChanged: (value) =>
                  setState(() => _taskExpirationEnabled = value),
              activeColor: Theme.of(context).primaryColor,
            ),

            const Divider(height: 32),

            // Household Section
            Text(
              'Household',
              style: textTheme.titleMedium?.copyWith(
                color: Theme.of(context).primaryColor,
              ),
            ),
            SwitchListTile(
              title: Text(
                'Household Updates',
                style: Theme.of(context).textTheme.bodyLarge,
              ),
              subtitle: Text(
                'Member changes and achievements',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              value: _householdUpdatesEnabled,
              onChanged: (value) =>
                  setState(() => _householdUpdatesEnabled = value),
              activeColor: Theme.of(context).primaryColor,
            ),
            SwitchListTile(
              title: Text(
                'Weekly Reports',
                style: Theme.of(context).textTheme.bodyLarge,
              ),
              subtitle: Text(
                'Weekly household performance summary',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              value: _weeklyReportsEnabled,
              onChanged: (value) =>
                  setState(() => _weeklyReportsEnabled = value),
              activeColor: Theme.of(context).primaryColor,
            ),

            const Divider(height: 32),

            // Communication Section
            Text(
              'Communication',
              style: textTheme.titleMedium?.copyWith(
                color: Theme.of(context).primaryColor,
              ),
            ),
            SwitchListTile(
              title: Text(
                'Chat Notifications',
                style: Theme.of(context).textTheme.bodyLarge,
              ),
              subtitle: Text(
                'Messages and @mentions',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              value: _chatNotificationsEnabled,
              onChanged: (value) =>
                  setState(() => _chatNotificationsEnabled = value),
              activeColor: Theme.of(context).primaryColor,
            ),

            const Divider(height: 32),

            // Shopping Section
            Text(
              'Shopping',
              style: textTheme.titleMedium?.copyWith(
                color: Theme.of(context).primaryColor,
              ),
            ),
            SwitchListTile(
              title: Text(
                'Shopping List Updates',
                style: Theme.of(context).textTheme.bodyLarge,
              ),
              subtitle: Text(
                'When items are added or completed',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              value: _shoppingListUpdatesEnabled,
              onChanged: (value) =>
                  setState(() => _shoppingListUpdatesEnabled = value),
              activeColor: Theme.of(context).primaryColor,
            ),
            SwitchListTile(
              title: Text(
                'Expense Updates',
                style: Theme.of(context).textTheme.bodyLarge,
              ),
              subtitle: Text(
                'When new expenses are added',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              value: _expenseUpdateEnabled,
              onChanged: (value) =>
                  setState(() => _expenseUpdateEnabled = value),
              activeColor: Theme.of(context).primaryColor,
            ),

            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _saveNotificationSettings,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).primaryColor,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
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
                color: Theme.of(context).primaryColor,
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
                        child: CircleAvatar(
                          radius: 15,
                          backgroundColor: Colors.white,
                          child: Icon(
                            Icons.camera_alt,
                            size: 15,
                            color: Theme.of(context).primaryColor,
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
                        style: Theme.of(context).textTheme.bodyLarge,
                        decoration: InputDecoration(
                          labelText: 'Username',
                          labelStyle: Theme.of(context).textTheme.bodyLarge?.copyWith(
                            color: Theme.of(context).primaryColor,
                          ),
                          prefixIcon: Icon(Icons.person, color: Theme.of(context).primaryColor),
                          helperText: 'This name will be visible to other members',
                          helperStyle: Theme.of(context).textTheme.bodySmall,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide(
                              color: Theme.of(context).primaryColor,
                            ),
                          ),
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
                        style: Theme.of(context).textTheme.bodyLarge,
                        decoration: InputDecoration(
                          labelText: 'Email Address',
                          labelStyle: Theme.of(context).textTheme.bodyLarge?.copyWith(
                            color: Theme.of(context).primaryColor,
                          ),
                          prefixIcon: Icon(Icons.email, color: Theme.of(context).primaryColor),
                          helperText: 'Your account email address cannot be changed',
                          helperStyle: Theme.of(context).textTheme.bodySmall,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        readOnly: true,
                        enabled: false,
                      ),
                      const SizedBox(height: 16),
                      Consumer<ThemeNotifier>(
                        builder: (context, themeNotifier, child) {
                          return DropdownButtonFormField<String>(
                            style: Theme.of(context).textTheme.bodyLarge,
                            decoration: InputDecoration(
                              labelText: 'Theme',
                              labelStyle: Theme.of(context).textTheme.bodyLarge?.copyWith(
                                color: Theme.of(context).primaryColor,
                              ),
                              prefixIcon: Icon(Icons.color_lens, color: Theme.of(context).primaryColor),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide: BorderSide(
                                  color: Theme.of(context).primaryColor,
                                ),
                              ),
                            ),
                            items: const [
                              DropdownMenuItem(
                                value: 'Blue',
                                child: Text('Blue Theme'),
                              ),
                              DropdownMenuItem(
                                value: 'Green',
                                child: Text('Green Theme'),
                              ),
                            ],
                            value: ThemeNotifier.getThemeName(themeNotifier.currentTheme),
                            onChanged: (value) {
                              if (value != null) {
                                themeNotifier.setTheme(value);
                                _saveThemePreference(value);
                              }
                            },
                          );
                        },
                      ),
                      const SizedBox(height: 24),
                      ElevatedButton(
                        onPressed: _isUsernameChanged ? _saveUsername : null,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Theme.of(context).primaryColor,
                          disabledBackgroundColor: Colors.grey[400],
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: Text(
                          'Save Changes',
                          style: Theme.of(context).textTheme.labelLarge?.copyWith(
                            color: Colors.white,
                          ),
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
                      Text(
                        'Household Members',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          color: Theme.of(context).primaryColor,
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
                  title: Text(
                    email,
                    style: Theme.of(context).textTheme.bodyLarge,
                  ),
                  leading: CircleAvatar(
                    backgroundColor: Theme.of(context).primaryColor.withOpacity(0.1),
                    child: Text(
                      email[0].toUpperCase(),
                      style: TextStyle(
                        color: Theme.of(context).primaryColor,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
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
