import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'local_notifications.dart';

class Chat extends StatefulWidget {
  const Chat({super.key});

  @override
  _ChatState createState() => _ChatState();
}

class _ChatState extends State<Chat> {
  final TextEditingController messageController = TextEditingController();
  final ScrollController scrollController = ScrollController();
  String? chatRoomId;
  String householdName = '';
  String? currentUserEmail;
  bool _chatNotificationsEnabled = true;

  @override
  void initState() {
    super.initState();
    setupChatRoom();
    _loadCurrentUser();
    _loadNotificationPreferences();
  }

  Future<void> _loadCurrentUser() async {
    final User? user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      setState(() {
        currentUserEmail = user.email;
      });
    }
  }

  Future<void> _loadNotificationPreferences() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('settings')
          .doc('notifications')
          .get();

      if (doc.exists) {
        setState(() {
          _chatNotificationsEnabled = doc.data()?['chatNotifications'] ?? true;
        });
      }
    } catch (e) {
      print('Error loading notification preferences: $e');
    }
  }

  Future<void> setupChatRoom() async {
    final User? user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      final DocumentSnapshot userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

      setState(() {
        householdName = userDoc['householdName'] ?? 'Household Chat';
      });

      final List<dynamic> householdMembers =
          List<String>.from(userDoc['householdMembers'] ?? []);

      householdMembers.add(user.uid);
      householdMembers.sort();
      chatRoomId = 'chat_${householdMembers.join('_')}';

      FirebaseFirestore.instance.collection('chatRooms').doc(chatRoomId).set({
        'members': householdMembers,
        'createdBy': user.uid,
        'householdName': householdName,
      }, SetOptions(merge: true));

      setState(() {});
    }
  }

  Future<void> sendMessage() async {
    if (messageController.text.trim().isEmpty || chatRoomId == null) return;

    final User? user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      try {
        final messageText = messageController.text.trim();

        await FirebaseFirestore.instance
            .collection('chatRooms')
            .doc(chatRoomId!)
            .collection('messages')
            .add({
          'text': messageText,
          'senderId': user.uid,
          'senderEmail': user.email,
          'timestamp': FieldValue.serverTimestamp(),
        });

        // Send notification to other household members if they have notifications enabled
        if (_chatNotificationsEnabled) {
          final userDoc = await FirebaseFirestore.instance
              .collection('users')
              .doc(user.uid)
              .get();

          // Get list of household members to notify
          final List<dynamic> householdMembers =
              List<String>.from(userDoc['householdMembers'] ?? []);

          // Remove the sender from the notification list
          householdMembers.remove(user.uid);

          // Check each member's notification preferences and send if enabled
          for (String memberId in householdMembers) {
            final memberPrefs = await FirebaseFirestore.instance
                .collection('users')
                .doc(memberId)
                .collection('settings')
                .doc('notifications')
                .get();

            if (memberPrefs.exists &&
                memberPrefs.data()?['chatNotifications'] == true) {
              // Send notification
              await LocalNotificationService.sendChatMessageNotification(
                user.email ?? 'Unknown User',
                messageText,
                chatId: chatRoomId,
              );
            }
          }
        }

        messageController.clear();

        Future.delayed(const Duration(milliseconds: 100), () {
          if (scrollController.hasClients) {
            scrollController.animateTo(
              0,
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeOut,
            );
          }
        });
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error sending message: $e')),
        );
      }
    }
  }

  String _getSenderEmail(Map<String, dynamic> message) {
    return message['senderEmail'] ?? 'Unknown User';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.blue[50],
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              householdName,
              style: TextStyle(
                color: Colors.blue[900],
                fontWeight: FontWeight.bold,
                fontSize: 20,
              ),
            ),
            const Text(
              'Group Chat',
              style: TextStyle(
                color: Colors.grey,
                fontSize: 18, // Increased from 14
                fontWeight: FontWeight.bold, // Changed to bold
              ),
            ),
          ],
        ),
        centerTitle: false,
      ),
      body: Column(
        children: [
          Expanded(
            child: chatRoomId == null
                ? const Center(child: CircularProgressIndicator())
                : StreamBuilder<QuerySnapshot>(
                    stream: FirebaseFirestore.instance
                        .collection('chatRooms')
                        .doc(chatRoomId!)
                        .collection('messages')
                        .orderBy('timestamp', descending: true)
                        .snapshots(),
                    builder: (context, snapshot) {
                      if (!snapshot.hasData) {
                        return const Center(child: CircularProgressIndicator());
                      }

                      if (snapshot.data!.docs.isEmpty) {
                        return Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.chat_bubble_outline,
                                size: 64,
                                color: Colors.blue[200],
                              ),
                              const SizedBox(height: 16),
                              Text(
                                'No messages yet',
                                style: TextStyle(
                                  fontSize: 18,
                                  color: Colors.blue[900],
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Start the conversation!',
                                style: TextStyle(
                                  color: Colors.grey[600],
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                        );
                      }

                      return ListView.builder(
                        reverse: true,
                        controller: scrollController,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 8),
                        itemCount: snapshot.data!.docs.length,
                        itemBuilder: (context, index) {
                          var message = snapshot.data!.docs[index].data()
                              as Map<String, dynamic>;
                          bool isCurrentUser =
                              _getSenderEmail(message) == currentUserEmail;

                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 4),
                            child: Column(
                              crossAxisAlignment: isCurrentUser
                                  ? CrossAxisAlignment.end
                                  : CrossAxisAlignment.start,
                              children: [
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 4, vertical: 2),
                                  child: Text(
                                    _getSenderEmail(message),
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey[600],
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                                Row(
                                  mainAxisAlignment: isCurrentUser
                                      ? MainAxisAlignment.end
                                      : MainAxisAlignment.start,
                                  children: [
                                    if (!isCurrentUser) ...[
                                      CircleAvatar(
                                        backgroundColor: Colors.blue[100],
                                        child: Text(
                                          _getSenderEmail(message)[0]
                                              .toUpperCase(),
                                          style: TextStyle(
                                            color: Colors.blue[900],
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                    ],
                                    Flexible(
                                      child: Container(
                                        margin: const EdgeInsets.only(top: 4),
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 16, vertical: 10),
                                        decoration: BoxDecoration(
                                          color: isCurrentUser
                                              ? Colors.blue[900]
                                              : Colors.white,
                                          borderRadius:
                                              BorderRadius.circular(20),
                                          boxShadow: [
                                            BoxShadow(
                                              color: Colors.black
                                                  .withOpacity(0.05),
                                              blurRadius: 4,
                                              offset: const Offset(0, 2),
                                            ),
                                          ],
                                        ),
                                        child: Text(
                                          message['text'] ?? '',
                                          style: TextStyle(
                                            color: isCurrentUser
                                                ? Colors.white
                                                : Colors.black87,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          );
                        },
                      );
                    },
                  ),
          ),
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 4,
                  offset: const Offset(0, -2),
                ),
              ],
            ),
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.grey[100],
                      borderRadius: BorderRadius.circular(24),
                    ),
                    child: TextField(
                      controller: messageController,
                      textCapitalization: TextCapitalization.sentences,
                      decoration: InputDecoration(
                        hintText: 'Type a message...',
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 20, vertical: 10),
                        hintStyle: TextStyle(color: Colors.grey[500]),
                      ),
                      onSubmitted: (_) => sendMessage(),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  decoration: BoxDecoration(
                    color: Colors.blue[900],
                    shape: BoxShape.circle,
                  ),
                  child: IconButton(
                    icon: const Icon(Icons.send),
                    color: Colors.white,
                    onPressed: sendMessage,
                  ),
                ),
              ],
            ),
          ),
          MediaQuery.of(context).padding.bottom > 0
              ? SizedBox(height: MediaQuery.of(context).padding.bottom)
              : const SizedBox(height: 0),
        ],
      ),
    );
  }
}
