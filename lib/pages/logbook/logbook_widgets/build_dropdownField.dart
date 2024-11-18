
  import 'package:flutter/material.dart';
Widget buildDropdownField(
  String label,
  List<String> items,
  String? value,
  ValueChanged<String?> onChanged,
) {
  // Ensure there are no duplicates in the list
  final uniqueItems = items.toSet().toList();

  // Provide a default value if the current value is not in the items list
  final dropdownValue = value != null && uniqueItems.contains(value)
      ? value
      : (uniqueItems.isNotEmpty ? uniqueItems.first : null);

  return DropdownButtonFormField<String>(
    value: dropdownValue,
    decoration: InputDecoration(
      labelText: label,
      border: const OutlineInputBorder(),
    ),
    items: uniqueItems.map((item) {
      return DropdownMenuItem<String>(
        value: item,
        child: Text(item),
      );
    }).toList(),
    onChanged: onChanged,
  );
}
