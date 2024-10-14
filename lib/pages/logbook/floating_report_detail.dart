// floating_report_widget.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class FloatingReportWidget extends StatelessWidget {
  final DocumentSnapshot report;
  final String responderId;
  final String responderName;
  final VoidCallback onAccept;
  final VoidCallback onCancel;
  final bool isAccepting; // Add this field for the loading state

  const FloatingReportWidget({
    Key? key,
    required this.report,
    required this.responderId,
    required this.responderName,
    required this.onAccept,
    required this.onCancel,
    required this.isAccepting, // Add this parameter for loading state
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(16.0),
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12.0),
        boxShadow: [
          BoxShadow(
            color: Colors.black26,
            offset: Offset(0, 4),
            blurRadius: 8.0,
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Report Details',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.blueAccent,
            ),
          ),
          SizedBox(height: 10),
          Text(
            'Incident Type: ${report['incidentType']}',
            style: TextStyle(fontSize: 16),
          ),
          SizedBox(height: 8),
          Text(
            'Location: ${report['location'] != null ? 'Lat: ${(report['location'] as GeoPoint).latitude}, Lng: ${(report['location'] as GeoPoint).longitude}' : 'No location available'}',
            style: TextStyle(fontSize: 16),
          ),
          SizedBox(height: 8),
          Text(
            'Seriousness: ${report['seriousness']}',
            style: TextStyle(fontSize: 16),
          ),
          SizedBox(height: 8),
          Text(
            'Address: ${report['address']}',
            style: TextStyle(fontSize: 16),
          ),
          Text(
            'Landmark:',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          SizedBox(height: 4),
          Text(
            report['landmark'] ?? 'No landmark provided',
            style: TextStyle(fontSize: 14, color: Colors.grey[700]),
          ),
          SizedBox(height: 12),
          Text(
            'Description:',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          SizedBox(height: 4),
          Text(
            report['description'] ?? 'No description provided',
            style: TextStyle(fontSize: 14, color: Colors.grey[700]),
          ),
          SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              ElevatedButton(
                onPressed: isAccepting
                    ? null
                    : onAccept, // Disable the button when accepting is true
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green, // Custom color
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8.0), // Rounded corners
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16.0, vertical: 8.0),
                  child: isAccepting
                      ? CircularProgressIndicator(
                          color: Colors.white, // White spinner
                        )
                      : Text(
                          'Accept',
                          style: TextStyle(fontSize: 16, color: Colors.white),
                        ),
                ),
              ),
              TextButton(
                onPressed: onCancel,
                style: TextButton.styleFrom(
                  backgroundColor: Colors.red[100], // Light red background
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8.0),
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16.0, vertical: 8.0),
                  child: Text(
                    'Cancel',
                    style: TextStyle(fontSize: 16, color: Colors.red),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}