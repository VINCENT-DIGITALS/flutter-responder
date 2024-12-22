import 'dart:async';
import 'dart:convert';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:responder/services/shared_pref.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import '../api/firebase_api.dart';
import '../pages/login_page.dart';

class DatabaseService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  final CollectionReference chats =
      FirebaseFirestore.instance.collection('chats');

  Future<bool> isEmailVerified(User user) async {
    // Reload user data to get the latest verification status
    await user.reload();
    return user.emailVerified;
  }

  Future<void> sendVerificationEmail(User user) async {
    if (!user.emailVerified) {
      await user.sendEmailVerification();
    }
  }

  Future<void> saveFcmToken(String userId) async {
    try {
      final FirebaseApi firebaseApi = FirebaseApi();
      await firebaseApi.initNotifications(userId);
    } catch (e) {
      print('Failed to save FCM token: $e');
    }
  }

  // Fetch logbook data from Firestore
  Future<void> saveLogBookToFirestore(
      String logbookId, Map<String, dynamic> logbookData) async {
    await _db.collection('logBook').doc(logbookId).update({
      'landmark': logbookData['landmark'],
      'transportedTo': logbookData['transportedTo'],
      'incidentType': logbookData['incidentType'],
      'incident': logbookData['incident'],
      'incidentDesc': logbookData['incidentDesc'],
      'victims': logbookData['victims'],
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<DocumentSnapshot> getUserDoc(String uid) async {
    return await _db.collection('responders').doc(uid).get();
  }

  Future<DocumentSnapshot> getReporterName(String uid) async {
    return await _db.collection('citizens').doc(uid).get();
  }

  // Save logbook locally to SharedPreferences
  Future<void> saveLogBookLocally(
      String logbookId, Map<String, dynamic> logbookData) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();

    // Get stored logbooks
    List<String> storedLogbooks = prefs.getStringList('logbooks') ?? [];

    // Encode logbook data
    logbookData['logbookId'] = logbookId;
    storedLogbooks.add(jsonEncode(logbookData));

    // Save to SharedPreferences
    await prefs.setStringList('logbooks', storedLogbooks);
  }

  // Remove logbook from SharedPreferences after successful Firestore save
  Future<void> removeLogBookFromLocal(String logbookId) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    List<String> storedLogbooks = prefs.getStringList('logbooks') ?? [];
    storedLogbooks.removeWhere(
        (logbook) => jsonDecode(logbook)['logbookId'] == logbookId);
    await prefs.setStringList('logbooks', storedLogbooks);
  }

// Method to update or create locationSharing, latitude, longitude, and lastUpdated fields
  Future<void> updateLocationSharing({
    required GeoPoint location, // Use GeoPoint here
    required bool locationSharing, // New parameter for locationSharing
  }) async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        throw Exception('No user is currently signed in');
      }

      final userRef = _db.collection('responders').doc(user.uid);

      // Set the locationSharing, location, and lastUpdated fields (creates if not exist)
      await userRef.set(
          {
            'locationSharing': locationSharing, // Enable location sharing
            'location': location, // Store as GeoPoint
            'lastUpdated': FieldValue
                .serverTimestamp(), // Update the last updated timestamp
          },
          SetOptions(
              merge: true)); // Merge to ensure fields are created if not exist
    } catch (e) {
      // Handle errors
      throw Exception('Error updating user location: $e');
    }
  }

  /// Method to retrieve a document with dynamic fields
  Future<Map<String, dynamic>?> getDocument(String collection) async {
    try {
      // Ensure the user is authenticated
      final user = _auth.currentUser;
      if (user == null) {
        print("User is not authenticated!");
        return null;
      }
      _checkAuthentication();
      DocumentSnapshot document =
          await _db.collection(collection).doc(user.uid).get();
      if (document.exists) {
        return document.data() as Map<String, dynamic>?;
      } else {
        print("Document does not exist!");
        return null;
      }
    } catch (e) {
      print("Error fetching document: $e");
      return null;
    }
  }

  void redirectToLogin(BuildContext context) {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => const LoginPage()),
    );
  }

// Get chat messages for a specific chat with pagination
  Stream<QuerySnapshot> getMessages(String chatId, {int limit = 10}) {
    return chats
        .doc(chatId)
        .collection('messages')
        .orderBy('timestamp', descending: true)
        .limit(limit)
        .snapshots();
  }

  Future<String> getDisplayName(DocumentReference senderRef) async {
    DocumentSnapshot userDoc = await senderRef.get();
    String collectionName =
        userDoc.reference.parent.id; // Get the parent collection name

    // Assuming the collection names are 'responders' or 'operators'
    if (collectionName == 'responders' || collectionName == 'operator') {
      return userDoc['displayName'] ?? 'Unknown';
    }
    return 'Unknown';
  }

  Future<void> sendMessage(
      String chatId, String message, String senderId, bool isOperator) async {
    var timestamp = DateTime.now();

    // Determine the correct user collection based on whether the user is an operator or responder
    CollectionReference userCollection = isOperator
        ? FirebaseFirestore.instance.collection('operators')
        : FirebaseFirestore.instance.collection('responders');

    // Fetch the display name
    DocumentSnapshot userDoc = await userCollection.doc(senderId).get();
    String displayName =
        userDoc['displayName'] ?? 'Unknown'; // Get the display name directly

    var messageData = {
      'message': message,
      'sender':
          userCollection.doc(senderId), // Reference the correct collection
      'timestamp': timestamp,
      'seen_by': [], // Initially no one has seen the message
      'displayName': displayName,
    };

    await chats.doc(chatId).collection('messages').add(messageData);

    // Update the chat's last message details
    await chats.doc(chatId).update({
      'last_message': message,
      'last_message_time': timestamp,
      'last_message_sent_by':
          userCollection.doc(senderId), // Correct reference for sender
    });
  }

  // Check if user is authenticated
  bool isAuthenticated() {
    return _auth.currentUser != null;
  }

  // Check if an email already exists
  Future<bool> doesEmailExist(String email) async {
    // Query all relevant collections where an email might exist
    final citizenQuery =
        _db.collection('citizens').where('email', isEqualTo: email).get();

    // Await all the queries
    final results = await Future.wait([citizenQuery]);

    // Check if any of the queries returned documents
    final emailExists = results.any((query) => query.docs.isNotEmpty);
    return emailExists;
  }

  // Check if an email belongs to a citizen
  Future<bool> isAuthorizedEmail(String email) async {
    final citizenQuery =
        _db.collection('citizens').where('email', isEqualTo: email).get();
    final results = await Future.wait([citizenQuery]);
    final isCitizen = results[0].docs.isNotEmpty;
    return isCitizen;
  }

  // Getter for the current user
  User? get currentUser {
    return _auth.currentUser;
  }

  // Method to get the current user's document ID and display name
  Future<Map<String, String?>> getCurrentUserDetails() async {
    User? user = _auth.currentUser;
    if (user != null) {
      // Query the 'responders' collection where 'uid' matches the current user's UID
      QuerySnapshot querySnapshot = await _db
          .collection('responders')
          .where('uid', isEqualTo: user.uid)
          .get();

      if (querySnapshot.docs.isNotEmpty) {
        var responderDoc = querySnapshot.docs.first;

        // Retrieve the Firestore document ID (not the uid) and the display name
        String documentId = responderDoc.id;
        String displayName = responderDoc['displayName'] ?? 'Responder';

        print('Document ID: $documentId'); // Log the actual document ID
        print(
            'Display Name: $displayName'); // Log the display name for verification

        return {
          'id': documentId,
          'name': displayName,
        };
      } else {
        print('No responder document found for UID: ${user.uid}');
      }
    }
    return {
      'id': null,
      'name': null
    }; // Return null values if no document found
  }

  // Method to get current user ID
  String? getCurrentUserId() {
    User? user = currentUser;
    return user?.uid; // Return UID if user is logged in, otherwise null
  }

  // Method to get current user DisplayName
  String? getCurrentUserName() {
    User? user = currentUser;
    return user?.displayName; // Return UID if user is logged in, otherwise null
  }

  // Method to fetch current user data once
  Future<Map<String, dynamic>> fetchCurrentUserData() async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        throw Exception('No user is currently signed in');
      }

      final querySnapshot = await FirebaseFirestore.instance
          .collection('citizens')
          .where('uid', isEqualTo: user.uid)
          .get();

      if (querySnapshot.docs.isEmpty) {
        throw Exception('No data available for the current user');
      }

      final userData = querySnapshot.docs.first.data() as Map<String, dynamic>;
      return userData;
    } catch (e) {
      // Handle errors
      throw Exception('Error fetching user data: $e');
    }
  }

// Fetch announcements as a stream from Firestore where archived is false
  Stream<List<Map<String, dynamic>>> getAnnouncementsStream() {
    return _db
        .collection('announcements')
        .where('archived', isEqualTo: false) // Filter archived items
        .orderBy('timestamp', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => doc.data() as Map<String, dynamic>)
            .toList());
  }

  Stream<List<Map<String, dynamic>>> getLatestItemsStream(String collection,
      {int limit = 3}) {
    return _db
        .collection(collection)
        .where('archived', isEqualTo: false) // Filter archived items
        .orderBy('timestamp', descending: true)
        .limit(limit)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) {
        Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
        data['id'] = doc.id; // Include document ID if needed
        return data;
      }).toList();
    });
  }

  // Fetch current weather data from Firestore
  Future<Map<String, dynamic>?> fetchCurrentWeatherData() async {
    try {
      DocumentSnapshot<Map<String, dynamic>> doc =
          await _db.collection('weather').doc('current').get();
      if (doc.exists) {
        return doc.data()?['currentWeather'];
      } else {
        print('Current weather document does not exist');
        return null;
      }
    } catch (e) {
      print('Error fetching current weather data: $e');
      return null;
    }
  }

  Future<List<Map<String, dynamic>>> fetchForecastData() async {
    try {
      QuerySnapshot<Map<String, dynamic>> querySnapshot = await _db
          .collection(
              'weather') // Assuming 'weather' is your Firestore collection
          .where(FieldPath.documentId,
              isNotEqualTo: 'current') // Exclude the 'current' document
          .get();

      // Convert the query snapshot into a list of maps (documents data)
      return querySnapshot.docs.map((doc) => doc.data()).toList();
    } catch (e) {
      print('Error fetching forecast data: $e');
      return [];
    }
  }

  // Method to update specific fields of the current user document
  Future<void> updateUserData({
    required Map<String, dynamic> updatedFields,
  }) async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        throw Exception('No user is currently signed in');
      }

      final userRef = _db.collection('responders').doc(user.uid);
      await userRef.update(updatedFields);
    } catch (e) {
      // Handle errors
      throw Exception('Error updating user data: $e');
    }
  }

  // Method to update a document with a specified ID
  Future<void> updateDocument(String collectionPath, String documentId,
      Map<String, dynamic> data) async {
    _checkAuthentication();
    return await _db.collection(collectionPath).doc(documentId).update(data);
  }

  // Method to delete a document with a specified ID
  Future<void> deleteDocument(String collectionPath, String documentId) async {
    _checkAuthentication();
    return await _db.collection(collectionPath).doc(documentId).delete();
  }

  // Private method to check authentication
  void _checkAuthentication() {
    if (!isAuthenticated()) {
      throw Exception("User not authenticated");
    }
  }

  // Method to fetch weather data
  Future<Map<String, dynamic>?> fetchWeatherData() async {
    try {
      DocumentSnapshot<Map<String, dynamic>> doc =
          await _db.collection('weather').doc('weatherData').get();
      if (doc.exists) {
        return doc.data();
      } else {
        print('Document does not exist');
        return null;
      }
    } catch (e) {
      print('Error fetching weather data: $e');
      return null;
    }
  }

  Future<void> addFriends(String userId, List<String> friendIds) async {
    final friendsDoc = _db.collection("friends").doc(userId);
    await friendsDoc.set({
      'friendIds': FieldValue.arrayUnion(friendIds),
    }, SetOptions(merge: true));
  }

  Future<List<String>> getFriends(String userId) async {
    final friendsDoc = _db.collection("friends").doc(userId);
    final docSnapshot = await friendsDoc.get();

    if (docSnapshot.exists) {
      final data = docSnapshot.data();
      if (data != null && data['friendIds'] != null) {
        return List<String>.from(data['friendIds']);
      }
    }
    return [];
  }

  void flutterToastError(String message) {
    Fluttertoast.showToast(
      msg: message,
      toastLength: Toast.LENGTH_SHORT,
      gravity: ToastGravity.CENTER,
      timeInSecForIosWeb: 1,
      backgroundColor: Colors.red,
      textColor: Colors.white,
      fontSize: 16.0,
    );
  }

  void flutterToast(String message) {
    Fluttertoast.showToast(
      msg: message,
      toastLength: Toast.LENGTH_SHORT,
      gravity: ToastGravity.CENTER,
      timeInSecForIosWeb: 1,
      backgroundColor: Colors.green,
      textColor: Colors.white,
      fontSize: 16.0,
    );
  }

  // Future<String?> verifyPhone() async {
  //   await _auth.verifyPhoneNumber(
  //     phoneNumber: '+44 7123 123 456',
  //     verificationFailed: (FirebaseAuthException e) {
  //       if (e.code == 'invalid-phone-number') {
  //         print('The provided phone number is not valid.');
  //       }

  //       // Handle other errors
  //     },
  //   );
  // }

  bool isValidPassword(String password) {
    // Check if password is at least 6 characters long
    return password.length >= 6;
  }

  bool isValidEmail(String email) {
    // Regular expression for validating an email
    final emailRegExp = RegExp(
      r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,4}$',
    );
    return emailRegExp.hasMatch(email);
  }

  Future<UserCredential> registerWithEmailAndPassword(String email,
      String password, String displayName, String phoneNumber) async {
    try {
      // Try to create the user with email and password
      UserCredential userCredential =
          await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      // Ensure the user document exists in Firestore
      await _createUserDocumentIfNotExists(
          userCredential.user, displayName, phoneNumber, email);

      // Store user details in SharedPreferences
      if (userCredential.user != null) {
        User user = userCredential.user!;
        SharedPreferencesService prefs =
            await SharedPreferencesService.getInstance();
        prefs.saveUserData({
          'uid': user.uid,
          'email': user.email ?? '',
          'displayName': displayName,
          'photoURL': user.photoURL ?? '',
          'phoneNum': phoneNumber,
          'createdAt': DateTime.now().toIso8601String(),
          'address': '',
          'type': 'citizen',
          'status': 'Activated',
        });
      }

      return userCredential;
    } on FirebaseAuthException catch (e) {
      print('Caught FirebaseAuthException: ${e.code}');
      print('Error message: ${e.message}');
      switch (e.code) {
        case 'email-already-in-use':
          flutterToast('The email address is already in use');
          break;
        case 'weak-password':
          flutterToast('The password is too weak, at least six characters');
          break;
        case 'invalid-email':
          flutterToast('The email address is not valid.');
          break;
        default:
          flutterToast('Something went wrong, please try again1');
          break;
      }
      throw (e.code);
    } catch (e) {
      flutterToast('Something went wrong, please try again');
      throw Exception('Something went wrong: $e');
    }
  }

// Create user document in Firestore if it doesn't already exist
  Future<void> _createUserDocumentIfNotExists(User? user,
      [String? displayName, String? phoneNumber, String? email]) async {
    if (user != null) {
      final userDoc = _db.collection("citizens").doc(user.uid);
      final docSnapshot = await userDoc.get();

      if (!docSnapshot.exists) {
        final userInfoMap = {
          // 'uid': user.uid,   redundant
          'email': user.email,
          'displayName': displayName ?? user.displayName,
          'photoURL': user.photoURL,
          'phoneNum': phoneNumber ?? user.phoneNumber,
          'createdAt': FieldValue.serverTimestamp(),
          'address': '',
          'type': 'citizen',
          'status': 'Activated',
        };

        await userDoc.set(userInfoMap);

        await sendEmailVerification(email);
      } //else
    }
  }

  Future<String?> createGoogleUser() async {
    try {
      // Begin interactive sign-in process
      final GoogleSignInAccount? gUser = await GoogleSignIn().signIn();

      if (gUser == null) {
        return 'User canceled the sign-in process';
      }

      // Obtain auth details from user
      final GoogleSignInAuthentication gAuth = await gUser.authentication;

      // Create a new credential for user
      final credential = GoogleAuthProvider.credential(
        accessToken: gAuth.accessToken,
        idToken: gAuth.idToken,
      );

      // Sign in to Firebase with the credential
      UserCredential userCredential =
          await _auth.signInWithCredential(credential);
      User? user = userCredential.user;

      if (user == null) {
        return 'Google sign-in failed';
      }

      // Create Firestore document
      await _createUserDocumentIfNotExists(
          user, gUser.displayName, '', gUser.email);

      return 'Account successfully created.';
    } catch (e) {
      print("Something went wrong: $e");
      return 'An unknown error occurred: $e';
    }
  }

  Future<String?> signInWithGoogle() async {
    try {
      // Begin interactive sign-in process
      final GoogleSignInAccount? gUser = await GoogleSignIn().signIn();

      if (gUser == null) {
        return 'User canceled the sign-in process';
      }

      // Obtain auth details from user
      final GoogleSignInAuthentication gAuth = await gUser.authentication;

      // Obtain the user's email from Google sign-in
      final email = gUser.email;

      // Fetch user document from Firestore
      final userDoc = _db
          .collection("responders")
          .where('email', isEqualTo: email)
          .limit(1);
      final docSnapshot = await userDoc.get();

      if (docSnapshot.docs.isEmpty) {
        return 'Account does not exist. Please register first.';
      }

      final userData = docSnapshot.docs.first.data();
      final documentId = docSnapshot.docs.first.id;
      if (userData['status'] == 'Deactivated') {
        return 'User account is deactivated, contact the operator to activate';
      }

      // Sign in to Firebase with the credential
      final credential = GoogleAuthProvider.credential(
        accessToken: gAuth.accessToken,
        idToken: gAuth.idToken,
      );
      UserCredential userCredential =
          await _auth.signInWithCredential(credential);

      // Store user details in SharedPreferences
      SharedPreferencesService prefs =
          await SharedPreferencesService.getInstance();
      prefs.saveUserData({
        'uid': userData['uid'] ?? '',
        'email': userData['email'] ?? '',
        'displayName': userData['displayName'] ?? '',
        'photoURL': userData['photoURL'] ?? '',
        'phoneNum': userData['phoneNum'] ?? '',
        'createdAt':
            (userData['createdAt'] as Timestamp).toDate().toIso8601String(),
        'address': userData['address'] ?? '',
        'type': userData['type'] ?? '',
        'status': userData['status'] ?? '',
      });

      // Save FCM token
      await saveFcmToken(documentId);

      return null;
    } catch (e) {
      print("Something went wrong: $e");
      return 'Something went wrong, please try again';
    }
  }

  Future<String> checkInternetSpeed() async {
    final url = Uri.parse('https://www.google.com');

    try {
      final stopwatch = Stopwatch()..start();
      final response = await http.get(url);
      stopwatch.stop();

      if (response.statusCode == 200) {
        final pingTime = stopwatch.elapsedMilliseconds;
        if (pingTime < 100) {
          return 'Fast';
        } else if (pingTime < 300) {
          return 'Moderate';
        } else {
          return 'Slow';
        }
      } else {
        return 'unstable';
      }
    } catch (e) {
      return 'Failed to measure';
    }
  }

// Sign in with email and password (Only for authorized users)
  Future<String?> signInWithEmail(String email, String password) async {
    try {
      // Fetch user document from Firestore
      final userDoc = _db
          .collection("responders")
          .where('email', isEqualTo: email)
          .limit(1);
      final docSnapshot = await userDoc.get();

      if (docSnapshot.docs.isEmpty) {
        final netSpeed = await checkInternetSpeed(); // Await the result

        // flutterToastError('User document does not exist');
        if (netSpeed == 'Slow') {
          return 'Slow or No Internet Connection';
        } else if (netSpeed == 'Moderate') {
          return 'Moderate Internet';
        } else if (netSpeed == 'Fast') {
          return 'Fast Internet';
        } else if (netSpeed == 'unstable') {
          return 'Internet connection is unstable or unreachable.';
        } else if (netSpeed == 'Failed to measure') {
          return 'Failed to measure internet speed. Please check your connection.';
        } else if (docSnapshot.docs.isEmpty) {
          return 'No Record Shown. Please contact the operator';
        } else {
          return 'No Record Shown. Please contact the operator';
        }
      }

      final userData = docSnapshot.docs.first.data();
      final documentId = docSnapshot.docs.first.id;
      if (userData['status'] == 'Deactivated') {
        //flutterToast('User account is deactivated, contact the operator to activate');
        return 'User account is deactivated, contact the operator to activate';
      }

      UserCredential userCredential = await _auth.signInWithEmailAndPassword(
          email: email, password: password);
      User? user = userCredential.user;
      if (user == null) {
        return 'Sign-in failed. Please try again.';
      }

      // Reload user to get latest email verification status
      await user.reload();

      if (!user.emailVerified) {
        user.sendEmailVerification();
        await _auth.signOut(); // Sign out if email is not verified
        
        return 'Email is not verified yet. Please check the email we sent to your email.';
      }
      // Store user details in SharedPreferences
      SharedPreferencesService prefs =
          await SharedPreferencesService.getInstance();
      prefs.saveUserData({
        'uid': documentId ?? '',
        'email': userData['email'] ?? '',
        'displayName': userData['displayName'] ?? '',
        'photoURL': userData['photoURL'] ?? '',
        'phoneNum': userData['phoneNum'] ?? '',
        'createdAt':
            (userData['createdAt'] as Timestamp).toDate().toIso8601String(),
        'address': userData['address'] ?? '',
        'type': userData['type'] ?? '',
        'status': userData['status'] ?? '',
        'privacyPolicyAccepted': userData['privacyPolicyAcceptance'] ??
            false, // Added privacy policy status
      });
      // Save FCM token
      await saveFcmToken(documentId);

      return null; // Sign-in successful
    } on FirebaseAuthException catch (e) {
      print('Caught FirebaseAuthException: ${e.code}');
      print('Error message: ${e.message}');
      switch (e.code) {
        case 'user-not-found':
          //('User not found');
          print('Something went wrong: $e');
          return 'User not found';
        //break;
        case 'invalid-credential':
          //flutterToastError('Incorrect password');
          print('Something went wrong: $e');
          return 'Incorrect Email/password';
        //break;
        case 'user-disabled':
          //flutterToastError('User account has been disabled');\
          print('Something went wrong: $e');
          return 'User account has been disabled';
        //break;
        case 'invalid-email':
          //flutterToast('The email address is not valid.');
          print('Something went wrong: $e');
          return 'The email address is not valid.';
        default:
          //flutterToastError('Something went wrong, please try again');
          print('Something went wrong: $e');
          return 'Something went wrong, please try again';
        //break;
      }
      throw (e.code);
    } catch (e) {
      print('Something went wrong: $e');
      //flutterToastError('Something went wrong, please try again');
      return 'Something went wrong, please try again';
      //throw Exception('Something went wrong: $e');
    }
  }

  // Sign out
  Future<void> signOut() async {
    await _auth.signOut();
    await GoogleSignIn().signOut();
    SharedPreferencesService prefs =
        await SharedPreferencesService.getInstance();
    _clearUserData(prefs);
  }

  // Clear user data from SharedPreferences
  void _clearUserData(SharedPreferencesService prefs) {
    prefs.saveData('uid', '');
    prefs.saveData('email', '');
    prefs.saveData('displayName', '');
    prefs.saveData('photoURL', '');
    prefs.saveData('phoneNum', '');
    prefs.saveData('createdAt', '');
    prefs.saveData('address', '');
    prefs.saveData('type', '');
    prefs.saveData('status', '');
  }

  //Email verification
  Future<void> sendEmailVerification(String? email) async {
    try {
      await _auth.currentUser?.sendEmailVerification();
      flutterToast('Email verification has been sent to your email.');
    } catch (e) {
      print('Something went wrong: $e');
      flutterToast('Something went wrong, please try again');
    }
  }

  //forgot password
  Future<void> sendPasswordResetEmail(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email);
      flutterToast('Password reset has been sent to your email.');
    } catch (e) {
      print('Something went wrong: $e');
      flutterToast('Something went wrong, please try again');
    }
  }

  Future<void> logout() async {
    await _auth.signOut();
  }
}
