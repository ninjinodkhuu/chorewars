import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:expenses_tracker/local_notifications.dart';

class ShoppingList extends StatefulWidget {
  const ShoppingList({super.key});
  @override
  _ShoppingListState createState() => _ShoppingListState();
}

class _ShoppingListState extends State<ShoppingList> {
  String? householdID;
  String? userID;
  bool _shoppingReminderEnabled = false;
  TimeOfDay _shoppingReminderTime = const TimeOfDay(hour: 9, minute: 0);
  bool _prefsloaded = false;

  @override
  void initState() {
    super.initState();
    _loadHouseholdAndPrefs();
  }

  Future<void> _loadHouseholdAndPrefs() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    
    // Grab userID
    userID = user.uid;

    // Grab householdID from user document
    final userDoc = await FirebaseFirestore.instance
        .collection('users')
        .doc(userID)
        .get();
    householdID = userDoc.data()?['householdID'] as String?;

    // Load user preferences from Firestore
    final prefsDoc = await FirebaseFirestore.instance
        .collection('users')
        .doc(userID)
        .collection('notificationSettings')
        .doc('shopping')
        .get();
    final data = prefsDoc.data() ?? {};
    _shoppingReminderEnabled = data['shoppingReminderEnabled'] as bool? ?? false;
    final int hour = data['shoppingReminderHour'] as int? ?? 9;
    final int minute = data['shoppingReminderMinute'] as int? ?? 0;
    _shoppingReminderTime = TimeOfDay(hour: hour, minute: minute);

    setState(() => _prefsloaded = true);

    // Schedule or cancel the shopping reminder based on user preference
    if (_shoppingReminderEnabled && householdID != null) {
      await LocalNotificationService.scheduleShoppingReminder(
        householdID: householdID!,
        userID: userID!,
        hour: _shoppingReminderTime.hour,
        minute: _shoppingReminderTime.minute,
      );
    } else {
      await LocalNotificationService.cancelShoppingReminder();
    }
  }
  
  Future<void> addItem(String uid, String item) async {
    await FirebaseFirestore.instance
        .collection('household')
        .doc(householdID!)
        .collection('members')
        .doc(userID!)
        .collection('shopping_list')
        .add({
      'item': item,
      'done': false,
      'quantity': 1,
      'unit': '',
      'price': 0.0
    });
    await LocalNotificationService.sendShoppingItemAddedNotification(item);
  }

  Future<void> toggleDone(String uid, String itemId, bool currentStatus) async {
    await FirebaseFirestore.instance
        .collection('household')
        .doc(householdID!)
        .collection('members')
        .doc(userID!)
        .collection('shopping_list')
        .doc(itemId)
        .update({'done': !currentStatus});
  }

  Future<void> deleteItem(String uid, String itemId) async {
    await FirebaseFirestore.instance
        .collection('household')
        .doc(householdID!)
        .collection('members')
        .doc(userID!)
        .collection('shopping_list')
        .doc(itemId)
        .delete();
  }

  Future<void> updateItemDetails(String uid, String itemId, int quantity,
      String unit, double price) async {
    await FirebaseFirestore.instance
        .collection('household')
        .doc(householdID!)
        .collection('members')
        .doc(userID!)
        .collection('shopping_list')
        .doc(itemId)
        .update({
      'quantity': quantity,
      'unit': unit,
      'price': price,
    });
  }

  void showItemDetails(BuildContext context, String uid, String itemId,
      String itemName, int quantity, String unit, double price) {
    final TextEditingController quantityController =
        TextEditingController(text: quantity.toString());
    final TextEditingController unitController =
        TextEditingController(text: unit);
    final TextEditingController priceController =
        TextEditingController(text: price.toString());

    void updateDetails() {
      final updatedQuantity = int.tryParse(quantityController.text) ?? quantity;
      final updatedUnit = unitController.text;
      final updatedPrice = double.tryParse(priceController.text) ?? price;
      updateItemDetails(
          uid, itemId, updatedQuantity, updatedUnit, updatedPrice);
    }

    quantityController.addListener(updateDetails);
    unitController.addListener(updateDetails);
    priceController.addListener(updateDetails);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) {
        return Padding(
          padding:
              EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
          child: Container(
            padding: EdgeInsets.all(16.0),
            height: MediaQuery.of(context).size.height / 4,
            width: MediaQuery.of(context).size.width,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Item: $itemName',
                    style:
                        TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: quantityController,
                        decoration: InputDecoration(labelText: 'Quantity'),
                        keyboardType: TextInputType.number,
                      ),
                    ),
                    SizedBox(width: 10),
                    Expanded(
                      child: TextField(
                        controller: unitController,
                        decoration: InputDecoration(labelText: 'Unit'),
                      ),
                    ),
                    SizedBox(width: 10),
                    Expanded(
                      child: TextField(
                        controller: priceController,
                        decoration: InputDecoration(labelText: 'Price'),
                        keyboardType: TextInputType.number,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final TextEditingController itemController = TextEditingController();
    final User? user = FirebaseAuth.instance.currentUser;
    final String uid = user?.uid ?? '';
    if (!_prefsloaded) {
      return const Center(child: CircularProgressIndicator());
    }

    return Scaffold(
      appBar: AppBar(
        title: Text('Shopping List'),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(
              width: 350,
              child: TextField(
                controller: itemController,
                decoration: InputDecoration(labelText: 'Enter item'),
              ),
            ),
            ElevatedButton(
              onPressed: () {
                if (uid.isNotEmpty) {
                  addItem(uid, itemController.text);
                  itemController.clear();
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('No user logged in')),
                  );
                }
              },
              child: Text('Add Item'),
            ),
            // Shopping Reminder Switch
            if (_prefsloaded)
            Padding(
              padding: const EdgeInsets.symmetric(
                  vertical: 8.0, horizontal: 16.0),
              child: SwitchListTile(
                title: const Text('Daily Shopping Reminder'),
                subtitle: Text(
                  _shoppingReminderEnabled
                      ? 'Every day at ${_shoppingReminderTime.format(context)}'
                      : 'No reminder set',
                ),
                value: _shoppingReminderEnabled,
                onChanged: (enabled) async {
                  // Update state
                  setState(() => _shoppingReminderEnabled = enabled);

                  // When enabling, ask for time
                  if (enabled) {
                    final picked = await showTimePicker(
                      context: context,
                      initialTime: _shoppingReminderTime,
                    );
                    if (picked != null) {
                      setState(() => _shoppingReminderTime = picked);
                    }
                  }

                  // Schedule or cancel the reminder
                  if (_shoppingReminderEnabled) {
                    await LocalNotificationService.scheduleShoppingReminder(
                      householdID: householdID!,
                      userID:       userID!,
                      hour:         _shoppingReminderTime.hour,
                      minute:       _shoppingReminderTime.minute,
                    );
                  } else {
                    await LocalNotificationService.cancelShoppingReminder();
                  }

                  // Persist back to Firestore
                  await FirebaseFirestore.instance
                      .collection('users')
                      .doc(userID!)
                      .collection('notificationSettings')
                      .doc('shopping')
                      .set({
                        'shoppingReminderEnabled': _shoppingReminderEnabled,
                        'shoppingReminderHour':     _shoppingReminderTime.hour,
                        'shoppingReminderMinute':   _shoppingReminderTime.minute,
                      }, SetOptions(merge: true));
                },
              ),
            ),

            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('household')
                    .doc(householdID!)
                    .collection('members')
                    .doc(userID!)
                    .collection('shopping_list')
                    .orderBy('done')
                    .snapshots(),
                builder: (context, snapshot) {
                  if (!snapshot.hasData) {
                    return Center(child: CircularProgressIndicator());
                  }
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

                  return ListView.builder(
                    itemCount: sortedItems.length,
                    itemBuilder: (context, index) {
                      final item = sortedItems[index];
                      final itemId = item.id;
                      final itemName = item['item'];
                      final data = item.data() as Map<String, dynamic>;
                      final itemDone =
                          data.containsKey('done') ? data['done'] : false;
                      final quantity =
                          data.containsKey('quantity') ? data['quantity'] : 1;
                      final unit = data.containsKey('unit') ? data['unit'] : '';
                      final price =
                          data.containsKey('price') ? data['price'] : 0.0;

                      return Dismissible(
                        key: Key(itemId),
                        direction: DismissDirection.endToStart,
                        onDismissed: (direction) {
                          deleteItem(uid, itemId);
                        },
                        background: Container(
                          color: Colors.red,
                          alignment: Alignment.centerRight,
                          padding: EdgeInsets.symmetric(horizontal: 20),
                          child: Icon(Icons.delete, color: Colors.white),
                        ),
                        child: ListTile(
                          leading: IconButton(
                            icon: Icon(
                              itemDone
                                  ? Icons.check_circle
                                  : Icons.radio_button_unchecked,
                              color: itemDone ? Colors.green : null,
                            ),
                            onPressed: () {
                              toggleDone(uid, itemId, itemDone);
                            },
                          ),
                          title: Text(
                            itemName,
                            style: TextStyle(
                              decoration: itemDone
                                  ? TextDecoration.lineThrough
                                  : TextDecoration.none,
                            ),
                          ),
                          subtitle: Text(
                            unit.isNotEmpty
                                ? (price > 0
                                    ? '$quantity x $unit   \$${price.toStringAsFixed(2)}'
                                    : '$quantity x $unit')
                                : (price > 0
                                    ? '$quantity   \$${price.toStringAsFixed(2)}'
                                    : '$quantity'),
                          ),
                          onTap: () {
                            showItemDetails(context, uid, itemId, itemName,
                                quantity, unit, price);
                          },
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
