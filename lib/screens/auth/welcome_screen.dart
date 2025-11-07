import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../common/role_based_redirect.dart';

class WelcomeScreen extends StatefulWidget {
  const WelcomeScreen({super.key});

  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen> {
  @override
  void initState() {
    super.initState();
    _checkUserStatusAndRedirect();
  }

  void _checkUserStatusAndRedirect() {
    // Listen to the user's authentication state changes
    FirebaseAuth.instance.authStateChanges().listen((User? user) {
      if (user != null) {
        // If a user is logged in, immediately redirect them
        // This replaces the WelcomeScreen so the user can't press back to it
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (context) => const RoleBasedRedirect(),
          ),
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Full-screen background image centered
          Positioned.fill(
            child: Center(
              child: Image.asset(
                'assets/images/login_bg.png',
                fit: BoxFit.contain, // Center and maintain aspect ratio
                width: MediaQuery.of(context).size.width,
                height: MediaQuery.of(context).size.height,
                alignment: Alignment.center,
              ),
            ),
          ),

          // Semi-transparent overlay for readability
          Positioned.fill(
            child: Container(color: Colors.black.withOpacity(0.4)),
          ),

          // Content
          Positioned.fill(
            child: SafeArea(
              child: Center(
                child: SizedBox(
                  width: 500,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.start,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        const SizedBox(height: 48),
                        const Text(
                          'Welcome',
                          style: TextStyle(
                            color: Color.fromARGB(255, 4, 109, 9),
                            fontSize: 38,
                            fontWeight: FontWeight.bold,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 6),
                        const Text(
                          'Get your Package delivered in no time\n'
                          'with LogiDelivery',
                          style: TextStyle(
                            color: Color.fromARGB(213, 0, 0, 0),
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 48),
                        const Spacer(),

                        // Login Button
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            // Use pushReplacementNamed to prevent returning to WelcomeScreen
                            onPressed: () => Navigator.of(context).pushReplacementNamed('/login'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.lightGreenAccent[700],
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(50),
                              ),
                            ),
                            child: const Text(
                              'Login',
                              style: TextStyle(fontSize: 18, color: Colors.white),
                            ),
                          ),
                        ),

                        const SizedBox(height: 16),

                        // Sign Up Button
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton(
                            // Use pushReplacementNamed to prevent returning to WelcomeScreen
                            onPressed: () => Navigator.of(context).pushReplacementNamed('/register'),
                            style: OutlinedButton.styleFrom(
                              side: const BorderSide(color: Color.fromRGBO(172, 170, 79, 0.949)),
                              backgroundColor: const Color.fromARGB(255, 218, 215, 204),
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(50),
                              ),
                            ),
                            child: const Text(
                              'Sign Up',
                              style: TextStyle(fontSize: 18, color: Colors.black),
                            ),
                          ),
                        ),
                        const SizedBox(height: 48),
                      ],
                    ),
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