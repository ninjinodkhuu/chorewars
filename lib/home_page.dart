// Import screens and services
import 'CalenderScreen.dart';
import 'Chat.dart';
import 'Expense_tracking.dart';
import 'Gamification.dart';
import 'home_screen.dart';
import 'shopping_list.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'household_members_screen.dart';
import '/ProfileScreen.dart';
import 'services/household_service.dart';

/// Main home page of the application
/// Contains bottom navigation and manages different screens
class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  _HomePageState createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  // Get current authenticated user
  final user = FirebaseAuth.instance.currentUser!;
  // Track selected navigation item
  int _selectedIndex = 0;
  // Controller for page view
  final PageController _pageController = PageController();

  /// Signs out the current user
  void signUserOut() {
    FirebaseAuth.instance.signOut();
  }

  /// Handles bottom navigation bar item taps
  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
    _pageController.jumpToPage(index);
  }

  /// Navigate to household members screen
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
        backgroundColor: Colors.blue[100],
        // Stream builder for dynamic app bar title
        title: StreamBuilder<Widget>(
          stream: HouseholdService.streamAppBarTitle(),
          builder: (context, snapshot) {
            return snapshot.data ?? const SizedBox();
          },
        ),
        actions: [
          // Household members button
          IconButton(
            icon: const Icon(Icons.group),
            onPressed: () => viewHouseholdMembers(context),
          ),
          // Chat button
          IconButton(
            icon: const Icon(Icons.chat),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const Chat()),
              );
            },
          ),
          // Profile button
          IconButton(
            icon: const Icon(Icons.person),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const ProfileScreen()),
              );
            },
          ),
          // Logout button
          IconButton(
            onPressed: signUserOut,
            icon: const Icon(Icons.logout),
          )
        ],
      ),
      // Bottom navigation bar with 5 main sections
      bottomNavigationBar: BottomNavigationBar(
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
          BottomNavigationBarItem(
              icon: Icon(Icons.calendar_today), label: 'Calendar'),
          BottomNavigationBarItem(
              icon: Icon(Icons.attach_money), label: 'Expenses'),
          BottomNavigationBarItem(
              icon: Icon(Icons.leaderboard), label: 'Points'),
          BottomNavigationBarItem(
              icon: Icon(Icons.shopping_cart), label: 'Shopping'),
        ],
        currentIndex: _selectedIndex,
        onTap: _onItemTapped,
        backgroundColor: Colors.blue[50],
        selectedItemColor: Colors.blue[900],
        unselectedItemColor: Colors.grey,
        type: BottomNavigationBarType.fixed,
        showSelectedLabels: true,
        showUnselectedLabels: true,
      ),
      body: PageView(
        controller: _pageController,
        onPageChanged: (index) {
          setState(() {
            _selectedIndex = index;
          });
        },
        children: const [
          HomeScreen(),
          CalendarScreen(),
          ExpenseTracking(),
          Gamification(),
          ShoppingList(),
        ],
      ),
    );
  }
}
