import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

import '../models/logbook_model.dart';

class Preferences {
  Future<void> saveDetailsList(List<Details> detailsList) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    List<String> detailsJsonList = detailsList.map((details) => jsonEncode(details.toJson())).toList();
    await prefs.setStringList('details_list', detailsJsonList);
  }

  Future<List<Details>?> getDetailsList() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    List<String>? detailsJsonList = prefs.getStringList('details_list');
    if (detailsJsonList != null) {
      return detailsJsonList.map((detailsJson) => Details.fromJson(jsonDecode(detailsJson))).toList();
    }
    return null;
  }

  Future<void> saveDateTime(String dateTime) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setString('saved_datetime', dateTime);
  }

  Future<String?> getSavedDateTime() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    return prefs.getString('saved_datetime');
  }

  Future<void> saveIncidentNature(String incidentNature) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setString('saved_incident_nature', incidentNature);
  }

  Future<String?> getIncidentNature() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    return prefs.getString('saved_incident_nature');
  }

  Future<void> saveIncidentPlace(String incidentPlace) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setString('saved_incident_place', incidentPlace);
  }

  Future<String?> getIncidentPlace() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    return prefs.getString('saved_incident_place');
  }

  Future<void> saveResponders(List<String> responders) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('saved_responders', responders);
  }

  Future<List<String>?> getResponders() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    return prefs.getStringList('saved_responders');
  }
}