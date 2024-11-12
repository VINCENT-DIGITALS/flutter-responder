import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:geolocator/geolocator.dart';
import 'package:intl/intl.dart';
import 'package:latlong2/latlong.dart';
import 'package:responder/services/shared_pref.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../services/database.dart';
import '../../services/location_service.dart';
import '../maps/incident_report_map.dart';
import 'add_new_log.dart';
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
  Position? _currentPosition;
  final LocationService _locationService =
      LocationService(); // Instantiate the LocationService
  final DatabaseService _dbService = DatabaseService();

  TextEditingController responderNameController = TextEditingController();
  String? responderName;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchChanged);
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser != null) {
      getReporterDisplayName(currentUser.uid);
    }
  }

  void getReporterDisplayName(String? reporterId) async {
    // Call the getUserDoc function and wait for the DocumentSnapshot
    DocumentSnapshot userDoc = await _dbService.getUserDoc(reporterId!);

    // Check if the document exists
    if (userDoc.exists) {
      // Access the displayName field and assign it to the TextEditingController
      String displayName = userDoc.get('displayName');
      responderNameController.text =
          displayName; // Correctly set text for the controller
      print('Reporter Name: $displayName');
    } else {
      print('No user found for the given reporterId.');
    }
  }

  @override
  void dispose() {
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    super.dispose();
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

  void _onSearchChanged() {
    setState(() {
      _searchTerm = _searchController.text.toLowerCase();
    });
  }

  String _formatTimestamp(Timestamp? timestamp) {
    if (timestamp == null) return 'N/A';
    final dateTime = timestamp.toDate();
    return DateFormat('MMMM d, y h:mm a').format(dateTime);
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = FirebaseAuth.instance.currentUser;
    print("Current User: ${currentUser}");
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
                SizedBox(width: 8.0), // Space between search and button
                Material(
                  color: Colors.blueAccent, // Button background color
                  borderRadius: BorderRadius.circular(8.0),
                  elevation: 2, // Adds a shadow for depth
                  child: InkWell(
                    borderRadius: BorderRadius.circular(8.0),
                    onTap: () {
                      showModalBottomSheet(
                        context: context,
                        isScrollControlled: true,
                        isDismissible:
                            false, // Prevents closing by tapping the background
                        builder: (context) {
                          return FractionallySizedBox(
                            heightFactor: 0.8,
                            child: FloatingNewLogBookWidget(
                              onSave: () {
                                Navigator.pop(context);
                              },
                            ),
                          );
                        },
                      );
                    },
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12.0, vertical: 8.0),
                      child: Row(
                        children: [
                          Icon(Icons.add, color: Colors.white),
                          SizedBox(width: 4.0),
                          Text(
                            'New',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('logBook')
            .where('primaryResponderId', isEqualTo: currentUser.uid)
            .orderBy('timestamp', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(
                child:
                    Text('Error loading logbook entries ${snapshot.hasError}'));
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
              final String? mediaUrl = logbook['mediaUrl'];
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
                                  isDismissible:
                                      false, // Prevents closing by tapping the background
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
                      SizedBox(height: 10),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [],
                      ),
                      SizedBox(height: 10),
                      Row(
                        mainAxisAlignment: MainAxisAlignment
                            .spaceBetween, // Spread children apart
                        children: [
                          Expanded(
                            // Wrap each child in Expanded to take up available space
                            child: Container(
                              padding: EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 5),
                              decoration: BoxDecoration(
                                color: _getStatusColor(
                                    logbook['scam'] ?? 'Pending'),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Row(
                                children: [
                                  Icon(Icons.circle,
                                      color: Colors.white, size: 12),
                                  SizedBox(width: 4),
                                  Text(
                                    'Legitimacy: ${logbook['scam'] ?? 'Pending'}',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          SizedBox(width: 8), // Adjust this spacing if needed
                          Expanded(
                            child: Container(
                              padding: EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 5),
                              decoration: BoxDecoration(
                                color: _getStatusColor(
                                    logbook['status'] ?? 'Pending'),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Row(
                                children: [
                                  Icon(Icons.circle,
                                      color: Colors.white, size: 12),
                                  SizedBox(width: 4),
                                  Text(
                                    'Status: ${logbook['status'] ?? 'Pending'}',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment
                            .spaceBetween, // Spread children apart
                        children: [
                          Center(
                            child: Visibility(
                              visible: mediaUrl !=
                                  null, // Show button only if mediaUrl is not null
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
                                  ' Media',
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
                          ),
                          // Space between Status and Map Button
                          SizedBox(
                              width:
                                  16), // You can adjust this value for more or less space

                          // Map Button Container
                          Container(
                            padding: EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors
                                  .blue, // Set a separate color for the map button background
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: IconButton(
                              icon: Icon(
                                Icons.map_outlined,
                                color: Colors.white,
                                size: 30,
                              ),
                              onPressed: () {
                                // Check if the location is a GeoPoint
                                if (logbook['location'] != null &&
                                    logbook['location'] is GeoPoint) {
                                  // Extract latitude and longitude from the GeoPoint
                                  GeoPoint geoPoint = logbook['location'];
                                  LatLng location = LatLng(
                                      geoPoint.latitude, geoPoint.longitude);

                                  // Navigate to the map screen
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => IncidentReportMap(
                                        locationName: logbook[
                                            'address'], // Use the address from logbook
                                        LocationCoords:
                                            location, // Pass the LatLng object
                                        incidentType: logbook['incidentType'],
                                      ),
                                    ),
                                  );
                                } else {
                                  // Handle error if location is not properly formatted (optional)
                                  print('Location is not properly formatted');
                                }
                              },
                            ),
                          )
                        ],
                      )
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
}
