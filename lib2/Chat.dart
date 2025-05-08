import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class Chat extends StatefulWidget {
  @override
  _ChatState createState() => _ChatState();
}

class _ChatState extends State<Chat> {
  final TextEditingController messageController = TextEditingController();
  final ScrollController scrollController = ScrollController();
  String? chatRoomId;

  @override
  void initState() {
    super.initState();
    setupChatRoom();
  }

  Future<void> setupChatRoom() async {
    final User? user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      final DocumentSnapshot userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();
      final List<dynamic> householdMembers =
          List<String>.from(userDoc['householdMembers'] ?? []);

      // Include the current user's UID in the list for creating a common chat room
      householdMembers.add(user.uid);
      householdMembers.sort(); // Sort to ensure the chatRoomId is consistent
      chatRoomId = 'chat_${householdMembers.join('_')}';

      // Ensure the chat room exists and contains all household members
      FirebaseFirestore.instance.collection('chatRooms').doc(chatRoomId).set({
        'members': householdMembers,
        'createdBy': user.uid,
      }, SetOptions(merge: true));

      setState(() {});
    }
  }

  Future<void> sendMessage() async {
    if (messageController.text.isNotEmpty && chatRoomId != null) {
      final User? user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        await FirebaseFirestore.instance
            .collection('chatRooms')
            .doc(chatRoomId!)
            .collection('messages')
            .add({
          'text': messageController.text,
          'senderId': user.email,
          'timestamp': FieldValue.serverTimestamp(),
        });

        messageController.clear();
        scrollController.animateTo(
          scrollController.position.maxScrollExtent,
          duration: Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Household Group Chat"),
        backgroundColor: Colors.grey[400],
      ),
      body: Column(
        children: <Widget>[
          Expanded(
            child: chatRoomId == null
                ? Center(child: CircularProgressIndicator())
                : StreamBuilder<QuerySnapshot>(
                    stream: FirebaseFirestore.instance
                        .collection('chatRooms')
                        .doc(chatRoomId!)
                        .collection('messages')
                        .orderBy('timestamp', descending: true)
                        .snapshots(),
                    builder: (context, snapshot) {
                      if (!snapshot.hasData)
                        return Center(child: CircularProgressIndicator());

                      return ListView.builder(
                        reverse: true,
                        controller: scrollController,
                        itemCount: snapshot.data!.docs.length,
                        itemBuilder: (context, index) {
                          var message = snapshot.data!.docs[index];
                          String initial = message['senderId'][0].toUpperCase();
                          return ListTile(
                            leading: CircleAvatar(
                              backgroundColor: Colors.grey[400],
                              child: Text(initial,
                                  style: TextStyle(color: Colors.black)),
                            ),
                            title: Text(
                              message['senderId'],
                              style: TextStyle(fontSize: 12),
                            ),
                            subtitle: Wrap(
                              children: [
                                Container(
                                  padding: EdgeInsets.symmetric(
                                      horizontal: 10, vertical: 8),
                                  decoration: BoxDecoration(
                                    color: Colors.blue,
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: Text(message['text'],
                                      style: TextStyle(color: Colors.white)),
                                ),
                              ],
                            ),
                          );
                        },
                      );
                    },
                  ),
          ),
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Container(
              decoration: BoxDecoration(
                  color: Colors
                      .grey[200], // Choose any color that fits your design
                  borderRadius: BorderRadius.circular(30),
                  border: Border.all(
                      color: Colors.grey,
                      width: 1) // Grey border around the container
                  ),
              child: Row(
                children: <Widget>[
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20.0),
                      child: TextField(
                        controller: messageController,
                        decoration: InputDecoration(
                          hintText: "Type a message...",
                          border: InputBorder.none,
                        ),
                      ),
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.send),
                    onPressed: sendMessage,
                  )
                ],
              ),
            ),
          ),
          SizedBox(
            height: 20,
          )
        ],
      ),
    );
  }
}
