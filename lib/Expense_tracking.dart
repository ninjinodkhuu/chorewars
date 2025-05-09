import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:expenses_tracker/local_notifications.dart';

class ExpenseTracking extends StatefulWidget {
  const ExpenseTracking({super.key});

  @override
  _ExpenseTrackingState createState() => _ExpenseTrackingState();
}

class _ExpenseTrackingState extends State<ExpenseTracking> {
  double monthlyIncome = 0.0;
  Map<String, double> expenses = {};
  List<Color> pieColors = [
    Colors.red,
    Colors.blue,
    Colors.green,
    Colors.orange,
    Colors.purple,
    Colors.yellow,
    Colors.cyan,
    Colors.pink,
  ];

  @override
  void initState() {
    super.initState();
    _loadIncomeAndExpenses();
  }

  Future<void> _loadIncomeAndExpenses() async {
    User? user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      DocumentSnapshot incomeSnapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

      QuerySnapshot expensesSnapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('expenses')
          .orderBy('timestamp', descending: true)
          .get();

      setState(() {
        monthlyIncome = incomeSnapshot['monthlyIncome'] ?? 0.0;
        expenses = {};
        for (var doc in expensesSnapshot.docs) {
          String category = doc['category'];
          double amount = doc['amount'];
          if (expenses.containsKey(category)) {
            expenses[category] = expenses[category]! + amount;
          } else {
            expenses[category] = amount;
          }
        }
      });

      if (monthlyIncome == 0.0) {
        _promptAddIncome();
      }
    }
  }

  void _promptAddIncome() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _addIncome();
    });
  }

  void _addIncome() {
    showDialog(
      context: context,
      builder: (context) {
        TextEditingController incomeController = TextEditingController();
        return AlertDialog(
          title: Text('Add Monthly Income'),
          content: TextField(
            controller: incomeController,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(labelText: 'Income Amount'),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
              },
              child: Text('Cancel'),
            ),
            TextButton(
              onPressed: () async {
                double income = double.parse(incomeController.text);
                setState(() {
                  monthlyIncome = income;
                });

                // Save to Firestore
                User? user = FirebaseAuth.instance.currentUser;
                if (user != null) {
                  await FirebaseFirestore.instance
                      .collection('users')
                      .doc(user.uid)
                      .set({
                    'monthlyIncome': income,
                  }, SetOptions(merge: true));
                }

                Navigator.pop(context);
              },
              child: Text('Add'),
            ),
          ],
        );
      },
    );
  }

  void _addExpense() {
    showDialog(
      context: context,
      builder: (context) {
        TextEditingController amountController = TextEditingController();
        String selectedCategory = 'Food';
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: Text('Add Expense'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DropdownButton<String>(
                    value: selectedCategory,
                    onChanged: (String? newValue) {
                      setState(() {
                        selectedCategory = newValue!;
                      });
                    },
                    items: <String>[
                      'Food',
                      'Transport',
                      'Entertainment',
                      'Bills',
                      'Other'
                    ].map<DropdownMenuItem<String>>((String value) {
                      return DropdownMenuItem<String>(
                        value: value,
                        child: Text(value),
                      );
                    }).toList(),
                  ),
                  TextField(
                    controller: amountController,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(labelText: 'Amount'),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.pop(context);
                  },
                  child: Text('Cancel'),
                ),
                TextButton(
                  onPressed: () async {
                    double amount = double.parse(amountController.text);
                    setState(() {
                      if (expenses.containsKey(selectedCategory)) {
                        expenses[selectedCategory] =
                            expenses[selectedCategory]! + amount;
                      } else {
                        expenses[selectedCategory] = amount;
                      }
                    });

                    // Save to Firestore
                    User? user = FirebaseAuth.instance.currentUser;
                    if (user != null) {
                      await FirebaseFirestore.instance
                          .collection('users')
                          .doc(user.uid)
                          .collection('expenses')
                          .add({
                        'category': selectedCategory,
                        'amount': amount,
                        'timestamp': FieldValue.serverTimestamp(),
                      });

                      // Get a native notification
                      print('Sending notification for $amount / $selectedCategory');
                      await LocalNotificationService.sendExpenseNotification(
                        amount,
                        'New Expense Added: You have added a new expense of \$${amount.toStringAsFixed(2)} for $selectedCategory.',
                      );
                    }

                    Navigator.pop(context);
                    _loadIncomeAndExpenses(); // Reload expenses after adding
                  },
                  child: Text('Add'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    double totalExpenses = expenses.values.fold(0.0, (sum, item) => sum + item);
    double remainingBudget = monthlyIncome - totalExpenses;

    return Scaffold(
      appBar: AppBar(
        title: Text('Budget Tracking'),
      ),
      body: Column(
        children: [
          SizedBox(
            height: 200,
            child: Stack(
              children: [
                PieChart(
                  PieChartData(
                    sections: [
                      PieChartSectionData(
                        color: Colors.grey,
                        value: remainingBudget,
                        title: 'Remaining',
                        radius: 50,
                        titleStyle: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      ...expenses.entries.map((entry) {
                        int index = expenses.keys.toList().indexOf(entry.key);
                        return PieChartSectionData(
                          color: pieColors[index % pieColors.length],
                          value: entry.value,
                          title:
                              '${entry.key}: \$${entry.value.toStringAsFixed(2)}',
                          radius: 50,
                          titleStyle: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: const Color.fromARGB(255, 0, 0, 0),
                          ),
                        );
                      }).toList(),
                    ],
                  ),
                ),
                Center(
                  child: Text(
                    '\$${remainingBudget.toStringAsFixed(2)}',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.black,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'Items',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          Expanded(
            child: ListView.builder(
              itemCount: expenses.length,
              itemBuilder: (context, index) {
                String category = expenses.keys.elementAt(index);
                double amount = expenses[category]!;
                return Padding(
                  padding: const EdgeInsets.symmetric(
                      vertical: 4.0, horizontal: 14.0),
                  child: ListTile(
                    title: Text('$category: \$${amount.toStringAsFixed(2)}'),
                    tileColor: Colors.black12,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          showModalBottomSheet(
            context: context,
            builder: (context) {
              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ListTile(
                    leading: Icon(Icons.attach_money),
                    title: Text('Add Income'),
                    onTap: () {
                      Navigator.pop(context);
                      _addIncome();
                    },
                  ),
                  ListTile(
                    leading: Icon(Icons.money_off),
                    title: Text('Add Expense'),
                    onTap: () {
                      Navigator.pop(context);
                      _addExpense();
                    },
                  ),
                ],
              );
            },
          );
        },
        child: Icon(Icons.add),
      ),
    );
  }
}
