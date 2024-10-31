import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_map_tile_caching/flutter_map_tile_caching.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:responder/models/splash_screen.dart';
import 'firebase_options.dart';
import 'pages/announcement_page.dart';
import 'dart:async';
import 'services/notificatoin_service.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

final navigatorKey = GlobalKey<NavigatorState>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('en_PH', null); // Initialize the locale
  await initializeFirebase();
  await dotenv.load(fileName: '.env');
  // Initialize Notification Service for Android
  await NotificationService().initialize();
  await FMTCObjectBoxBackend().initialise();

  final mgmt = FMTCStore('mapCache').manage;

  bool storeExists = await mgmt.ready;
  if (storeExists) {
    print('Store exists and is ready for use.');

    final stats = FMTCStore('mapCache').stats;
    final allStats = await stats.all;
    print(allStats);

    final realSize = await FMTCRoot.stats.realSize;
    print('storesAvailable: $realSize');
  } else {
    print('Store does not exist. Creating it now...');
    await mgmt.create();
  }

  runApp(
    const MyApp(),
  );
}

Future<void> initializeFirebase() async {
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    FirebaseFirestore.instance.settings = const Settings(
      persistenceEnabled: true,
    );
  } catch (e) {
    print('Firebase initialization error: $e');
  }
}

class MyApp extends StatefulWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      debugShowCheckedModeBanner: false,
      home: SplashScreen(),
    );
  }
}
