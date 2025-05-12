import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'chat_service.dart';

class ShoppingListException implements Exception {
  final String message;
  final String? code;
  ShoppingListException(this.message, [this.code]);

  @override
  String toString() =>
      'ShoppingListException: $message${code != null ? ' (Code: $code)' : ''}';
}

class ShoppingItem {
  final String id;
  final String name;
  final int quantity;
  final String unit;
  final double price;
  final bool done;
  final String addedBy;
  final DateTime createdAt;
  final DateTime? updatedAt;

  ShoppingItem({
    required this.id,
    required this.name,
    this.quantity = 1,
    this.unit = '',
    this.price = 0.0,
    this.done = false,
    required this.addedBy,
    required this.createdAt,
    this.updatedAt,
  });

  factory ShoppingItem.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return ShoppingItem(
      id: doc.id,
      name: data['name'] ?? '',
      quantity: (data['quantity'] as num?)?.toInt() ?? 1,
      unit: data['unit'] ?? '',
      price: (data['price'] as num?)?.toDouble() ?? 0.0,
      done: data['done'] ?? false,
      addedBy: data['addedBy'] ?? '',
      createdAt: (data['createdAt'] as Timestamp).toDate(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'quantity': quantity,
      'unit': unit,
      'price': price,
      'done': done,
      'addedBy': addedBy,
      'createdAt': Timestamp.fromDate(createdAt),
      if (updatedAt != null) 'updatedAt': Timestamp.fromDate(updatedAt!),
    };
  }

  ShoppingItem copyWith({
    String? name,
    int? quantity,
    String? unit,
    double? price,
    bool? done,
    String? addedBy,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return ShoppingItem(
      id: id,
      name: name ?? this.name,
      quantity: quantity ?? this.quantity,
      unit: unit ?? this.unit,
      price: price ?? this.price,
      done: done ?? this.done,
      addedBy: addedBy ?? this.addedBy,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

class ShoppingListService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final ChatService _chatService = ChatService();

  String? _householdId;
  String get userId => _auth.currentUser?.uid ?? '';

  ShoppingListService() {
    _initialize();
  }

  Future<void> _initialize() async {
    try {
      final userDoc = await _firestore.collection('users').doc(userId).get();

      if (!userDoc.exists) throw ShoppingListException('User not found');
      _householdId = userDoc.get('householdID') as String?;

      if (_householdId == null) {
        throw ShoppingListException('No household found');
      }
    } catch (e) {
      debugPrint('Error initializing shopping list: $e');
      rethrow;
    }
  }

  CollectionReference<Map<String, dynamic>> get _itemsCollection {
    if (_householdId == null) {
      throw ShoppingListException('Shopping list not initialized');
    }
    return _firestore
        .collection('households')
        .doc(_householdId)
        .collection('shopping_items');
  }

  Stream<List<ShoppingItem>> streamItems() {
    try {
      return _itemsCollection
          .orderBy('done')
          .orderBy('createdAt', descending: true)
          .snapshots()
          .map((snapshot) => snapshot.docs
              .map((doc) => ShoppingItem.fromFirestore(doc))
              .toList());
    } catch (e) {
      debugPrint('Error streaming items: $e');
      return Stream.value([]);
    }
  }

  Future<String> addItem(
    String name, {
    int quantity = 1,
    String unit = '',
    double price = 0.0,
  }) async {
    try {
      final item = ShoppingItem(
        id: '',
        name: name.trim(),
        quantity: quantity,
        unit: unit.trim(),
        price: price,
        addedBy: userId,
        createdAt: DateTime.now(),
      );

      final doc = await _itemsCollection.add(item.toMap());

      // Notify in chat about new item
      await _chatService.shareShoppingItem(doc.id, name);

      return doc.id;
    } catch (e) {
      debugPrint('Error adding item: $e');
      throw ShoppingListException('Failed to add item');
    }
  }

  Future<void> updateItem(
    String itemId, {
    int? quantity,
    String? unit,
    double? price,
  }) async {
    try {
      final updates = <String, dynamic>{
        'updatedAt': FieldValue.serverTimestamp(),
      };

      if (quantity != null) updates['quantity'] = quantity;
      if (unit != null) updates['unit'] = unit.trim();
      if (price != null) updates['price'] = price;

      await _itemsCollection.doc(itemId).update(updates);
    } catch (e) {
      debugPrint('Error updating item: $e');
      throw ShoppingListException('Failed to update item');
    }
  }

  Future<void> toggleDone(String itemId) async {
    try {
      final doc = await _itemsCollection.doc(itemId).get();
      if (!doc.exists) {
        throw ShoppingListException('Item not found');
      }

      final item = ShoppingItem.fromFirestore(doc);
      await _itemsCollection.doc(itemId).update({
        'done': !item.done,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      if (!item.done) {
        // Item was just marked as done
        await _chatService
            .sendSystemMessage('✅ "${item.name}" marked as purchased');
      }
    } catch (e) {
      debugPrint('Error toggling item: $e');
      throw ShoppingListException('Failed to update item');
    }
  }

  Future<void> deleteItem(String itemId) async {
    try {
      final doc = await _itemsCollection.doc(itemId).get();
      if (!doc.exists) {
        throw ShoppingListException('Item not found');
      }

      final item = ShoppingItem.fromFirestore(doc);
      await _itemsCollection.doc(itemId).delete();

      await _chatService
          .sendSystemMessage('🗑️ "${item.name}" removed from shopping list');
    } catch (e) {
      debugPrint('Error deleting item: $e');
      throw ShoppingListException('Failed to delete item');
    }
  }

  Future<void> clearCompletedItems() async {
    try {
      final completedItems =
          await _itemsCollection.where('done', isEqualTo: true).get();

      final batch = _firestore.batch();
      for (var doc in completedItems.docs) {
        batch.delete(doc.reference);
      }
      await batch.commit();

      if (completedItems.docs.isNotEmpty) {
        await _chatService.sendSystemMessage(
            '🧹 Cleared ${completedItems.docs.length} completed items from shopping list');
      }
    } catch (e) {
      debugPrint('Error clearing completed items: $e');
      throw ShoppingListException('Failed to clear completed items');
    }
  }
}
