import 'package:chorewars2_13/shopping_list.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'CalenderScreen.dart';
import 'Expense_tracking.dart';
import 'Gamification.dart';
import 'ProfileScreen.dart';
import 'home_screen.dart';
import 'Chat.dart';

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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.blue[100],
        actions: [
          IconButton(
            icon: Icon(Icons.person),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (context) =>
                        ProfileScreen()), // Navigate to ProfileScreen
              );
            },
          ),
          IconButton(
            icon: Icon(Icons.chat),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (context) => Chat()), // Navigate to ProfileScreen
              );
            },
          ),
          IconButton(
            onPressed: signUserOut,
            icon: Icon(Icons.logout),
          )
        ],
      ),
      bottomNavigationBar: Container(
        child: BottomNavigationBar(
          items: [
            BottomNavigationBarItem(icon: Icon(Icons.home), label: ''),
            BottomNavigationBarItem(
                icon: Icon(Icons.calendar_today), label: ' '),
            BottomNavigationBarItem(icon: Icon(Icons.attach_money), label: ''),
            BottomNavigationBarItem(icon: Icon(Icons.leaderboard), label: ''),
            BottomNavigationBarItem(
                icon: Icon(Icons.add_shopping_cart), label: ''),
          ],
          currentIndex: _selectedIndex, // Highlight the selected item
          onTap: _onItemTapped, // Call _onItemTapped when an item is tapped
          backgroundColor: Colors.blue[50],
          selectedItemColor: Colors.purple,
          unselectedItemColor: Colors.grey,
          type: BottomNavigationBarType.fixed,
        ),
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
          CalendarScreen(), // Placeholder for Calendar screen
          ExpenseTracking(), // Placeholder for Notvsifications screen
          Gamification(),
          ShoppingList(),
          // Placeholder for Search screen
        ],
      ),
    );
  }
}
