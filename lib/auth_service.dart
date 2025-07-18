import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'dart:convert';

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
  }) async{
    return await firebaseAuth.signInWithEmailAndPassword(
        email: email, password: password);
  }

  Future<UserCredential> createAccount({
    required String email,
    required String password,
  }) async{
    return await firebaseAuth.createUserWithEmailAndPassword(
        email: email, password: password);
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
      print('Starting account deletion for $email');
      AuthCredential credential = EmailAuthProvider.credential(email: email, password: password);
      print('Reauthenticating...');
      await currentUser!.reauthenticateWithCredential(credential);
      print('Deleting user data from Firestore...');
      await firestore.collection('users').doc(currentUser!.uid).delete();
      print('Deleting user from Firebase Auth...');
      await currentUser!.delete();
      print('Signing out...');
      await firebaseAuth.signOut();
      print('Account deletion complete.');
    } catch (e) {
      print('Error during account deletion: $e');
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
      print('Upload error: $e');
      rethrow;
    }
  }
}
