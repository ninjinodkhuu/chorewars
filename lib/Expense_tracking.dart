import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'services/household_expense_service.dart';

class ExpenseTracking extends StatefulWidget {
  const ExpenseTracking({super.key});

  @override
  _ExpenseTrackingState createState() => _ExpenseTrackingState();
}

class _ExpenseTrackingState extends State<ExpenseTracking> {
  double monthlyBudget = 0.0;
  String? householdId;
  Map<String, double> expenses = {};
  bool isLoading = true;
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
    _initializeHousehold();
  }

  Future<void> _initializeHousehold() async {
    try {
      householdId = await HouseholdExpenseService.getCurrentHouseholdId();
      if (householdId != null) {
        await _loadBudgetAndExpenses();
      }
    } catch (e) {
      print('Error initializing household: $e');
    } finally {
      if (mounted) {
        setState(() {
          isLoading = false;
        });
      }
    }
  }

  Future<void> _loadBudgetAndExpenses() async {
    try {
      if (householdId == null) return;

      // Fetch household budget
      double budget =
          await HouseholdExpenseService.getHouseholdBudget(householdId!);

      // Fetch expenses
      Map<String, double> monthlyExpenses =
          await HouseholdExpenseService.getMonthlyExpensesByCategory(
              householdId!);

      if (mounted) {
        setState(() {
          monthlyBudget = budget;
          expenses = monthlyExpenses;
        });

        if (monthlyBudget == 0.0) {
          _promptAddBudget();
        }
      }
    } catch (e) {
      print('Error loading budget and expenses: $e');
      // Show error to user if needed
    }
  }

  // Prompt user to add monthly budget
  void _promptAddBudget() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _updateBudget();
    });
  }

  // Show dialog to update household budget
  void _updateBudget() {
    showDialog(
      context: context,
      builder: (context) {
        TextEditingController budgetController = TextEditingController();
        return AlertDialog(
          title: const Text('Update Monthly Budget'),
          content: TextField(
            controller: budgetController,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: 'Budget Amount'),
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
                if (householdId == null) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('No household found')),
                  );
                  return;
                }

                double budget = double.parse(budgetController.text);
                User? user = FirebaseAuth.instance.currentUser;
                if (user != null) {
                  await HouseholdExpenseService.updateHouseholdBudget(
                    householdId: householdId!,
                    monthlyBudget: budget,
                    updatedBy: user.uid,
                  );
                  _loadBudgetAndExpenses();
                }
                Navigator.pop(context);
              },
              child: const Text('Update'),
            ),
          ],
        );
      },
    );
  }

  // Show dialog to add an expense
  void _addExpense() {
    if (householdId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No household found')),
      );
      return;
    }

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
                    User? user = FirebaseAuth.instance.currentUser;
                    if (user != null) {
                      await HouseholdExpenseService.addExpense(
                        householdId: householdId!,
                        category: selectedCategory,
                        amount: amount,
                        addedBy: user.uid,
                      );
                      _loadBudgetAndExpenses(); // Reload expenses after adding
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

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (householdId == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.home_outlined, size: 64, color: Colors.blue[200]),
              const SizedBox(height: 16),
              Text(
                'No Household Found',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.blue[900],
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Join or create a household to start tracking expenses',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey),
              ),
            ],
          ),
        ),
      );
    }

    double totalExpenses = expenses.values.fold(0.0, (sum, item) => sum + item);
    double remainingBudget = monthlyBudget - totalExpenses;
    final screenWidth = MediaQuery.of(context).size.width;
    final isSmallScreen = screenWidth < 600;

    return Scaffold(
      backgroundColor: Colors.blue[50],
      appBar: AppBar(
        backgroundColor: Colors.blue[100],
        title: Text(
          'Household Budget',
          style: TextStyle(
            color: Colors.blue[900],
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit),
            onPressed: _updateBudget,
            tooltip: 'Update Budget',
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadBudgetAndExpenses,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: Padding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(context).padding.bottom +
                  80, // Add extra padding for FAB
            ),
            child: Column(
              children: [
                // Header Section with Monthly Budget
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
                      const Text(
                        'Monthly Budget',
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.white,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '\$${monthlyBudget.toStringAsFixed(2)}',
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
                ), // List of Expenses
                Padding(
                  padding: EdgeInsets.fromLTRB(
                      16, 0, 16, MediaQuery.of(context).padding.bottom + 90),
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
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Expense Details',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.blue[900],
                                ),
                              ),
                              Text(
                                'Total: \$${totalExpenses.toStringAsFixed(2)}',
                                style: TextStyle(
                                  fontSize: 16,
                                  color: Colors.blue[900],
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
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
                                backgroundColor:
                                    pieColors[index % pieColors.length]
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
        ),
      ),
      floatingActionButton: Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).padding.bottom),
        child: FloatingActionButton(
          backgroundColor: Colors.blue[900],
          onPressed: _addExpense,
          tooltip: 'Add Expense',
          child: const Icon(Icons.add, color: Colors.white),
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
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

  const _Badge(this.label, this.color, this.value, this.isTouched);

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
