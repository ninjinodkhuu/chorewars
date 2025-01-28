import 'package:expenses_tracker/CalenderScreen.dart';
import 'package:expenses_tracker/Data/Task.dart';
import 'package:expenses_tracker/Expense_tracking.dart';
import 'package:expenses_tracker/Gamification.dart';
import 'package:expenses_tracker/home_screen.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'ProfileScreen.dart';
import 'SquareCard.dart';
import 'SquareCard2.dart';

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
            BottomNavigationBarItem(icon: Icon(Icons.search), label: ''),
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
          ExpenseTracking(), // Placeholder for Notifications screen
          Gamification(), // Placeholder for Search screen
        ],
      ),
    );
  }
}
