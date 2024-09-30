import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../components/group_setting.dart';
import '../../components/groupchat_header.dart';
import '../../services/database.dart';
import 'package:intl/intl.dart'; // For formatting timestamps

class GroupChatPage extends StatefulWidget {
  final String chatId;
  final String gChatname;

  const GroupChatPage({Key? key, required this.chatId,  required this.gChatname}) : super(key: key);

  @override
  _GroupChatPageState createState() => _GroupChatPageState();
}

class _GroupChatPageState extends State<GroupChatPage> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final DatabaseService _dbService = DatabaseService();
  int _limit = 10;
  List<DocumentSnapshot> _messages = [];
  bool _isSending = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: GroupChatHeader(
        onBackPress: () {
          Navigator.pop(context); // Navigate back
        },
        onSettingsPress: () {
          openSettings(context, widget.chatId); // Open the settings widget
        },
        gChatname: widget.gChatname,
      ),
      body: Column(
        children: [
          Expanded(
            child: NotificationListener<ScrollNotification>(
              onNotification: (ScrollNotification notification) {
                if (notification.metrics.pixels ==
                    notification.metrics.minScrollExtent) {
                  _loadMoreMessages();
                  return true;
                }
                return false;
              },
              child: StreamBuilder<QuerySnapshot>(
                stream: _dbService.getMessages(widget.chatId, limit: _limit),
                builder: (context, snapshot) {
                  if (!snapshot.hasData) {
                    return Center(child: CircularProgressIndicator());
                  }

                  var messages = snapshot.data!.docs;

                  return ListView.builder(
                    reverse: true, // Reverse the list
                    controller: _scrollController,
                    itemCount: messages.length,
                    itemBuilder: (context, index) {
                      var messageData = messages[index];
                      var message = messageData['message'];
                      var senderRef =
                          messageData['sender'] as DocumentReference;
                      var timestamp = messageData['timestamp'].toDate();
                      var formattedTime =
                          DateFormat('hh:mm a').format(timestamp);

                      // Get the current user's ID to check if the message was sent by the current user
                      String currentUserId =
                          _dbService.getCurrentUserId() ?? '';
                      bool isMe = senderRef.id == currentUserId;

                      // Retrieve the display name from the message document
                      var displayName = messageData['displayName'] ??
                          'Unknown'; // Fallback to 'Unknown' if not available

                      return Align(
                        alignment:
                            isMe ? Alignment.centerRight : Alignment.centerLeft,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                              vertical: 4.0, horizontal: 8.0),
                          child: Column(
                            crossAxisAlignment: isMe
                                ? CrossAxisAlignment.end
                                : CrossAxisAlignment.start,
                            children: [
                              // Show the display name above the message box, but only for others
                              if (!isMe)
                                Padding(
                                  padding: const EdgeInsets.only(bottom: 2.0),
                                  child: Text(
                                    displayName,
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: Colors.black,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                    maxLines: 1,
                                  ),
                                ),

                              // Message box
                              Container(
                                padding: const EdgeInsets.all(10.0),
                                decoration: BoxDecoration(
                                  color: isMe
                                      ? Colors.blueAccent.shade100
                                      : Colors.grey.shade200,
                                  borderRadius: BorderRadius.circular(10.0),
                                ),
                                child: Text(
                                  message,
                                  style: TextStyle(
                                    color: isMe ? Colors.white : Colors.black,
                                  ),
                                  softWrap: true,
                                ),
                              ),

                              // Show the time below the message box
                              Padding(
                                padding: const EdgeInsets.only(top: 2.0),
                                child: Text(
                                  formattedTime,
                                  style: TextStyle(
                                    color:
                                        isMe ? Colors.white70 : Colors.black54,
                                    fontSize: 10.0,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _messageController,
                    decoration: InputDecoration(
                      hintText: 'Type a message...',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(20.0),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16.0, vertical: 8.0),
                    ),
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.send, color: Colors.blueAccent),
                  onPressed: _isSending
                      ? null
                      : () async {
                          if (_messageController.text.isNotEmpty) {
                            setState(() {
                              _isSending = true; // Disable button
                            });

                            String? userId = _dbService.getCurrentUserId();
                            if (userId != null) {
                              await _dbService.sendMessage(
                                widget.chatId,
                                _messageController.text,
                                userId,
                                false, // Adjust operator logic if necessary
                              );
                              _messageController.clear();

                              // Scroll logic here
                            } else {
                              print("User is not logged in");
                            }

                            setState(() {
                              _isSending = false; // Re-enable button
                            });
                          }
                        },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _loadMoreMessages() async {
    setState(() {
      _limit += 10; // Increase limit for the next fetch
    });
  }

}
