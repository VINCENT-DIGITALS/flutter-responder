import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geolocator/geolocator.dart';
import 'package:intl/intl.dart';
import 'package:latlong2/latlong.dart';

import 'dart:async';

import '../../services/database.dart';
import '../../services/location_service.dart';
import '../maps/incident_report_map.dart';
import 'floating_report_detail.dart';

class ReportsListPage extends StatefulWidget {
  const ReportsListPage({super.key});

  @override
  State<ReportsListPage> createState() => _ReportsListPageState();
}

class _ReportsListPageState extends State<ReportsListPage> {
  TextEditingController _searchController = TextEditingController();
  String _searchTerm = '';
  bool _isDialogVisible = false;
  bool _isLoading = false; // Loading state
  bool _isAccepting = false; // State for accept button loading
  DocumentSnapshot? _currentReport;
  Timer? _timer;
  final DatabaseService _dbService = DatabaseService();
  String? _responderId;
  String? _responderName;
  Position? _currentPosition;
  final LocationService _locationService =
      LocationService(); // Instantiate the LocationService
  TextEditingController reporterNameController = TextEditingController();
  String? reporterName;
  String? reporterId;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchChanged);
    _fetchCurrentUserDetails();
    _getCurrentLocation();
  }

  void _onSearchChanged() {
    setState(() {
      _searchTerm = _searchController.text.toLowerCase();
    });
  }

  Future<void> _getCurrentLocation() async {
    try {
      Position? position = await _locationService.requestLocation();
      if (position != null) {
        setState(() {
          _currentPosition = position;
        });
      }
    } catch (e) {
      print('Error: $e');
    }
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

  String _formatTimestamp(Timestamp? timestamp) {
    if (timestamp == null) return 'N/A';
    final dateTime = timestamp.toDate();
    return DateFormat('MMMM d, y h:mm a').format(dateTime);
  }

  @override
  void dispose() {
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    _timer?.cancel();
    super.dispose();
  }

  Color _getSeriousnessColor(String? seriousness) {
    switch (seriousness?.toLowerCase()) {
      case 'severe':
        return Colors.red[700]!;
      case 'moderate':
        return Colors.orange[700]!;
      case 'minor':
        return Colors.green[700]!;
      default:
        return Colors.grey; // Default color for unknown seriousness
    }
  }

  Color _getStatusColor(String? status) {
    switch (status?.toLowerCase()) {
      case 'pending':
        return Colors.blue[700]!;
      case 'in progress':
        return Colors.orange[700]!;
      case 'completed':
        return Colors.green[700]!;
      default:
        return Colors.grey; // Default color for unknown status
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false, // Removes the back arrow
        toolbarHeight: 30, // Adjusted to reduce extra space
        bottom: PreferredSize(
          preferredSize: Size.fromHeight(56.0),
          child: Padding(
            padding: const EdgeInsets.all(8.0),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      hintText: 'Search incidents...',
                      prefixIcon: Icon(Icons.search, color: Colors.grey[600]),
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
                // SizedBox(width: 8.0), // Space between search and button
              ],
            ),
          ),
        ),
      ),
      body: Stack(
        children: [
          StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('reports')
                .orderBy('timestamp', descending: true)
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

                // Filter reports based on the search term
                String incidentType =
                    report['incidentType']?.toLowerCase() ?? '';
                String incident = report['incident']?.toLowerCase() ?? '';
                String status = report['status']?.toLowerCase() ?? '';
                String seriousness = report['seriousness']?.toLowerCase() ?? '';

                // Include only non-archived or not explicitly archived reports
                bool matchesSearchTerm = incidentType.contains(_searchTerm) ||
                    incident.contains(_searchTerm) ||
                    status.contains(_searchTerm) ||
                    seriousness.contains(_searchTerm);

                return (report['archived'] == null ||
                        report['archived'] == false) &&
                    matchesSearchTerm;
              }).toList();
              // .where((doc) {
              //   var report = doc.data() as Map<String, dynamic>;
              //   return (report['acceptedBy'] == null ||
              //           !report.containsKey('acceptedBy')) &&
              //       (report['archived'] == null || report['archived'] == false);
              // }).toList();
// Sort: Move reports with acceptedBy == null to the top
              // Sort reports: By seriousness, acceptedBy, and timestamp
              reports.sort((a, b) {
                var reportA = a.data() as Map<String, dynamic>;
                var reportB = b.data() as Map<String, dynamic>;

                // Determine if reports have 'acceptedBy'
                bool isAcceptedA = reportA['acceptedBy'] != null;
                bool isAcceptedB = reportB['acceptedBy'] != null;

                // 1. Reports without 'acceptedBy' come first
                if (!isAcceptedA && isAcceptedB) return -1; // A goes above B
                if (isAcceptedA && !isAcceptedB) return 1; // B goes above A

                // 2. For reports without 'acceptedBy', sort by seriousness
                if (!isAcceptedA && !isAcceptedB) {
                  final seriousnessPriority = {
                    'severe': 1,
                    'moderate': 2,
                    'minor': 3
                  };
                  int seriousnessA = seriousnessPriority[
                          reportA['seriousness']?.toString().toLowerCase()] ??
                      4;
                  int seriousnessB = seriousnessPriority[
                          reportB['seriousness']?.toString().toLowerCase()] ??
                      4;

                  if (seriousnessA != seriousnessB) {
                    return seriousnessA -
                        seriousnessB; // Lower priority number comes first
                  }

                  // Tiebreaker: Sort by timestamp (descending)
                  Timestamp? timestampA = reportA['timestamp'] as Timestamp?;
                  Timestamp? timestampB = reportB['timestamp'] as Timestamp?;
                  if (timestampA != null && timestampB != null) {
                    return timestampB
                        .compareTo(timestampA); // Newer reports first
                  }
                  return 0; // If timestamps are null or equal
                }

                // 3. For reports with 'acceptedBy', sort by status
                if (isAcceptedA && isAcceptedB) {
                  final statusPriority = {'in progress': 1, 'completed': 2};
                  int statusA = statusPriority[
                          reportA['status']?.toString().toLowerCase()] ??
                      3;
                  int statusB = statusPriority[
                          reportB['status']?.toString().toLowerCase()] ??
                      3;

                  if (statusA != statusB) {
                    return statusA -
                        statusB; // Lower priority number comes first
                  }

                  // Tiebreaker: Sort by timestamp (descending)
                  Timestamp? timestampA = reportA['timestamp'] as Timestamp?;
                  Timestamp? timestampB = reportB['timestamp'] as Timestamp?;
                  if (timestampA != null && timestampB != null) {
                    return timestampB
                        .compareTo(timestampA); // Newer reports first
                  }
                  return 0; // If timestamps are null or equal
                }

                return 0; // Default case if all other checks fail
              });

              return ListView.builder(
                padding: const EdgeInsets.all(16.0),
                itemCount: reports.length,
                itemBuilder: (context, index) {
                  var report = reports[index].data() as Map<String, dynamic>;

                  // Check if the report is already accepted by a responder
                  bool isAccepted = report['acceptedBy'] != null;

                  // Calculate distance if location is available
                  double? distance;
                  bool isLocationAvailable = _currentPosition != null;
                  if (isLocationAvailable && report['location'] is GeoPoint) {
                    final Distance distanceCalculator = Distance();
                    final LatLng currentLocation = LatLng(
                        _currentPosition!.latitude,
                        _currentPosition!.longitude);
                    final GeoPoint location =
                        report['location']; // GeoPoint object
                    final LatLng evacuationCoords = LatLng(location.latitude,
                        location.longitude); // Accessing GeoPoint properties
                    distance = distanceCalculator.as(LengthUnit.Kilometer,
                        currentLocation, evacuationCoords);
                  }

                  return Card(
                    elevation: 4,
                    margin: const EdgeInsets.symmetric(vertical: 8.0),
                    child: ListTile(
                      contentPadding: const EdgeInsets.all(16.0),
                      title: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            report['incidentType'],
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          SizedBox(height: 8),
                          Text(
                            _formatTimestamp(report['timestamp']),
                            style: TextStyle(color: Colors.grey[600]),
                          ),
                          SizedBox(height: 8),
                          Text(
                            report['address'],
                            style: TextStyle(color: Colors.grey[600]),
                          ),
                          SizedBox(height: 8),
                          Text(
                            'Severity: ${report['seriousness']}',
                            style: TextStyle(
                              color:
                                  _getSeriousnessColor(report['seriousness']),
                              fontWeight: FontWeight
                                  .bold, // Optional: Highlight based on seriousness
                            ),
                          ),
                          SizedBox(height: 8),
                          Text(
                            'Status: ${report['status']}',
                            style: TextStyle(
                              color: _getStatusColor(report['status']),
                              fontWeight: FontWeight
                                  .bold, // Optional: Highlight based on status
                            ),
                          ),
                          if (isAccepted)
                            Padding(
                              padding: const EdgeInsets.only(top: 8.0),
                              child: Text(
                                'Accepted by: ${report['acceptedBy']}',
                                style: TextStyle(
                                  color: Colors.green[700],
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                        ],
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize
                            .min, // Ensures the trailing content doesn't take up unnecessary space
                        children: [
                          if (isLocationAvailable)
                            IconButton(
                              icon: Icon(
                                Icons.map,
                                color: Colors.orange,
                                size: 30, // Adjust size accordingly
                              ),
                              onPressed: () {
                                if (report['location'] is GeoPoint) {
                                  GeoPoint geoPoint = report['location'];
                                  LatLng location = LatLng(
                                      geoPoint.latitude, geoPoint.longitude);

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
                                  print('Location is not a GeoPoint');
                                }
                              },
                            ),
                          if (isLocationAvailable)
                            Text(
                              '${distance?.toStringAsFixed(2)} km',
                              style:
                                  const TextStyle(fontWeight: FontWeight.bold),
                            ),
                          if (!isLocationAvailable)
                            const SizedBox(
                              width: 20,
                              height: 20,
                              child:
                                  CircularProgressIndicator(strokeWidth: 2.0),
                            ),
                        ],
                      ),
                      onTap: () => _handleReportClick(report, reports[index]),
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
              reportId: _currentReport!.id, // Pass the report ID here
              responderId: _responderId!,
              responderName: _responderName!,
              onAccept: _acceptReport,
              onCancel: _cancelReport,
              isAccepting: _isAccepting,
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

  Future<bool> _showConfirmationPrompt(
      BuildContext context, String message) async {
    return await showDialog<bool>(
          context: context,
          builder: (BuildContext context) {
            return AlertDialog(
              title: const Text('Confirmation'),
              content: Text(message),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(false), // Cancel
                  child: const Text('Cancel'),
                ),
                TextButton(
                  onPressed: () => Navigator.of(context).pop(true), // Confirm
                  child: const Text('Confirm'),
                ),
              ],
            );
          },
        ) ??
        false; // Default to false if dialog is dismissed
  }

  Future<void> _acceptReport() async {
    // Show confirmation dialog before proceeding
    bool shouldProceed = await _showConfirmationPrompt(
      context,
      "Are you sure you want to accept this report?",
    );

    if (!shouldProceed) {
      return; // Exit if user cancels
    }
    setState(() {
      _isAccepting = true; // Start loading when accepting report
    });

    if (_currentReport != null) {
      final reportRef = FirebaseFirestore.instance
          .collection('reports')
          .doc(_currentReport!.id);

      try {
        // Use Firestore transaction to ensure atomic operation
        await FirebaseFirestore.instance.runTransaction((transaction) async {
          // Get the latest state of the report document
          DocumentSnapshot snapshot = await transaction.get(reportRef);

          if (snapshot.exists) {
            final reportData = snapshot.data() as Map<String, dynamic>;

            // Check if the report has already been accepted
            if (reportData.containsKey('acceptedBy') &&
                reportData['acceptedBy'] != null) {
              // If accepted, notify the user and do not overwrite
              String acceptedBy = reportData['acceptedBy'];
              _showConfirmationDialog(context,
                  'This report has already been accepted by $acceptedBy.');
            } else {
              DocumentSnapshot userDoc =
                  await _dbService.getReporterName(reportData['reporterId']);

              // Check if the document exists
              if (userDoc.exists) {
                // Access the displayName field
                reporterNameController.text = userDoc.get('displayName');
                print('Reporter Name: $reporterName');
              } else {
                print('No user found for the given reporterId.');
              }
              // Proceed with accepting the report
              // Log the report in the logBook collection
              transaction.set(
                FirebaseFirestore.instance.collection('logBook').doc(),
                {
                  'reportId': _currentReport!.id,
                  'primaryResponderId': _responderId,
                  'primaryResponderDisplayName': _responderName,
                  'timestamp': FieldValue.serverTimestamp(),
                  'location': reportData['location'] as GeoPoint,
                  'status': 'In Progress',
                  'incident': '',
                  'incidentDesc': reportData['description'],
                  'address': reportData['address'],
                  'landmark': reportData['landmark'] ?? '',
                  'transportedTo': '',
                  'incidentType': reportData['incidentType'],
                  'injuredCount': reportData['injuredCount'],
                  'seriousness': reportData['seriousness'],
                  'mediaUrl': reportData['mediaUrl'] ?? '',
                  'victims': [],
                  'responders': [
                    {
                      'responderName': _responderName,
                    },
                  ],
                  'scam': 'Pending',
                  'reporterName': reporterNameController.text,
                },
              );

              // Update the report to mark it as accepted and add the responder's name
              transaction.set(
                reportRef,
                {
                  'acceptedBy': _responderName,
                  'responderId': _responderId,
                  'viewed': true,
                  'lockedBy': _responderId,
                  'status': 'In Progress',
                  'updatedAt': FieldValue.serverTimestamp(),
                },
                SetOptions(merge: true),
              );

              // Show confirmation dialog after successful acceptance
              _showConfirmationDialog(context, 'Report accepted successfully.');
              setState(() {
                _currentReport = null; // Reset the current report
              });
            }
          }
        });
      } catch (e) {
        // Handle any errors during the transaction
        _showConfirmationDialog(context, 'Failed to accept the report.');
      }
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
}
