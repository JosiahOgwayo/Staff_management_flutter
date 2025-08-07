/*import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../firebase_options.dart';
import 'login_page.dart';
import 'home_page.dart'; 
import 'chat_arguments.dart'; 

class Application extends StatelessWidget {
  const Application({super.key});

  // Called after widget builds
  void _setupFCM(BuildContext context) {
    _requestNotificationPermissions();
    _fetchAndSaveFcmToken();
    _listenForegroundMessages();
    _setupInteractedMessage(context);
  }

  void _requestNotificationPermissions() async {
    await FirebaseMessaging.instance.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );
  }

  void _fetchAndSaveFcmToken() async {
    String? token = await FirebaseMessaging.instance.getToken();
    User? user = FirebaseAuth.instance.currentUser;

    if (token != null && user != null) {
      await FirebaseFirestore.instance.collection('users').doc(user.uid).update({
        'fcmToken': token,
      });
    }
  }

  void _listenForegroundMessages() {
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      debugPrint('Foreground notification received: ${message.notification?.title}');
      // TODO: Optionally show a local notification here if needed
    });
  }

  void _setupInteractedMessage(BuildContext context) async {
    RemoteMessage? initialMessage =
        await FirebaseMessaging.instance.getInitialMessage();

    if (initialMessage != null) {
      _handleMessage(context, initialMessage);
    }

    FirebaseMessaging.onMessageOpenedApp.listen(
      (RemoteMessage message) => _handleMessage(context, message),
    );
  }

  void _handleMessage(BuildContext context, RemoteMessage message) {
    if (message.data['type'] == 'chat') {
      Navigator.pushNamed(
        context,
        '/chat',
        arguments: ChatArguments(message),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    // All Firebase-related logic after build
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _setupFCM(context);
    });

    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        // Check if user is logged in
        if (snapshot.connectionState == ConnectionState.active) {
          final user = snapshot.data;
          if (user == null) {
            return const LoginPage();
          } else {
            return const HomePage(); // Replace with your main page
          }
        }
        return const Scaffold(
          body: Center(child: CircularProgressIndicator()),
        );
      },
    );
  }
}*/
