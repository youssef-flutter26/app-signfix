import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class AuthService {
  static const String baseUrl = 'https://signfix.me';

  // Google Sign-In initialization with serverClientId
  static Future<void>? _googleSignInInitialization;

  static Future<void> _initializeGoogleSignIn() {
    return _googleSignInInitialization ??= GoogleSignIn.instance.initialize(
      // تمرير الـ Web Client ID الخاص بمشروع signfix-feb4b لمنع إيرور الأندرويد
      serverClientId: '531570390505.apps.googleusercontent.com',
    );
  }

  static Future<void> signInWithGoogle({
    String role = 'customer',
  }) async {
    try {
      // 1. Initialize Google Sign-In
      await _initializeGoogleSignIn();

      // 2. Sign in with Google
      final GoogleSignInAccount googleUser =
          await GoogleSignIn.instance.authenticate();

      // 3. Get Google Authentication
      final GoogleSignInAuthentication googleAuth = googleUser.authentication;

      final String? idToken = googleAuth.idToken;

      if (idToken == null) {
        throw Exception('Google ID Token is null');
      }

      // 4. Create Firebase Credential
      final AuthCredential credential = GoogleAuthProvider.credential(
        idToken: idToken,
      );

      // 5. Sign in to Firebase
      final UserCredential userCredential =
          await FirebaseAuth.instance.signInWithCredential(
        credential,
      );

      final User? firebaseUser = userCredential.user;

      if (firebaseUser == null) {
        throw Exception('Firebase user is null');
      }

      // 6. Get Firebase ID Token
      final String? firebaseIdToken = await firebaseUser.getIdToken();

      if (firebaseIdToken == null) {
        throw Exception('Could not retrieve Firebase ID token');
      }

      // 7. Send Token to Backend
      final response = await http.post(
        Uri.parse('$baseUrl/api/auth/google'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: jsonEncode({
          'idToken': firebaseIdToken,
          'role': role,
        }),
      );

      // 8. Handle Backend Response
      dynamic responseData;

      try {
        responseData = jsonDecode(response.body);
      } catch (_) {
        responseData = null;
      }

      if (response.statusCode != 200 && response.statusCode != 201) {
        String errorMessage = 'Authentication failed';

        if (responseData is Map) {
          errorMessage = responseData['error']?.toString() ??
              responseData['message']?.toString() ??
              errorMessage;
        }

        throw Exception(
          '$errorMessage (Status: ${response.statusCode})',
        );
      }

      print('Google Sign-In Successful');
      print('Backend Response: ${response.body}');
    } catch (e) {
      print('Google Sign-In Error: $e');
      rethrow;
    }
  }
}
