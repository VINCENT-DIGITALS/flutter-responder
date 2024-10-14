import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'logBook_edit_widget.dart';

class LogBookListPage extends StatefulWidget {
  final String currentPage;

  const LogBookListPage({super.key, this.currentPage = 'logbook'});

  @override
  State<LogBookListPage> createState() => _LogBookListPageState();
}

class _LogBookListPageState extends State<LogBookListPage> {
  TextEditingController _searchController = TextEditingController();
  String _searchTerm = '';

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    setState(() {
      _searchTerm = _searchController.text.toLowerCase();
    });
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = FirebaseAuth.instance.currentUser;

    if (currentUser == null) {
      return Center(child: Text('You are not logged in'));
    }

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false, // Removes the back arrow
        toolbarHeight: 30, // Adjusted to reduce extra space
        bottom: PreferredSize(
          preferredSize: Size.fromHeight(56.0),
          child: Padding(
            padding: const EdgeInsets.all(8.0),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search incidents...',
                prefixIcon: Icon(Icons.search),
                contentPadding: EdgeInsets.symmetric(vertical: 12),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(25.0),
                  borderSide: BorderSide.none,
                ),
                filled: true,
                fillColor: Colors.grey[200], // Light background color
              ),
            ),
          ),
        ),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('logBook')
            .where('responders', arrayContains: {
              'responderId': currentUser.uid,
            })
            .orderBy('timestamp', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Error loading logbook entries'));
          }

          final logbookEntries = snapshot.data?.docs ?? [];

          if (logbookEntries.isEmpty) {
            return Center(child: Text('No logbook entries found'));
          }

          final filteredEntries = logbookEntries.where((doc) {
            var logbook = doc.data() as Map<String, dynamic>;
            String incidentType = logbook['incidentType'].toLowerCase();
            String incident = logbook['incident'].toLowerCase();
            String status = logbook['status']?.toLowerCase() ?? '';

            return incidentType.contains(_searchTerm) ||
                incident.contains(_searchTerm) ||
                status.contains(_searchTerm);
          }).toList();

          return ListView.builder(
            itemCount: filteredEntries.length,
            itemBuilder: (context, index) {
              var logbook =
                  filteredEntries[index].data() as Map<String, dynamic>;
              bool isPrimaryResponder =
                  logbook['primaryResponderId'] == currentUser.uid;

              return Card(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(15),
                ),
                elevation: 3,
                margin: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            logbook['incidentType'] ?? 'Unknown Incident Type',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          if (isPrimaryResponder)
                            IconButton(
                              icon: Icon(Icons.edit, color: Colors.blue),
                              onPressed: () {
                                showModalBottomSheet(
                                  context: context,
                                  isScrollControlled: true,
                                  builder: (context) {
                                    return FractionallySizedBox(
                                      heightFactor: 0.8,
                                      child: FloatingLogBookEditWidget(
                                        logbook: filteredEntries[index],
                                        onSave: () {
                                          Navigator.pop(context);
                                        },
                                      ),
                                    );
                                  },
                                );
                              },
                            ),
                        ],
                      ),
                      SizedBox(height: 8),
                      Text(
                        'Description: ${logbook['incidentDesc'] != null && logbook['incidentDesc'].length > 50 ? logbook['incidentDesc'].substring(0, 50) + '...' : logbook['incidentDesc'] ?? 'No description available'}',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[700],
                        ),
                      ),
                      SizedBox(height: 8),
                      Text(
                        'Created At: ${_formatTimestamp(logbook['timestamp'])}',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[600],
                        ),
                      ),
                      SizedBox(height: 8),
                      Container(
                        padding:
                            EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color:
                              _getStatusColor(logbook['status'] ?? 'Pending'),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.circle, color: Colors.white, size: 12),
                            SizedBox(width: 4),
                            Text(
                              logbook['status'] ?? 'Pending',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
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
    );
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'In Progress':
        return Colors.orange;
      case 'Completed':
        return Colors.green;
      case 'Pending':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }
  String _formatTimestamp(Timestamp? timestamp) {
  if (timestamp == null) {
    return 'Unknown date';
  }
  DateTime dateTime = timestamp.toDate();
  return DateFormat('yyyy-MM-dd – kk:mm').format(dateTime); // Format the date
}

}
