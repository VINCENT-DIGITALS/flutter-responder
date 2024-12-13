import 'dart:async';

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_localization/flutter_localization.dart';
import 'package:geolocator/geolocator.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../../localization/locales.dart';
import '../../services/location_service copy.dart';
import '../logbook/logbook_widgets/buildTextField.dart';
import '../../services/database.dart';
import 'logbook_widgets/build_dropdownField.dart';

class FloatingNewLogBookWidget extends StatefulWidget {
  final VoidCallback onSave;

  const FloatingNewLogBookWidget({Key? key, required this.onSave})
      : super(key: key);

  @override
  _FloatingNewLogBookWidgetState createState() =>
      _FloatingNewLogBookWidgetState();
}

class _FloatingNewLogBookWidgetState extends State<FloatingNewLogBookWidget>
    with WidgetsBindingObserver {
  final TextEditingController _landmarkController = TextEditingController();
  final TextEditingController _transportedToController =
      TextEditingController();
  final TextEditingController _incidentTypeController = TextEditingController();
  final TextEditingController _incidentController = TextEditingController();
  final TextEditingController _incidentDescController = TextEditingController();
  final TextEditingController _addressController = TextEditingController();
  TextEditingController reporterNameController = TextEditingController();
  List<Map<String, dynamic>> _vehicles = []; // List to hold vehicle details
  List<Map<String, dynamic>> _victims = [];
  List<Map<String, dynamic>> _responders = [];
  String? _status; // Add this variable to store the status
  String? _seriousness;
  String? _scam;
  final TextEditingController _injuredCountController = TextEditingController();
  String? reporterName;
  String? reportnerId;
  bool _isSaving = false;
  Timestamp? _timestamp; // To store the Firestore timestamp
  Timestamp? _updatedAt; // To store the updatedAt timestamp
  double? _latitude;
  double? _longitude;
  String? _responderId;
  String? _responderName;
  bool _isLoading = false;
  final LocationService _locationService = LocationService();
  String _formatTimestamp(Timestamp? timestamp) {
    if (timestamp == null) return 'N/A';
    final dateTime = timestamp.toDate();
    return DateFormat('MMMM d, y h:mm a').format(dateTime);
  }

  final DatabaseService _dbService = DatabaseService();
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _getCurrentLocation();
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

  Future<void> _saveLogBookToFirestore() async {
    setState(() {
      _isSaving = true;
    });

    try {
      // Attempt to update the logbook in Firestore with a timeout
      await FirebaseFirestore.instance.collection('logBook').add({
        'reporterName': reporterNameController.text,
        'transportedTo': _transportedToController.text,
        'victims': _victims,
        'injuredCount': _injuredCountController.text,
        'vehicles': _vehicles,
        'seriousness': _seriousness,
        'responders': _responders,
        'status': _status, // Add the status field here
        'scam': _scam,
        'address': _addressController.text, // Add address field here
        'incident': _incidentController.text,
        'incidentDesc': _incidentDescController.text, // New field
        'incidentType': _incidentTypeController.text,
        'landmark': _landmarkController.text,
        'location': GeoPoint(_latitude!, _longitude!),
        'primaryResponderDisplayName': _responderName,
        'primaryResponderId': _responderId,
        'reportId': '',
        'reporterId': '',
        'timestamp': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(), // New field to track updates
      }).timeout(const Duration(seconds: 5)); // Timeout after 5 seconds

      widget.onSave(); // Callback to notify parent widget

      // Firestore save successful, delete the locally saved logbook
      // Delete the logbook from shared preferences upon successful update

      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Logbook saved successfully.'),
        backgroundColor: Colors.green,
      ));
    } on TimeoutException catch (_) {
      // If a timeout occurs, notify the user and keep the local save
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content:
            Text('Network timeout. Data saved locally; Upload it again later.'),
        backgroundColor: Colors.green,
      ));
      widget.onSave(); // Callback to notify parent widget
    } catch (e) {
      // Catch other Firestore errors
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(
            'Failed to sync with Firestore. Local save, Upload it again later.'),
        backgroundColor: Colors.red,
      ));
    } finally {
      setState(() {
        _isSaving = false;
      });
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Implement autosave logic here
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      _saveLogBookToFirestore(); // Autosave if the app is backgrounded
    }
  }

  // Methods to add and remove vehicles
  void _addVehicle() {
    setState(() {
      _vehicles.add({'vehicleType': 'Single'}); // Default vehicle type
    });
  }

  void _removeVehicle(int index) {
    setState(() {
      _vehicles.removeAt(index);
    });
  }

  void _addVictim() {
    setState(() {
      _victims.add({
        'name': '',
        'age': '',
        'sex': 'Other', // Default to 'Male' or any valid option
        'address': '',
        'injury': '',
        'lifeStatus': 'Injured',
      });
    });
  }

  void _removeVictim(int index) {
    setState(() {
      _victims.removeAt(index);
    });
  }

  void _addResponder() {
    setState(() {
      _responders.add({
        'responderName': '',
      });
    });
  }

  void _removeResponder(int index) {
    setState(() {
      _responders.removeAt(index);
    });
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context)
            .viewInsets
            .bottom, // Adjust padding for keyboard
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
               LocaleData.NewLogbook.getString(context),
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 16),

            // Incident Information Section
            Card(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12.0),
              ),
              elevation: 3,
              child: Padding(
                padding: const EdgeInsets.all(12.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                       LocaleData.incidentInfo.getString(context),
                      style:
                          TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                    ),
                    SizedBox(height: 8),

                    // Display Created At and Updated At timestamps
                    Text(
                       LocaleData.CreatedAt.getString(context)+': ${_formatTimestamp(_timestamp)}',
                      style: TextStyle(
                          color: const Color.fromARGB(255, 0, 0, 0),
                          fontWeight: FontWeight.bold),
                    ),
                    SizedBox(height: 4),
                    Text(
                       LocaleData.LastUpdatedAt.getString(context)+': ${_formatTimestamp(_updatedAt)}',
                      style: TextStyle(
                          color: const Color.fromARGB(255, 0, 0, 0),
                          fontWeight: FontWeight.bold),
                    ),
                    SizedBox(height: 12),
                    buildTextField( LocaleData.ReporterName.getString(context), reporterNameController),
                    SizedBox(height: 12),
                    buildAddressTextField( LocaleData.Address.getString(context), _addressController),
                    SizedBox(height: 12),
                    buildTextField( LocaleData.landmark.getString(context), _landmarkController),
                    SizedBox(height: 12),
                    buildTextField( LocaleData.NoOfInjured.getString(context), _injuredCountController),
                    SizedBox(height: 12),
                    buildTextField('Transported To', _transportedToController),
                    SizedBox(height: 12),
                    // Status Dropdown
                    buildDropdownField( LocaleData.severity.getString(context),
                        ['Minor', 'Moderate', 'Severe'], _seriousness, (val) {
                      setState(() {
                        _seriousness = val ?? 'Minor';
                      });
                    }),
                    SizedBox(height: 12),
                    // Status Dropdown
                    buildDropdownField(
                         LocaleData.status.getString(context), ['In Progress', 'Completed'], _status, (val) {
                      setState(() {
                        _status = val ?? 'In Progress';
                      });
                    }),
                    SizedBox(height: 12),
                    buildDropdownField(
                        'Legitimacy', ['Pending', 'Scam', 'Legit'], _scam,
                        (val) {
                      setState(() {
                        _scam = val ?? 'Pending';
                      });
                    }),
                    SizedBox(height: 12),
                    buildTextField( LocaleData.incidenttype.getString(context), _incidentTypeController),
                    SizedBox(height: 12),
                    buildTextField(
                       LocaleData.Incident.getString(context),
                      _incidentController,
                      minLines: 3,
                      maxLines: null,
                    ),
                    SizedBox(height: 12),
                    buildTextField(
                       LocaleData.IncidentDescription.getString(context),
                      _incidentDescController,
                      minLines: 3,
                      maxLines: null,
                    ),
                    SizedBox(height: 12),
                  ],
                ),
              ),
            ),

            SizedBox(height: 16),
            // Vehicle Section
            Card(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12.0),
              ),
              elevation: 3,
              child: Padding(
                padding: const EdgeInsets.all(12.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                       LocaleData.VehiclesInvolved.getString(context),
                      style:
                          TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                    ),
                    SizedBox(height: 12),

                    // List of vehicles
                    ListView.builder(
                      shrinkWrap: true,
                      physics: NeverScrollableScrollPhysics(),
                      itemCount: _vehicles.length,
                      itemBuilder: (context, index) {
                        Map<String, dynamic> vehicle = _vehicles[index];

                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8.0),
                          child: Card(
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8.0),
                            ),
                            elevation: 2,
                            child: Padding(
                              padding: const EdgeInsets.all(12.0),
                              child: Column(
                                children: [
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        'Vehicle ${index + 1}',
                                        style: TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.w600),
                                      ),
                                      IconButton(
                                        icon: Icon(Icons.delete,
                                            color: Colors.red),
                                        onPressed: () => _removeVehicle(index),
                                      ),
                                    ],
                                  ),
                                  SizedBox(height: 12),

                                  // Dropdown for vehicle type
                                  DropdownButtonFormField<String>(
                                    value: vehicle['vehicleType'],
                                    decoration: InputDecoration(
                                      labelText: 'Vehicle Type',
                                      border: OutlineInputBorder(),
                                    ),
                                    items: [
                                      'Single',
                                      'Tricycle',
                                      'E-bike',
                                      '4 Wheels',
                                      'Truck',
                                      'Other',
                                    ]
                                        .map((type) => DropdownMenuItem(
                                              value: type,
                                              child: Text(type),
                                            ))
                                        .toList(),
                                    onChanged: (val) {
                                      setState(() {
                                        vehicle['vehicleType'] = val ?? '';
                                      });
                                    },
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),

                    SizedBox(height: 8),

                    // Add Vehicle Button
                    ElevatedButton.icon(
                      onPressed: _addVehicle,
                      icon: Icon(Icons.add),
                      label: Text( LocaleData.AddVehicle.getString(context)),
                      style: ElevatedButton.styleFrom(
                        padding:
                            EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            SizedBox(height: 16),

// Victims Section
            Card(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12.0),
              ),
              elevation: 3,
              child: Padding(
                padding: const EdgeInsets.all(12.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                       LocaleData.Victims.getString(context),
                      style:
                          TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                    ),
                    SizedBox(height: 12),

                    // List of victims
                    ListView.builder(
                      shrinkWrap: true,
                      physics: NeverScrollableScrollPhysics(),
                      itemCount: _victims.length,
                      itemBuilder: (context, index) {
                        Map<String, dynamic> victim = _victims[index];

                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8.0),
                          child: Card(
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8.0),
                            ),
                            elevation: 2,
                            child: Padding(
                              padding: const EdgeInsets.all(12.0),
                              child: Column(
                                children: [
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        'Victim ${index + 1}',
                                        style: TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.w600),
                                      ),
                                      IconButton(
                                        icon: Icon(Icons.delete,
                                            color: Colors.red),
                                        onPressed: () => _removeVictim(index),
                                      ),
                                    ],
                                  ),
                                  SizedBox(height: 12),
                                  buildTextField(
                                     LocaleData.Name.getString(context),
                                    TextEditingController(text: victim['name']),
                                    onChanged: (val) => victim['name'] = val,
                                  ),
                                  SizedBox(height: 12),
                                  buildTextField(
                                     LocaleData.Age.getString(context),
                                    TextEditingController(text: victim['age']),
                                    onChanged: (val) => victim['age'] = val,
                                  ),
                                  SizedBox(height: 12),
                                  buildDropdownField(
                                     LocaleData.Sex.getString(context),
                                    ['Male', 'Female', 'Other'],
                                    victim['sex'],
                                    (val) =>
                                        setState(() => victim['sex'] = val),
                                  ),
                                  SizedBox(height: 12),
                                  buildTextField(
                                     LocaleData.Address.getString(context),
                                    TextEditingController(
                                        text: victim['address']),
                                    onChanged: (val) => victim['address'] = val,
                                  ),
                                  SizedBox(height: 12),
                                  buildTextField(
                                     LocaleData.Injury.getString(context),
                                    TextEditingController(
                                        text: victim['injury']),
                                    onChanged: (val) => victim['injury'] = val,
                                  ),
                                  SizedBox(height: 12),
                                  buildDropdownField(
                                     LocaleData.LifeStatus.getString(context), // New dropdown for condition
                                    ['Injured', 'Dead'],
                                    victim['lifeStatus'],
                                    (val) => setState(
                                        () => victim['lifeStatus'] = val),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),

                    SizedBox(height: 8),
                    ElevatedButton.icon(
                      onPressed: _addVictim,
                      icon: Icon(Icons.add),
                      label: Text( LocaleData.AddVictim.getString(context)),
                      style: ElevatedButton.styleFrom(
                        padding:
                            EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            SizedBox(height: 16),

            // Responder Section
            Card(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12.0),
              ),
              elevation: 3,
              child: Padding(
                padding: const EdgeInsets.all(12.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Responders',
                      style:
                          TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                    ),
                    SizedBox(height: 12),

                    // List of responders
                    ListView.builder(
                      shrinkWrap: true,
                      physics: NeverScrollableScrollPhysics(),
                      itemCount: _responders.length,
                      itemBuilder: (context, index) {
                        Map<String, dynamic> responder = _responders[index];

                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8.0),
                          child: Card(
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8.0),
                            ),
                            elevation: 2,
                            child: Padding(
                              padding: const EdgeInsets.all(12.0),
                              child: Column(
                                children: [
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        index == 0
                                            ? 'Main Responder'
                                            : 'Responder ${index + 1}',
                                        style: TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.w600),
                                      ),
                                      // Show delete button only if the index is greater than 0
                                      if (index > 0)
                                        IconButton(
                                          icon: Icon(Icons.delete,
                                              color: Colors.red),
                                          onPressed: () =>
                                              _removeResponder(index),
                                        ),
                                    ],
                                  ),
                                  SizedBox(height: 12),
                                  buildTextField(
                                    'Name',
                                    TextEditingController(
                                        text: responder['responderName']),
                                    onChanged: (val) =>
                                        responder['responderName'] = val,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),

                    SizedBox(height: 8),
                    ElevatedButton.icon(
                      onPressed: _addResponder,
                      icon: Icon(Icons.add),
                      label: Text('Add Responder'),
                      style: ElevatedButton.styleFrom(
                        padding:
                            EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            SizedBox(height: 16),

            // Save and Cancel Buttons
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                // Cancel Button
                ElevatedButton(
                  onPressed: () async {
                    // Show confirmation dialog
                    bool? confirmCancel = await showDialog(
                      context: context,
                      builder: (context) => AlertDialog(
                        title: Text('Cancel Changes'),
                        content: Text(
                            'Are you sure you want to discard your changes?'),
                        actions: [
                          TextButton(
                            onPressed: () =>
                                Navigator.pop(context, false), // Cancel dialog
                            child: Text(
                              'No',
                              style: TextStyle(color: Colors.grey),
                            ),
                          ),
                          TextButton(
                            onPressed: () =>
                                Navigator.pop(context, true), // Confirm cancel
                            child: Text(
                              'Yes',
                              style: TextStyle(color: Colors.red),
                            ),
                          ),
                        ],
                      ),
                    );

                    if (confirmCancel == true) {
                      Navigator.pop(
                          context); // Close the bottom sheet if confirmed
                    }
                  },
                  child: Text(
                    'Cancel',
                    style: TextStyle(
                        color: Colors.white), // Set text color to white
                  ),
                  style: ElevatedButton.styleFrom(
                    padding: EdgeInsets.symmetric(vertical: 12, horizontal: 24),
                    textStyle: TextStyle(fontSize: 16),
                    backgroundColor:
                        Colors.red, // Set a distinct color for Cancel button
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),

                SizedBox(width: 16), // Spacing between buttons

                // Save Button
                _isSaving
                    ? CircularProgressIndicator()
                    : ElevatedButton(
                        onPressed: _saveLogBookToFirestore,
                        child: Text('Save'),
                        style: ElevatedButton.styleFrom(
                          padding: EdgeInsets.symmetric(
                              vertical: 12, horizontal: 24),
                          textStyle: TextStyle(fontSize: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                      ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget buildTextField(String label, TextEditingController controller,
      {Function(String)? onChanged,
      bool readOnly = false,
      int minLines = 1,
      int? maxLines}) {
    return TextField(
      controller: controller,
      onChanged: onChanged,
      readOnly: readOnly, // Makes the field uneditable if true
      minLines: minLines, // Sets the minimum height of the TextField
      maxLines: maxLines, // Expands the TextField as needed
      decoration: InputDecoration(
        labelText: label,
        border: OutlineInputBorder(),
        floatingLabelBehavior:
            FloatingLabelBehavior.always, // Move label to top
      ),
    );
  }

  Widget buildAddressTextField(String label, TextEditingController controller,
      {Function(String)? onChanged, bool readOnly = false}) {
    return TextField(
      controller: _addressController,
      readOnly: true, // Disable typing
      decoration: InputDecoration(
        hintText: 'Click the icon to find location',
        labelText:  LocaleData.yourcurrentaddress.getString(context),
        border: OutlineInputBorder(),
        filled: true,
        floatingLabelBehavior:
            FloatingLabelBehavior.always, // Move label to top
        suffixIcon: _isLoading
            ? CircularProgressIndicator()
            : IconButton(
                icon: Icon(Icons.my_location),
                onPressed: _getCurrentLocation, // Automatically fill location
              ),
      ),
    );
  }

  Future<void> _getCurrentLocation() async {
    setState(() {
      _isLoading = true;
    });

    try {
      Position position = await _locationService.getCurrentLocation();
      String address = await _locationService.getAddressFromLocation(position);
      setState(() {
        _addressController.text = address;
        _latitude = position.latitude; // Store latitude
        _longitude = position.longitude; // Store longitude
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Success: Access to location been granted'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content:
              Text('Failed to get current location: enable it in app setting.'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  void dispose() {
    _landmarkController.dispose();
    _transportedToController.dispose();
    _incidentTypeController.dispose();
    _incidentController.dispose();
    _incidentDescController.dispose();
    WidgetsBinding.instance.removeObserver(this); // Remove the observer
    super.dispose();
  }
}
