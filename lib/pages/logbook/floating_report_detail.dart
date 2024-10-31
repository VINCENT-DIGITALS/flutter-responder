import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';

import '../maps/incident_report_map.dart';

class FloatingReportWidget extends StatelessWidget {
  final String reportId;
  final String responderId;
  final String responderName;
  final VoidCallback onAccept;
  final VoidCallback onCancel;
  final bool isAccepting;

  const FloatingReportWidget({
    Key? key,
    required this.reportId,
    required this.responderId,
    required this.responderName,
    required this.onAccept,
    required this.onCancel,
    required this.isAccepting,
  }) : super(key: key);

  String formatTimestamp(Timestamp? timestamp) {
    if (timestamp == null) return 'N/A';
    final dateTime = timestamp.toDate();
    return DateFormat('MMMM d, y h:mm a').format(dateTime);
  }

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    final screenWidth = MediaQuery.of(context).size.width;

    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection('reports')
          .doc(reportId)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return CircularProgressIndicator(); // Show a loading indicator while waiting for data
        }

        if (snapshot.hasError) {
          return Text('Error loading report details');
        }

        if (!snapshot.hasData || !snapshot.data!.exists) {
          return Text('Report not available');
        }

        var report = snapshot.data!.data() as Map<String, dynamic>;
        final String? mediaUrl = report['mediaUrl'];
        return SafeArea(
          child: Container(
            margin: const EdgeInsets.all(16.0),
            padding: const EdgeInsets.all(16.0),
            constraints: BoxConstraints(
              maxHeight:
                  screenHeight * 0.8, // Constrain height for scrollable area
              maxWidth: screenWidth * 0.95,
            ),
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
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Report Details',
                        style: TextStyle(
                          fontSize: screenWidth * 0.05, // Responsive font size
                          fontWeight: FontWeight.bold,
                          color: Colors.blueAccent,
                        ),
                      ),
                      IconButton(
                        icon: Icon(Icons.map,
                            color: Colors.orange, size: screenWidth * 0.1),
                        onPressed: () {
                          if (report['location'] is GeoPoint) {
                            GeoPoint geoPoint = report['location'];
                            LatLng location =
                                LatLng(geoPoint.latitude, geoPoint.longitude);

                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => IncidentReportMap(
                                  locationName: report['address'],
                                  LocationCoords: location,
                                  incidentType: report['incidentType'],
                                ),
                              ),
                            );
                          } else {
                            // Handle the case when the location is not available
                            print('Location is not a GeoPoint');
                          }
                        },
                      ),
                    ],
                  ),
                  SizedBox(height: 10),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Center(
                        child: ElevatedButton.icon(
                          onPressed: () async {
                            if (mediaUrl != null) {
                              final uri = Uri.parse(mediaUrl);
                              if (await canLaunchUrl(uri)) {
                                await launchUrl(uri,
                                    mode: LaunchMode.externalApplication);
                              } else {
                                print('Could not launch $mediaUrl');
                              }
                            } else {
                              print('No media URL available');
                            }
                          },
                          icon: const Icon(Icons.open_in_new,
                              color: Colors.white),
                          label: const Text(
                            'Open Media',
                            style: TextStyle(color: Colors.white),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.orange,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(30),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 10),
                  Text(
                    'Date/Time: ${formatTimestamp(report['timestamp'])}',
                    style: TextStyle(fontSize: screenWidth * 0.045),
                  ),
                  SizedBox(height: 10),
                  Text(
                    'Incident Type: ${report['incidentType']}',
                    style: TextStyle(fontSize: screenWidth * 0.045),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Location: ${report['location'] != null ? 'Lat: ${(report['location'] as GeoPoint).latitude}, Lng: ${(report['location'] as GeoPoint).longitude}' : 'No location available'}',
                    style: TextStyle(fontSize: screenWidth * 0.045),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Seriousness: ${report['seriousness']}',
                    style: TextStyle(fontSize: screenWidth * 0.045),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Address: ${report['address']}',
                    style: TextStyle(fontSize: screenWidth * 0.045),
                  ),
                  Text(
                    'Landmark:',
                    style: TextStyle(
                      fontSize: screenWidth * 0.045,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    report['landmark'] ?? 'No landmark provided',
                    style: TextStyle(
                        fontSize: screenWidth * 0.04, color: Colors.grey[700]),
                  ),
                  SizedBox(height: 12),
                  Text(
                    'Description:',
                    style: TextStyle(
                      fontSize: screenWidth * 0.045,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    report['description'] ?? 'No description provided',
                    style: TextStyle(
                        fontSize: screenWidth * 0.04, color: Colors.grey[700]),
                  ),
                  SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      ElevatedButton(
                        onPressed: isAccepting ? null : onAccept,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8.0),
                          ),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16.0, vertical: 8.0),
                          child: isAccepting
                              ? CircularProgressIndicator(
                                  color: Colors.white,
                                )
                              : Text(
                                  'Accept',
                                  style: TextStyle(
                                      fontSize: screenWidth * 0.045,
                                      color: Colors.white),
                                ),
                        ),
                      ),
                      TextButton(
                        onPressed: onCancel,
                        style: TextButton.styleFrom(
                          backgroundColor: Colors.red[100],
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8.0),
                          ),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16.0, vertical: 8.0),
                          child: Text(
                            'Cancel',
                            style: TextStyle(
                                fontSize: screenWidth * 0.045,
                                color: Colors.red),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
