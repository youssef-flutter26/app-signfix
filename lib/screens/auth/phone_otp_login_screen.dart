import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/app_theme.dart';
import '../../services/auth_service.dart';

class PhoneOtpLoginScreen extends StatefulWidget {
  const PhoneOtpLoginScreen({
    super.key,
    required this.authenticate,
    required this.onAuthenticated,
  });

  final Future<void> Function(String idToken, String name) authenticate;
  final VoidCallback onAuthenticated;

  @override
  State<PhoneOtpLoginScreen> createState() => _PhoneOtpLoginScreenState();
}

class _PhoneOtpLoginScreenState extends State<PhoneOtpLoginScreen> {
  // India. (For Pakistan testing use '+92' and r'^3\d{9}$'.)
  static const _countryCode = '+91';
  static final _numberPattern = RegExp(r'^[6-9]\d{9}$');
  final _phone = TextEditingController();
  final _name = TextEditingController();
  final _otp = TextEditingController();
  String? _verificationId;
  int? _resendToken;
  String? _error;
  bool _codeSent = false;
  bool _loading = false;
  bool _processingCredential = false;

  @override
  void dispose() {
    _phone.dispose();
    _name.dispose();
    _otp.dispose();
    super.dispose();
  }

  Future<void> _sendOtp({bool resend = false}) async {
    FocusScope.of(context).unfocus();
    final phone = _phone.text.trim();
    if (!_numberPattern.hasMatch(phone)) {
      setState(() => _error = 'Enter a valid 10-digit mobile number.');
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await AuthService.requestPhoneOtp(
        phoneNumber: '$_countryCode$phone',
        forceResendingToken: resend ? _resendToken : null,
        onCodeSent: (verificationId, resendToken) {
          if (!mounted) return;
          setState(() {
            _verificationId = verificationId;
            _resendToken = resendToken;
            _codeSent = true;
            _loading = false;
          });
        },
        onVerificationCompleted: _signInWithCredential,
        onError: (message) {
          if (!mounted) return;
          setState(() {
            _error = message;
            _loading = false;
          });
        },
        onAutoRetrievalTimeout: (verificationId) {
          _verificationId = verificationId;
        },
      );
    } on FirebaseAuthException catch (error) {
      if (mounted) {
        setState(() {
          _error = error.message ?? 'Phone verification failed.';
          _loading = false;
        });
      }
    } catch (error) {
      if (mounted) {
        setState(() {
          _error = error.toString().replaceFirst('Exception: ', '');
          _loading = false;
        });
      }
    }
  }

  Future<void> _verifyOtp() async {
    final verificationId = _verificationId;
    if (verificationId == null) {
      setState(() => _error = 'Request a verification code first.');
      return;
    }
    final code = _otp.text.trim();
    if (!RegExp(r'^\d{6}$').hasMatch(code)) {
      setState(() => _error = 'Enter the 6-digit verification code.');
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final credential = PhoneAuthProvider.credential(
        verificationId: verificationId,
        smsCode: code,
      );
      await _signInWithCredential(credential);
    } on FirebaseAuthException catch (error) {
      if (mounted) {
        setState(() {
          _error = error.message ?? 'The verification code is invalid.';
          _loading = false;
        });
      }
    } catch (error) {
      if (mounted) {
        setState(() {
          _error = error.toString().replaceFirst('Exception: ', '');
          _loading = false;
        });
      }
    }
  }

  Future<void> _signInWithCredential(PhoneAuthCredential credential) async {
    if (_processingCredential) return;
    _processingCredential = true;
    if (mounted) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }
    try {
      final idToken = await AuthService.signInWithPhoneCredential(credential);
      await widget.authenticate(idToken, _name.text.trim());
      if (mounted) {
        // This screen is pushed on top of the login page, so close it before
        // the app swaps to the signed-in home; otherwise the spinner stays.
        setState(() => _loading = false);
        Navigator.of(context).popUntil((route) => route.isFirst);
        widget.onAuthenticated();
      }
    } catch (error) {
      if (mounted) {
        setState(() {
          _error = error.toString().replaceFirst('Exception: ', '');
          _loading = false;
        });
      }
    } finally {
      _processingCredential = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.softGray,
      appBar: AppBar(
        backgroundColor: AppColors.navy,
        title: const Text('Phone number login'),
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 430),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Icon(Icons.sms_outlined,
                      size: 56, color: AppColors.gold),
                  const SizedBox(height: 16),
                  const Text(
                    'Sign in with your phone',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: AppColors.navy,
                      fontSize: 23,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'We will send a one-time verification code by SMS.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: AppColors.textLight),
                  ),
                  const SizedBox(height: 28),
                  TextField(
                    controller: _phone,
                    enabled: !_codeSent && !_loading,
                    keyboardType: TextInputType.phone,
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                      LengthLimitingTextInputFormatter(10),
                    ],
                    decoration: const InputDecoration(
                      labelText: 'Mobile number',
                      prefixText: '$_countryCode ',
                      prefixIcon: Icon(Icons.phone_android),
                    ),
                  ),
                  if (!_codeSent) ...[
                    const SizedBox(height: 12),
                    TextField(
                      controller: _name,
                      enabled: !_loading,
                      textCapitalization: TextCapitalization.words,
                      decoration: const InputDecoration(
                        labelText: 'Name (optional)',
                        prefixIcon: Icon(Icons.person_outline),
                      ),
                    ),
                  ],
                  if (_codeSent) ...[
                    const SizedBox(height: 16),
                    TextField(
                      controller: _otp,
                      enabled: !_loading,
                      keyboardType: TextInputType.number,
                      textInputAction: TextInputAction.done,
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                        LengthLimitingTextInputFormatter(6),
                      ],
                      onSubmitted: (_) => _verifyOtp(),
                      decoration: const InputDecoration(
                        labelText: '6-digit verification code',
                        prefixIcon: Icon(Icons.lock_outline),
                      ),
                    ),
                  ],
                  if (_error != null) ...[
                    const SizedBox(height: 14),
                    Text(
                      _error!,
                      style: const TextStyle(
                        color: AppColors.danger,
                        fontSize: 13,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                  const SizedBox(height: 20),
                  FilledButton(
                    onPressed: _loading
                        ? null
                        : _codeSent
                            ? _verifyOtp
                            : _sendOtp,
                    child: _loading
                        ? const SizedBox.square(
                            dimension: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: AppColors.navy,
                            ),
                          )
                        : Text(_codeSent ? 'Verify and sign in' : 'Send OTP'),
                  ),
                  if (_codeSent)
                    TextButton(
                      onPressed: _loading ? null : () => _sendOtp(resend: true),
                      child: const Text('Resend code'),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
