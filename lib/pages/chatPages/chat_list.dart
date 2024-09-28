import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'group_chat.dart';

class ChatListPage extends StatefulWidget {
    final String currentPage;

  const ChatListPage({super.key, this.currentPage = 'chats'});
  @override
  State<ChatListPage> createState() => _ChatListPageState();
}

class _ChatListPageState extends State<ChatListPage> {
  final CollectionReference chats = FirebaseFirestore.instance.collection('chats');

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Chats'),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: chats.snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return Center(child: CircularProgressIndicator());
          }

          var chatDocs = snapshot.data!.docs;

          return ListView.builder(
            itemCount: chatDocs.length,
            itemBuilder: (context, index) {
              var chatData = chatDocs[index];
              var lastMessage = chatData['last_message'];
              var lastMessageTime = chatData['last_message_time'].toDate();
              var chatTitle = "Group Chat"; // Change this to your chat title field

              return ListTile(
                leading: CircleAvatar(child: Text(chatTitle[0])), // Placeholder for user image
                title: Text(chatTitle),
                subtitle: Text(lastMessage),
                trailing: Text(
                  "${lastMessageTime.hour}:${lastMessageTime.minute}",
                  style: TextStyle(color: Colors.grey),
                ),
                onTap: () {
                  // Navigate to the specific group chat
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => GroupChatPage(chatId: chatData.id),
                    ),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}
