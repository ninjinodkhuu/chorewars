import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class ShoppingList extends StatelessWidget {
  const ShoppingList({super.key});

  // ===========================
  // Use Case 6.1: List Management Interface
  // ===========================

  Future<void> addItem(String uid, String item) async {
    await FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('shoppinglistinfohere')
        .add({
      'item': item,
      'done': false,
      'quantity': 1,
      'unit': '',
      'price': 0.0
    });
  }

  Future<void> toggleDone(String uid, String itemId, bool currentStatus) async {
    await FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('shoppinglistinfohere')
        .doc(itemId)
        .update({'done': !currentStatus});
  }

  Future<void> deleteItem(String uid, String itemId) async {
    await FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('shoppinglistinfohere')
        .doc(itemId)
        .delete();
  }

  Future<void> updateItemDetails(String uid, String itemId, int quantity,
      String unit, double price) async {
    await FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('shoppinglistinfohere')
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
            padding: const EdgeInsets.all(16.0),
            height: MediaQuery.of(context).size.height / 4,
            width: MediaQuery.of(context).size.width,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Item: $itemName',
                    style: const TextStyle(
                        fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: quantityController,
                        decoration:
                            const InputDecoration(labelText: 'Quantity'),
                        keyboardType: TextInputType.number,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: TextField(
                        controller: unitController,
                        decoration: const InputDecoration(labelText: 'Unit'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: TextField(
                        controller: priceController,
                        decoration: const InputDecoration(labelText: 'Price'),
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

    return Scaffold(
      appBar: AppBar(
        title: const Text('Shopping List'),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(
              width: 350,
              child: TextField(
                controller: itemController,
                decoration: const InputDecoration(labelText: 'Enter item'),
              ),
            ),
            ElevatedButton(
              onPressed: () {
                if (uid.isNotEmpty) {
                  addItem(uid, itemController.text);
                  itemController.clear();
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('No user logged in')),
                  );
                }
              },
              child: const Text('Add Item'),
            ),
            // ===========================
            // Use Case 6.2: Shared Access and Updates
            // ===========================
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('users')
                    .doc(uid)
                    .collection('shoppinglistinfohere')
                    .snapshots(),
                builder: (context, snapshot) {
                  if (!snapshot.hasData) {
                    return const Center(child: CircularProgressIndicator());
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
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          child: const Icon(Icons.delete, color: Colors.white),
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
