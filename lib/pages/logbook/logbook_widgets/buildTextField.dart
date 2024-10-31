  import 'package:flutter/material.dart';

Widget buildTextField(String label, TextEditingController controller,
      {Function(String)? onChanged, bool readOnly = false}) {
    return TextField(
      controller: controller,
      onChanged: onChanged,
      readOnly: readOnly, // Makes the field uneditable if true
      decoration: InputDecoration(
        labelText: label,
        border: OutlineInputBorder(),
      ),
    );
  }