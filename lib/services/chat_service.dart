import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

enum MessageType {
  text,
  system,
  task,
  expense,
  shoppingList,
}

class ChatMessage {
  final String id;
  final String senderId;
  final String senderEmail;
  final String text;
  final DateTime timestamp;
  final MessageType type;
  final Map<String, dynamic>? metadata;

  ChatMessage({
    required this.id,
    required this.senderId,
    required this.senderEmail,
    required this.text,
    required this.timestamp,
    this.type = MessageType.text,
    this.metadata,
  });

  factory ChatMessage.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return ChatMessage(
      id: doc.id,
      senderId: data['senderId'] ?? '',
      senderEmail: data['senderEmail'] ?? '',
      text: data['text'] ?? '',
      timestamp: (data['timestamp'] as Timestamp).toDate(),
      type: MessageType.values.firstWhere(
        (t) => t.name == (data['type'] ?? 'text'),
        orElse: () => MessageType.text,
      ),
      metadata: data['metadata'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'senderId': senderId,
      'senderEmail': senderEmail,
      'text': text,
      'timestamp': Timestamp.fromDate(timestamp),
      'type': type.name,
      if (metadata != null) 'metadata': metadata,
    };
  }
}

class ChatService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  String? _householdId;
  String? _householdName;

  String get userId => _auth.currentUser?.uid ?? '';
  String get userEmail => _auth.currentUser?.email ?? '';
  String get householdName => _householdName ?? 'Household';

  Future<void> initializeChatRoom() async {
    try {
      final userDoc = await _firestore
          .collection('users')
          .doc(_auth.currentUser?.uid)
          .get();

      if (!userDoc.exists) throw Exception('User document not found');

      _householdId = userDoc.get('householdID') as String?;
      if (_householdId == null) throw Exception('No household ID found');

      final householdDoc =
          await _firestore.collection('households').doc(_householdId).get();

      _householdName = householdDoc.get('name') as String? ?? 'Household';
    } catch (e) {
      debugPrint('Error initializing chat room: $e');
      rethrow;
    }
  }

  Stream<List<ChatMessage>> streamMessages() {
    if (_householdId == null) {
      return Stream.value([]);
    }

    return _firestore
        .collection('households')
        .doc(_householdId)
        .collection('messages')
        .orderBy('timestamp', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => ChatMessage.fromFirestore(doc))
            .toList());
  }

  Future<void> sendMessage(
    String text, {
    MessageType type = MessageType.text,
    Map<String, dynamic>? metadata,
  }) async {
    if (_householdId == null) {
      throw Exception('Chat room not initialized');
    }

    try {
      await _firestore
          .collection('households')
          .doc(_householdId)
          .collection('messages')
          .add(ChatMessage(
            id: '',
            senderId: userId,
            senderEmail: userEmail,
            text: text,
            timestamp: DateTime.now(),
            type: type,
            metadata: metadata,
          ).toMap());
    } catch (e) {
      debugPrint('Error sending message: $e');
      rethrow;
    }
  }

  Future<void> sendSystemMessage(String text) async {
    await sendMessage(text, type: MessageType.system);
  }

  Future<void> shareTask(
      String taskId, String taskName, String assignedTo) async {
    await sendMessage(
      'New task "$taskName" created',
      type: MessageType.task,
      metadata: {
        'taskId': taskId,
        'assignedTo': assignedTo,
      },
    );
  }

  Future<void> shareBasicExpense(
      String expenseId, String title, double amount) async {
    await sendMessage(
      'New expense: $title (\$${amount.toStringAsFixed(2)})',
      type: MessageType.expense,
      metadata: {
        'expenseId': expenseId,
        'amount': amount,
      },
    );
  }

  Future<void> shareExpense(String expenseId, String category, double amount,
      String description) async {
    await sendMessage(
      'New expense added: $category - \$${amount.toStringAsFixed(2)}${description.isNotEmpty ? '\nDescription: $description' : ''}',
      type: MessageType.expense,
      metadata: {
        'expenseId': expenseId,
        'category': category,
        'amount': amount,
        'description': description
      },
    );
  }

  Future<void> shareExpenseUpdate(String expenseId, String category,
      double oldAmount, double newAmount) async {
    await sendMessage(
      'Expense updated: $category from \$${oldAmount.toStringAsFixed(2)} to \$${newAmount.toStringAsFixed(2)}',
      type: MessageType.expense,
      metadata: {
        'expenseId': expenseId,
        'category': category,
        'oldAmount': oldAmount,
        'newAmount': newAmount
      },
    );
  }

  Future<void> shareShoppingItem(String itemId, String itemName) async {
    await sendMessage(
      'Added to shopping list: $itemName',
      type: MessageType.shoppingList,
      metadata: {
        'itemId': itemId,
      },
    );
  }

  Future<void> markAsRead() async {
    if (_householdId == null || userId.isEmpty) return;

    try {
      await _firestore
          .collection('households')
          .doc(_householdId)
          .collection('members')
          .doc(userId)
          .set({
        'lastRead': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (e) {
      debugPrint('Error marking messages as read: $e');
    }
  }
}
