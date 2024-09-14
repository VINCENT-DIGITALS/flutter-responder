
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:smooth_page_indicator/smooth_page_indicator.dart';
import 'dart:async';

import '../components/bottom_bar.dart';
import '../components/custom_drawer.dart';
import '../services/database.dart';
import '../services/location_service.dart';
import 'announcement_detail_page.dart';
import 'hotlineDirectories_page.dart';
import 'login_page.dart';
import 'post_detail_page.dart';


class HomePage extends StatefulWidget {
  final String currentPage;

  const HomePage({Key? key, this.currentPage = 'home'}) : super(key: key);

  @override
  _HomePageState createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  SharedPreferences? _prefs;
  final DatabaseService _dbService = DatabaseService();
  Map<String, String> _userData = {};
  bool _isLoading = true;

  final ScrollController _scrollController = ScrollController();
  final PageController _postsPageController = PageController();
  final PageController _announcementsPageController = PageController();
  Map<String, dynamic>? _weatherData;
  Position? _currentLocation;
  String _currentAddress = "";
  String _errorMessage = "";
  final LocationService _locationService = LocationService();

  @override
  void initState() {
    super.initState();
    _initializePreferences();
    _fetchLocation();
    _fetchWeatherData();
  }

  Future<void> _fetchWeatherData() async {
    final data = await _dbService.fetchWeatherData();
    setState(() {
      _weatherData = data;
    });
  }

  Future<void> _fetchLocation() async {
    try {
      _currentLocation = await _locationService.getCurrentLocation();
      _currentAddress =
          await _locationService.getAddressFromLocation(_currentLocation!);
      _errorMessage = "";

      double? latitude = _currentLocation?.latitude;
      double? longitude = _currentLocation?.longitude;
      print("Latitude: $latitude, Longitude: $longitude");
      bool isLocationServiceEnabled = await _locationService.isLocationEnabled();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Success: Access to location been granted'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      _errorMessage = e.toString();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
              'Failed to get current location: Access to location been denied'),
          backgroundColor: Colors.red,
        ),
      );
    }
    setState(() {});
    print("$_currentLocation");
    print("$_currentAddress");
  }

  void _initializePreferences() async {
    _prefs = await SharedPreferences.getInstance();
    await _fetchAndDisplayUserData();
    setState(() {
      _isLoading = false;
    });
  }

  Future<void> _fetchAndDisplayUserData() async {
    try {
      _userData = {
        'uid': _prefs?.getString('uid') ?? '',
        'email': _prefs?.getString('email') ?? '',
        'displayName': _prefs?.getString('displayName') ?? '',
        'photoURL': _prefs?.getString('photoURL') ?? '',
        'phoneNum': _prefs?.getString('phoneNum') ?? '',
        'createdAt': _prefs?.getString('createdAt') ?? '',
        'address': _prefs?.getString('address') ?? '',
        'status': _prefs?.getString('status') ?? '',
      };
    } catch (e) {
      print('Error fetching user data: $e');
    }
  }

  void startCountdown() {
    int countdown = 10; // 10-second countdown
    Timer.periodic(Duration(seconds: 1), (Timer timer) {
      if (countdown == 0) {
        timer.cancel();
        // Call your function here after countdown ends
        handleSOS();
      } else {
        countdown--;
        print("Countdown: $countdown"); // You can update UI with countdown
      }
    });
  }

  void handleSOS() {
    // TODO: Add the SOS feature implementation here
    print("SOS feature triggered");
  }

  void _redirectToLogin(BuildContext context) {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => const LoginPage()),
    );
  }

  @override
  Widget build(BuildContext context) {
    String formattedDateTime = DateFormat('MMMM d, h:mm a', 'en_PH').format(
        DateTime.now()
            .toUtc()
            .add(Duration(hours: 8))); // UTC+8 for Philippines
    String locationName = _weatherData?['name'] ?? 'Science City of Muñoz, PH';
    double temperature = _weatherData?['temperature'] ?? 0.0;
    int humidity = _weatherData?['humidity'] ?? 0;
    double windSpeed = _weatherData?['windSpeed'] ?? 0.0;
    double feelsLike = _weatherData?['feelsLike'] ?? 0.0;
    String weatherDescription = _weatherData != null &&
            _weatherData!['weather'] != null &&
            (_weatherData!['weather'] as List).isNotEmpty
        ? _weatherData!['weather'][0]['description'] ??
            'Clear sky, Light breeze'
        : 'Clear sky, Light breeze';
    String weatherIcon = _weatherData != null &&
            _weatherData!['weather'] != null &&
            (_weatherData!['weather'] as List).isNotEmpty
        ? _weatherData!['weather'][0]['icon'] ?? '01d'
        : '01d';
    return SafeArea(
      child: Scaffold(
        key: _scaffoldKey,
        appBar: AppBar(
          title: Text('Home Page'),
          shadowColor: Colors.black,
          elevation: 2.0,
        ),
        drawer: CustomDrawer(scaffoldKey: _scaffoldKey),
        body: _isLoading
            ? Center(child: CircularProgressIndicator())
            : Scrollbar(
                controller: _scrollController,
                thickness: 5,
                thumbVisibility: true,
                radius: Radius.circular(5),
                child: ListView(
                  controller: _scrollController,
                  padding: const EdgeInsets.all(16.0),
                  children: [
                    _buildWeatherWidget(
                      formattedDateTime,
                      locationName,
                      temperature,
                      humidity,
                      windSpeed,
                      feelsLike,
                      weatherDescription,
                      weatherIcon,
                    ),
                   
                    SizedBox(height: 20),
                    _buildAnnouncements(),
                    SizedBox(height: 20),
                    _buildPosts(),
                  ],
                ),
              ),
        bottomNavigationBar: BottomNavBar(currentPage: widget.currentPage),
      ),
    );
  }

  Widget _buildWeatherWidget(
      String formattedDateTime,
      String locationName,
      double temperature,
      int humidity,
      double windSpeed,
      double feelsLike,
      String weatherDescription,
      String weatherIcon) {
    String dayOfWeek = DateFormat('EEEE', 'en_PH').format(DateTime.now()
        .toUtc()
        .add(Duration(hours: 8))); // UTC+8 for PhilippinesF
    return Container(
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.blue[200]!, Colors.blue[400]!],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16.0),
        boxShadow: [
          BoxShadow(
            color: Colors.blue.withOpacity(0.5),
            spreadRadius: 2,
            blurRadius: 5,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(formattedDateTime,
              style: TextStyle(fontSize: 12, color: Colors.white)),
          Text('$locationName',
              style: TextStyle(fontSize: 12, color: Colors.white)),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text("${temperature.toStringAsFixed(1)}°C",
                      style: TextStyle(fontSize: 24, color: Colors.white)),
                  Text("$humidity%",
                      style: TextStyle(fontSize: 12, color: Colors.white)),
                  Text("${windSpeed.toStringAsFixed(2)}km/h",
                      style: TextStyle(fontSize: 12, color: Colors.white)),
                  Text("${feelsLike.toStringAsFixed(1)}°C",
                      style: TextStyle(fontSize: 12, color: Colors.white)),
                  Text(weatherDescription,
                      style: TextStyle(fontSize: 12, color: Colors.white)),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text('Weather',
                      style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: Colors.white)),
                  Text(dayOfWeek,
                      style: TextStyle(fontSize: 12, color: Colors.white)),
                ],
              ),
            ],
          ),
          // SizedBox(height: 16.0),
          // Row(
          //   mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          //   children: [
          //     Text('Morning\n29°C', textAlign: TextAlign.center, style: TextStyle(fontSize: 12, color: Colors.white)),
          //     Text('Afternoon\n33°C', textAlign: TextAlign.center, style: TextStyle(fontSize: 12, color: Colors.white)),
          //     Text('Evening\n31°C', textAlign: TextAlign.center, style: TextStyle(fontSize: 12, color: Colors.white)),
          //     Text('Night\n27°C', textAlign: TextAlign.center, style: TextStyle(fontSize: 12, color: Colors.white)),
          //   ],
          // ),
        ],
      ),
    );
  }


  Widget _buildAnnouncements() {
    List<String> announcements = [
      'Announcement 1: Lorem ipsum dolor sit amet, consectetur adipiscing elit.',
      'Announcement 2: Sed do eiusmod tempor incididunt ut labore et dolore magna aliqua.',
      'Announcement 3: Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat.',
      'Announcement 4: Duis aute irure dolor in reprehenderit in voluptate velit esse cillum dolore eu fugiat nulla pariatur.',
      'Announcement 5: Excepteur sint occaecat cupidatat non proident, sunt in culpa qui officia deserunt mollit anim id est laborum.'
    ];

    return Container(
      padding: EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            const Color.fromARGB(255, 186, 186, 186)!,
            const Color.fromARGB(255, 166, 159, 167)!
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16.0),
        boxShadow: [
          BoxShadow(
            color: const Color.fromARGB(255, 132, 132, 132).withOpacity(0.3),
            spreadRadius: 2,
            blurRadius: 5,
            offset: Offset(0, 3),
          ),
        ],
      ),
      height: 250,
      child: Column(
        children: [
          Expanded(
            child: PageView.builder(
              controller: _announcementsPageController,
              itemCount: announcements.length,
              itemBuilder: (context, index) {
                return _buildAnnouncementCard(announcements[index]);
              },
            ),
          ),
          SizedBox(height: 10),
          SmoothPageIndicator(
            controller: _announcementsPageController,
            count: announcements.length,
            effect: WormEffect(
              dotHeight: 8,
              dotWidth: 8,
              spacing: 16,
              dotColor: Colors.grey,
              activeDotColor: Colors.blue,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPosts() {
    List<String> posts = [
      'Lorem ipsum dolor sit amet, consectetur adipiscing elit.',
      'Sed do eiusmod tempor incididunt ut labore et dolore magna aliqua.',
      'Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat.',
      'Duis aute irure dolor in reprehenderit in voluptate velit esse cillum dolore eu fugiat nulla pariatur.',
      'Excepteur sint occaecat cupidatat non proident, sunt in culpa qui officia deserunt mollit anim id est laborum.'
    ];

    return Container(
      padding: EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            const Color.fromARGB(255, 186, 186, 186)!,
            const Color.fromARGB(255, 166, 159, 167)!
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16.0),
        boxShadow: [
          BoxShadow(
            color: const Color.fromARGB(255, 132, 132, 132).withOpacity(0.3),
            spreadRadius: 2,
            blurRadius: 5,
            offset: Offset(0, 3),
          ),
        ],
      ),
      height: 250,
      child: Column(
        children: [
          Expanded(
            child: PageView.builder(
              controller: _postsPageController,
              itemCount: posts.length,
              itemBuilder: (context, index) {
                return _buildPostCard(posts[index]);
              },
            ),
          ),
          SizedBox(height: 10),
          SmoothPageIndicator(
            controller: _postsPageController,
            count: posts.length,
            effect: WormEffect(
              dotHeight: 8,
              dotWidth: 8,
              spacing: 16,
              dotColor: Colors.grey,
              activeDotColor: Colors.blue,
            ),
          ),
        ],
      ),
    );
  }

Widget _buildAnnouncementCard(String announcement) {
  return GestureDetector(
    onTap: () {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => AnnouncementDetailScreen(announcement: announcement),
        ),
      );
    },
    child: Container(
      margin: EdgeInsets.symmetric(horizontal: 8.0),
      padding: EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.8),
        borderRadius: BorderRadius.circular(16.0),
        boxShadow: [
          BoxShadow(
            color: const Color.fromARGB(255, 132, 132, 132).withOpacity(0.3),
            spreadRadius: 1,
            blurRadius: 3,
            offset: Offset(0, 1),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Announcement',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          SizedBox(height: 10),
          Text(announcement),
        ],
      ),
    ),
  );
}

Widget _buildPostCard(String post) {
  return GestureDetector(
    onTap: () {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => PostDetailScreen(post: post),
        ),
      );
    },
    child: Container(
      margin: EdgeInsets.symmetric(horizontal: 8.0),
      padding: EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.8),
        borderRadius: BorderRadius.circular(16.0),
        boxShadow: [
          BoxShadow(
            color: const Color.fromARGB(255, 132, 132, 132).withOpacity(0.3),
            spreadRadius: 1,
            blurRadius: 3,
            offset: Offset(0, 1),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Post',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          SizedBox(height: 10),
          Text(post),
        ],
      ),
    ),
  );
}

}
