import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:expenses_tracker/Data/Task.dart';
import 'package:expenses_tracker/SquareCard.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:expenses_tracker/local_notifications.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  List<Task> tasks = [];
  String selectedCategory = 'My Tasks';
  String? householdID;

  @override
  void initState() {
    super.initState();
    _fetchHouseholdID();
  }

  // Load householdID and tasks separately
  Future<void> _fetchHouseholdID() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return; // User is not logged in

    // Grab the householdID from the user document
    final userDoc = await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .get();
    setState(() {
      householdID = userDoc.get('householdID') as String;
    });
  }

  void signUserOut() {
    FirebaseAuth.instance.signOut();
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    // While we're fetching, show  a loading indicator
    if (user == null || householdID == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    // Listen for changes in the tasks collection
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('household')
          .doc(householdID!)
          .collection('members')
          .doc(user.uid)
          .collection('tasks')
          .orderBy('date', descending: false)
          .snapshots(),
      builder: (context, snapshot) {
        // While stream is loading, show a loading indicator
        if (snapshot.connectionState != ConnectionState.active) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        // If we got data, map in task
        if (snapshot.hasData) {
          final tasks = snapshot.data!.docs
            .map((doc) => Task.fromFirestore(doc))
            .toList();
          print('HomeScreen: tasks loaded: ${tasks.length}');

          // Filter tasks based on selected category
          final now = DateTime.now();
          final startOfWeek = now.subtract(Duration(days: now.weekday - 1));
          final endOfWeek = startOfWeek.add(Duration(days: 6));

          final filteredTasks = tasks.where((task) {
            switch (selectedCategory) {
              case 'In Progress':
                return !task.done;
              case 'Completed':
                return task.done;
              case 'My Tasks':
              default:
                return task.date.isAfter(startOfWeek) &&
                    task.date.isBefore(endOfWeek);
            }
          }).toList();
          return Scaffold(
          body: Container(
            color: Colors.blue[50],
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(height: 10),
                /*
                // Test notification button
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  child: ElevatedButton(
                    onPressed: () {
                      // calls local_notifications helper
                      print("Test Notification Pressed");
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Test Notification Pressed'),
                        ),
                      );
                    },
                    child: const Text('Test Notification'),
                  ),
                ),
                */
                SizedBox(height: 20),
                Padding(
                  padding: const EdgeInsets.all(15.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      FutureBuilder<User?>(
                        future: Future.value(FirebaseAuth.instance.currentUser),
                        builder: (context, snapshot) {
                          if (snapshot.connectionState == ConnectionState.waiting) {
                            return CircularProgressIndicator();
                          } else if (snapshot.hasError) {
                            return Text('Error: ${snapshot.error}');
                          } else if (!snapshot.hasData || snapshot.data == null) {
                            return Text('No user found');
                          } else {
                            User user = snapshot.data!;
                            return Text(
                              'Hello ' + user.email! + "!",
                              style: TextStyle(
                                color: Colors.black,
                                fontSize: 23,
                                fontWeight: FontWeight.bold,
                              ),
                            );
                          }
                        },
                      ),
                      SizedBox(height: 8),
                      Text(
                        'Have a nice day.',
                        style: TextStyle(
                          color: Colors.black,
                          fontSize: 18,
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(height: 15),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    ElevatedButton(
                      onPressed: () {
                        setState(() {
                          selectedCategory = 'My Tasks';
                        });
                      },
                      child: Text('My Tasks'),
                    ),
                    ElevatedButton(
                      onPressed: () {
                        setState(() {
                          selectedCategory = 'In Progress';
                        });
                      },
                      child: Text('In Progress'),
                    ),
                    ElevatedButton(
                      onPressed: () {
                        setState(() {
                          selectedCategory = 'Completed';
                        });
                      },
                      child: Text('Completed'),
                    ),
                  ],
                ),
                SizedBox(height: 5),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: filteredTasks
                        .map((task) => Container(
                              child: SquareCard(task: task),
                            ))
                        .toList(),
                  ),
                ),
                SizedBox(height: 10),
                Padding(
                  padding: const EdgeInsets.only(left: 15.0),
                  child: Text(
                    'Progress',
                    style: TextStyle(
                      color: Colors.black,
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(15.0),
                  child: Container(
                    height: 65,
                    padding: EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              SizedBox(width: 10),
                              Container(
                                width: 40,
                                height: 40,
                                decoration: BoxDecoration(
                                  color: Colors.blueAccent,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Icon(
                                  Icons.calendar_today,
                                  color: Colors.white,
                                  size: 20,
                                ),
                              ),
                              SizedBox(width: 30),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    "Clean bathroom",
                                    style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 18,
                                        color: Colors.black),
                                  ),
                                  SizedBox(height: 0),
                                  Text('2 days ago',
                                      style: TextStyle(
                                        fontWeight: FontWeight.normal,
                                        fontSize: 15,
                                        color: Colors.grey[400],
                                      ))
                                ],
                              ),
                            ],
                          ),
                        ]),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(top: 1.0, left: 15, right: 15),
                  child: Container(
                    height: 65,
                    padding: EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              SizedBox(width: 10),
                              Container(
                                width: 40,
                                height: 40,
                                decoration: BoxDecoration(
                                  color: Colors.blueAccent,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Icon(
                                  Icons.calendar_today,
                                  color: Colors.white,
                                  size: 20,
                                ),
                              ),
                              SizedBox(width: 30),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    "Buy Food",
                                    style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 18,
                                        color: Colors.black),
                                  ),
                                  SizedBox(height: 0),
                                  Text('2 days ago',
                                      style: TextStyle(
                                        fontWeight: FontWeight.normal,
                                        fontSize: 15,
                                        color: Colors.grey[400],
                                      ))
                                ],
                              ),
                            ],
                          ),
                        ]),
                  ),
                ),
              ],
            ),
          ),
        );
        }
        // If we got no data, show an error message
        return const Scaffold(
          body: Center(child: Text('No tasks found')),
        );
      },
    );
    
  }
}
