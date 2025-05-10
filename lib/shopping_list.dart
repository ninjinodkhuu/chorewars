import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class ShoppingList extends StatelessWidget {
  const ShoppingList({super.key});

  // ===========================
  // Use Case 6.1: List Management Interface
  // ===========================

  Future<void> addItem(String uid, String item,
      {String category = 'Food'}) async {
    await FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('shoppinglistinfohere')
        .add({
      'item': item,
      'done': false,
      'quantity': 1,
      'unit': '',
      'price': 0.0,
      'category': category
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
      String unit, double price, String category) async {
    await FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('shoppinglistinfohere')
        .doc(itemId)
        .update({
      'quantity': quantity,
      'unit': unit,
      'price': price,
      'category': category,
    });
  }

  void showItemDetails(
      BuildContext context,
      String uid,
      String itemId,
      String itemName,
      int quantity,
      String unit,
      double price,
      String selectedCategory) {
    final TextEditingController quantityController =
        TextEditingController(text: quantity.toString());
    final TextEditingController unitController =
        TextEditingController(text: unit);
    final TextEditingController priceController =
        TextEditingController(text: price.toString());

    void updateDetails(String category) {
      final updatedQuantity = int.tryParse(quantityController.text) ?? quantity;
      final updatedUnit = unitController.text;
      final updatedPrice = double.tryParse(priceController.text) ?? price;
      updateItemDetails(
          uid, itemId, updatedQuantity, updatedUnit, updatedPrice, category);
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            String currentCategory = selectedCategory;

            return Padding(
              padding: EdgeInsets.only(
                  bottom: MediaQuery.of(context).viewInsets.bottom),
              child: Container(
                padding: const EdgeInsets.all(16.0),
                height: MediaQuery.of(context).size.height / 3,
                width: MediaQuery.of(context).size.width,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Item: $itemName',
                        style: const TextStyle(
                            fontSize: 18, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 10),
                    DropdownButton<String>(
                      value: currentCategory,
                      onChanged: (String? newValue) {
                        if (newValue != null) {
                          setState(() {
                            currentCategory = newValue;
                          });
                          updateDetails(newValue);
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
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: quantityController,
                            decoration:
                                const InputDecoration(labelText: 'Quantity'),
                            keyboardType: TextInputType.number,
                            onChanged: (_) => updateDetails(currentCategory),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: TextField(
                            controller: unitController,
                            decoration:
                                const InputDecoration(labelText: 'Unit'),
                            onChanged: (_) => updateDetails(currentCategory),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: TextField(
                            controller: priceController,
                            decoration:
                                const InputDecoration(labelText: 'Price'),
                            keyboardType: TextInputType.number,
                            onChanged: (_) => updateDetails(currentCategory),
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
      },
    );
  }

  Future<void> convertToExpense(
      String uid, String itemId, String category, double price) async {
    // Add the expense
    await FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('expenses')
        .add({
      'category': category,
      'amount': price,
      'timestamp': FieldValue.serverTimestamp(),
    });

    // Delete the shopping list item
    await deleteItem(uid, itemId);
  }

  @override
  Widget build(BuildContext context) {
    final TextEditingController itemController = TextEditingController();
    String selectedCategory = 'Food';
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
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Column(
                children: [
                  TextField(
                    controller: itemController,
                    decoration: const InputDecoration(labelText: 'Enter item'),
                  ),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String>(
                    value: selectedCategory,
                    decoration: const InputDecoration(labelText: 'Category'),
                    onChanged: (String? newValue) {
                      if (newValue != null) {
                        selectedCategory = newValue;
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
                  ElevatedButton(
                    onPressed: () {
                      if (uid.isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('No user logged in.'),
                            backgroundColor: Colors.red,
                          ),
                        );
                        return;
                      }

                      if (itemController.text.trim().isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Please name your item!'),
                            backgroundColor: Colors.red,
                          ),
                        );
                        return;
                      }

                      addItem(uid, itemController.text.trim(),
                          category: selectedCategory);
                      itemController.clear();
                    },
                    child: const Text('Add Item'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
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
                      final category = data.containsKey('category')
                          ? data['category']
                          : 'Food';

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
                            onPressed: () async {
                              try {
                                await toggleDone(uid, itemId, itemDone);

                                if (!itemDone) {
                                  // Show dialog to add expense when marking as done
                                  // ignore: use_build_context_synchronously
                                  showDialog(
                                    context: context,
                                    builder: (context) {
                                      final priceController =
                                          TextEditingController(
                                              text: price > 0
                                                  ? price.toString()
                                                  : '');
                                      return AlertDialog(
                                        title: const Text('Add as Expense?'),
                                        content: Column(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Text(
                                                'Would you like to add "$itemName" as an expense?'),
                                            const SizedBox(height: 16),
                                            TextField(
                                              controller: priceController,
                                              decoration: const InputDecoration(
                                                labelText: 'Price',
                                                prefixText: '\$',
                                              ),
                                              keyboardType:
                                                  TextInputType.number,
                                            ),
                                          ],
                                        ),
                                        actions: [
                                          TextButton(
                                            onPressed: () {
                                              Navigator.pop(context);
                                            },
                                            child: const Text('No'),
                                          ),
                                          TextButton(
                                            onPressed: () {
                                              final expensePrice =
                                                  double.tryParse(
                                                          priceController
                                                              .text) ??
                                                      0.0;
                                              if (expensePrice > 0) {
                                                convertToExpense(uid, itemId,
                                                    category, expensePrice);
                                              }
                                              Navigator.pop(context);
                                            },
                                            child: const Text('Yes'),
                                          ),
                                        ],
                                      );
                                    },
                                  );
                                }

                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      itemDone
                                          ? 'Item marked incomplete'
                                          : '✅ Item completed!',
                                      style: const TextStyle(fontSize: 16),
                                    ),
                                    backgroundColor:
                                        itemDone ? Colors.orange : Colors.green,
                                    behavior: SnackBarBehavior.floating,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(15),
                                    ),
                                    duration: const Duration(seconds: 2),
                                  ),
                                );
                              } catch (e) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: const Text(
                                      'Something went wrong!',
                                      style: TextStyle(fontSize: 16),
                                    ),
                                    backgroundColor: Colors.red,
                                    behavior: SnackBarBehavior.floating,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(15),
                                    ),
                                  ),
                                );
                                print('Error toggling shopping item: $e');
                              }
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
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                unit.isNotEmpty
                                    ? (price > 0
                                        ? '$quantity x $unit   \$${price.toStringAsFixed(2)}'
                                        : '$quantity x $unit')
                                    : (price > 0
                                        ? '$quantity   \$${price.toStringAsFixed(2)}'
                                        : '$quantity'),
                              ),
                              Text(category,
                                  style: TextStyle(
                                      color: Colors.grey[600], fontSize: 12)),
                            ],
                          ),
                          onTap: () {
                            showItemDetails(context, uid, itemId, itemName,
                                quantity, unit, price, category);
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
