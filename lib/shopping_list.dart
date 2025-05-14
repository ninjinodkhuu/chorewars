// =========================
// shopping_list.dart
// =========================
// This file is for the shopping list screen in Chorewars.
// Here, you can add stuff you need to buy, mark things as done, and even turn items into expenses.

// Import Flutter and Firebase packages for UI and backend
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'local_notifications.dart'; // For local notification features
import 'services/household_shopping_service.dart'; // Handles Firestore logic

// Main widget for the shopping list screen
class ShoppingList extends StatefulWidget {
  const ShoppingList({super.key});

  @override
  State<ShoppingList> createState() => _ShoppingListState();
}

// State class for ShoppingList
class _ShoppingListState extends State<ShoppingList> {
  // Controller for the item input field
  final TextEditingController _itemController = TextEditingController();
  // Default category for new items
  String _selectedCategory = 'Food';
  // Stores the current household ID
  String? householdId;
  // Loading state for the screen
  bool isLoading = true;
  // Whether shopping reminder is enabled
  bool _shoppingReminderEnabled = false;
  // Time for the shopping reminder
  TimeOfDay _shoppingReminderTime = const TimeOfDay(hour: 9, minute: 0);

  @override
  void initState() {
    super.initState();
    _initializeHousehold(); // Get household ID
    _loadNotificationPreferences(); // Load reminder settings
    LocalNotificationService.initialize(); // Set up notifications
  }

  // Get the household ID from Firestore
  Future<void> _initializeHousehold() async {
    try {
      householdId = await HouseholdShoppingService.getCurrentHouseholdId();
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

  // Load shopping reminder preferences from Firestore
  Future<void> _loadNotificationPreferences() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    try {
      final prefsDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('notificationSettings')
          .doc('shopping')
          .get();
      final data = prefsDoc.data() ?? {};
      setState(() {
        _shoppingReminderEnabled =
            data['shoppingReminderEnabled'] as bool? ?? false;
        final int hour = data['shoppingReminderHour'] as int? ?? 9;
        final int minute = data['shoppingReminderMinute'] as int? ?? 0;
        _shoppingReminderTime = TimeOfDay(hour: hour, minute: minute);
      });
      // If enabled, set up the reminder
      if (_shoppingReminderEnabled) {
        await _setupShoppingReminder(user.uid);
      }
    } catch (e) {
      print('Error loading notification preferences: $e');
    }
  }

  // Set up a daily shopping reminder notification
  Future<void> _setupShoppingReminder(String uid) async {
    final userDoc =
        await FirebaseFirestore.instance.collection('users').doc(uid).get();
    if (!userDoc.exists) return;
    final householdId = userDoc.get('household_id') as String?;
    if (householdId == null) return;
    await LocalNotificationService.scheduleShoppingReminder(
      householdID: householdId,
      userID: uid,
      hour: _shoppingReminderTime.hour,
      minute: _shoppingReminderTime.minute,
    );
  }

  // Save shopping reminder preferences to Firestore
  Future<void> _saveNotificationPreferences(String uid) async {
    await FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('notificationSettings')
        .doc('shopping')
        .set({
      'shoppingReminderEnabled': _shoppingReminderEnabled,
      'shoppingReminderHour': _shoppingReminderTime.hour,
      'shoppingReminderMinute': _shoppingReminderTime.minute,
    }, SetOptions(merge: true));
  }

  // ===========================
  // Use Case 6.1: List Management Interface
  // ===========================

  // Add a new item to the shopping list
  Future<void> addItem(String item, {String category = 'Food'}) async {
    if (householdId == null) return;
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    try {
      await HouseholdShoppingService.addItem(
        householdId: householdId!,
        item: item,
        category: category,
        addedBy: user.uid,
      );
    } catch (e) {
      print('Error adding item: $e');
    }
    // Notify users that a new item was added
    await LocalNotificationService.sendShoppingItemAddedNotification(item);
  }

  // Toggle the done status of a shopping list item
  Future<void> toggleDone(String itemId, bool currentStatus) async {
    if (householdId == null) return;
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    try {
      // Get item details for notification
      final doc = await FirebaseFirestore.instance
          .collection('households')
          .doc(householdId)
          .collection('shopping_list')
          .doc(itemId)
          .get();
      await HouseholdShoppingService.toggleItemDone(
        householdId: householdId!,
        itemId: itemId,
        currentStatus: currentStatus,
        completedBy: user.uid,
      );
      // If marking as done, send a notification
      if (!currentStatus && doc.exists) {
        final data = doc.data() as Map<String, dynamic>;
        final itemName = data['item'] as String;
        await LocalNotificationService.sendTaskNotification(
          title: "Item Completed",
          body: "You've marked '$itemName' as done",
          payload: itemId,
        );
      }
    } catch (e) {
      print('Error toggling item: $e');
    }
  }

  // Delete an item from the shopping list
  Future<void> deleteItem(String itemId) async {
    if (householdId == null) return;
    try {
      // Get item name before deleting for notification
      final doc = await FirebaseFirestore.instance
          .collection('households')
          .doc(householdId)
          .collection('shopping_list')
          .doc(itemId)
          .get();
      await HouseholdShoppingService.deleteItem(
        householdId: householdId!,
        itemId: itemId,
      );
      // Notify users that an item was deleted
      if (doc.exists) {
        final data = doc.data() as Map<String, dynamic>;
        final itemName = data['item'] as String;
        await LocalNotificationService.sendTaskNotification(
          title: "Item Removed",
          body: "'$itemName' has been removed from your shopping list",
          payload: itemId,
        );
      }
    } catch (e) {
      print('Error deleting item: $e');
    }
  }

  // Update the details of a shopping list item
  Future<void> updateItemDetails(String itemId, int quantity, String unit,
      double price, String category) async {
    if (householdId == null) return;
    try {
      await HouseholdShoppingService.updateItem(
        householdId: householdId!,
        itemId: itemId,
        updates: {
          'quantity': quantity,
          'unit': unit,
          'price': price,
          'category': category,
        },
      );
    } catch (e) {
      print('Error updating item: $e');
    }
  }

  // Show a modal to edit item details and convert to expense
  void showItemDetails(BuildContext context, String itemId, String itemName,
      int quantity, String unit, double price, String selectedCategory) {
    String currentCategory = selectedCategory;
    final TextEditingController priceController =
        TextEditingController(text: price > 0 ? price.toString() : '');
    // Helper to update item details
    void updateDetails(String category, double? newPrice) {
      if (newPrice != null) {
        updateItemDetails(itemId, 1, '', newPrice, category);
      }
    }

    // Show the modal bottom sheet
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return Container(
              margin: const EdgeInsets.all(16),
              padding: EdgeInsets.only(
                  bottom: MediaQuery.of(context).viewInsets.bottom),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 6,
                    spreadRadius: 2,
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header with item name
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.blue[900],
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(16),
                        topRight: Radius.circular(16),
                      ),
                    ),
                    width: double.infinity,
                    child: Text(
                      itemName,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  // Editable fields for category and price
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Category dropdown
                        const Text(
                          'Category',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        DropdownButtonFormField<String>(
                          value: currentCategory,
                          decoration: InputDecoration(
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                            filled: true,
                            fillColor: Colors.grey[100],
                          ),
                          onChanged: (String? newValue) {
                            if (newValue != null) {
                              setState(() {
                                currentCategory = newValue;
                              });
                              final newPrice =
                                  double.tryParse(priceController.text);
                              updateDetails(newValue, newPrice);
                            }
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
                        const SizedBox(height: 16),
                        // Price input
                        const Text(
                          'Amount',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        TextField(
                          controller: priceController,
                          decoration: InputDecoration(
                            hintText: 'Enter amount',
                            prefixText: '\$',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                            filled: true,
                            fillColor: Colors.grey[100],
                          ),
                          keyboardType: const TextInputType.numberWithOptions(
                              decimal: true),
                          autofocus: true,
                          onChanged: (value) {
                            final newPrice = double.tryParse(value);
                            updateDetails(currentCategory, newPrice);
                          },
                        ),
                        const SizedBox(height: 24),
                        // Buttons for closing or converting to expense
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            Expanded(
                              child: TextButton(
                                onPressed: () => Navigator.pop(context),
                                style: TextButton.styleFrom(
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 12),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                    side: BorderSide(color: Colors.blue[900]!),
                                  ),
                                ),
                                child: Text(
                                  'Close',
                                  style: TextStyle(color: Colors.blue[900]),
                                ),
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: ElevatedButton(
                                onPressed: () {
                                  final expensePrice =
                                      double.tryParse(priceController.text) ??
                                          0.0;
                                  if (expensePrice > 0) {
                                    convertToExpense(
                                        itemId, currentCategory, expensePrice);
                                    Navigator.pop(context);
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content:
                                            const Text('Added to expenses'),
                                        backgroundColor: Colors.green,
                                        behavior: SnackBarBehavior.floating,
                                        shape: RoundedRectangleBorder(
                                          borderRadius:
                                              BorderRadius.circular(15),
                                        ),
                                      ),
                                    );
                                  } else {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: const Text(
                                            'Please enter a valid amount'),
                                        backgroundColor: Colors.red,
                                        behavior: SnackBarBehavior.floating,
                                        shape: RoundedRectangleBorder(
                                          borderRadius:
                                              BorderRadius.circular(15),
                                        ),
                                      ),
                                    );
                                  }
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.blue[900],
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 12),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                ),
                                child: const Text(
                                  'Convert to Expense',
                                  style: TextStyle(color: Colors.white),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  // Convert a shopping list item to an expense
  Future<void> convertToExpense(
      String itemId, String category, double price) async {
    if (householdId == null) return;
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    try {
      await HouseholdShoppingService.convertToExpense(
        householdId: householdId!,
        itemId: itemId,
        category: category,
        amount: price,
        addedBy: user.uid,
      );
    } catch (e) {
      print('Error converting to expense: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    // Get the current user
    final User? user = FirebaseAuth.instance.currentUser;
    final String uid = user?.uid ?? '';
    // Main UI for the shopping list screen
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.blue[100],
        title: Text(
          'Shopping List',
          style: TextStyle(
            color: Colors.blue[900],
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          // Button to set shopping reminder time
          IconButton(
            icon: const Icon(Icons.notifications),
            onPressed: () async {
              if (user == null) return;
              final picked = await showTimePicker(
                context: context,
                initialTime: _shoppingReminderTime,
              );
              if (picked != null) {
                setState(() {
                  _shoppingReminderEnabled = true;
                  _shoppingReminderTime = picked;
                });
                await _setupShoppingReminder(user.uid);
                await _saveNotificationPreferences(user.uid);
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        'Shopping reminder set for ${picked.format(context)}',
                      ),
                      behavior: SnackBarBehavior.floating,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(15),
                      ),
                    ),
                  );
                }
              }
            },
          ),
        ],
      ),
      body: Center(
        child: isLoading
            ? const CircularProgressIndicator() // Show loading spinner
            : Column(
                children: [
                  // Card for shopping reminder settings
                  Card(
                    margin: const EdgeInsets.all(16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: SwitchListTile(
                        title: const Text('Daily Shopping Reminder'),
                        subtitle: Text(
                          _shoppingReminderEnabled
                              ? 'Every day at ${_shoppingReminderTime.format(context)}'
                              : 'Tap to set reminder time',
                        ),
                        value: _shoppingReminderEnabled,
                        onChanged: (user != null)
                            ? (enabled) async {
                                setState(
                                    () => _shoppingReminderEnabled = enabled);
                                if (enabled) {
                                  final picked = await showTimePicker(
                                    context: context,
                                    initialTime: _shoppingReminderTime,
                                  );
                                  if (picked != null) {
                                    setState(
                                        () => _shoppingReminderTime = picked);
                                    await _setupShoppingReminder(user.uid);
                                  }
                                } else {
                                  await LocalNotificationService
                                      .cancelShoppingReminder();
                                }
                                await _saveNotificationPreferences(user.uid);
                              }
                            : null,
                      ),
                    ),
                  ),
                  // Section for adding a new item
                  Container(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      children: [
                        // Card for item input
                        Card(
                          elevation: 2,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Column(
                              children: [
                                // Input for item name
                                TextField(
                                  controller: _itemController,
                                  decoration: InputDecoration(
                                    labelText: 'Item',
                                    filled: true,
                                    fillColor: Colors.grey[50],
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 16),
                                // Dropdown for category
                                Container(
                                  decoration: BoxDecoration(
                                    border:
                                        Border.all(color: Colors.grey[300]!),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 12),
                                  child: DropdownButton<String>(
                                    isExpanded: true,
                                    value: _selectedCategory,
                                    underline: Container(), // Remove underline
                                    items: <String>[
                                      'Food',
                                      'Transport',
                                      'Entertainment',
                                      'Bills',
                                      'Other'
                                    ].map<DropdownMenuItem<String>>(
                                        (String value) {
                                      return DropdownMenuItem<String>(
                                        value: value,
                                        child: Text(value),
                                      );
                                    }).toList(),
                                    onChanged: (String? value) {
                                      setState(() {
                                        _selectedCategory = value!;
                                      });
                                    },
                                  ),
                                ),
                                const SizedBox(height: 16),
                                // Button to add item
                                ElevatedButton(
                                  onPressed: () {
                                    if (uid.isEmpty) {
                                      ScaffoldMessenger.of(context)
                                          .showSnackBar(
                                        const SnackBar(
                                          content: Text('No user logged in.'),
                                          backgroundColor: Colors.red,
                                        ),
                                      );
                                      return;
                                    }
                                    if (_itemController.text.trim().isEmpty) {
                                      ScaffoldMessenger.of(context)
                                          .showSnackBar(
                                        const SnackBar(
                                          content:
                                              Text('Please name your item!'),
                                          backgroundColor: Colors.red,
                                        ),
                                      );
                                      return;
                                    }
                                    addItem(_itemController.text.trim(),
                                        category: _selectedCategory);
                                    _itemController.clear();
                                  },
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.blue[900],
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 32, vertical: 12),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                  ),
                                  child: const Text(
                                    'Add Item',
                                    style: TextStyle(color: Colors.white),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  // List of shopping items
                  Expanded(
                    child: StreamBuilder<QuerySnapshot>(
                      // Listen for shopping list changes
                      stream: HouseholdShoppingService.streamShoppingList(
                          householdId!),
                      builder: (context, snapshot) {
                        if (!snapshot.hasData) {
                          return const Center(
                              child: CircularProgressIndicator());
                        }
                        // Sort items by done status
                        final items = snapshot.data!.docs;
                        final doneItems = items.where((item) {
                          final data = item.data() as Map<String, dynamic>;
                          return data.containsKey('done') && data['done'];
                        }).toList();
                        final notDoneItems = items.where((item) {
                          final data = item.data() as Map<String, dynamic>?;
                          return data == null ||
                              !data.containsKey('done') ||
                              !data['done'];
                        }).toList();
                        final sortedItems = [...notDoneItems, ...doneItems];
                        // Show message if list is empty
                        if (sortedItems.isEmpty) {
                          return Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.shopping_cart_outlined,
                                  size: 64,
                                  color: Colors.blue[200],
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  'Your shopping list is empty',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.blue[900],
                                  ),
                                ),
                                Text(
                                  'Add some items above',
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Colors.grey[600],
                                  ),
                                ),
                              ],
                            ),
                          );
                        }
                        // Build the list of shopping items
                        return ListView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount: sortedItems.length,
                          itemBuilder: (context, index) {
                            // Get item details
                            final item = sortedItems[index];
                            final itemId = item.id;
                            final itemName = item['item'];
                            final data = item.data() as Map<String, dynamic>;
                            final itemDone =
                                data.containsKey('done') ? data['done'] : false;
                            final quantity = data.containsKey('quantity')
                                ? data['quantity']
                                : 1;
                            final unit =
                                data.containsKey('unit') ? data['unit'] : '';
                            final price =
                                data.containsKey('price') ? data['price'] : 0.0;
                            final category = data.containsKey('category')
                                ? data['category']
                                : 'Food';
                            // Dismissible card for deleting items
                            return Dismissible(
                              key: Key(itemId),
                              direction: DismissDirection.endToStart,
                              onDismissed: (direction) {
                                deleteItem(itemId);
                              },
                              background: Container(
                                margin: const EdgeInsets.symmetric(vertical: 4),
                                decoration: BoxDecoration(
                                  color: Colors.red.shade400,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                alignment: Alignment.centerRight,
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 20),
                                child: const Icon(Icons.delete,
                                    color: Colors.white),
                              ),
                              child: Card(
                                margin: const EdgeInsets.symmetric(vertical: 4),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                elevation: 2,
                                child: ListTile(
                                  contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 8,
                                  ),
                                  leading: Container(
                                    width: 40,
                                    height: 40,
                                    decoration: BoxDecoration(
                                      color: itemDone
                                          ? Colors.green.withOpacity(0.2)
                                          : Colors.blue[900]!.withOpacity(0.2),
                                      shape: BoxShape.circle,
                                    ),
                                    child: IconButton(
                                      icon: Icon(
                                        itemDone
                                            ? Icons.check_circle
                                            : Icons.radio_button_unchecked,
                                        color: itemDone
                                            ? Colors.green
                                            : Colors.blue[900],
                                      ),
                                      onPressed: () async {
                                        try {
                                          await toggleDone(itemId, itemDone);
                                          if (!itemDone) {
                                            // Show details modal when marking as done
                                            showItemDetails(
                                                context,
                                                itemId,
                                                itemName,
                                                quantity,
                                                unit,
                                                price,
                                                category);
                                          }
                                          ScaffoldMessenger.of(context)
                                              .showSnackBar(
                                            SnackBar(
                                              content: Text(
                                                itemDone
                                                    ? 'Item marked incomplete'
                                                    : '✅ Item completed!',
                                                style: const TextStyle(
                                                    fontSize: 16),
                                              ),
                                              backgroundColor: itemDone
                                                  ? Colors.orange
                                                  : Colors.green,
                                              behavior:
                                                  SnackBarBehavior.floating,
                                              shape: RoundedRectangleBorder(
                                                borderRadius:
                                                    BorderRadius.circular(15),
                                              ),
                                              duration:
                                                  const Duration(seconds: 2),
                                            ),
                                          );
                                        } catch (e) {
                                          ScaffoldMessenger.of(context)
                                              .showSnackBar(
                                            SnackBar(
                                              content: const Text(
                                                'Something went wrong!',
                                                style: TextStyle(fontSize: 16),
                                              ),
                                              backgroundColor: Colors.red,
                                              behavior:
                                                  SnackBarBehavior.floating,
                                              shape: RoundedRectangleBorder(
                                                borderRadius:
                                                    BorderRadius.circular(15),
                                              ),
                                            ),
                                          );
                                          print(
                                              'Error toggling shopping item: $e');
                                        }
                                      },
                                    ),
                                  ),
                                  title: Text(
                                    itemName,
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      decoration: itemDone
                                          ? TextDecoration.lineThrough
                                          : TextDecoration.none,
                                      color:
                                          itemDone ? Colors.grey : Colors.black,
                                    ),
                                  ),
                                  subtitle: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      // Show quantity, unit, and price
                                      Text(
                                        unit.isNotEmpty
                                            ? (price > 0
                                                ? '$quantity x $unit   \$${price.toStringAsFixed(2)}'
                                                : '$quantity x $unit')
                                            : (price > 0
                                                ? '$quantity   \$${price.toStringAsFixed(2)}'
                                                : '$quantity'),
                                        style: TextStyle(
                                          fontSize: 14,
                                          color: Colors.grey[600],
                                        ),
                                      ),
                                      // Show category label
                                      Container(
                                        margin: const EdgeInsets.only(top: 4),
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 8,
                                          vertical: 4,
                                        ),
                                        decoration: BoxDecoration(
                                          color: Colors.blue[100]!
                                              .withOpacity(0.3),
                                          borderRadius:
                                              BorderRadius.circular(12),
                                        ),
                                        child: Text(
                                          category,
                                          style: TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w500,
                                            color: Colors.blue[900],
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  onTap: () {
                                    showItemDetails(context, itemId, itemName,
                                        quantity, unit, price, category);
                                  },
                                ),
                              ),
                            );
                          },
                        );
                      },
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}
// End of shopping_list.dart
