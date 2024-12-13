import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_map_tile_caching/flutter_map_tile_caching.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:responder/localization/locales.dart';
import 'package:responder/models/splash_screen.dart';
import 'firebase_options.dart';
import 'pages/announcement_page.dart';
import 'dart:async';
import 'services/notificatoin_service.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_localization/flutter_localization.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import 'services/reportsListener.dart';

final navigatorKey = GlobalKey<NavigatorState>();
final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
    FlutterLocalNotificationsPlugin();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Initialize the report listener globally

  await SystemChrome.setPreferredOrientations([
    // LOCKING THE APP RATOTION INTO POTRAIT ONLY
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);
  await initializeDateFormatting('en_PH', null); // Initialize the locale
  // Initialize Firebase
  try {
    await initializeFirebase();
    print("Firebase initialized successfully.");
  } catch (e) {
    print("Error during Firebase initialization: $e");
    // Optionally: show a dialog or UI message to inform the user of the issue
  }
  FirebaseAuth.instance.authStateChanges().listen((user) {
    if (user != null) {
      print('User is logged in. Initializing Firestore listener.');
      FirestoreListenerService().initialize();
    } else {
      print(
          'User is not logged in. Skipping Firestore listener initialization.');
    }
  });

  await dotenv.load(fileName: '.env');
  // Initialize Notification Service for Android
  try {
    await NotificationService().initialize();
    print("Notification service initialized successfully.");
  } catch (e) {
    print("Error during NotificationService initialization: $e");
    // Optionally: show a dialog or UI message to inform the user of the issue
  }
  // Initialize FMTC for Android
  try {
    await FMTCObjectBoxBackend().initialise();
    print("FMTC service initialized successfully.");
  } catch (e) {
    print("Error during FMTC initialization: $e");
    // Optionally: show a dialog or UI message to inform the user of the issue
  }

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
  final FlutterLocalization localization = FlutterLocalization.instance;

  @override
  void initState() {
    super.initState();
    configureLocalization();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: navigatorKey, // Set the global navigator key
      debugShowCheckedModeBanner: false,
      supportedLocales: localization.supportedLocales,
      localizationsDelegates: localization.localizationsDelegates,
      home: const SplashScreen(),
    );
  }

  void configureLocalization() {
    localization.init(mapLocales: LOCALES, initLanguageCode: "en");
    localization.onTranslatedLanguage = onTranslatedLanguage;
  }

  void onTranslatedLanguage(Locale? locale) {
    setState(() {});
  }
}
