import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

class LocalStorage {
  static Future<List<Map<String, dynamic>>> loadUnsavedLogbooks() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    List<String> storedLogbooks = prefs.getStringList('logbooks') ?? [];
    return storedLogbooks
        .map((logbook) => jsonDecode(logbook) as Map<String, dynamic>)
        .toList();
  }

  static Future<void> deleteLogbook(int index) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    List<String> storedLogbooks = prefs.getStringList('logbooks') ?? [];
    if (index >= 0 && index < storedLogbooks.length) {
      storedLogbooks.removeAt(index);
      await prefs.setStringList('logbooks', storedLogbooks);
    }
  }

  // New method to remove a logbook by its logbookId
  static Future<void> removeLogbook(String logbookId) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    List<String> storedLogbooks = prefs.getStringList('logbooks') ?? [];

    // Find the logbook with the specified logbookId
    storedLogbooks.removeWhere((logbook) {
      Map<String, dynamic> logbookMap = jsonDecode(logbook);
      return logbookMap['logbookId'] == logbookId;
    });

    // Update the stored logbooks
    await prefs.setStringList('logbooks', storedLogbooks);
  }
}
