import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

class PhoneVerificationPage extends StatefulWidget {
  final String phoneNumber;
  final Function(String uid) onVerified;
  const PhoneVerificationPage({super.key, required this.phoneNumber, required this.onVerified});

  @override
  State<PhoneVerificationPage> createState() => _PhoneVerificationPageState();
}

class _PhoneVerificationPageState extends State<PhoneVerificationPage> {
  final TextEditingController _otpController = TextEditingController();
  String? _verificationId;
  bool _isLoading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _sendCode();
  }

  void _sendCode() async {
    setState(() { _isLoading = true; _error = null; });
    await FirebaseAuth.instance.verifyPhoneNumber(
      phoneNumber: widget.phoneNumber,
      verificationCompleted: (PhoneAuthCredential credential) async {
        // Auto-retrieval or instant verification
        await FirebaseAuth.instance.signInWithCredential(credential);
        widget.onVerified(FirebaseAuth.instance.currentUser!.uid);
      },
      verificationFailed: (FirebaseAuthException e) {
        setState(() { _error = e.message; _isLoading = false; });
      },
      codeSent: (String verificationId, int? resendToken) {
        setState(() { _verificationId = verificationId; _isLoading = false; });
      },
      codeAutoRetrievalTimeout: (String verificationId) {
        setState(() { _verificationId = verificationId; });
      },
    );
  }

  void _verifyCode() async {
    if (_verificationId == null) return;
    setState(() { _isLoading = true; _error = null; });
    try {
      final credential = PhoneAuthProvider.credential(
        verificationId: _verificationId!,
        smsCode: _otpController.text.trim(),
      );
      final userCredential = await FirebaseAuth.instance.signInWithCredential(credential);
      widget.onVerified(userCredential.user!.uid);
    } catch (e) {
      setState(() { _error = 'Invalid OTP or verification failed.'; _isLoading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Verify Phone')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('Enter the OTP sent to ${widget.phoneNumber}'),
            const SizedBox(height: 16),
            TextField(
              controller: _otpController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'OTP'),
            ),
            const SizedBox(height: 16),
            if (_error != null) Text(_error!, style: const TextStyle(color: Colors.red)),
            ElevatedButton(
              onPressed: _isLoading ? null : _verifyCode,
              child: _isLoading ? const CircularProgressIndicator() : const Text('Verify'),
            ),
            TextButton(
              onPressed: _isLoading ? null : _sendCode,
              child: const Text('Resend OTP'),
            ),
          ],
        ),
      ),
    );
  }
} 