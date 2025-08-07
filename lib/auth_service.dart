import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:firebase_messaging/firebase_messaging.dart';

final ValueNotifier<AuthService?> authServiceNotifier = ValueNotifier<AuthService?>(AuthService());

class AuthService{
  final FirebaseAuth firebaseAuth = FirebaseAuth.instance;
  final FirebaseFirestore firestore = FirebaseFirestore.instance;
  final FirebaseStorage storage = FirebaseStorage.instance;

  User? get currentUser => firebaseAuth.currentUser;

  Stream<User?> get authStateChanges => firebaseAuth.authStateChanges();

  Future<UserCredential> signIn({
    required String email, 
    required String password,
  }) async {
    final credential = await firebaseAuth.signInWithEmailAndPassword(
      email: email, password: password);
    
    return credential;
  }
  

  Future<UserCredential> createAccount({
    required String email,
    required String password,
    required String username,
  }) async{
    // ignore: non_constant_identifier_names
    final UserCredential = await firebaseAuth.createUserWithEmailAndPassword(
      email: email, 
      password: password
    );

    final uid = UserCredential.user!.uid;

    await saveUserInfo(
      uid: uid,
      data: {
        'email': email,
        'username': username,
        'role': 'user',
        'createdAt': FieldValue.serverTimestamp(),
      },
    );

    return UserCredential;
    
  }

  Future<void> signOut() async{
    await firebaseAuth.signOut();
  }

  Future<void> resetPassword({
    required String email,
  }) async{
    await firebaseAuth.sendPasswordResetEmail(email: email);
  }

  Future<void> userName({
    required String userName,
  }) async{
    await currentUser!.updateDisplayName(userName);
  }

  Future<void> deleteAccount(
    String email,
    String password,
  ) async {
    AuthCredential credential =  
      EmailAuthProvider.credential(
      email: email,
      password: password,
    );
    await currentUser!.reauthenticateWithCredential(credential);
    await currentUser!.delete();
    await firebaseAuth.signOut();
  }

  Future<void> resetPasswordFromCurrentPassword({
    required String currentPassword,
    required String newPassword,
    required String email,
  }) async{
    AuthCredential credential = 
      EmailAuthProvider.credential(
      email: email,
      password: currentPassword,
    );
    await currentUser!.reauthenticateWithCredential(credential);
    await currentUser!.updatePassword(newPassword);
  }

  Future<void> saveUserInfo({
    required String uid,
    required Map<String, dynamic> data,
  }) async {
    try {
      await firestore.collection('users').doc(uid).set(data);
    } catch (e) {
      rethrow;
    }
  }

  Future<void> updateUsername(String newUsername, {bool updateFirestore = false}) async {
    try {
      await currentUser!.updateDisplayName(newUsername);
      if (updateFirestore) {
        await firestore.collection('users').doc(currentUser!.uid).update({'username': newUsername});
      }
    } catch (e) {
      rethrow;
    }
  }

  Future<void> changePassword(String newPassword) async {
    try {
      await currentUser!.updatePassword(newPassword);
    } catch (e) {
      rethrow;
    }
  }

  Future<void> deleteAccountAndData(String email, String password) async {
    try {
      debugPrint('Starting account deletion for $email');
      AuthCredential credential = EmailAuthProvider.credential(email: email, password: password);
      debugPrint('Reauthenticating...');
      await currentUser!.reauthenticateWithCredential(credential);
      debugPrint('Deleting user data from Firestore...');
      await firestore.collection('users').doc(currentUser!.uid).delete();
      debugPrint('Deleting user from Firebase Auth...');
      await currentUser!.delete();
      debugPrint('Signing out...');
      await firebaseAuth.signOut();
      debugPrint('Account deletion complete.');
    } catch (e) {
      debugPrint('Error during account deletion: $e');
      rethrow;
    }
  }

  Future<String> uploadImageToCloudinary(String filePath) async {
    const cloudName = 'dw5bwmosg'; 
    const uploadPreset = 'flutter_profile_uploads'; 

    final url = Uri.parse('https://api.cloudinary.com/v1_1/$cloudName/image/upload');
    final file = File(filePath);

    if (!file.existsSync()) {
      throw Exception("File does not exist at path: $filePath");
    }

    final request = http.MultipartRequest('POST', url)
      ..fields['upload_preset'] = uploadPreset
      ..files.add(await http.MultipartFile.fromPath('file', filePath));

    final response = await request.send();

    if (response.statusCode == 200) {
      final resStr = await response.stream.bytesToString();
      final resJson = json.decode(resStr);
      return resJson['secure_url']; 
    } else {
      throw Exception('Failed to upload image to Cloudinary: [${response.statusCode}]');
    }
  }

  Future<String> uploadProfilePicture(String uid, String filePath) async {
    try {
      final url = await uploadImageToCloudinary(filePath);
      await firestore.collection('users').doc(uid).update({'profilePicture': url});
      return url;
    } catch (e) {
      debugPrint('Upload error: $e');
      rethrow;
    }
  }

  Future<void> clockIn() async {
    final user = currentUser;
    if (user == null) return;

    final today = DateTime.now();
    final dateStr = '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';

    final docRef = firestore
        .collection('clockins')
        .doc(dateStr)
        .collection('entries')
        .doc(user.uid);

    final doc = await docRef.get();

    if (doc.exists) {
      debugPrint("User has already clocked in today.");
      return;
    }

    final userDoc = await firestore.collection('users').doc(user.uid).get();
    final userData = userDoc.data() ?? {};

    await docRef.set({
      'uid': user.uid,
      'email': user.email,
      'username': user.displayName ?? userData['username'] ?? user.email,
      'clockedInAt': Timestamp.now(),
    });

    debugPrint("Clock-in successful.");
  }

  /// Call this after user signs in or registers to save/update their FCM token in Firestore.
  Future<void> saveFcmToken() async {
    final user = currentUser;
    if (user != null) {
      final token = await FirebaseMessaging.instance.getToken();
      if (token != null) {
        await firestore.collection('users').doc(user.uid).update({'fcmToken': token});
        debugPrint('FCM token saved to Firestore for user: ${user.uid}');
      }
    }
  }

  /*
  /// Send a push notification via FCM HTTP v1 API
  /// Deprecated: Use backend (firebase-admin) for sending notifications.
  Future<void> sendPushNotification({
    required String fcmToken,
    required String title,
    required String body,
    Map<String, dynamic>? data,
  }) async {
    const String serverKey = 'YOUR_SERVER_KEY'; 
    final url = Uri.parse('https://fcm.googleapis.com/fcm/send');

    final payload = {
      'to': fcmToken,
      'notification': {
        'title': title,
        'body': body,
      },
      'data': data ?? {},
    };

    final response = await http.post(
      url,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'key=$serverKey',
      },
      body: json.encode(payload),
    );

    if (response.statusCode != 200) {
      throw Exception('Failed to send notification: ${response.body}');
    }
  }
  */
}
