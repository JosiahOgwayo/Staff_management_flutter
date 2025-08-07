// ignore_for_file: use_build_context_synchronously

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
// import 'package:get/get.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:image_picker/image_picker.dart';

import 'package:employee_app_new/auth_service.dart';
import 'package:employee_app_new/pages/login_page.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

Future<void> sendPushToAdmin(String token, String title, String body) async {
  const url = 'http://127.0.0.1:8000/send-notification/'; 
  try {
    final response = await http.post(
      Uri.parse(url),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'token': token,
        'title': title,
        'body': body,
      }),
    );

    if (response.statusCode == 200) {
      debugPrint('✅ Notification sent to $token');
    } else {
      debugPrint('❌ Failed to send: ${response.body}');
    }
  } catch (e) {
    debugPrint('❌ Error sending notification: $e');
  }
}

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  String? _profilePicUrl;
  String? _username;
  String? _email;
  String? _staffNumber;
  String? _department;
  int? _yearJoined;
  bool _loading = false;
  final _authService = AuthService();

  bool _isClockedIn = false;
  bool _isClocking = false;

  @override
  void initState() {
    super.initState();
    _loadUserData();
    _checkClockInStatus();
    //It Save/update FCM token when profile loads
    AuthService().saveFcmToken();
  }

  Future<void> _checkClockInStatus() async {
    final auth = authServiceNotifier.value;
    final user = auth?.currentUser;
    if (user == null) return;

    final today = DateTime.now();
    final dateStr = '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';

    final docRef = auth!.firestore
        .collection('clockins')
        .doc(dateStr)
        .collection('entries')
        .doc(user.uid);

    final doc = await docRef.get();

    setState(() {
      _isClockedIn = doc.exists;
    });
  }

  Future<void> _handleClockIn() async {
    setState(() => _isClocking = true);
    try {
      final auth = authServiceNotifier.value;
      await auth?.clockIn();

      setState(() => _isClockedIn = true);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('You have clocked in.'))
      );
          // AFTER CLOCK-IN: It fetch all admins and send push
      final admins = await _authService.firestore
        .collection('users')
        .where('role', isEqualTo: 'admin')
        .get();

      for (var doc in admins.docs) {
      final token = doc['fcmToken'];
      if (token != null && token is String && token.isNotEmpty) {
        await sendPushToAdmin(
          token,
          'Employee Clock In',
          '$_username just clocked in.',
        );
      }
      }


    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to clock in.'))
      );
    } finally {
      setState(() => _isClocking = false);
    }
  }

  Future<void> _loadUserData() async {
    setState(() => _loading = true);
    try {
      final user = _authService.currentUser;
      if (user != null) {
        final doc = await _authService.firestore.collection('users').doc(user.uid).get();
        if (!mounted) return;
        setState(() {
          _profilePicUrl = doc.data()?['profilePicture'];
          _username = doc.data()?['username'] ?? user.displayName ?? user.email;
          _email = doc.data()?['email'] ?? user.email;
          _staffNumber = doc.data()?['staffNumber'];
          _department = doc.data()?['department'];
          _yearJoined = doc.data()?['yearJoined'];
        });
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to load user data: \${e.toString()}'))
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  String? getOptimizedCloudinaryUrl(String? url) {
    if (url == null || !url.contains('/upload/')) return url;
    return url.replaceFirst('/upload/', '/upload/w_200,h_200,c_fill/');
  }

  Future<void> _logout() async {
    try {
      final user = _authService.currentUser;
      if (user != null) {
        await _authService.firestore.collection('users').doc(user.uid).update({'status': 'offline'});
      }
      await _authService.signOut();
      if (!mounted) return;
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (context) => const LoginPage()),
        (route) => false,
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to log out: \${e.toString()}'))
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Profile')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              child: Column(
                children: [
                  const SizedBox(height: 24),
                  GestureDetector(
                    onTap: _pickAndUploadProfilePic,
                    child: _profilePicUrl != null && _profilePicUrl!.isNotEmpty
                        ? CachedNetworkImage(
                            imageUrl: getOptimizedCloudinaryUrl(_profilePicUrl!)!,
                            placeholder: (context, url) => const CircleAvatar(
                              radius: 60, 
                              child: CircularProgressIndicator()
                            ),
                            errorWidget: (context, url, error) => const CircleAvatar(
                              radius: 60, 
                              child: Icon(Icons.error)
                            ),
                            imageBuilder: (context, imageProvider) => CircleAvatar(
                              radius: 60,
                              backgroundImage: imageProvider,
                            ),
                          )
                        : const CircleAvatar(
                            radius: 60, 
                            child: Icon(Icons.person, size: 60)
                          ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    _username ?? '', 
                    style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)
                  ),
                  const SizedBox(height: 8),
                  Card(
                    margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 4),
                    child: Padding(
                      padding: const EdgeInsets.all(12.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Details', 
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)
                          ),
                          const SizedBox(height: 8),
                          if (_email != null) Text('Email: \$_email'),
                          if (_staffNumber != null) Text('Staff Number: \$_staffNumber'),
                          if (_department != null) Text('Department: \$_department'),
                          if (_yearJoined != null) Text('Year Joined: \$_yearJoined'),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  if (!_isClockedIn)
                    ElevatedButton(
                      onPressed: _isClocking ? null : _handleClockIn,
                      child: _isClocking
                          ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                          : const Text('Clock In'),
                    )
                  else
                    const Text('You have already clocked in today.'),

                  const Divider(),
                  const SizedBox(height: 12),
                  const Text(
                    'Settings', 
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)
                  ),
                  ListTile(
                    leading: const Icon(Icons.edit),
                    title: const Text('Update Username'),
                    onTap: _showUpdateUsernameDialog,
                  ),
                  ListTile(
                    leading: const Icon(Icons.lock),
                    title: const Text('Change Password'),
                    onTap: _showChangePasswordDialog,
                  ),
                  ListTile(
                    leading: const Icon(Icons.delete),
                    title: const Text('Delete Account'),
                    onTap: _showDeleteAccountDialog,
                  ),
                  ListTile(
                    leading: const Icon(Icons.info),
                    title: const Text('About this app'),
                    onTap: () {
                      showAboutDialog(
                        context: context,
                        applicationName: 'Employee App',
                        applicationVersion: '1.0.0',
                        children: [const Text('This app is built with Flutter and Firebase.')],
                      );
                    },
                  ),
                  ListTile(
                    leading: const Icon(Icons.logout),
                    title: const Text('Log Out'),
                    onTap: _logout,
                  ),
                ],
              ),
            ),
    );
  }

  Future<void> _pickAndUploadProfilePic() async {
    try {
      final picker = ImagePicker();
      final picked = await picker.pickImage(source: ImageSource.gallery);
      if (picked == null) return;

      final croppedFile = await ImageCropper().cropImage(
        sourcePath: picked.path,
        uiSettings: [
          AndroidUiSettings(
            toolbarTitle: 'Crop Image',
            toolbarColor: Colors.black,
            toolbarWidgetColor: Colors.white,
            initAspectRatio: CropAspectRatioPreset.square,
            lockAspectRatio: false,
            cropStyle: CropStyle.rectangle,
            showCropGrid: true,
            hideBottomControls: false,
          ),
          IOSUiSettings(
            title: 'Crop Image',
            aspectRatioLockEnabled: false,
            rotateButtonsHidden: false,
            resetButtonHidden: false,
            aspectRatioPickerButtonHidden: false,
          ),
        ],
      );

      if (!mounted || croppedFile == null) return;

      setState(() => _loading = true);

      final url = await _authService.uploadProfilePicture(
        _authService.currentUser!.uid,
        croppedFile.path,
      );

      if (!mounted) return;

      setState(() => _profilePicUrl = url);

      await _authService.saveFcmToken();


      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Profile picture updated!'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to upload profile picture: \${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _showUpdateUsernameDialog() {
    final controller = TextEditingController(text: _username);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Update Username'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(labelText: 'New Username'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context), 
            child: const Text('Cancel')
          ),
          ElevatedButton(
            onPressed: () async {
              final newName = controller.text.trim();
              if (newName.isEmpty) return;
              try {
                await _authService.updateUsername(newName, updateFirestore: true);

                await _authService.saveFcmToken();
                if (!mounted) return;
                setState(() => _username = newName);
                if (!mounted) return;
                Navigator.pop(context);
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Username updated!'), 
                    backgroundColor: Colors.green
                  ),
                );
              } catch (e) {
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Failed: \${e.toString()}'), 
                    backgroundColor: Colors.red
                  ),
                );
              }
            },
            child: const Text('Update'),
          ),
        ],
      ),
    );
  }

  void _showChangePasswordDialog() {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Change Password'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(labelText: 'New Password'),
          obscureText: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context), 
            child: const Text('Cancel')
          ),
          ElevatedButton(
            onPressed: () async {
              final newPassword = controller.text.trim();
              if (newPassword.length < 6) {
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Password must be at least 6 characters'))
                );
                return;
              }
              try {
                await _authService.changePassword(newPassword);
                if (!mounted) return;
                Navigator.pop(context);
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Password changed!'))
                );
              } catch (e) {
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Failed: \${e.toString()}'))
                );
              }
            },
            child: const Text('Change'),
          ),
        ],
      ),
    );
  }

  void _showDeleteAccountDialog() {
    final emailController = TextEditingController();
    final passwordController = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Account'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Enter your email and password to confirm.'),
            TextField(
              controller: emailController,
              decoration: const InputDecoration(labelText: 'Email'),
            ),
            TextField(
              controller: passwordController,
              decoration: const InputDecoration(labelText: 'Password'),
              obscureText: true,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context), 
            child: const Text('Cancel')
          ),
          ElevatedButton(
            onPressed: () async {
              final email = emailController.text.trim();
              final password = passwordController.text.trim();
              if (email.isEmpty || password.isEmpty) return;
              try {
                await _authService.deleteAccountAndData(email, password);
                if (!mounted) return;
                Navigator.pop(context);
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Account deleted.'), 
                    backgroundColor: Colors.green
                  ),
                );
                if (!mounted) return;
                Navigator.of(context).pushAndRemoveUntil(
                  MaterialPageRoute(builder: (context) => const LoginPage()),
                  (route) => false,
                );
              } catch (e) {
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Failed: \${e.toString()}'), 
                    backgroundColor: Colors.red
                  ),
                );
              }
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}
