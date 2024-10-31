import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

class UploadLogbookWidget extends StatefulWidget {
  final Map<String, dynamic> logbook;
  final VoidCallback onUpload;

  const UploadLogbookWidget(
      {Key? key, required this.logbook, required this.onUpload})
      : super(key: key);

  @override
  _UploadLogbookWidgetState createState() => _UploadLogbookWidgetState();
}

class _UploadLogbookWidgetState extends State<UploadLogbookWidget> {
  bool _isUploading = false;

  Future<void> _uploadLogbook() async {
    setState(() {
      _isUploading = true;
    });

    try {
      // Create a copy of the logbook to avoid modifying the original
      Map<String, dynamic> logbookToUpdate =
          Map<String, dynamic>.from(widget.logbook);

      // Set the updatedAt field with the value from createdLocallyAt
      logbookToUpdate['updatedAt'] = logbookToUpdate['createdLocallyAt'];

      // Remove the createdLocallyAt field to prevent it from being uploaded
      logbookToUpdate.remove('createdLocallyAt');

      // Update the logbook in Firestore with merge: true to avoid overwriting
      await FirebaseFirestore.instance
          .collection('logBook')
          .doc(widget.logbook['logbookId'])
          .set(logbookToUpdate, SetOptions(merge: true));

      widget
          .onUpload(); // Callback to notify parent widget that upload is complete
    } catch (e) {
      // Handle upload error
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to upload logbook'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() {
        _isUploading = false;
      });
    }
  }

  Future<void> _deleteUnsavedLogbook() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    List<String> storedLogbooks = prefs.getStringList('logbooks') ?? [];

    // Remove the logbook with matching logbookId
    storedLogbooks.removeWhere((logbook) =>
        jsonDecode(logbook)['logbookId'] == widget.logbook['logbookId']);
    await prefs.setStringList('logbooks', storedLogbooks);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Logbook deleted successfully'),
        backgroundColor: Colors.green,
      ),
    );

    // Notify parent after deletion
    widget.onUpload();
  }

  void _confirmDelete() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Confirm Deletion'),
          content:
              Text('Are you sure you want to delete this unsaved logbook?'),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop(); // Close dialog without action
              },
              child: Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop(); // Close dialog
                _deleteUnsavedLogbook(); // Proceed with deletion
              },
              child: Text('Delete'),
              style: TextButton.styleFrom(
                foregroundColor: Colors.red,
              ),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    List victims = widget.logbook['victims'] ?? [];
    bool hasVictims = victims.isNotEmpty;

    List responders = widget.logbook['responders'] ?? [];
    bool hasResponders = responders.isNotEmpty;

    List vehicles = widget.logbook['vehicles'] ?? [];
    bool hasVehicles = vehicles.isNotEmpty;

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: SingleChildScrollView(
        // Enable scrolling
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Logbook Details',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 16),
            Text('Incident Type: ${widget.logbook['incidentType']}'),
            SizedBox(height: 8),
            Text('Location: ${widget.logbook['address']}'),
            SizedBox(height: 8),
            Text('Landmark: ${widget.logbook['landmark']}'),
            SizedBox(height: 8),
            Text('Transported To: ${widget.logbook['transportedTo']}'),
            SizedBox(height: 8),
            Text('Created Locally At: ${widget.logbook['createdLocallyAt']}'),
            SizedBox(height: 8),
            Text('Report Status: ${widget.logbook['status']}'),
            SizedBox(height: 8),
            Text('Report Legitbility: ${widget.logbook['scam']}'),
            SizedBox(height: 8),
            Text('Report Desc: ${widget.logbook['incidentDesc']}'),
            SizedBox(height: 8),

            // Handle Victims Section
            Text(
              'Victims:',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 8),
            hasVictims
                ? Wrap(
                    children: victims.map((victim) {
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4.0),
                        child: Card(
                          elevation: 2,
                          child: Padding(
                            padding: const EdgeInsets.all(8.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Name: ${victim['name'] ?? 'Unknown'}'),
                                Text('Age: ${victim['age'] ?? 'N/A'}'),
                                Text('Sex: ${victim['sex'] ?? 'N/A'}'),
                                Text('Address: ${victim['address'] ?? 'N/A'}'),
                                Text('Injury: ${victim['injury'] ?? 'N/A'}'),
                              ],
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  )
                : Text('No victims recorded'),
            SizedBox(height: 16),
            // Handle Responders Section
            Text(
              'Responders:',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 8),
            hasResponders
                ? Wrap(
                    children: responders.map((responder) {
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4.0),
                        child: Card(
                          elevation: 2,
                          child: Padding(
                            padding: const EdgeInsets.all(8.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                    'Name: ${responder['responderName'] ?? 'Unknown'}'),
                              ],
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  )
                : Text('No Responders recorded'),
            SizedBox(height: 16),

            // Handle Vehicles Section
            Text(
              'Vehicles Involved:',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 8),
            hasVehicles
                ? Wrap(
                    // crossAxisAlignment: CrossAxisAlignment.start, FOR ROW()
                    children: vehicles.map((vehicle) {
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4.0),
                        child: Card(
                          elevation: 2,
                          child: Padding(
                            padding: const EdgeInsets.all(8.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                    'Type: ${vehicle['vehicleType'] ?? 'Unknown'}'),
                              ],
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  )
                : Text('No Vehicles recorded'),
            SizedBox(height: 16),

            // Spacer removes unnecessary gaps; instead, we use ScrollView for flexible UI

            // Row to place buttons side by side
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: _confirmDelete,
                    style: ElevatedButton.styleFrom(
                      padding:
                          EdgeInsets.symmetric(vertical: 14), // Adjust padding
                      shape: RoundedRectangleBorder(
                        borderRadius:
                            BorderRadius.circular(12), // Rounded corners
                      ),
                      elevation: 4, // Button elevation
                      backgroundColor: Colors.redAccent, // Softer red
                    ),
                    child: Center(
                      child: Text(
                        'Delete Unsaved Logbook',
                        style: TextStyle(
                          fontSize: 14, // Smaller font size
                          fontWeight: FontWeight.w500,
                          color: Colors.white,
                        ),
                        textAlign: TextAlign.center, // Center text
                      ),
                    ),
                  ),
                ),
              ],
            )
          ],
        ),
      ),
    );
  }
}
