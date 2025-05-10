import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  _ProfileScreenState createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  List<String> householdMembers = [];
  Map<String, String> householdMemberEmails = {};
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _usernameController = TextEditingController();
  bool _isUsernameChanged = false;

  @override
  void initState() {
    super.initState();
    _loadHouseholdMembers();
    _loadUserEmail();
    _loadUsername();
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
            child: Padding(
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
                      helperText:
                          'Your account email address cannot be changed',
                    ),
                    readOnly: true,
                    enabled: false,
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
                    value: 'Light',
                    onChanged: (value) {
                      // Handle theme change
                    },
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
    );
  }
}
