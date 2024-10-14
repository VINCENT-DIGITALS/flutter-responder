import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

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

class _FloatingLogBookEditWidgetState extends State<FloatingLogBookEditWidget> {
  final TextEditingController _landmarkController = TextEditingController();
  final TextEditingController _transportedToController =
      TextEditingController();
  final TextEditingController _incidentTypeController = TextEditingController();
  final TextEditingController _incidentController = TextEditingController();
  final TextEditingController _incidentDescController = TextEditingController();
  final TextEditingController _addressController = TextEditingController();

  List<Map<String, dynamic>> _victims = [];
  String? _status; // Add this variable to store the status
  bool _isSaving = false;
  Timestamp? _timestamp; // To store the Firestore timestamp
  Timestamp? _updatedAt; // To store the updatedAt timestamp

  @override
  void initState() {
    super.initState();

    // Safely check if the 'status' field exists or set default value
    final logbookData = widget.logbook.data() as Map<String, dynamic>?;

    // Initialize all fields safely
    _landmarkController.text = logbookData?['landmark'] ?? '';
    _transportedToController.text = logbookData?['transportedTo'] ?? '';
    _incidentTypeController.text = logbookData?['incidentType'] ?? '';
    _incidentController.text = logbookData?['incident'] ?? '';
    _incidentDescController.text = logbookData?['incidentDesc'] ?? '';
    _addressController.text =
        logbookData != null && logbookData.containsKey('address')
            ? logbookData['address']
            : ''; // Handle missing 'address' field
    _status = logbookData != null && logbookData.containsKey('status')
        ? widget.logbook['status']
        : 'In Progress';
    // Store the timestamps
    _timestamp = logbookData?['timestamp'];
    _updatedAt = logbookData?['updatedAt'];
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
      'reportId': widget.logbook['reportId'],
      'status': _status, // Add the status field here
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
      // Update the logbook in Firestore
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
        'status': _status, // Add the status field here
        'address': _addressController.text, // Add address field here
        'updatedAt': FieldValue.serverTimestamp(), // New field to track updates
      });

      // Check if 'reportId' exists in the logbook document
      if (widget.logbook['reportId'] != null) {
        String reportId = widget.logbook['reportId'];

        // Update the status of the corresponding report
        await FirebaseFirestore.instance
            .collection('reports')
            .doc(reportId)
            .update({
          'status': _status, // Update the status of the report
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }

      // // Delete the logbook from shared preferences upon successful update
      // SharedPreferences prefs = await SharedPreferences.getInstance();
      // List<String> storedLogbooks = prefs.getStringList('logbooks') ?? [];
      // storedLogbooks.removeWhere(
      //     (logbook) => jsonDecode(logbook)['logbookId'] == widget.logbook.id);
      // await prefs.setStringList('logbooks', storedLogbooks);

      widget.onSave(); // Callback to notify parent widget
    } catch (e) {
      await _saveLogBookLocally();
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Failed to save. Will retry later.'),
        backgroundColor: Colors.red,
      ));
    } finally {
      setState(() {
        _isSaving = false;
      });
    }
  }

  void _addVictim() {
    setState(() {
      _victims.add({
        'name': '',
        'age': '',
        'sex': 'Other', // Default to 'Male' or any valid option
        'address': '',
        'injury': '',
      });
    });
  }

  void _removeVictim(int index) {
    setState(() {
      _victims.removeAt(index);
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
                      'Created At: ${_timestamp != null ? _timestamp!.toDate().toString() : 'Unknown'}',
                      style: TextStyle(
                          color: const Color.fromARGB(255, 0, 0, 0),
                          fontWeight: FontWeight.bold),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Last Updated At: ${_updatedAt != null ? _updatedAt!.toDate().toString() : 'Unknown'}',
                      style: TextStyle(
                          color: const Color.fromARGB(255, 0, 0, 0),
                          fontWeight: FontWeight.bold),
                    ),
                    SizedBox(height: 12),
                    _buildTextField('Address', _addressController),
                    SizedBox(height: 12),
                    _buildTextField('Landmark', _landmarkController),
                    SizedBox(height: 12),
                    _buildTextField('Incident Type', _incidentTypeController),
                    SizedBox(height: 12),
                    _buildTextField('Incident', _incidentController),
                    SizedBox(height: 12),
                    _buildTextField(
                        'Incident Description', _incidentDescController),
                    SizedBox(height: 12),
                    _buildTextField('Transported To', _transportedToController),
                    SizedBox(height: 12),
                    // Status Dropdown
                    _buildDropdownField(
                        'Status', ['In Progress', 'Completed'], _status, (val) {
                      setState(() {
                        _status = val ?? 'In Progress';
                      });
                    }),
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
                                  _buildTextField(
                                    'Name',
                                    TextEditingController(text: victim['name']),
                                    onChanged: (val) => victim['name'] = val,
                                  ),
                                  SizedBox(height: 12),
                                  _buildTextField(
                                    'Age',
                                    TextEditingController(text: victim['age']),
                                    onChanged: (val) => victim['age'] = val,
                                  ),
                                  SizedBox(height: 12),
                                  _buildDropdownField(
                                    'Sex',
                                    ['Male', 'Female', 'Other'],
                                    victim['sex'],
                                    (val) =>
                                        setState(() => victim['sex'] = val),
                                  ),
                                  SizedBox(height: 12),
                                  _buildTextField(
                                    'Address',
                                    TextEditingController(
                                        text: victim['address']),
                                    onChanged: (val) => victim['address'] = val,
                                  ),
                                  SizedBox(height: 12),
                                  _buildTextField(
                                    'Injury',
                                    TextEditingController(
                                        text: victim['injury']),
                                    onChanged: (val) => victim['injury'] = val,
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

            // Save Button
            _isSaving
                ? CircularProgressIndicator()
                : ElevatedButton(
                    onPressed: _saveLogBookToFirestore,
                    child: Text('Save'),
                    style: ElevatedButton.styleFrom(
                      padding:
                          EdgeInsets.symmetric(vertical: 12, horizontal: 24),
                      textStyle: TextStyle(fontSize: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
          ],
        ),
      ),
    );
  }

  Widget _buildTextField(String label, TextEditingController controller,
      {Function(String)? onChanged}) {
    return TextField(
      controller: controller,
      onChanged: onChanged,
      decoration: InputDecoration(
        labelText: label,
        border: OutlineInputBorder(),
      ),
    );
  }

  Widget _buildDropdownField(String label, List<String> items, String? value,
      ValueChanged<String?> onChanged) {
    return DropdownButtonFormField<String>(
      value: value ??
          items.first, // Set the first item as default if value is null
      decoration: InputDecoration(
        labelText: label,
        border: OutlineInputBorder(),
      ),
      items: items.map((item) {
        return DropdownMenuItem<String>(
          value: item,
          child: Text(item),
        );
      }).toList(),
      onChanged: onChanged,
    );
  }

  @override
  void dispose() {
    _landmarkController.dispose();
    _transportedToController.dispose();
    _incidentTypeController.dispose();
    _incidentController.dispose();
    _incidentDescController.dispose();
    super.dispose();
  }
}
