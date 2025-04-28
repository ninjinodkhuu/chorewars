import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class ExpenseTracking extends StatefulWidget {
  const ExpenseTracking({super.key});

  @override
  _ExpenseTrackingState createState() => _ExpenseTrackingState();
}

class _ExpenseTrackingState extends State<ExpenseTracking> {
  double monthlyIncome = 0.0;
  Map<String, double> expenseCategories = {};

  @override
  void initState() {
    super.initState();
    _loadMonthlyIncome();
  }

  Future<void> _loadMonthlyIncome() async {
    User? user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      DocumentSnapshot incomeSnapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

      if (mounted) {
        setState(() {
          monthlyIncome = (incomeSnapshot['monthlyIncome'] ?? 0.0).toDouble();
        });
      }

      if (monthlyIncome == 0.0) {
        _promptAddIncome();
      }
    }
  }

  void _loadExpenses() async {
    User? user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    QuerySnapshot snapshot = await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('expenses')
        .get();

    Map<String, double> categoryTotals = {};

    for (var doc in snapshot.docs) {
      var data = doc.data() as Map<String, dynamic>;
      String category = data['category'] ?? 'Other';
      double amount = (data['amount'] as num).toDouble();

      categoryTotals[category] = (categoryTotals[category] ?? 0) + amount;
    }

    if (mounted) {
      setState(() {
        expenseCategories = categoryTotals;
      });
    }
  }

  void _promptAddIncome() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _addIncome();
    });
  }

  void _addIncome() {
    TextEditingController incomeController =
        TextEditingController(text: monthlyIncome.toString());

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Set Monthly Income'),
          content: TextField(
            controller: incomeController,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: 'Income Amount'),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () async {
                double income = double.tryParse(incomeController.text) ?? 0.0;
                if (income > 0) {
                  setState(() {
                    monthlyIncome = income;
                  });

                  User? user = FirebaseAuth.instance.currentUser;
                  if (user != null) {
                    await FirebaseFirestore.instance
                        .collection('users')
                        .doc(user.uid)
                        .set({'monthlyIncome': income}, SetOptions(merge: true));
                  }
                }
                Navigator.pop(context);
              },
              child: const Text('Save'),
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
        TextEditingController nameController = TextEditingController();
        TextEditingController amountController = TextEditingController();
        String selectedCategory = 'Food';

        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Text('Add Expense'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: nameController,
                    decoration: const InputDecoration(labelText: 'Expense Name'),
                  ),
                  DropdownButton<String>(
                    value: selectedCategory,
                    onChanged: (String? newValue) {
                      setState(() {
                        selectedCategory = newValue!;
                      });
                    },
                    items: <String>['Food', 'Transport', 'Entertainment', 'Bills', 'Other']
                        .map<DropdownMenuItem<String>>((String value) {
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
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
                TextButton(
                  onPressed: () async {
                    double amount = double.tryParse(amountController.text) ?? 0.0;
                    if (amount > 0 && nameController.text.isNotEmpty) {
                      User? user = FirebaseAuth.instance.currentUser;
                      if (user != null) {
                        await FirebaseFirestore.instance
                            .collection('users')
                            .doc(user.uid)
                            .collection('expenses')
                            .add({
                          'name': nameController.text,
                          'category': selectedCategory,
                          'amount': amount,
                          'timestamp': FieldValue.serverTimestamp(),
                        });
                      }
                    }
                    Navigator.pop(context);
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

  void _requestPayment() {
    showDialog(
      context: context,
      builder: (context) {
        TextEditingController nameController = TextEditingController();
        TextEditingController amountController = TextEditingController();
        TextEditingController reasonController = TextEditingController();
        TextEditingController dueDateController = TextEditingController();

        return AlertDialog(
          title: const Text('Request Payment'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(labelText: 'Name:'),
              ),
              TextField(
                controller: amountController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Amount:'),
              ),
              TextField(
                controller: reasonController,
                decoration: const InputDecoration(labelText: 'Charge Reason:'),
              ),
              TextField(
                controller: dueDateController,
                keyboardType: TextInputType.datetime,
                decoration: const InputDecoration(labelText: 'Payment Due Date:'),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                if (nameController.text.isEmpty ||
                    amountController.text.isEmpty ||
                    reasonController.text.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Please fill out all required fields.')),
                  );
                  return;
                }

                Navigator.pop(context);
              },
              child: const Text('Send Request'),
            ),
          ],
        );
      },
    );
  }

  Widget _buildPieChart() {
    if (expenseCategories.isEmpty) {
      return const Center(child: Text('No expenses to display.'));
    }

    final theme = Theme.of(context);
    final colors = [
      theme.colorScheme.primary,
      theme.colorScheme.secondary,
      theme.colorScheme.tertiary ?? theme.colorScheme.primaryContainer,
      theme.colorScheme.error,
      theme.colorScheme.surfaceVariant,
      theme.colorScheme.secondaryContainer,
    ];

    return SizedBox(
      height: 250,
      child: PieChart(
        PieChartData(
          sections: expenseCategories.entries.map((entry) {
            final index = expenseCategories.keys.toList().indexOf(entry.key);
            return PieChartSectionData(
              color: colors[index % colors.length],
              value: entry.value,
              title: '${entry.key}\n\$${entry.value.toStringAsFixed(2)}',
              radius: 50,
              titleStyle: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onPrimary,
                fontWeight: FontWeight.bold,
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    _loadExpenses();

    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Expense Tracker'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                Text(
                  'Monthly Income: \$${monthlyIncome.toStringAsFixed(2)}',
                  style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                TextButton(
                  onPressed: _addIncome,
                  child: const Text('Update Income'),
                ),
              ],
            ),
          ),
          _buildPieChart(),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('users')
                  .doc(FirebaseAuth.instance.currentUser!.uid)
                  .collection('expenses')
                  .orderBy('timestamp', descending: true)
                  .snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return const Center(child: Text('No expenses found.'));
                }

                double totalExpenses = snapshot.data!.docs.fold(0.0, (sum, doc) {
                  var data = doc.data() as Map<String, dynamic>;
                  return sum + (data['amount'] as num).toDouble();
                });

                return Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Text(
                        'Total Expenses: \$${totalExpenses.toStringAsFixed(2)}',
                        style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                      ),
                    ),
                    Expanded(
                      child: ListView(
                        children: snapshot.data!.docs.map((doc) {
                          var data = doc.data() as Map<String, dynamic>;
                          return ListTile(
                            title: Text('${data['name']} - \$${data['amount'].toStringAsFixed(2)}'),
                            subtitle: Text('Category: ${data['category']}'),
                            trailing: IconButton(
                              icon: Icon(Icons.delete, color: theme.colorScheme.error),
                              onPressed: () async {
                                await FirebaseFirestore.instance
                                    .collection('users')
                                    .doc(FirebaseAuth.instance.currentUser!.uid)
                                    .collection('expenses')
                                    .doc(doc.id)
                                    .delete();
                                _loadExpenses();
                              },
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          FloatingActionButton(
            onPressed: _addExpense,
            child: const Icon(Icons.add),
          ),
          const SizedBox(width: 16),
          FloatingActionButton(
            onPressed: _requestPayment,
            child: const Icon(Icons.money),
          ),
        ],
      ),
    );
  }
}
