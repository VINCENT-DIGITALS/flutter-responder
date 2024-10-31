import 'dart:async';
import 'dart:convert';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_map_marker_popup/flutter_map_marker_popup.dart';
import 'package:flutter_map_tile_caching/flutter_map_tile_caching.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:responder/api/routing.dart';
import '../../services/location_service.dart';
import '../sidebar_Pages/about_app_page.dart';

class EvacuationPlaceMapPage extends StatefulWidget {
  final String locationName;
  final LatLng evacuationCoords;

  const EvacuationPlaceMapPage({
    required this.locationName,
    required this.evacuationCoords,
    super.key,
  });

  @override
  State<EvacuationPlaceMapPage> createState() => _EvacuationPlaceMapPageState();
}

class _EvacuationPlaceMapPageState extends State<EvacuationPlaceMapPage> {
  // Raw coordinates got from  OpenRouteService
  List listOfPoints = [];
  bool _isLoading = false;

  // Conversion of listOfPoints into LatLng(Latitude, Longitude) list of points
  List<LatLng> points = [];
  final MapController mapController = MapController();
  late final tileProvider = FMTCStore('mapCache').getTileProvider(
    settings: FMTCTileProviderSettings(
      behavior: CacheBehavior.cacheFirst,
      cachedValidDuration: const Duration(days: 5),
    ),
  );

  final LocationService _locationService =
      LocationService(); // Initialize LocationService
  StreamSubscription<Position>?
      _positionStream; // For listening to location updates
  LatLng? _currentLocation; // Store the current location
  final PopupController _popupController =
      PopupController(); // Add PopupController to manage popups

  @override
  void initState() {
    super.initState();
    _startListeningToLocationUpdates();
  }

  // Start listening to location updates
  void _startListeningToLocationUpdates() async {
    try {
      bool hasPermission =
          await _locationService.checkLocationServicesAndPermissions();
      if (hasPermission) {
        // Get the initial position first
        Position position = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.best,
        );
        setState(() {
          _currentLocation = LatLng(position.latitude, position.longitude);
        });

        // Then start the position stream for real-time updates
        _positionStream = Geolocator.getPositionStream(
          locationSettings:
              const LocationSettings(accuracy: LocationAccuracy.best),
        ).listen((Position position) {
          setState(() {
            _currentLocation = LatLng(position.latitude, position.longitude);
          });
        });
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text(
                  'Location permission denied. Please enable it to use the map.')),
        );
      }
    } catch (e) {
      print('Error starting location updates: $e');
    }
  }

  // Get markers including current and evacuation location
  List<Marker> getMarkers() {
    List<Marker> markers = [
      Marker(
        point: widget.evacuationCoords,
        child: const Icon(
          Icons.location_on,
          color: Colors.red,
          size: 40,
        ),
        key: const Key(
            'evacuationMarker'), // Add unique key for popup functionality
      ),
    ];

    if (_currentLocation != null) {
      markers.add(
        Marker(
          point: _currentLocation!,
          child: const Icon(
            Icons.person_pin_circle,
            color: Colors.blue,
            size: 40,
          ),
          key: const Key(
              'currentLocationMarker'), // Add unique key for popup functionality
        ),
      );
    }

    return markers;
  }

// Helper function to convert LatLng to 'longitude,latitude' string format
  String latLngToString(LatLng coords) {
    return '${coords.longitude},${coords.latitude}';
  }

  getCoordinates() async {
    setState(() {
      _isLoading = true;
    });

    var connectivityResult = await (Connectivity().checkConnectivity());

    if (connectivityResult == ConnectivityResult.none) {
      // No internet connection
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Internet connection required for routing!'),
          duration: Duration(seconds: 3),
        ),
      );
      setState(() {
        _isLoading = false;
      });
      return;
    }

    if (_currentLocation != null) {
      // Convert current location and evacuation coordinates to string format
      String startPoint = latLngToString(_currentLocation!);
      String endPoint = latLngToString(widget.evacuationCoords);

      try {
        var response = await http.get(getRouteUrl(startPoint, endPoint));

        setState(() {
          if (response.statusCode == 200) {
            var data = jsonDecode(response.body);
            listOfPoints = data['features'][0]['geometry']['coordinates'];
            points = listOfPoints
                .map((p) => LatLng(p[1].toDouble(), p[0].toDouble()))
                .toList();
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                    'Internet connection required for routing!, please try again'),
                duration: Duration(seconds: 3),
              ),
            );
            print('Error: ${response.reasonPhrase}');
          }
          _isLoading = false; // Stop loading after the response is processed
        });
      } catch (e) {
        setState(() {
          _isLoading = false; // Stop loading if there's an exception
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Internet connection required for routing!, please try again'),
            duration: Duration(seconds: 3),
          ),
        );
        print('Exception caught: $e');
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Current location not available!'),
          duration: Duration(seconds: 3),
        ),
      );
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  void dispose() {
    _positionStream?.cancel(); // Cancel the location updates when disposing
    super.dispose();
  }

  // Method to delete the cached tiles
  Future<void> _deleteCachedTiles() async {
    final mgmt = FMTCStore('mapCache').manage;

    try {
      await mgmt.delete(); // Delete the cached tiles
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Map cache deleted successfully.'),
        ),
      );
    } catch (e) {
      print('Error deleting cache: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Error deleting cache.'),
        ),
      );
    }
  }

  // Show a confirmation dialog before deleting the cache
  void _showDeleteConfirmationDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Delete Cache'),
          content: const Text(
              'Are you sure you want to delete the cached map data?'),
          actions: <Widget>[
            TextButton(
              onPressed: () {
                Navigator.of(context).pop(); // Close the dialog
              },
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                _deleteCachedTiles(); // Call the delete method
                Navigator.of(context).pop(); // Close the dialog
              },
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );
  }

  // Show the confirmation dialog before navigating to the GPL page
  void _showGPLConfirmationDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('GPL License Acknowledgment'),
          content: const Text(
              'This app uses the flutter_map_tile_caching package, which is licensed under the GPL. Would you like to view more details?'),
          actions: <Widget>[
            TextButton(
              onPressed: () {
                Navigator.of(context).pop(); // Close the dialog
              },
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop(); // Close the dialog
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) =>
                        AboutAppPage(), // Navigate to GPL License Page
                  ),
                );
              },
              child: const Text('View'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Evacuation Map'),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete),
            onPressed:
                _showDeleteConfirmationDialog, // Show confirmation dialog on delete button click
          ),
        ],
      ),
      body: Stack(
        children: [
          FlutterMap(
            mapController: mapController,
            options: MapOptions(
              initialCenter: widget
                  .evacuationCoords, // Center on evacuation location initially
              initialZoom: 15,
              maxZoom: 20,
              minZoom: 13,
              onTap: (_, __) =>
                  _popupController.hideAllPopups(), // Hide popup on map tap
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.example.app',
                tileProvider: tileProvider,
              ),

              PolylineLayer(
                polylineCulling: false,
                polylines: [
                  Polyline(points: points, color: Colors.black, strokeWidth: 5),
                ],
              ),
              MarkerLayer(
                markers: getMarkers(), // Use dynamic markers
              ),
              PopupMarkerLayer(
                options: PopupMarkerLayerOptions(
                  markers: getMarkers(),
                  popupController: _popupController,
                  markerTapBehavior: MarkerTapBehavior
                      .togglePopup(), // Toggle popup on marker tap
                  popupDisplayOptions: PopupDisplayOptions(
                    builder: (BuildContext context, Marker marker) {
                      // Popup content based on marker key
                      if (marker.key == const Key('evacuationMarker')) {
                        return Container(
                          color: Colors.white,
                          padding: const EdgeInsets.all(8.0),
                          child: Text(
                              'Evacuation Location: ${widget.locationName}'),
                        );
                      } else if (marker.key ==
                          const Key('currentLocationMarker')) {
                        return Container(
                          color: Colors.white,
                          padding: const EdgeInsets.all(8.0),
                          child: const Text('You are here'),
                        );
                      }
                      return Container();
                    },
                  ),
                ),
              ),
              // Polylines layer
            ],
          ),
          Positioned(
            bottom: 20,
            left: 20,
            child: GestureDetector(
              onTap: _showGPLConfirmationDialog, // Show dialog on tap
              child: FlutterLogo(size: 30), // Display the Flutter logo
            ),
          ),
        ],
      ),
      bottomNavigationBar: BottomAppBar(
        color: Colors.white, // Use white background for a modern look
        shape:
            CircularNotchedRectangle(), // Adds a notch for the floating action button
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 10.0, horizontal: 10.0),
          child: Row(
            mainAxisAlignment:
                MainAxisAlignment.spaceBetween, // Align icons to left and right
            children: [
              // Remove the 'ready' check and ensure mapController is properly handled
              IconButton(
                icon: Icon(Icons.my_location, color: Colors.blue, size: 40),
                onPressed: () {
                  if (_currentLocation != null) {
                    mapController.move(_currentLocation!, 15.0);
                  } else {
                    print("Current location is null.");
                  }
                },
              ),

              // Friend's location button
              IconButton(
                icon: Icon(Icons.shield, color: Colors.green, size: 40),
                onPressed: () {
                  if (widget.evacuationCoords != null) {
                    mapController.move(widget.evacuationCoords!, 15.0);
                  } else {
                    print("Evacuation location is null.");
                  }
                },
              ),
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _isLoading
            ? null
            : () {
                getCoordinates();
              },
        tooltip: 'Get Coordinates',
        child: _isLoading
            ? CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
              )
            : Icon(Icons.route_sharp),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
    );
  }
}
