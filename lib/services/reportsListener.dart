import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart'; // For calculating distances
import 'package:intl/intl.dart'; // For timestamp formatting
import 'package:logger/logger.dart';

import '../main.dart';
import '../pages/logbook/report_logbook.dart';
import 'location_service.dart';

class FirestoreListenerService {
  Timestamp? lastDocumentTimestamp;
  final LocationService _locationService = LocationService();
  final Logger _logger = Logger(); // Use Logger for better error logging.
  Position? _currentPosition;
  static final FirestoreListenerService _instance =
      FirestoreListenerService._internal();
  factory FirestoreListenerService() {
    return _instance;
  }

  FirestoreListenerService._internal();
  void initialize() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      _logger.w(
          'User is not logged in. Firestore listener will not be initialized.');
      return;
    }
    _listenToReports();
    _fetchCurrentLocation();
  }

  void _listenToReports() async {
    try {
      final now = DateTime.now();

      // Fetch reports created within the last 10 minutes for late login.
      final cutoffTime = now.subtract(Duration(minutes: 10));

      final querySnapshot = await FirebaseFirestore.instance
          .collection('reports')
          .where('timestamp',
              isGreaterThanOrEqualTo: Timestamp.fromDate(cutoffTime))
          .get();

      for (var doc in querySnapshot.docs) {
        final docData = doc.data();
        final createdAt = (docData['timestamp'] as Timestamp).toDate();

        // Skip reports that are older than 30 minutes
        if (createdAt.isAfter(now.subtract(Duration(minutes: 30)))) {
          _showNewReportDialog(docData);
        }
      }

      // Continue listening for real-time updates.
      FirebaseFirestore.instance.collection('reports').snapshots().listen(
        (snapshot) {
          for (var change in snapshot.docChanges) {
            if (change.type == DocumentChangeType.added) {
              final docData = change.doc.data() as Map<String, dynamic>?;
              final createdAt = docData?['timestamp'] as Timestamp?;

              if (createdAt != null) {
                final createdAtDate = createdAt.toDate();

                // Only show reports created within the last 30 minutes
                if (createdAtDate
                    .isAfter(now.subtract(Duration(minutes: 30)))) {
                  _showNewReportDialog(docData);
                }
              }
            }
          }
        },
        onError: (e) => _logger.e('Error listening to reports: $e'),
      );
    } catch (e) {
      _logger.e('Error initializing Firestore listener: $e');
    }
  }

  Future<void> _fetchCurrentLocation() async {
    try {
      _currentPosition = await _locationService.requestLocation();
    } catch (e) {
      _logger.e('Error fetching location: $e');
    }
  }

  Future<void> _showNewReportDialog(Map<String, dynamic>? data) async {
    final context = navigatorKey.currentState?.context;
    if (context == null) {
      print('Context is null; cannot show dialog.');
      return;
    }
    if (data == null) return;

    // Fetch reporter name
    String? reporterName = data['reporterId'] != null
        ? await _getReporterName(data['reporterId'])
        : 'Anonymous';

    // Calculate distance
    double? distance = _calculateDistance(data['location']);

    // Build dialog
    showDialog(
      context: context,
      builder: (context) =>
          _buildReportDialog(context, data, reporterName, distance),
    );
  }

  Future<String?> _getReporterName(String reporterId) async {
    try {
      final userDoc = await FirebaseFirestore.instance
          .collection('citizens')
          .doc(reporterId)
          .get();
      return userDoc.get('displayName') as String?;
    } catch (e) {
      _logger.e('Error fetching reporter name: $e');
    }
    return 'Anonymous';
  }

  double? _calculateDistance(GeoPoint? location) {
    if (_currentPosition == null || location == null) return null;

    final Distance distanceCalculator = Distance();
    final LatLng currentLocation =
        LatLng(_currentPosition!.latitude, _currentPosition!.longitude);
    final LatLng reportLocation = LatLng(location.latitude, location.longitude);

    return distanceCalculator.as(
        LengthUnit.Kilometer, currentLocation, reportLocation);
  }

  Widget _buildReportDialog(BuildContext context, Map<String, dynamic> data,
      String? reporterName, double? distance) {
    return AlertDialog(
      title: Row(
        children: [
          Icon(Icons.report, color: Colors.red),
          SizedBox(width: 8),
          Expanded(
            child: Text(
              data['title'] ?? 'New Incident Report!!',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildDetailRow(
                'Details', data['description'] ?? 'No details available'),
            _buildDetailRow('Incident Type', data['incidentType'] ?? 'N/A'),
            _buildDetailRow('Severity', data['seriousness'] ?? 'N/A'),
            _buildDetailRow('Reporter', reporterName ?? 'N/A'),
            _buildDetailRow('Reported At', _formatTimestamp(data['timestamp'])),
            _buildDetailRow(
              'Distance',
              distance != null
                  ? '${distance.toStringAsFixed(2)} km away'
                  : 'Unknown or unavailable',
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text('Close'),
        ),
        TextButton(
          onPressed: () {
            Navigator.of(context).pop(); // Close the dialog first
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) =>
                    ReportsLogBookPage(currentPage: 'logbook'),
              ),
            );
          },
          child: Text('View Reports'),
        ),
      ],
    );
  }

  Widget _buildDetailRow(String title, String detail) {
    // Check if the title is "Severity" to apply color coding
    if (title == 'Severity') {
      return Padding(
        padding: const EdgeInsets.only(bottom: 8.0),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '$title:',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            SizedBox(width: 8),
            _buildSeverityChip(detail),
          ],
        ),
      );
    }

    // Default row for other details
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$title:',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          SizedBox(width: 8),
          Expanded(
            child: Text(
              detail,
              style: TextStyle(color: Colors.grey[700]),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSeverityChip(String severity) {
    Color backgroundColor;
    Color textColor = Colors.white; // Default text color is white

    // Determine the background color based on the severity level
    switch (severity.toLowerCase()) {
      case 'severe':
        backgroundColor = Colors.red;
        break;
      case 'moderate':
        backgroundColor = Colors.orange;
        break;
      case 'minor':
        backgroundColor = Colors.yellow;
        textColor =
            Colors.black; // Use black text for better contrast on yellow
        break;
      default:
        backgroundColor = Colors.grey; // Default color for unknown severity
        textColor = Colors.white;
    }

    return Chip(
      label: Text(
        severity,
        style: TextStyle(color: textColor, fontWeight: FontWeight.bold),
      ),
      backgroundColor: backgroundColor,
    );
  }

  String _formatTimestamp(Timestamp? timestamp) {
    if (timestamp == null) return 'N/A';
    final dateTime = timestamp.toDate();
    return DateFormat('MMMM d, y h:mm a').format(dateTime);
  }
}
