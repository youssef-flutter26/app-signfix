import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:http/http.dart' as http;

class AuthService {
  static const String baseUrl = 'https://signfix.me/api';

  // ✅ Ye exact Web Client ID tumhare google-services.json (client_type: 3) se liya gaya hai
  static const String _googleServerClientId =
      '531570390505-n86thi83hq0p9eirs5bf8ajo4j24ovkp.apps.googleusercontent.com';

  static Future<void> requestPhoneOtp({
    required String phoneNumber,
    required void Function(String verificationId, int? resendToken) onCodeSent,
    required Future<void> Function(PhoneAuthCredential credential)
        onVerificationCompleted,
    required void Function(String error) onError,
    required void Function(String verificationId) onAutoRetrievalTimeout,
    int? forceResendingToken,
  }) {
    return FirebaseAuth.instance.verifyPhoneNumber(
      phoneNumber: phoneNumber,
      forceResendingToken: forceResendingToken,
      verificationCompleted: onVerificationCompleted,
      verificationFailed: (error) =>
          onError(error.message ?? 'Phone verification failed.'),
      codeSent: onCodeSent,
      codeAutoRetrievalTimeout: onAutoRetrievalTimeout,
    );
  }

  static Future<String> signInWithPhoneCredential(
      PhoneAuthCredential credential) async {
    final userCredential =
        await FirebaseAuth.instance.signInWithCredential(credential);
    final idToken = await userCredential.user?.getIdToken();
    if (idToken == null || idToken.isEmpty) {
      throw Exception('Failed to get Firebase token.');
    }
    return idToken;
  }

  static Future<Map<String, dynamic>?> signInWithGoogle({
    String role = 'customer',
  }) async {
    try {
      // 1. Trigger Google Sign-In on device
      final GoogleSignIn googleSignIn = GoogleSignIn(
        scopes: ['email', 'profile'],
        serverClientId:
            _googleServerClientId, // ✅ Zaroori hai backend verification ke liye
      );

      // Purana session clear karo taake fresh login ho
      await googleSignIn.signOut();
      final GoogleSignInAccount? googleUser = await googleSignIn.signIn();

      if (googleUser == null) {
        return null; // User ne cancel kar diya
      }

      // 2. Obtain Google Auth details
      final GoogleSignInAuthentication googleAuth =
          await googleUser.authentication;

      // 3. Google ID Token (Ye backend ko bhejna hai, Firebase token se overwrite NA karein)
      final String? googleIdToken = googleAuth.idToken;

      if (googleIdToken == null || googleIdToken.isEmpty) {
        throw Exception(
            'Could not retrieve Google ID token. Check SHA-1 and OAuth setup.');
      }

      // 4. Optional: Firebase Auth state ko bhi sync kar lo (taake app me currentUser available ho)
      try {
        final AuthCredential credential = GoogleAuthProvider.credential(
          accessToken: googleAuth.accessToken,
          idToken: googleIdToken,
        );
        await FirebaseAuth.instance.signInWithCredential(credential);
      } catch (fbError) {
        debugPrint('⚠️ Firebase sync warning (non-fatal): $fbError');
      }

      // 5. Send GOOGLE ID Token to SignFix Backend
      final response = await http.post(
        Uri.parse('$baseUrl/auth/google'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'idToken':
              googleIdToken, // ✅ Backend ko Google ka original token bhejo
          'role': role,
          'portal': role,
          'email': googleUser.email,
          'name': googleUser.displayName ?? '',
        }),
      );

      final Map<String, dynamic> data = jsonDecode(response.body);

      if (response.statusCode == 200 || response.statusCode == 201) {
        final String token = data['token']?.toString() ?? '';
        final Map<String, dynamic> user =
            (data['user'] as Map<String, dynamic>?) ?? {};
        final bool isNewUser = data['isNewUser'] == true;

        return {
          'token': token,
          'user': user,
          'isNewUser': isNewUser,
        };
      } else {
        final String errMsg = data['error']?.toString() ??
            'Google authentication failed (${response.statusCode})';
        throw Exception(errMsg);
      }
    } catch (e) {
      debugPrint('❌ Google Sign-In Error: $e');
      rethrow;
    }
  }

  static Future<void> signOut() async {
    await GoogleSignIn().signOut();
    await FirebaseAuth.instance.signOut();
  }
}
