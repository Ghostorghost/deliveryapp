import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:LogiDelivery/core/services/auth_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:LogiDelivery/screens/auth/phone_login_screen.dart';
import 'package:LogiDelivery/screens/auth/register_screen.dart';

class LoginScreen extends StatefulWidget {
  final void Function(ThemeMode)? onThemeChanged;

  const LoginScreen({super.key, this.onThemeChanged});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final emailController = TextEditingController();
  final passwordController = TextEditingController();
  final authService = AuthService();
  bool isLoading = false;

  void loginUser() async {
    setState(() => isLoading = true);
    try {
      User? user = await authService.login(
        email: emailController.text.trim(),
        password: passwordController.text.trim(),
      );

      if (user == null) {
        throw Exception("Invalid credentials.");
      }

      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

      if (!userDoc.exists) throw Exception("Profile not found");

      final role = userDoc.data()?['role'] ?? 'customer';
      _navigateToRole(role);
    } catch (e) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text("Login failed: $e")));
    } finally {
      setState(() => isLoading = false);
    }
  }

  void loginWithGoogle() async {
    setState(() => isLoading = true);
    try {
      final user = await authService.signInWithGoogle();
      if (user == null) throw Exception("Google sign-in canceled");

      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

      final role = doc.data()?['role'] ?? 'customer';
      _navigateToRole(role);
    } catch (e) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text("Google login failed: $e")));
    } finally {
      setState(() => isLoading = false);
    }
  }

  void loginWithFacebook() async {
    setState(() => isLoading = true);
    try {
      final user = await authService.signInWithFacebook();
      if (user == null) throw Exception("Facebook sign-in canceled");

      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

      final role = doc.data()?['role'] ?? 'customer';
      _navigateToRole(role);
    } catch (e) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text("Facebook login failed: $e")));
    } finally {
      setState(() => isLoading = false);
    }
  }

  void _navigateToRole(String role) {
    String route = role == 'admin'
        ? '/admin'
        : role == 'agent'
            ? '/agent'
            : '/customer';
    Navigator.pushReplacementNamed(context, route);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Background
          Container(
            decoration: const BoxDecoration(
              image: DecorationImage(
                image: AssetImage("assets/images/login_bg.png"),
                fit: BoxFit.contain,
              ),
            ),
          ),
          // Card form
          Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Card(
                elevation: 8,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                color: Colors.white.withOpacity(0.95),
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text(
                        "Welcome Back",
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Color.fromARGB(255, 97, 185, 14),
                        ),
                      ),
                      const SizedBox(height: 24),
                      TextField(
                        controller: emailController,
                        decoration: const InputDecoration(
                          labelText: 'Email',
                          prefixIcon: Icon(Icons.email),
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: passwordController,
                        decoration: const InputDecoration(
                          labelText: 'Password',
                          prefixIcon: Icon(Icons.lock),
                          border: OutlineInputBorder(),
                        ),
                        obscureText: true,
                      ),
                      const SizedBox(height: 24),
                      isLoading
                          ? const CircularProgressIndicator()
                          : ElevatedButton(
                              onPressed: loginUser,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.lightGreenAccent[700],
                                // Reduce vertical and horizontal padding
                                padding: const EdgeInsets.symmetric(
                                    vertical: 10, horizontal: 30), // Reduced from 14 and 80
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              child: const Text(
                                'Login',
                                style: TextStyle(
                                    fontSize: 14, color: Colors.white), // Reduced from 16
                              ),
                            ),
                      const SizedBox(height: 20),
                      const Text("Or login with",
                        style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: Color.fromARGB(255, 97, 185, 14),
                            ),
                          ),
                      const SizedBox(height: 10),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          IconButton(
                            icon: const FaIcon(FontAwesomeIcons.google,
                                color: Colors.redAccent, size: 32),
                            onPressed: loginWithGoogle,
                            tooltip: "Login with Google",
                          ),
                          const SizedBox(width: 20),
                          IconButton(
                            icon: const FaIcon(FontAwesomeIcons.facebook,
                                color: Colors.blueAccent, size: 32),
                            onPressed: loginWithFacebook,
                            tooltip: "Login with Facebook",
                          ),
                          const SizedBox(width: 20),
                          IconButton(
                            icon: const Icon(Icons.phone,
                                size: 30, color: Colors.green),
                            tooltip: "Login with Phone",
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => const PhoneLoginScreen(),
                                ),
                              );
                            },
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      TextButton(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const RegisterPage(),
                            ),
                          );
                        },
                        child:
                            const Text("Don't have an account? Sign Up here",
                            style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Color.fromARGB(255, 97, 185, 14),
                          ),
                        ),
                      ),
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
