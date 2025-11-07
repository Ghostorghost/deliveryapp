import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:flutter_facebook_auth/flutter_facebook_auth.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // General Register User (Customer or Agent)
 Future<User?> registerUser({
  required String name,
  required String email,
  required String password,
  required String phone,
  String? referralCode,
  required String role,
}) async {
  try {
    UserCredential cred = await _auth.createUserWithEmailAndPassword(
      email: email,
      password: password,
    );

    await _firestore.collection('users').doc(cred.user!.uid).set({
      'uid': cred.user!.uid,
      'name': name,
      'email': email,
      'phone': phone,
      'referralCode': referralCode ?? '',
      'role': role,
      'createdAt': FieldValue.serverTimestamp(),
    });

    return cred.user;
  } on FirebaseAuthException catch (e) {
    if (e.code == 'email-already-in-use') {
      throw FirebaseAuthException(
        code: e.code,
        message: 'This email is already in use. Try logging in.',
      );
    } else {
      throw FirebaseAuthException(code: e.code, message: e.message);
    }
  } catch (e) {
    throw Exception('Unexpected error: $e');
  }
}


  // Register agent (admin only – backend controlled)
  Future<User?> registerAgentByAdmin({
    required String name,
    required String email,
    required String password,
  }) async {
    try {
      final currentUser = _auth.currentUser;
      if (currentUser == null) throw Exception("No logged-in user");

      DocumentSnapshot currentUserDoc =
          await _firestore.collection('users').doc(currentUser.uid).get();

      if (!currentUserDoc.exists || currentUserDoc['role'] != 'admin') {
        throw Exception("Only admins can register agents");
      }

      UserCredential cred = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      await _firestore.collection('users').doc(cred.user!.uid).set({
        'uid': cred.user!.uid,
        'name': name,
        'email': email,
        'role': 'agent',
        'createdAt': FieldValue.serverTimestamp(),
      });

      return cred.user;
    } catch (e) {
      print("Register agent error: $e");
      return null;
    }
  }

  // Email & Password Login
  Future<User?> login({required String email, required String password}) async {
    try {
      UserCredential cred = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      return cred.user;
    } catch (e) {
      print("Login error: $e");
      return null;
    }
  }

  // Google Sign-In
  Future<User?> signInWithGoogle() async {
    try {
      final GoogleSignInAccount? googleUser = await GoogleSignIn().signIn();
      if (googleUser == null) return null;

      final GoogleSignInAuthentication googleAuth =
          await googleUser.authentication;

      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      UserCredential cred = await _auth.signInWithCredential(credential);

      final doc =
          await _firestore.collection('users').doc(cred.user!.uid).get();

      if (!doc.exists) {
        await _firestore.collection('users').doc(cred.user!.uid).set({
          'uid': cred.user!.uid,
          'name': cred.user!.displayName ?? '',
          'email': cred.user!.email,
          'phone': '',
          'referralCode': '',
          'role': 'customer',
          'createdAt': FieldValue.serverTimestamp(),
        });
      }

      return cred.user;
    } catch (e) {
      print("Google sign-in error: $e");
      return null;
    }
  }

  // Facebook Sign-In
  Future<User?> signInWithFacebook() async {
    try {
      final LoginResult result = await FacebookAuth.instance.login();

      if (result.status == LoginStatus.success) {
        final accessToken = result.accessToken;
        final facebookAuthCredential =
            FacebookAuthProvider.credential(accessToken!.tokenString);

        UserCredential cred =
            await _auth.signInWithCredential(facebookAuthCredential);

        final doc =
            await _firestore.collection('users').doc(cred.user!.uid).get();

        if (!doc.exists) {
          await _firestore.collection('users').doc(cred.user!.uid).set({
            'uid': cred.user!.uid,
            'name': cred.user!.displayName ?? '',
            'email': cred.user!.email,
            'phone': '',
            'referralCode': '',
            'role': 'customer',
            'createdAt': FieldValue.serverTimestamp(),
          });
        }

        return cred.user;
      }
    } catch (e) {
      print("Facebook sign-in error: $e");
    }

    return null;
  }

  // Get user role
  Future<String?> getUserRole(String uid) async {
    try {
      DocumentSnapshot doc =
          await _firestore.collection('users').doc(uid).get();
      return doc['role'];
    } catch (e) {
      print("Error fetching user role: $e");
      return null;
    }
  }

  // Logout
  Future<void> logout() async {
    await _auth.signOut();
  }
}