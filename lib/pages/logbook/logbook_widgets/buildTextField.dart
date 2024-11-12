  import 'package:flutter/material.dart';

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