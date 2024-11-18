import 'dart:async';

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../logbook/logbook_widgets/buildTextField.dart';
import '../../services/database.dart';
import 'logbook_widgets/build_dropdownField.dart';

class FloatingLogBookEditWidget extends StatefulWidget {
  final DocumentSnapshot logbook;
  final VoidCallback onSave;

  const FloatingLogBookEditWidget(
      {Key? key, required this.logbook, required this.onSave})
      : super(key: key);

  @override
  _FloatingLogBookEditWidgetState createState() =>
      _FloatingLogBookEditWidgetState();
}

class _FloatingLogBookEditWidgetState extends State<FloatingLogBookEditWidget>
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

  bool _isSaving = false;
  Timestamp? _timestamp; // To store the Firestore timestamp
  Timestamp? _updatedAt; // To store the updatedAt timestamp
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
    // Safely check if the 'status' field exists or set default value
    final logbookData = widget.logbook.data() as Map<String, dynamic>?;

    // Initialize all fields safely
    _landmarkController.text = logbookData?['landmark'] ?? '';
    _transportedToController.text = logbookData?['transportedTo'] ?? '';
    _incidentTypeController.text = logbookData?['incidentType'] ?? '';
    _incidentController.text = logbookData?['incident'] ?? '';
    _incidentDescController.text = logbookData?['incidentDesc'] ?? '';
    _injuredCountController.text = logbookData?['injuredCount'] ?? '';
    reporterNameController.text = logbookData?['reporterName'] ?? '';
    _addressController.text =
        logbookData != null && logbookData.containsKey('address')
            ? logbookData['address']
            : ''; // Handle missing 'address' field
    _status = logbookData != null && logbookData.containsKey('status')
        ? widget.logbook['status']
        : 'In Progress';

    _seriousness = logbookData != null && logbookData.containsKey('seriousness')
        ? widget.logbook['seriousness']
        : 'Minor';

    _scam = logbookData != null && logbookData.containsKey('scam')
        ? widget.logbook['scam']
        : 'Pending';

    // Store the timestamps
    _timestamp = logbookData?['timestamp'];
    _updatedAt = logbookData?['updatedAt'];

    // Load vehicles if the field exists
    if (logbookData != null && logbookData.containsKey('vehicles')) {
      _vehicles = List<Map<String, dynamic>>.from(logbookData['vehicles']);

      for (var vehicle in _vehicles) {
        vehicle['vehicleType'] ??= ''; // Default value if missing
      }
    } else {
      _vehicles = [];
    }

// Ensure default values for each vehicle
    for (var vehicle in _vehicles) {
      vehicle['vehicleType'] ??=
          ''; // Set default value if vehicleType is missing
    }

    // Load victims if available
    if (widget.logbook['victims'] != null) {
      _victims = List<Map<String, dynamic>>.from(widget.logbook['victims']);

      // Ensure default values for each victim
      for (var victim in _victims) {
        victim['name'] ??= '';
        victim['age'] ??= '';
        victim['sex'] ??= 'Male'; // Set default if null
        victim['address'] ??= '';
        victim['injury'] ??= '';
      }
    }
    // Load responders if available
    if (widget.logbook['responders'] != null) {
      _responders =
          List<Map<String, dynamic>>.from(widget.logbook['responders']);

      // Ensure default values for each responder
      for (var responder in _responders) {
        responder['responderName'] ??= '';
      }
    }
  }

  Future<void> _saveLogBookLocally() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String logbookId = widget.logbook.id;

    Map<String, dynamic> logbookData = {
      'logbookId': logbookId,
      'landmark': _landmarkController.text,
      'transportedTo': _transportedToController.text,
      'incidentType': _incidentTypeController.text,
      'incident': _incidentController.text,
      'incidentDesc': _incidentDescController.text,
      'victims': _victims,
      'injuredCount': _injuredCountController.text,
      'vehicles': _vehicles,
      'seriousness': _seriousness,
      'responders': _responders,
      'reportId': widget.logbook['reportId'],
      'status': _status, // Add the status field here
      'scam': _scam,
      'address': _addressController.text, // Add address field here
      'createdLocallyAt':
          DateTime.now().toIso8601String(), // Use DateTime for local storage()
    };

    // Retrieve the list of stored logbooks from shared preferences
    List<String> storedLogbooks = prefs.getStringList('logbooks') ?? [];
    bool logbookExists = false;

    // Search for an existing logbook with the same logbookId
    for (int i = 0; i < storedLogbooks.length; i++) {
      Map<String, dynamic> existingLogbook = jsonDecode(storedLogbooks[i]);
      if (existingLogbook['logbookId'] == logbookId) {
        // If logbook with the same logbookId exists, update it
        storedLogbooks[i] = jsonEncode(logbookData);
        logbookExists = true;
        break;
      }
    }

    if (!logbookExists) {
      // If no logbook with the same logbookId is found, add the new logbook
      storedLogbooks.add(jsonEncode(logbookData));
    }

    // Save the updated list of logbooks back to shared preferences
    await prefs.setStringList('logbooks', storedLogbooks);
  }

  Future<void> _saveLogBookToFirestore() async {
    setState(() {
      _isSaving = true;
    });

    try {
      // Attempt to update the logbook in Firestore with a timeout
      await FirebaseFirestore.instance
          .collection('logBook')
          .doc(widget.logbook.id)
          .update({
        'landmark': _landmarkController.text,
        'transportedTo': _transportedToController.text,
        'incidentType': _incidentTypeController.text,
        'incident': _incidentController.text,
        'incidentDesc': _incidentDescController.text, // New field
        'victims': _victims,
        'injuredCount': _injuredCountController.text,
        'vehicles': _vehicles,
        'seriousness': _seriousness,
        'responders': _responders,
        'status': _status, // Add the status field here
        'scam': _scam,
        'address': _addressController.text, // Add address field here

        'updatedAt': FieldValue.serverTimestamp(), // New field to track updates
      }).timeout(const Duration(seconds: 5)); // Timeout after 5 seconds

      // Check if 'reportId' exists in the logbook document and is not an empty string
      if (widget.logbook['reportId'] != null &&
          widget.logbook['reportId'].toString().trim().isNotEmpty) {
        String reportId = widget.logbook['reportId'];

        // Update the status of the corresponding report with a timeout
        await FirebaseFirestore.instance
            .collection('reports')
            .doc(reportId)
            .update({
          'status': _status, // Update the status of the report
          'updatedAt': FieldValue.serverTimestamp(),
        }).timeout(const Duration(seconds: 10)); // Timeout after 10 seconds
      } else {
        print('No valid reportId found, skipping update.');
      }

      widget.onSave(); // Callback to notify parent widget

      // Firestore save successful, delete the locally saved logbook
      // Delete the logbook from shared preferences upon successful update

      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Logbook saved successfully.'),
        backgroundColor: Colors.green,
      ));
    } on TimeoutException catch (e) {
      // Save locally first to ensure data persistence
      await _saveLogBookLocally();
      // If a timeout occurs, notify the user and keep the local save
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(
            'Network timeout. Data saved locally; Upload it again later. '),
        backgroundColor: Colors.green,
      ));
      widget.onSave(); // Callback to notify parent widget
    } catch (e) {
      // Save locally first to ensure data persistence
      await _saveLogBookLocally();
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
              'Edit LogBook',
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
                      'Incident Information',
                      style:
                          TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                    ),
                    SizedBox(height: 8),

                    // Display Created At and Updated At timestamps
                    Text(
                      'Created At: ${_formatTimestamp(_timestamp)}',
                      style: TextStyle(
                          color: const Color.fromARGB(255, 0, 0, 0),
                          fontWeight: FontWeight.bold),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Last Updated At: ${_formatTimestamp(_updatedAt)}',
                      style: TextStyle(
                          color: const Color.fromARGB(255, 0, 0, 0),
                          fontWeight: FontWeight.bold),
                    ),
                    SizedBox(height: 12),
                    buildTextField('Reporter Name', reporterNameController,
                        readOnly: true),
                    SizedBox(height: 12),
                    buildTextField('Address', _addressController,
                        readOnly: true),
                    SizedBox(height: 12),
                    buildTextField('Landmark', _landmarkController),
                    SizedBox(height: 12),
                    buildTextField('# of Injured', _injuredCountController),
                    SizedBox(height: 12),
                    buildTextField('Transported To', _transportedToController),
                    SizedBox(height: 12),
                    // Status Dropdown
                    buildDropdownField(
                        'Status', ['In Progress', 'Completed'], _status, (val) {
                      setState(() {
                        _status = val ?? 'In Progress';
                      });
                    }),
                    SizedBox(height: 12),
                    // Status Dropdown
                    buildDropdownField('Severity',
                        ['Minor', 'Moderate', 'Severe'], _seriousness, (val) {
                      setState(() {
                        _seriousness = val ?? 'Minor';
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
                    buildTextField('Incident Type', _incidentTypeController),
                    SizedBox(height: 12),
                    buildTextField(
                      'Incident',
                      _incidentController,
                      minLines: 3,
                      maxLines: null,
                    ),
                    SizedBox(height: 12),
                    buildTextField(
                      'Incident Description',
                      _incidentDescController,
                      minLines: 3,
                      maxLines: null,
                    ),
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
                      'Vehicles Involved',
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
                      label: Text('Add Vehicle'),
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
                      'Victims',
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
                                    'Name',
                                    TextEditingController(text: victim['name']),
                                    onChanged: (val) => victim['name'] = val,
                                  ),
                                  SizedBox(height: 12),
                                  buildTextField(
                                    'Age',
                                    TextEditingController(text: victim['age']),
                                    onChanged: (val) => victim['age'] = val,
                                  ),
                                  SizedBox(height: 12),
                                  buildDropdownField(
                                    'Sex',
                                    ['Male', 'Female', 'Other'],
                                    victim['sex'],
                                    (val) =>
                                        setState(() => victim['sex'] = val),
                                  ),
                                  SizedBox(height: 12),
                                  buildTextField(
                                    'Address',
                                    TextEditingController(
                                        text: victim['address']),
                                    onChanged: (val) => victim['address'] = val,
                                  ),
                                  SizedBox(height: 12),
                                  buildTextField(
                                    'Injury',
                                    TextEditingController(
                                        text: victim['injury']),
                                    onChanged: (val) => victim['injury'] = val,
                                  ),
                                  SizedBox(height: 12),
                                  buildDropdownField(
                                    'lifeStatus', // New dropdown for condition
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
                      label: Text('Add Victim'),
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
