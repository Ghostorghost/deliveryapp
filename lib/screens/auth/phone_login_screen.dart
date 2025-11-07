import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class PhoneLoginScreen extends StatefulWidget {
  const PhoneLoginScreen({super.key});

  @override
  State<PhoneLoginScreen> createState() => _PhoneLoginScreenState();
}

class _PhoneLoginScreenState extends State<PhoneLoginScreen> {
  final _phoneCtrl = TextEditingController();
  final _otpCtrl = TextEditingController();
  final FirebaseAuth _auth = FirebaseAuth.instance;

  String _verificationId = '';
  bool _otpSent = false;
  bool _isLoading = false;
  bool _awaitingRole = false;
  String _selectedRole = 'customer';

  void _sendOtp() async {
    setState(() => _isLoading = true);
    await _auth.verifyPhoneNumber(
      phoneNumber: _phoneCtrl.text.trim(),
      timeout: const Duration(seconds: 60),
      verificationCompleted: (PhoneAuthCredential credential) async {
        await _auth.signInWithCredential(credential);
        _checkOrSetupUser();
      },
      verificationFailed: (e) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Verification failed: ${e.message}")),
        );
      },
      codeSent: (verificationId, _) {
        setState(() {
          _verificationId = verificationId;
          _otpSent = true;
          _isLoading = false;
        });
      },
      codeAutoRetrievalTimeout: (id) {
        _verificationId = id;
      },
    );
  }

  void _verifyOtp() async {
    setState(() => _isLoading = true);
    try {
      final credential = PhoneAuthProvider.credential(
        verificationId: _verificationId,
        smsCode: _otpCtrl.text.trim(),
      );
      await _auth.signInWithCredential(credential);
      _checkOrSetupUser();
    } catch (e) {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("OTP verification failed: $e")),
      );
    }
  }

  void _checkOrSetupUser() async {
    final user = _auth.currentUser;
    if (user == null) return;

    final doc =
        await FirebaseFirestore.instance.collection('users').doc(user.uid).get();

    if (!doc.exists) {
      setState(() {
        _awaitingRole = true;
        _isLoading = false;
      });
    } else {
      final role = doc.data()?['role'] ?? 'customer';
      _navigateToRole(role);
    }
  }

  void _completeRegistration() async {
    final user = _auth.currentUser;
    if (user == null) return;

    await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
      'uid': user.uid,
      'phone': user.phoneNumber ?? '',
      'role': _selectedRole,
      'createdAt': FieldValue.serverTimestamp(),
    });

    _navigateToRole(_selectedRole);
  }

  void _navigateToRole(String role) {
    if (!mounted) return;
    Navigator.pushReplacementNamed(context, '/$role');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // 🌄 Background
          Container(
            decoration: const BoxDecoration(
              image: DecorationImage(
                image: AssetImage("assets/images/login_bg.jpg"),
                fit: BoxFit.cover,
              ),
            ),
          ),

          // 🟤 Optional dark overlay
          Container(color: Colors.black.withOpacity(0.4)),

          // 🪟 Card-based UI
          Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Card(
                elevation: 8,
                color: Colors.white.withOpacity(0.92),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: _awaitingRole
                      ? Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text("Select your role",
                                style: TextStyle(
                                    fontSize: 18, fontWeight: FontWeight.bold)),
                            const SizedBox(height: 16),
                            DropdownButtonFormField<String>(
                              value: _selectedRole,
                              decoration:
                                  const InputDecoration(labelText: 'Role'),
                              items: const [
                                DropdownMenuItem(
                                    value: 'customer', child: Text('Customer')),
                                DropdownMenuItem(
                                    value: 'agent', child: Text('Agent')),
                              ],
                              onChanged: (value) =>
                                  setState(() => _selectedRole = value!),
                            ),
                            const SizedBox(height: 20),
                            ElevatedButton(
                              onPressed:
                                  _isLoading ? null : _completeRegistration,
                              child: _isLoading
                                  ? const CircularProgressIndicator()
                                  : const Text("Continue"),
                            )
                          ],
                        )
                      : Column(
                          children: [
                            if (!_otpSent) ...[
                              TextField(
                                controller: _phoneCtrl,
                                decoration: const InputDecoration(
                                  labelText: 'Phone Number',
                                  hintText: '+234xxxxxxxxxx',
                                  border: OutlineInputBorder(),
                                ),
                                keyboardType: TextInputType.phone,
                              ),
                              const SizedBox(height: 20),
                              ElevatedButton(
                                onPressed: _isLoading ? null : _sendOtp,
                                child: _isLoading
                                    ? const CircularProgressIndicator()
                                    : const Text("Send OTP"),
                              ),
                            ] else ...[
                              TextField(
                                controller: _otpCtrl,
                                decoration: const InputDecoration(
                                  labelText: 'Enter OTP',
                                  border: OutlineInputBorder(),
                                ),
                                keyboardType: TextInputType.number,
                              ),
                              const SizedBox(height: 20),
                              ElevatedButton(
                                onPressed: _isLoading ? null : _verifyOtp,
                                child: _isLoading
                                    ? const CircularProgressIndicator()
                                    : const Text("Verify"),
                              ),
                            ]
                          ],
                        ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
