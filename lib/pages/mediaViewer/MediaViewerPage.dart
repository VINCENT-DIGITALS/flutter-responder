import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';

class MediaViewerPage extends StatefulWidget {
  final String mediaUrl;

  const MediaViewerPage({Key? key, required this.mediaUrl}) : super(key: key);

  @override
  _MediaViewerPageState createState() => _MediaViewerPageState();
}

class _MediaViewerPageState extends State<MediaViewerPage> {
  late VideoPlayerController _videoController;
  bool isVideo = false;
  bool isLoading = true;
  bool hasError = false;

  @override
  void initState() {
    super.initState();
    _determineMediaType();
  }

  Future<void> _determineMediaType() async {
    try {
      // Send an HTTP HEAD request to get the Content-Type
      final response = await http.head(Uri.parse(widget.mediaUrl));
      final contentType = response.headers['content-type'];

      if (contentType != null) {
        if (contentType.startsWith('video/')) {
          isVideo = true;
          _initializeVideoPlayer();
        } else if (contentType.startsWith('image/')) {
          isVideo = false;
        } else {
          throw Exception('Unsupported media type');
        }
      } else {
        throw Exception('Unable to determine media type');
      }
    } catch (error) {
      print('Error determining media type: $error');
      setState(() {
        hasError = true;
      });
    } finally {
      setState(() {
        isLoading = false;
      });
    }
  }

  void _initializeVideoPlayer() {
    _videoController = VideoPlayerController.networkUrl(Uri.parse(widget.mediaUrl))
      ..initialize().then((_) {
        setState(() {}); // Refresh the UI after initialization
        _videoController.play(); // Optionally auto-play the video
      }).catchError((error) {
        print('Error initializing video: $error');
        setState(() {
          hasError = true;
        });
      });
  }

  Future<void> _launchURL() async {
    if (await canLaunch(widget.mediaUrl)) {
      await launch(widget.mediaUrl);
    } else {
      throw 'Could not launch ${widget.mediaUrl}';
    }
  }

  @override
  void dispose() {
    if (isVideo) {
      _videoController.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Media Viewer'),
      ),
      body: Center(
        child: isLoading
            ? Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const CircularProgressIndicator(),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: _launchURL,
                    child: const Text('Open in Browser'),
                  ),
                ],
              )
            : hasError
                ? Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text('Failed to load media'),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: _launchURL,
                        child: const Text('Open in Browser'),
                      ),
                    ],
                  )
                : isVideo
                    ? _videoController.value.isInitialized
                        ? InteractiveViewer(
                            panEnabled: true,
                            scaleEnabled: true,
                            minScale: 0.5, // Allow zooming out
                            maxScale: 10.0, // Allow significant zooming in
                            child: Container(
                              width: double.infinity,
                              height: MediaQuery.of(context).size.height * 0.75,
                              child: AspectRatio(
                                aspectRatio: _videoController.value.aspectRatio,
                                child: VideoPlayer(_videoController),
                              ),
                            ),
                          )
                        : const CircularProgressIndicator()
                    : InteractiveViewer(
                        panEnabled: true,
                        scaleEnabled: true,
                        minScale: 0.5, // Allow zooming out
                        maxScale: 10.0, // Allow significant zooming in
                        child: Container(
                          width: double.infinity,
                          height: MediaQuery.of(context).size.height * 0.75,
                          child: Image.network(
                            widget.mediaUrl,
                            loadingBuilder: (context, child, loadingProgress) {
                              if (loadingProgress == null) return child;
                              return const CircularProgressIndicator();
                            },
                            errorBuilder: (context, error, stackTrace) {
                              return Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Text('Failed to load image'),
                                  const SizedBox(height: 16),
                                  ElevatedButton(
                                    onPressed: _launchURL,
                                    child: const Text('Open in Browser'),
                                  ),
                                ],
                              );
                            },
                          ),
                        ),
                      ),
      ),
    );
  }
}
