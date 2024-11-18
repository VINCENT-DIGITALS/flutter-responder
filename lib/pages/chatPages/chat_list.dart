import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart'; // For getting current user

import 'group_chat.dart';

class ChatListPage extends StatefulWidget {
  final String currentPage;

  const ChatListPage({super.key, this.currentPage = 'chats'});
  @override
  State<ChatListPage> createState() => _ChatListPageState();
}

class _ChatListPageState extends State<ChatListPage> {
  final CollectionReference chats =
      FirebaseFirestore.instance.collection('chats');
  final User? currentUser =
      FirebaseAuth.instance.currentUser; // Get current user

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Chats'),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: chats.where('archived', isEqualTo: false).snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return Center(child: CircularProgressIndicator());
          }

          var chatDocs = snapshot.data!.docs;

          // Filter chats where the current user's uid appears in the participants array
          var filteredChats = chatDocs.where((doc) {
            var participants = doc['participants'] as List<dynamic>;

            // Check if any participant path contains the current user's uid
            return participants.any((participant) {
              return participant.toString().contains(currentUser!.uid);
            });
          }).toList();

          if (filteredChats.isEmpty) {
            return Center(child: Text('No chats available'));
          }

          return ListView.builder(
            itemCount: filteredChats.length,
            itemBuilder: (context, index) {
              var chatData = filteredChats[index];
              var lastMessage = chatData['last_message'];
              var lastMessageTime = chatData['last_message_time'].toDate();
              var chatTitle =
                  chatData['chat_name']; // Change this to your chat title field

              return ListTile(
                leading: CircleAvatar(
                    child: Text(chatTitle[0])), // Placeholder for user image
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
                      builder: (context) => GroupChatPage(
                          chatId: chatData.id, gChatname: chatTitle),
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
