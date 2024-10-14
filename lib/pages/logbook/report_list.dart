import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'dart:async';

import '../../services/database.dart';
import 'floating_report_detail.dart';

class ReportsListPage extends StatefulWidget {
  const ReportsListPage({super.key});

  @override
  State<ReportsListPage> createState() => _ReportsListPageState();
}

class _ReportsListPageState extends State<ReportsListPage> {
  bool _isDialogVisible = false;
  bool _isLoading = false; // Loading state
  bool _isAccepting = false; // State for accept button loading
  DocumentSnapshot? _currentReport;
  Timer? _timer;
  final DatabaseService _dbService = DatabaseService();
  String? _responderId;
  String? _responderName;

  @override
  void initState() {
    super.initState();
    _fetchCurrentUserDetails();
  }

  Future<void> _fetchCurrentUserDetails() async {
    try {
      final userDetails = await _dbService.getCurrentUserDetails();
      print('User Details: $userDetails'); // Log the user details

      setState(() {
        _responderId = userDetails['id'];
        _responderName = userDetails['name'];
      });

      // Log responder information
      if (_responderName != null) {
        print('Responder ID: $_responderId');
        print('Responder Name: $_responderName');
      } else {
        print('Responder Name is null or does not exist.');
      }
    } catch (e) {
      print('Error fetching user details: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          StreamBuilder<QuerySnapshot>(
            stream:
                FirebaseFirestore.instance.collection('reports')
                .orderBy('timestamp', descending: false) // Order by 'timestamp' in ascending order
                .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return Center(child: CircularProgressIndicator());
              }
              if (snapshot.hasError) {
                return Center(child: Text('Error loading reports'));
              }

              final reports = (snapshot.data?.docs ?? []).where((doc) {
                var report = doc.data() as Map<String, dynamic>;
                return report['acceptedBy'] == null ||
                    !report.containsKey('acceptedBy');
              }).toList();

              if (reports.isEmpty) {
                return Center(child: Text('No reports available'));
              }

              return ListView.builder(
                padding: const EdgeInsets.all(16.0),
                itemCount: reports.length,
                itemBuilder: (context, index) {
                  var report = reports[index].data() as Map<String, dynamic>;

                  // Check if the report is already accepted by a responder
                  bool isAccepted = report['acceptedBy'] != null;

                  return Card(
                    elevation: 4,
                    margin: const EdgeInsets.symmetric(vertical: 8.0),
                    child: InkWell(
                      onTap: () => _handleReportClick(report, reports[index]),
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              report['incidentType'],
                              style: TextStyle(
                                  fontSize: 18, fontWeight: FontWeight.bold),
                            ),
                            SizedBox(height: 8),
                            Text(
                              report['address'],
                              style: TextStyle(color: Colors.grey[600]),
                            ),
                            SizedBox(height: 8),
                            Text(
                              'Seriousness: ${report['seriousness']}',
                              style: TextStyle(color: Colors.red[600]),
                            ),
                            SizedBox(height: 8),
                            if (isAccepted)
                              Text(
                                'Accepted by: ${report['acceptedBy']}',
                                style: TextStyle(
                                  color: Colors.green[700],
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              );
            },
          ),
          if (_isLoading)
            Center(
              child:
                  CircularProgressIndicator(), // Show loading indicator when loading
            ),
        ],
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      floatingActionButton: _currentReport != null &&
              _responderId != null &&
              _responderName != null
          ? FloatingReportWidget(
              report: _currentReport!,
              responderId: _responderId!,
              responderName: _responderName!,
              onAccept: _acceptReport,
              onCancel: _cancelReport, // Pass the cancel callback
              isAccepting: _isAccepting, // Pass the loading state here
            )
          : null,
    );
  }

  Future<void> _handleReportClick(
      Map<String, dynamic> report, DocumentSnapshot reportDoc) async {
    setState(() {
      _isLoading = true; // Start loading when report is clicked
    });

    // Update the report document to mark as viewed and locked by the responder
    await FirebaseFirestore.instance
        .collection('reports')
        .doc(reportDoc.id)
        .update({
      'viewed': true,
      'lockedBy': _responderId,
    });

    setState(() {
      _currentReport = reportDoc;
      _isLoading = false; // Stop loading after report data is loaded
    });
  }

  Future<void> _acceptReport() async {
    setState(() {
      _isAccepting = true; // Start loading when accepting report
    });

    if (_currentReport != null) {
      // Extract the report data
      final reportData = _currentReport!.data() as Map<String, dynamic>;

      // Log the report in the logBook collection
      await FirebaseFirestore.instance.collection('logBook').doc().set({
        'reportId': _currentReport!.id,
        'primaryResponderId': _responderId,
        'primaryResponderDisplayName': _responderName,
        'timestamp': FieldValue.serverTimestamp(),
        'location': {
          'latitude': (reportData['location'] as GeoPoint).latitude,
          'longitude': (reportData['location'] as GeoPoint).longitude,
        },
        'status': 'In Progress',
        'incident': '',
        'incidentDesc': reportData['description'],
        'address': reportData['address'],
        'landmark': reportData['landmark'] ?? '',
        'transportedTo': '',
        'incidentType': reportData['incidentType'],
        'seriousness': reportData['seriousness'],
        'mediaUrl': reportData['mediaUrl'] ?? '',
        'victims': [],
        'responders': [
          {'responderId': _responderId},
        ],
      });

      // Update the report to mark it as accepted and add the responder's name
      await FirebaseFirestore.instance
          .collection('reports')
          .doc(_currentReport!.id)
          .set({
        'acceptedBy':
            _responderName, // Add the acceptedBy field with responder's name
        'responderId': _responderId,
        'viewed': true,
        'lockedBy': _responderId,
        'status': 'In Progress',
      }, SetOptions(merge: true));

      // Show confirmation dialog after successful acceptance
      _showConfirmationDialog(context, 'Report accepted successfully.');
      setState(() {
        _currentReport = null; // Reset the current report
      });
    }

    setState(() {
      _isAccepting = false; // Stop loading when done
    });
  }

  Future<void> _cancelReport() async {
    setState(() {
      _currentReport = null; // Reset the current report
    });
  }

  // Future<void> _updateReportStatus(bool isViewing) async {
  //   if (_currentReport != null) {
  //     await FirebaseFirestore.instance
  //         .collection('reports')
  //         .doc(_currentReport!.id)
  //         .set({
  //       'viewed': true,
  //       'lockedBy': _responderId,
  //       'acceptedBy': _responderName,
  //     }, SetOptions(merge: true));

  //     setState(() {
  //       _currentReport = null; // Reset the current report
  //     });
  //   }
  // }

  void _showConfirmationDialog(BuildContext context, String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Confirmation'),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text('OK'),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}
