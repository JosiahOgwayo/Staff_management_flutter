import 'package:flutter/material.dart';
import 'package:employee_app_new/auth_service.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:employee_app_new/pages/login_page.dart';
import 'package:image_cropper/image_cropper.dart';

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

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    setState(() => _loading = true);
    try {
      final user = _authService.currentUser;
      if (user != null) {
        final doc = await _authService.firestore.collection('users').doc(user.uid).get();
        if (mounted) {
          setState(() {
            _profilePicUrl = doc.data()?['profilePicture'];
            _username = doc.data()?['username'] ?? user.displayName ?? user.email;
            _email = doc.data()?['email'] ?? user.email;
            _staffNumber = doc.data()?['staffNumber'];
            _department = doc.data()?['department'];
            _yearJoined = doc.data()?['yearJoined'];
          });
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to load user data:  ${e.toString()}')));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
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
          toolbarColor: Colors.grey,
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

    // ✅ Exit early if crop was cancelled
    if (!mounted || croppedFile == null) return;

    setState(() => _loading = true);

    final url = await _authService.uploadProfilePicture(
      _authService.currentUser!.uid,
      croppedFile.path,
    );

    if (!mounted) return;

    setState(() {
      _profilePicUrl = url;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Profile picture updated!'),
        backgroundColor: Colors.green,
      ),
    );
  } catch (e) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to upload profile picture: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  } finally {
    if (mounted) setState(() => _loading = false);
  }
}



  String? getOptimizedCloudinaryUrl(String? url) {
    if (url == null || !url.contains('/upload/')) return url;
    return url.replaceFirst('/upload/', '/upload/w_200,h_200,c_fill/');
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
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              final newName = controller.text.trim();
              if (newName.isEmpty) return;
              try {
                await _authService.updateUsername(newName, updateFirestore: true);
                setState(() => _username = newName);
                if (mounted) Navigator.pop(context);
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Username updated!'), backgroundColor: Colors.green),
                  );
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Failed:  ${e.toString()}'), backgroundColor: Colors.red),
                  );
                }
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
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              final newPassword = controller.text.trim();
              if (newPassword.length < 6) {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Password must be at least 6 characters')));
                return;
              }
              try {
                await _authService.changePassword(newPassword);
                if (mounted) Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Password changed!')));
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed:  ${e.toString()}')));
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
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              final email = emailController.text.trim();
              final password = passwordController.text.trim();
              if (email.isEmpty || password.isEmpty) return;
              try {
                await _authService.deleteAccountAndData(email, password);
                if (mounted) Navigator.pop(context);
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Account deleted.'), backgroundColor: Colors.green),
                  );
                  // Navigate to login page and remove all previous routes
                  Navigator.of(context).pushAndRemoveUntil(
                    MaterialPageRoute(builder: (context) => const LoginPage()),
                    (route) => false,
                  );
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Failed:  ${e.toString()}'), backgroundColor: Colors.red),
                  );
                }
              }
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  Future<void> _logout() async {
    try {
      await _authService.signOut();
      if (mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (context) => const LoginPage()),
          (route) => false,
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to log out:  ${e.toString()}')));
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
                            placeholder: (context, url) => const CircleAvatar(radius: 60, child: CircularProgressIndicator()),
                            errorWidget: (context, url, error) => const CircleAvatar(radius: 60, child: Icon(Icons.error)),
                            imageBuilder: (context, imageProvider) => CircleAvatar(
                              radius: 60,
                              backgroundImage: imageProvider,
                            ),
                          )
                        : const CircleAvatar(radius: 60, child: Icon(Icons.person, size: 60)),
                  ),
                  const SizedBox(height: 12),
                  Text(_username ?? '', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Card(
                    margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 4),
                    child: Padding(
                      padding: const EdgeInsets.all(12.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Details', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                          const SizedBox(height: 8),
                          if (_email != null) Text('Email:  $_email'),
                          if (_staffNumber != null) Text('Staff Number: $_staffNumber'),
                          if (_department != null) Text('Department: $_department'),
                          if (_yearJoined != null) Text('Year Joined: $_yearJoined'),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  const Divider(),
                  const SizedBox(height: 12),
                  const Text('Settings', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
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
} 