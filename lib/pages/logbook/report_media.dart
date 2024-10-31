import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

Future<bool> _showConfirmationDialog(
    BuildContext context, String title, String content) async {
  return await showDialog<bool>(
        context: context,
        builder: (BuildContext context) {
          return AlertDialog(
            title: Text(title),
            content: Text(content),
            actions: [
              TextButton(
                child: const Text("Cancel"),
                onPressed: () => Navigator.of(context).pop(false),
              ),
              TextButton(
                child: const Text("Confirm"),
                onPressed: () => Navigator.of(context).pop(true),
              ),
            ],
          );
        },
      ) ??
      false;
}

Widget _buildMediaWidget(String? mediaUrl) {
  if (mediaUrl == null) {
    return const Text('No media available');
  }

  if (!_isImage(mediaUrl)) {
    return Center(
      child: ElevatedButton.icon(
        onPressed: () async {
          final uri = Uri.parse(mediaUrl);
          if (await canLaunchUrl(uri)) {
            await launchUrl(uri, mode: LaunchMode.externalApplication);
          } else {
            print('Could not launch $mediaUrl');
          }
        },
        icon: const Icon(Icons.open_in_new, color: Colors.white),
        label: const Text(
          'Open Media',
          style: TextStyle(color: Colors.white),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.orange,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(30),
          ),
        ),
      ),
    );
  } else {
    return ClipRRect(
      borderRadius: BorderRadius.circular(8.0),
      child: Image.network(
        mediaUrl,
        height: 150,
        width: double.infinity,
        fit: BoxFit.cover,
        loadingBuilder: (context, child, loadingProgress) {
          if (loadingProgress == null) return child;
          return const Center(child: CircularProgressIndicator());
        },
        errorBuilder: (context, error, stackTrace) {
          return const Text('Error loading image');
        },
      ),
    );
  }
}

// Helper function to check if the URL is an image
bool _isImage(String url) {
  return url.endsWith('.jpg') ||
      url.endsWith('.jpeg') ||
      url.endsWith('.png') ||
      url.endsWith('.gif');
}

bool _isVideo(String url) {
  final videoExtensions = ['.mp4', '.mov', '.webm', '.avi', '.mkv', '.flv'];
  return videoExtensions
      .any((extension) => url.toLowerCase().endsWith(extension));
}
