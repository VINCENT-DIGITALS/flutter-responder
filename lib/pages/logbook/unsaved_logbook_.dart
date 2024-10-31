import 'package:flutter/material.dart';
import 'local_storage.dart';
import 'upload_logbook_widget.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart'; // For date formatting

class UnsavedLogBookListPage extends StatefulWidget {
  final String currentPage;

  const UnsavedLogBookListPage({super.key, this.currentPage = 'logbook'});

  @override
  _UnsavedLogBookListPageState createState() => _UnsavedLogBookListPageState();
}

class _UnsavedLogBookListPageState extends State<UnsavedLogBookListPage> {
  List<Map<String, dynamic>> _unsavedLogbooks = [];

  @override
  void initState() {
    super.initState();
    _loadUnsavedLogbooks();
  }

  Future<void> _loadUnsavedLogbooks() async {
    List<Map<String, dynamic>> logbooks =
        await LocalStorage.loadUnsavedLogbooks();
    setState(() {
      _unsavedLogbooks = logbooks;
    });
  }

Future<void> _uploadLogbook(Map<String, dynamic> logbook) async {
  try {
    String logbookId = logbook['logbookId'];
    DocumentSnapshot logbookDoc = await FirebaseFirestore.instance
        .collection('logBook')
        .doc(logbookId)
        .get();

    if (logbookDoc.exists) {
      // Safely retrieve the updatedAt field, allowing for null values
      Timestamp? updatedAt = logbookDoc['updatedAt'] as Timestamp?;
      DateTime createdLocallyAt = DateTime.parse(logbook['createdLocallyAt']);

      // Print values for debugging
      print('updatedAt: $updatedAt');
      print('createdLocallyAt: $createdLocallyAt');

      if (updatedAt == null || createdLocallyAt.isAfter(updatedAt.toDate())) {
        // Upload to Firestore if there is no updatedAt or if local logbook is more recent
        await FirebaseFirestore.instance
            .collection('logBook')
            .doc(logbookId)
            .update({
          'landmark': logbook['landmark'],
          'transportedTo': logbook['transportedTo'],
          'incidentType': logbook['incidentType'],
          'incident': logbook['incident'],
          'incidentDesc': logbook['incidentDesc'],
          'victims': logbook['victims'],
          'status': logbook['status'],
          'updatedAt': FieldValue.serverTimestamp(), // Update timestamp
        });

        // If 'reportId' exists, update the corresponding report's status
        if (logbook['reportId'] != null) {
          String reportId = logbook['reportId'];
          await FirebaseFirestore.instance
              .collection('reports')
              .doc(reportId)
              .update({
            'status': logbook['status'],
            'updatedAt': FieldValue.serverTimestamp(),
          });
        }
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Logbook uploaded successfully.')));
      } else {
        // Show prompt that there's a more recent update in the database
        bool? deleteConfirm = await showDialog<bool>(
          context: context,
          builder: (BuildContext context) {
            return AlertDialog(
              title: Text('Logbook Outdated'),
              content: Text(
                  'A more recent version of this logbook already exists in the database. Do you want to remove the locally stored logbook?'),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  child: Text('Keep'),
                ),
                TextButton(
                  onPressed: () => Navigator.of(context).pop(true),
                  child: Text('Remove'),
                ),
              ],
            );
          },
        );

        // Remove the locally stored logbook if user confirms
        if (deleteConfirm == true) {
          await LocalStorage.removeLogbook(logbookId);
          _loadUnsavedLogbooks(); // Reload the list of unsaved logbooks
          ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Local logbook removed.')));
        } else {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
              content: Text(
                  'Local logbook is not more recent than the latest version in the database.')));
        }
      }
    }
  } catch (e) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text('Upload failed: $e')));
  }
}

  String _formatDate(String dateString) {
    DateTime date = DateTime.parse(dateString);
    return DateFormat('dd MMM yyyy, hh:mm a').format(date);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(      body: _unsavedLogbooks.isEmpty
          ? Center(child: Text('No unsaved logbooks found'))
          : ListView.builder(
              itemCount: _unsavedLogbooks.length,
              itemBuilder: (context, index) {
                var logbook = _unsavedLogbooks[index];

                return Card(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(15),
                  ),
                  elevation: 5,
                  margin: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          logbook['incidentType'] ?? 'Unknown Incident Type',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        SizedBox(height: 8),
                        Text(
                          'Description: ${logbook['incidentDesc'] ?? 'No description available'}',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[700],
                          ),
                        ),
                        SizedBox(height: 8),
                        Text(
                          'Created At: ${_formatDate(logbook['createdLocallyAt'])}',
                          style: TextStyle(
                            fontSize: 14,
                            fontStyle: FontStyle.italic,
                            color: Colors.grey[600],
                          ),
                        ),
                        SizedBox(height: 16),
                        ButtonBar(
                          alignment: MainAxisAlignment.spaceBetween,
                          children: [
                            ElevatedButton(
                              onPressed: () {
                                // View more details about the logbook
                                showModalBottomSheet(
                                  context: context,
                                  isScrollControlled: true,
                                  builder: (context) {
                                    return FractionallySizedBox(
                                      heightFactor: 0.8,
                                      child: UploadLogbookWidget(
                                        logbook: logbook,
                                        onUpload: () {
                                          Navigator.pop(context);
                                        },
                                      ),
                                    );
                                  },
                                );
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors
                                    .blueGrey, // Background color for View button
                                padding: EdgeInsets.symmetric(
                                    horizontal: 24, vertical: 12),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                elevation: 3, // Add slight elevation for depth
                              ),
                              child: Text(
                                'View',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight:
                                      FontWeight.w600, // Slightly bolder text
                                  color: Colors
                                      .white, // Ensures contrast with background
                                ),
                              ),
                            ),
                            ElevatedButton(
                              onPressed: () async {
                                bool? confirm = await showDialog<bool>(
                                  context: context,
                                  builder: (BuildContext context) {
                                    return AlertDialog(
                                      title: Text('Confirm Upload'),
                                      content: Text(
                                          'Are you sure you want to upload this logbook?'),
                                      actions: [
                                        TextButton(
                                          onPressed: () => Navigator.of(context)
                                              .pop(false), // User cancels
                                          style: TextButton.styleFrom(
                                            foregroundColor: Colors
                                                .red, // Change Cancel button text color
                                          ),
                                          child: Text('Cancel'),
                                        ),
                                        TextButton(
                                          onPressed: () => Navigator.of(context)
                                              .pop(true), // User confirms
                                          style: TextButton.styleFrom(
                                            foregroundColor: Colors
                                                .green, // Change Upload button text color
                                          ),
                                          child: Text('Upload'),
                                        ),
                                      ],
                                    );
                                  },
                                );

                                if (confirm == true) {
                                  _uploadLogbook(
                                      logbook); // Proceed with uploading if confirmed
                                }
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors
                                    .green, // Background color for Upload button
                                padding: EdgeInsets.symmetric(
                                    horizontal: 24, vertical: 12),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                elevation: 3, // Add slight elevation for depth
                              ),
                              child: Text(
                                'Upload',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight:
                                      FontWeight.w600, // Slightly bolder text
                                  color: Colors
                                      .white, // Ensures contrast with background
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }
}
