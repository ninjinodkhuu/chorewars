import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class ExpenseTracking extends StatefulWidget {
  const ExpenseTracking({super.key});

  @override
  _ExpenseTrackingState createState() => _ExpenseTrackingState();
}

class _ExpenseTrackingState extends State<ExpenseTracking> {
  double monthlyIncome = 0.0;
  Map<String, double> expenses = {};
  List<Color> pieColors = [
    const Color(0xFF2196F3), // Blue
    const Color(0xFFFFA726), // Orange
    const Color(0xFF66BB6A), // Green
    const Color(0xFFF44336), // Red
    const Color(0xFF9C27B0), // Purple
    const Color(0xFF29B6F6), // Light Blue
    const Color(0xFFFF7043), // Deep Orange
    const Color(0xFF26A69A), // Teal
  ];
  int touchedIndex = -1;

  @override
  void initState() {
    super.initState();
    _loadIncomeAndExpenses();
  }

  // ===========================
  // Use Case 6: Shared Access and Updates
  // ===========================

  // Load income and expenses from Firestore
  Future<void> _loadIncomeAndExpenses() async {
    User? user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      try {
        // Fetch monthly income
        DocumentSnapshot incomeSnapshot = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .get();

        // Fetch expenses
        QuerySnapshot expensesSnapshot = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .collection('expenses')
            .orderBy('timestamp', descending: true)
            .get();

        if (mounted) {
          final data = incomeSnapshot.data() as Map<String, dynamic>?;
          setState(() {
            // Safely get monthlyIncome from the document data
            monthlyIncome = data != null
                ? (data['monthlyIncome'] as num?)?.toDouble() ?? 0.0
                : 0.0;

            expenses = {};
            for (var doc in expensesSnapshot.docs) {
              final expenseData = doc.data() as Map<String, dynamic>;
              String category = expenseData['category'] as String? ?? 'Other';
              double amount =
                  (expenseData['amount'] as num?)?.toDouble() ?? 0.0;
              expenses.update(category, (value) => value + amount,
                  ifAbsent: () => amount);
            }
          });
        }

        if (monthlyIncome == 0.0) {
          _promptAddIncome();
        }
      } catch (e) {
        print('Error loading income and expenses: $e');
        // Show error to user if needed
      }
    }
  }

  // Prompt user to add monthly income
  void _promptAddIncome() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _addIncome();
    });
  }

  // Show dialog to add monthly income
  void _addIncome() {
    showDialog(
      context: context,
      builder: (context) {
        TextEditingController incomeController = TextEditingController();
        return AlertDialog(
          title: const Text('Add Monthly Income'),
          content: TextField(
            controller: incomeController,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: 'Income Amount'),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
              },
              child: const Text('Cancel'),
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
              child: const Text('Add'),
            ),
          ],
        );
      },
    );
  }

  // ===========================
  // Use Case 6: List Management Interface
  // ===========================

  // Show dialog to add an expense
  void _addExpense() {
    showDialog(
      context: context,
      builder: (context) {
        TextEditingController amountController = TextEditingController();
        String selectedCategory = 'Food';
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Text('Add Expense'),
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
                    decoration: const InputDecoration(labelText: 'Amount'),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.pop(context);
                  },
                  child: const Text('Cancel'),
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
                    }

                    Navigator.pop(context);
                    _loadIncomeAndExpenses(); // Reload expenses after adding
                  },
                  child: const Text('Add'),
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
    final screenWidth = MediaQuery.of(context).size.width;
    final isSmallScreen = screenWidth < 600;

    return Scaffold(
      backgroundColor: Colors.blue[50],
      appBar: AppBar(
        backgroundColor: Colors.blue[100],
        title: Text(
          'Budget Tracking',
          style: TextStyle(
            color: Colors.blue[900],
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // Header Section with Monthly Income
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.blue[900],
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(16),
                  bottomRight: Radius.circular(16),
                ),
              ),
              child: Column(
                children: [
                  Text(
                    'Monthly Income',
                    style: const TextStyle(
                      fontSize: 16,
                      color: Colors.white,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '\$${monthlyIncome.toStringAsFixed(2)}',
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),

            // Expense Chart Section
            Padding(
              padding: const EdgeInsets.all(16),
              child: Card(
                elevation: 4,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: isSmallScreen
                      ? Column(
                          children: [
                            SizedBox(
                              height: 200,
                              child: _buildChart(remainingBudget),
                            ),
                            const Divider(height: 32),
                            SizedBox(
                              height: 200,
                              child: _buildLegend(remainingBudget),
                            ),
                          ],
                        )
                      : SizedBox(
                          height: 300,
                          child: Row(
                            children: [
                              Expanded(
                                flex: 3,
                                child: _buildChart(remainingBudget),
                              ),
                              const VerticalDivider(width: 32),
                              Expanded(
                                flex: 2,
                                child: _buildLegend(remainingBudget),
                              ),
                            ],
                          ),
                        ),
                ),
              ),
            ),

            // List of Expenses
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Card(
                elevation: 4,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Text(
                        'Expense Details',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.blue[900],
                        ),
                      ),
                    ),
                    const Divider(height: 1),
                    ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: expenses.length,
                      itemBuilder: (context, index) {
                        String category = expenses.keys.elementAt(index);
                        double amount = expenses[category]!;
                        return ListTile(
                          leading: CircleAvatar(
                            backgroundColor: pieColors[index % pieColors.length]
                                .withOpacity(0.2),
                            child: Icon(
                              Icons.category,
                              color: pieColors[index % pieColors.length],
                            ),
                          ),
                          title: Text(
                            category,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          trailing: Text(
                            '\$${amount.toStringAsFixed(2)}',
                            style: TextStyle(
                              color: Colors.blue[900],
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: Colors.blue[900],
        onPressed: () {
          showModalBottomSheet(
            context: context,
            builder: (context) {
              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ListTile(
                    leading: const Icon(Icons.attach_money),
                    title: const Text('Add Income'),
                    onTap: () {
                      Navigator.pop(context);
                      _addIncome();
                    },
                  ),
                  ListTile(
                    leading: const Icon(Icons.money_off),
                    title: const Text('Add Expense'),
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
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }

  Widget _buildChart(double remainingBudget) {
    return AspectRatio(
      aspectRatio: 1,
      child: Stack(
        children: [
          PieChart(
            PieChartData(
              pieTouchData: PieTouchData(
                touchCallback: (FlTouchEvent event, pieTouchResponse) {
                  setState(() {
                    if (!event.isInterestedForInteractions ||
                        pieTouchResponse == null ||
                        pieTouchResponse.touchedSection == null) {
                      touchedIndex = -1;
                      return;
                    }
                    touchedIndex =
                        pieTouchResponse.touchedSection!.touchedSectionIndex;
                  });
                },
              ),
              sectionsSpace: 0,
              centerSpaceRadius: 50,
              sections: [
                if (remainingBudget > 0)
                  PieChartSectionData(
                    color: Colors.grey.shade200,
                    value: remainingBudget,
                    title: '',
                    radius: touchedIndex == 0 ? 60 : 50,
                    showTitle: false,
                  ),
                ...expenses.entries.map((entry) {
                  final index = expenses.keys.toList().indexOf(entry.key) +
                      (remainingBudget > 0 ? 1 : 0);
                  final isTouched = index == touchedIndex;
                  return PieChartSectionData(
                    color: pieColors[index % pieColors.length],
                    value: entry.value,
                    title: '',
                    radius: isTouched ? 60 : 50,
                    showTitle: false,
                  );
                }),
              ],
            ),
            swapAnimationDuration: const Duration(milliseconds: 150),
            swapAnimationCurve: Curves.easeInOutQuad,
          ),
          Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Balance',
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.grey[600],
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '\$${remainingBudget.toStringAsFixed(2)}',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.blue[900],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLegend(double remainingBudget) {
    return SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (remainingBudget > 0) ...[
            _buildLegendItem(
              'Remaining',
              Colors.grey.shade200,
              remainingBudget,
              0,
            ),
            const Divider(height: 16),
          ],
          ...expenses.entries.map((entry) {
            final index = expenses.keys.toList().indexOf(entry.key) +
                (remainingBudget > 0 ? 1 : 0);
            return Padding(
              padding: const EdgeInsets.only(bottom: 12.0),
              child: _buildLegendItem(
                entry.key,
                pieColors[index % pieColors.length],
                entry.value,
                index,
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildLegendItem(String label, Color color, double value, int index) {
    final isTouched = index == touchedIndex;
    return InkWell(
      onTap: () => setState(() {
        touchedIndex = isTouched ? -1 : index;
      }),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(vertical: 4.0, horizontal: 8.0),
        decoration: BoxDecoration(
          color: isTouched ? color.withOpacity(0.1) : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            Container(
              width: 12,
              height: 12,
              decoration: BoxDecoration(
                color: color,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight:
                          isTouched ? FontWeight.bold : FontWeight.normal,
                      color: Colors.blue[900],
                    ),
                  ),
                  Text(
                    '\$${value.toStringAsFixed(2)}',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
                      fontWeight:
                          isTouched ? FontWeight.bold : FontWeight.normal,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  final String label;
  final Color color;
  final double value;
  final bool isTouched;

  const _Badge(this.label, this.color, this.value, this.isTouched, {Key? key})
      : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(8.0),
      decoration: BoxDecoration(
        color: isTouched ? color.withOpacity(0.8) : color,
        borderRadius: BorderRadius.circular(8.0),
        boxShadow: isTouched
            ? [
                BoxShadow(
                  color: Colors.black.withOpacity(0.2),
                  offset: const Offset(0, 3),
                  blurRadius: 6,
                )
              ]
            : [],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '\$${value.toStringAsFixed(2)}',
            style: const TextStyle(
              fontSize: 12,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }
}
