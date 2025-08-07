// ignore_for_file: use_build_context_synchronously

import 'package:flutter/material.dart';
import 'package:employee_app_new/pages/login_page.dart';
import 'package:employee_app_new/auth_service.dart';
import 'package:employee_app_new/pages/phone_verification_page.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

class SignupPage extends StatefulWidget {
  const SignupPage({super.key});

  @override
  State<SignupPage> createState() => _SignupPageState();
}

class _SignupPageState extends State<SignupPage> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _firstNameController = TextEditingController();
  final TextEditingController _secondNameController = TextEditingController();
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmPasswordController = TextEditingController();
  String? _selectedGender;
  String? _selectedDepartment;
  bool _isCheckingVerification = false;
  bool _isRegistering = false;
  String? _registrationError;

  @override
  void dispose() {
    _emailController.dispose();
    _phoneController.dispose();
    _firstNameController.dispose();
    _secondNameController.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  void _register() {
    if (_formKey.currentState!.validate()) {
      setState(() {
        _isRegistering = true;
        _registrationError = null;
      });
      final email = _emailController.text.trim();
      final password = _passwordController.text.trim();
      
      _performRegistration(email, password).whenComplete(() {
        if (mounted) setState(() => _isRegistering = false);
      });
    }
  }

  Future<void> _performRegistration(String email, String password) async {
    try {
      final userCredential = await AuthService().createAccount(email: email, password: password, username: _usernameController.text.trim());
      // Save FCM token after successful signup
      await AuthService().saveFcmToken();

      final user = userCredential.user;
      if (user != null && !user.emailVerified) {
        await user.sendEmailVerification();
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Verification email sent. Please check your inbox.'), backgroundColor: Colors.blue),
        );
        _showEmailVerificationDialog(user);
        return;
      }

      if (!mounted) return;

      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) => PhoneVerificationPage(
            phoneNumber: _phoneController.text.trim(),
            onVerified: (uid) async {
              final staffNumber = await _generateStaffNumber(
                department: _selectedDepartment!,
                year: DateTime.now().year,
              );

              final fcmToken = await FirebaseMessaging.instance.getToken();

              final userInfo = {
                'email': _emailController.text.trim(),
                'phone': _phoneController.text.trim(),
                'firstName': _firstNameController.text.trim(),
                'secondName': _secondNameController.text.trim(),
                'username': _usernameController.text.trim(),
                'gender': _selectedGender,
                'department': _selectedDepartment,
                'createdAt': DateTime.now().toIso8601String(),
                'staffNumber': staffNumber,
                'yearJoined': DateTime.now().year,
                'fcmToken': fcmToken, // Save FCM token
                'role': 'user',
              };

              try {
                await AuthService().saveUserInfo(uid: uid, data: userInfo);
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Registration successful! Please login.'), backgroundColor: Colors.green),
                );
                await Future.delayed(const Duration(seconds: 1));
                if (!mounted) return;
                await Navigator.of(context).pushAndRemoveUntil(
                  MaterialPageRoute(builder: (context) => const LoginPage()),
                  (route) => false,
                );
              } catch (e) {
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Failed to save user info: ${e.toString()}'), backgroundColor: Colors.red),
                );
              }
            },
          ),
        ),
      );
    } on FirebaseAuthException catch (e) {
      String message;
      switch (e.code) {
        case 'email-already-in-use':
          message = 'This email is already registered.';
          break;
        case 'invalid-email':
          message = 'The email address is invalid.';
          break;
        case 'weak-password':
          message = 'The password is too weak.';
          break;
        case 'network-request-failed':
          message = 'Network error. Please check your connection.';
          break;
        default:
          message = 'Registration failed: ${e.message ?? e.code}';
      }
      if (!mounted) return;
      setState(() {
        _registrationError = message;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message), backgroundColor: Colors.red),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _registrationError = 'Registration failed: ${e.toString()}';
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Registration failed: ${e.toString()}'), backgroundColor: Colors.red),
      );
    }
  }

  void _showEmailVerificationDialog(User user) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            bool isResending = false;
            return AlertDialog(
              title: const Text('Verify Your Email'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('A verification link has been sent to your email. Please verify your email before continuing.'),
                  if (_isCheckingVerification)
                    const Padding(
                      padding: EdgeInsets.only(top: 16),
                      child: CircularProgressIndicator(),
                    ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: isResending
                      // ignore: dead_code
                      ? null
                      : () async {
                          setState(() => isResending = true);
                          try {
                            await user.sendEmailVerification();
                            if (!context.mounted) return;
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Verification email resent.'), backgroundColor: Colors.green),
                            );
                          } catch (e) {
                            if (!context.mounted) return;
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Failed to resend email: ${e.toString()}'), backgroundColor: Colors.red),
                            );
                          }
                          if (!context.mounted) return;
                          setState(() => isResending = false);
                        },
                  child: isResending
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Text('Resend Email'),
                ),
                TextButton(
                  onPressed: () async {
                    setState(() => _isCheckingVerification = true);
                    try {
                      await user.reload();
                      final refreshedUser = AuthService().firebaseAuth.currentUser;
                      if (refreshedUser != null && refreshedUser.emailVerified) {
                        if (!context.mounted) return;
                        Navigator.of(context).pop();
                        await Navigator.of(context).pushReplacement(
                          MaterialPageRoute(
                            builder: (context) => PhoneVerificationPage(
                              phoneNumber: _phoneController.text.trim(),
                              onVerified: (uid) async {
                                final staffNumber = await _generateStaffNumber(
                                  department: _selectedDepartment!,
                                  year: DateTime.now().year,
                                );

                                final fcmToken = await FirebaseMessaging.instance.getToken();

                                final userInfo = {
                                  'email': _emailController.text.trim(),
                                  'phone': _phoneController.text.trim(),
                                  'firstName': _firstNameController.text.trim(),
                                  'secondName': _secondNameController.text.trim(),
                                  'username': _usernameController.text.trim(),
                                  'gender': _selectedGender,
                                  'department': _selectedDepartment,
                                  'createdAt': DateTime.now().toIso8601String(),
                                  'staffNumber': staffNumber,
                                  'yearJoined': DateTime.now().year,
                                  'fcmToken': fcmToken,
                                  'role': 'user',
                                };

                                try {
                                  await AuthService().saveUserInfo(uid: uid, data: userInfo);
                                  if (!mounted) return;
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text('Registration successful! Please login.'), backgroundColor: Colors.green),
                                  );
                                  await Future.delayed(const Duration(seconds: 1));
                                  if (!mounted) return;
                                  await Navigator.of(context).pushReplacement(
                                    MaterialPageRoute(builder: (context) => const LoginPage()),
                                  );
                                } catch (e) {
                                  if (!mounted) return;
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text('Failed to save user info: ${e.toString()}'), backgroundColor: Colors.red),
                                  );
                                }
                              },
                            ),
                          ),
                        );
                      } else {
                        if (!context.mounted) return;
                        setState(() => _isCheckingVerification = false);
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Email not verified yet. Please check your inbox.'), backgroundColor: Colors.orange),
                        );
                      }
                    } catch (e) {
                      if (!context.mounted) return;
                      setState(() => _isCheckingVerification = false);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Error checking verification: ${e.toString()}'), backgroundColor: Colors.red),
                      );
                    }
                  },
                  child: const Text('I have verified'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<String> _generateStaffNumber({required String department, required int year}) async {
    final departmentCodes = {
      'finance': 'F',
      'hr': 'H',
      'it': 'IT',
      'chef': 'C',
      'cleaner': 'CL',
    };
    final deptCode = departmentCodes[department.toLowerCase()] ?? department.substring(0, 2).toUpperCase();
    final trackerDoc = FirebaseFirestore.instance.collection('staff_number_tracker').doc('$deptCode-$year');
    return FirebaseFirestore.instance.runTransaction((transaction) async {
      final snapshot = await transaction.get(trackerDoc);
      int lastNumber = 0;
      if (snapshot.exists) {
        lastNumber = snapshot.data()?["lastNumber"] ?? 0;
      }
      final newNumber = lastNumber + 1;
      transaction.set(trackerDoc, {"lastNumber": newNumber}, SetOptions(merge: true));
      return 'B$deptCode-${newNumber.toString().padLeft(3, '0')}-$year';
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Sign Up')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              TextFormField(
                controller: _usernameController,
                decoration: const InputDecoration(labelText: 'Username'),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter a username';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _emailController,
                decoration: const InputDecoration(labelText: 'Email'),
                keyboardType: TextInputType.emailAddress,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter your email';
                  }
                  if (!RegExp(r'^[^@]+@[^@]+\.[^@]+').hasMatch(value)) {
                    return 'Enter a valid email';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _phoneController,
                decoration: const InputDecoration(labelText: 'Phone Number'),
                keyboardType: TextInputType.phone,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter your phone number';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _firstNameController,
                decoration: const InputDecoration(labelText: 'First Name'),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter your first name';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _secondNameController,
                decoration: const InputDecoration(labelText: 'Second Name'),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter your second name';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: _selectedGender,
                decoration: const InputDecoration(labelText: 'Gender'),
                items: const [
                  DropdownMenuItem(value: 'male', child: Text('Male')),
                  DropdownMenuItem(value: 'female', child: Text('Female')),
                  DropdownMenuItem(value: 'other', child: Text('Other')),
                ],
                onChanged: (value) {
                  setState(() {
                    _selectedGender = value;
                  });
                },
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please select your gender';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: _selectedDepartment,
                decoration: const InputDecoration(labelText: 'Department'),
                items: const [
                  DropdownMenuItem(value: 'finance', child: Text('Finance')),
                  DropdownMenuItem(value: 'hr', child: Text('HR')),
                  DropdownMenuItem(value: 'it', child: Text('IT')),
                  DropdownMenuItem(value: 'chef', child: Text('Chef')),
                  DropdownMenuItem(value: 'cleaner', child: Text('Cleaner')),
                ],
                onChanged: (value) {
                  setState(() {
                    _selectedDepartment = value;
                  });
                },
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please select your department';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _passwordController,
                decoration: const InputDecoration(labelText: 'Password'),
                obscureText: true,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter a password';
                  }
                  if (value.length < 6) {
                    return 'Password must be at least 6 characters';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _confirmPasswordController,
                decoration: const InputDecoration(labelText: 'Confirm Password'),
                obscureText: true,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please retype your password';
                  }
                  if (value != _passwordController.text) {
                    return 'Passwords do not match';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: _isRegistering ? null : _register,
                child: _isRegistering 
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)) 
                    : const Text('Register'),
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text('Already have an account? '),
                  TextButton(
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (context) => const LoginPage(),
                        ),
                      );
                    },
                    child: const Text('Login'),
                  ),
                ],
              ),
              if (_registrationError != null) ...[
                Padding(
                  padding: const EdgeInsets.only(bottom: 8.0),
                  child: Text(_registrationError!, style: const TextStyle(color: Colors.red)),
                ),
              ],
            ],
          ),
        ),
),
);
  }
}
