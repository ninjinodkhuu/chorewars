import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cw/ProfileScreen.dart';
import 'package:cw/CalenderScreen.dart';
import 'package:cw/Expense_tracking.dart';
import 'package:cw/Gamification.dart';
import 'package:cw/home_screen.dart';
import 'package:cw/shopping_list.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  _HomePageState createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final user = FirebaseAuth.instance.currentUser!;
  int _selectedIndex = 0;
  final PageController _pageController = PageController();

  void signUserOut() {
    FirebaseAuth.instance.signOut();
  }

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
    _pageController.jumpToPage(index);
  }

  // Navigate to household members screen
  void viewHouseholdMembers(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const HouseholdMembersScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).primaryColorLight,
        title: Text(
          'Home Page',
          style: Theme.of(context).textTheme.headlineMedium,
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.group, color: Theme.of(context).unselectedWidgetColor),
            onPressed: () => viewHouseholdMembers(context),
          ),
          IconButton(
            icon: Icon(Icons.person, color: Theme.of(context).unselectedWidgetColor),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (context) =>
                        const ProfileScreen()), // Navigate to ProfileScreen
              );
            },
          ),
          IconButton(
            onPressed: signUserOut,
            icon: Icon(Icons.logout, color: Theme.of(context).unselectedWidgetColor),
          )
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: ''),
          BottomNavigationBarItem(icon: Icon(Icons.calendar_today), label: ' '),
          BottomNavigationBarItem(icon: Icon(Icons.attach_money), label: ''),
          BottomNavigationBarItem(icon: Icon(Icons.leaderboard), label: ''),
          BottomNavigationBarItem(icon: Icon(Icons.apple), label: ''),
        ],
        currentIndex: _selectedIndex, // Highlight the selected item
        onTap: _onItemTapped, // Call _onItemTapped when an item is tapped
        backgroundColor: Theme.of(context).primaryColorLight,
        selectedItemColor: Theme.of(context).iconTheme.color,
        unselectedItemColor: Theme.of(context).unselectedWidgetColor,
        type: BottomNavigationBarType.fixed,
      ),
      body: PageView(
        controller: _pageController,
        onPageChanged: (index) {
          setState(() {
            _selectedIndex = index;
          });
        },
        children: [
          HomeScreen(), // Your current home page
          const CalendarScreen(), // Placeholder for Calendar screen
          const ExpenseTracking(), // Placeholder for Notifications screen
          const Gamification(),
          const ShoppingList(),
        ],
      ),
    );
  }
}

// Updated screen for household members
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
  }

  // Method to load household name from Firestore
  Future<void> _loadHouseholdName() async {
    User? user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      DocumentSnapshot snapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();
      setState(() {
        householdName = snapshot['householdName'] ?? '';
        _householdNameController.text = householdName;
      });
    }
  }

  // Method to fetch household members from Firestore
  Future<List<Map<String, dynamic>>> _fetchHouseholdMembers() async {
    User? user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      DocumentSnapshot snapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

      List<String> memberIds =
          List<String>.from(snapshot['householdMembers'] ?? []);
      if (!memberIds.contains(user.uid)) {
        memberIds.add(user.uid); // Include the user's own account
      }
      List<Map<String, dynamic>> members = [];

      for (String memberId in memberIds) {
        DocumentSnapshot memberSnapshot = await FirebaseFirestore.instance
            .collection('users')
            .doc(memberId)
            .get();
        members.add({
          'id': memberId,
          'email': memberSnapshot['email'],
        });
      }
      householdMembers = memberIds;
      householdMemberEmails = {
        for (var member in members) member['id']: member['email']
      };
      return members;
    }
    return [];
  }

  // Method to invite a new member to the household
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

          // Close the invite dialog
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

  // Method to assign leader to a member
  Future<void> _assignLeader(String memberId) async {
    User? user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .update({'leaderId': memberId});
      setState(() {
        leaderId = memberId;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).primaryColor,
        title: Text(
          householdName,
          style: Theme.of(context).textTheme.headlineMedium,
        ),
      ),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _fetchHouseholdMembers(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          } else if (snapshot.hasError) {
            return const Center(
                child: Text('Error fetching household members'));
          } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(child: Text('No household members found'));
          } else {
            List<Map<String, dynamic>> members = snapshot.data!;
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Padding(
                  padding: EdgeInsets.all(16.0),
                  child: Center(
                    child: Text(
                      'Household Members',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: ListView.builder(
                    itemCount: members.length,
                    itemBuilder: (context, index) {
                      String memberId = members[index]['id'];
                      return ListTile(
                        title: Text(members[index]['email']),
                        trailing: memberId == leaderId
                            ? const Text('Leader')
                            : TextButton(
                                onPressed: () {
                                  _assignLeader(memberId);
                                },
                                child: const Text('Assign Leader'),
                              ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 20),
                Center(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: ElevatedButton(
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
                  ),
                ),
              ],
            );
          }
        },
      ),
    );
  }
}
