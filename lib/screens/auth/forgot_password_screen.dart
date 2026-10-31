import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../../core/app_theme.dart';
import '../../services/api_client.dart';
import '../../technician/services/api_client.dart' as tech;
import '../../widgets/common.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({
    super.key,
    this.customerApi,
    this.technicianApi,
    this.initialEmail,
    this.portalName = 'Customer',
  }) : assert(
          customerApi != null || technicianApi != null,
          'Either customerApi or technicianApi must be provided.',
        );

  final ApiClient? customerApi;
  final tech.TechnicianApi? technicianApi;
  final String? initialEmail;
  final String portalName;

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  int _currentStep = 1;
  bool _isPhoneMode = false;

  final _emailCtl = TextEditingController();
  final _phoneCtl = TextEditingController();
  String? _inputError;

  final FirebaseAuth _auth = FirebaseAuth.instance;
  String? _verificationId;

  final List<TextEditingController> _otpCtls =
      List.generate(6, (_) => TextEditingController());
  final List<FocusNode> _otpNodes = List.generate(6, (_) => FocusNode());
  int _resendCountdown = 60;
  Timer? _countdownTimer;
  String? _resetToken;

  final _passwordCtl = TextEditingController();
  final _confirmPasswordCtl = TextEditingController();
  bool _obscurePassword = true;
  bool _obscureConfirm = true;
  String? _passwordError;
  String? _confirmError;

  bool _loading = false;
  String? _generalError;
  String? _successMessage;

  @override
  void initState() {
    super.initState();
    if (widget.initialEmail != null && widget.initialEmail!.trim().isNotEmpty) {
      _emailCtl.text = widget.initialEmail!.trim();
    }
    for (final n in _otpNodes) {
      n.addListener(() {
        if (mounted) setState(() {});
      });
    }
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    _emailCtl.dispose();
    _phoneCtl.dispose();
    for (final c in _otpCtls) {
      c.dispose();
    }
    for (final n in _otpNodes) {
      n.dispose();
    }
    _passwordCtl.dispose();
    _confirmPasswordCtl.dispose();
    super.dispose();
  }

  void _startCountdown() {
    _countdownTimer?.cancel();
    setState(() => _resendCountdown = 60);
    _countdownTimer = Timer.periodic(
      const Duration(seconds: 1),
      (timer) {
        if (!mounted) {
          timer.cancel();
          return;
        }
        if (_resendCountdown > 0) {
          setState(() => _resendCountdown--);
        } else {
          timer.cancel();
        }
      },
    );
  }

  String get _otpValue => _otpCtls.map((c) => c.text).join();

  Future<void> _sendOtp() async {
    FocusScope.of(context).unfocus();
    setState(() {
      _inputError = null;
      _generalError = null;
    });

    if (_isPhoneMode) {
      final phone = _phoneCtl.text.trim();
      if (phone.isEmpty) {
        setState(() => _inputError = 'Please enter your phone number.');
        return;
      }

      setState(() => _loading = true);
      try {
        await _auth.verifyPhoneNumber(
          phoneNumber: phone,
          verificationCompleted: (PhoneAuthCredential credential) async {
            await _signInWithPhoneCredential(credential);
          },
          verificationFailed: (FirebaseAuthException e) {
            setState(() {
              _generalError = e.message ?? 'Phone verification failed';
              _loading = false;
            });
          },
          codeSent: (String verificationId, int? resendToken) {
            setState(() {
              _verificationId = verificationId;
              _currentStep = 2;
              _loading = false;
              _generalError = null;
            });
            _startCountdown();
          },
          codeAutoRetrievalTimeout: (String verificationId) {
            _verificationId = verificationId;
          },
        );
      } catch (e) {
        setState(() {
          _generalError = e.toString();
          _loading = false;
        });
      }
    } else {
      final email = _emailCtl.text.trim();
      if (email.isEmpty) {
        setState(() => _inputError = 'Please enter your email address.');
        return;
      }
      if (!email.contains('@') || !email.contains('.')) {
        setState(() => _inputError = 'Please enter a valid email address.');
        return;
      }

      setState(() => _loading = true);
      try {
        if (widget.customerApi != null) {
          await widget.customerApi!.forgotPassword(email);
        } else {
          await widget.technicianApi!.forgotPassword(email);
        }
        if (!mounted) return;
        setState(() {
          _currentStep = 2;
          _generalError = null;
        });
        _startCountdown();
      } on ApiException catch (e) {
        if (!mounted) return;
        setState(() {
          if (e.message.toLowerCase().contains('email') ||
              e.message.toLowerCase().contains('account')) {
            _inputError = e.message;
          } else {
            _generalError = e.message;
          }
        });
      } catch (e) {
        if (!mounted) return;
        setState(() => _generalError = e.toString());
      } finally {
        if (mounted) setState(() => _loading = false);
      }
    }
  }

  Future<void> _signInWithPhoneCredential(
      PhoneAuthCredential credential) async {
    try {
      UserCredential userCredential =
          await _auth.signInWithCredential(credential);
      String? idToken = await userCredential.user?.getIdToken();
      if (idToken != null) {
        await _verifyPhoneBackend(idToken);
      }
    } catch (e) {
      setState(() => _generalError = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _verifyPhoneBackend(String idToken) async {
    final response = await http.post(
      Uri.parse("https://signfix.me/api/auth/firebase-phone"),
      headers: {"Content-Type": "application/json"},
      body: jsonEncode({
        "idToken": idToken,
        "role": widget.portalName.toLowerCase(),
      }),
    );

    dynamic data;
    try {
      data = jsonDecode(response.body);
    } catch (_) {
      data = {};
    }

    if (response.statusCode >= 200 && response.statusCode < 300) {
      setState(() {
        _currentStep = 4;
        _successMessage = 'Successfully signed in with phone number!';
      });
    } else {
      throw Exception(
          data is Map ? (data['error'] ?? "Login failed") : "Login failed");
    }
  }

  Future<void> _verifyOtp() async {
    FocusScope.of(context).unfocus();
    final otp = _otpValue;

    if (otp.length < 6) {
      setState(() => _generalError = 'Please enter the full 6-digit code.');
      return;
    }

    setState(() {
      _loading = true;
      _generalError = null;
    });

    if (_isPhoneMode) {
      try {
        if (_verificationId == null) {
          throw Exception("Please request OTP first");
        }
        PhoneAuthCredential credential = PhoneAuthProvider.credential(
          verificationId: _verificationId!,
          smsCode: otp,
        );
        UserCredential userCredential =
            await _auth.signInWithCredential(credential);
        String? idToken = await userCredential.user?.getIdToken();
        if (idToken == null) {
          throw Exception("Failed to get Firebase token");
        }
        await _verifyPhoneBackend(idToken);
      } catch (e) {
        setState(() {
          _generalError = e.toString();
          _loading = false;
        });
      }
    } else {
      final email = _emailCtl.text.trim();
      try {
        final Map<String, dynamic> res;
        if (widget.customerApi != null) {
          res = await widget.customerApi!.verifyResetOtp(email, otp);
        } else {
          res = await widget.technicianApi!.verifyResetOtp(email, otp);
        }
        final token = res['resetToken']?.toString();
        if (token == null || token.isEmpty) {
          throw const ApiException(
              'Password reset verification token missing.');
        }
        if (!mounted) return;
        setState(() {
          _resetToken = token;
          _currentStep = 3;
          _generalError = null;
        });
      } on ApiException catch (e) {
        if (!mounted) return;
        setState(() => _generalError = e.message);
      } catch (e) {
        if (!mounted) return;
        setState(() => _generalError = e.toString());
      } finally {
        if (mounted) setState(() => _loading = false);
      }
    }
  }

  Future<void> _resendOtp() async {
    if (_resendCountdown > 0 || _loading) return;
    _sendOtp();
  }

  Future<void> _submitNewPassword() async {
    FocusScope.of(context).unfocus();
    final pass = _passwordCtl.text;
    final confirm = _confirmPasswordCtl.text;

    setState(() {
      _passwordError = null;
      _confirmError = null;
      _generalError = null;
    });

    if (pass.isEmpty) {
      setState(() => _passwordError = 'Please enter a new password.');
      return;
    }
    if (pass.length < 10) {
      setState(
          () => _passwordError = 'Password must be at least 10 characters.');
      return;
    }
    if (confirm.isEmpty) {
      setState(() => _confirmError = 'Please confirm your new password.');
      return;
    }
    if (pass != confirm) {
      setState(() => _confirmError = 'Passwords do not match.');
      return;
    }
    if (_resetToken == null) {
      setState(
          () => _generalError = 'Reset session expired. Please start over.');
      return;
    }

    setState(() => _loading = true);
    try {
      if (widget.customerApi != null) {
        await widget.customerApi!.resetPassword(_resetToken!, pass);
      } else {
        await widget.technicianApi!.resetPassword(_resetToken!, pass);
      }
      if (!mounted) return;
      setState(() {
        _currentStep = 4;
        _successMessage = 'Your password has been reset successfully!';
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _generalError = e.message);
    } catch (e) {
      if (!mounted) return;
      setState(() => _generalError = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _onDigitChanged(int index, String value) {
    if (value.length == 1 && index < 5) {
      _otpNodes[index + 1].requestFocus();
    } else if (value.isEmpty && index > 0) {
      _otpNodes[index - 1].requestFocus();
    }
    setState(() {});
    if (_otpValue.length == 6) {
      _verifyOtp();
    }
  }

  void _handleBack() {
    if (_currentStep == 2) {
      setState(() {
        _currentStep = 1;
        _generalError = null;
      });
    } else if (_currentStep == 3) {
      setState(() {
        _currentStep = 2;
        _generalError = null;
      });
    } else {
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: _currentStep == 1 || _currentStep == 4,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        _handleBack();
      },
      child: Scaffold(
        backgroundColor: AppColors.softGray,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(
              Icons.arrow_back_ios_new_rounded,
              color: AppColors.gold,
              size: 20,
            ),
            onPressed: _handleBack,
          ),
          title: Text(
            _currentStep == 4
                ? 'Success'
                : (_isPhoneMode ? 'Phone Login' : 'Reset Password'),
            style: const TextStyle(
              color: AppColors.navy,
              fontWeight: FontWeight.w700,
              fontSize: 18,
            ),
          ),
          centerTitle: true,
        ),
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(
              horizontal: 24,
              vertical: 16,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (_currentStep < 4 && !_isPhoneMode) ...[
                  _buildStepIndicator(),
                  const SizedBox(height: 28),
                ],
                if (_currentStep == 1) _buildStep1Input(),
                if (_currentStep == 2) _buildStep2Otp(),
                if (_currentStep == 3) _buildStep3NewPassword(),
                if (_currentStep == 4) _buildStep4Success(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStepIndicator() {
    return Row(
      children: [
        _stepCircle(1, 'Verify'),
        _stepLine(1),
        _stepCircle(2, 'OTP'),
        _stepLine(2),
        _stepCircle(3, 'Password'),
      ],
    );
  }

  Widget _stepCircle(int step, String label) {
    final isActive = _currentStep == step;
    final isDone = _currentStep > step;
    return Column(
      children: [
        AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: isDone
                ? AppColors.success
                : isActive
                    ? AppColors.gold
                    : AppColors.navyDark,
            shape: BoxShape.circle,
            border: Border.all(
              color: isDone
                  ? AppColors.success
                  : isActive
                      ? AppColors.gold
                      : AppColors.navyLight,
              width: 1.5,
            ),
          ),
          child: Center(
            child: isDone
                ? const Icon(
                    Icons.check,
                    color: AppColors.navyDeep,
                    size: 18,
                  )
                : Text(
                    '$step',
                    style: TextStyle(
                      color:
                          isActive ? AppColors.navyDeep : AppColors.textMuted,
                      fontWeight: FontWeight.w800,
                      fontSize: 13,
                    ),
                  ),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            color: isActive ? AppColors.navy : AppColors.textMuted,
            fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _stepLine(int afterStep) {
    final isDone = _currentStep > afterStep;
    return Expanded(
      child: Container(
        height: 2,
        margin: const EdgeInsets.only(
          bottom: 16,
          left: 6,
          right: 6,
        ),
        color: isDone ? AppColors.success : AppColors.cardBorder,
      ),
    );
  }

  Widget _buildStep1Input() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          width: 64,
          height: 64,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: AppColors.gold.withValues(alpha: 0.12),
            shape: BoxShape.circle,
          ),
          child: Icon(
            _isPhoneMode
                ? Icons.phone_android_rounded
                : Icons.lock_reset_rounded,
            color: AppColors.gold,
            size: 34,
          ),
        ),
        const SizedBox(height: 20),
        Text(
          _isPhoneMode ? 'Phone Number Login' : 'Forgot Password?',
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w800,
            color: AppColors.navy,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          _isPhoneMode
              ? 'Enter your phone number (e.g., +919999999999) to receive SMS OTP.'
              : 'Enter the email address registered with your account. We will send you a 6-digit verification code.',
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 13,
            color: AppColors.textLight,
            height: 1.4,
          ),
        ),
        const SizedBox(height: 20),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ChoiceChip(
              label: const Text('Email Recovery'),
              selected: !_isPhoneMode,
              onSelected: (val) => setState(() => _isPhoneMode = false),
              selectedColor: AppColors.gold,
            ),
            const SizedBox(width: 12),
            ChoiceChip(
              label: const Text('Phone SMS OTP'),
              selected: _isPhoneMode,
              onSelected: (val) => setState(() => _isPhoneMode = true),
              selectedColor: AppColors.gold,
            ),
          ],
        ),
        const SizedBox(height: 24),
        if (_isPhoneMode)
          TextField(
            controller: _phoneCtl,
            keyboardType: TextInputType.phone,
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => _sendOtp(),
            style: const TextStyle(
              color: AppColors.charcoal,
            ),
            decoration: InputDecoration(
              labelText: 'Phone Number',
              hintText: '+919999999999',
              prefixIcon: const Icon(
                Icons.phone_outlined,
                color: AppColors.goldLight,
              ),
              errorText: _inputError,
              filled: true,
              fillColor: AppColors.white,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          )
        else
          TextField(
            controller: _emailCtl,
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => _sendOtp(),
            style: const TextStyle(
              color: AppColors.charcoal,
            ),
            decoration: InputDecoration(
              labelText: 'Email Address',
              hintText: 'name@example.com',
              prefixIcon: const Icon(
                Icons.mail_outline_rounded,
                color: AppColors.goldLight,
              ),
              errorText: _inputError,
              filled: true,
              fillColor: AppColors.white,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        if (_generalError != null) ...[
          const SizedBox(height: 14),
          _buildErrorBox(_generalError!),
        ],
        const SizedBox(height: 24),
        LoadingButton(
          loading: _loading,
          onPressed: _sendOtp,
          child: Text(
            _isPhoneMode ? 'Send SMS OTP' : 'Send Verification Code',
          ),
        ),
      ],
    );
  }

  Widget _buildStep2Otp() {
    final targetInfo =
        _isPhoneMode ? _phoneCtl.text.trim() : _emailCtl.text.trim();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          width: 64,
          height: 64,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: AppColors.info.withValues(alpha: 0.12),
            shape: BoxShape.circle,
          ),
          child: Icon(
            _isPhoneMode ? Icons.sms_outlined : Icons.mark_email_read_outlined,
            color: AppColors.info,
            size: 34,
          ),
        ),
        const SizedBox(height: 20),
        Text(
          _isPhoneMode ? 'Enter SMS Code' : 'Check Your Email',
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w800,
            color: AppColors.navy,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          _isPhoneMode
              ? 'We have sent an SMS code to:'
              : 'We have sent a 6-digit recovery code to:',
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 13,
            color: AppColors.textLight,
          ),
        ),
        const SizedBox(height: 4),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Flexible(
              child: Text(
                targetInfo,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: AppColors.gold,
                ),
              ),
            ),
            IconButton(
              icon: const Icon(
                Icons.edit_outlined,
                size: 16,
                color: AppColors.textMuted,
              ),
              onPressed: () => setState(() => _currentStep = 1),
            ),
          ],
        ),
        const SizedBox(height: 24),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: List.generate(6, (i) => _buildOtpDigitBox(i)),
        ),
        if (_generalError != null) ...[
          const SizedBox(height: 16),
          _buildErrorBox(_generalError!),
        ],
        const SizedBox(height: 24),
        LoadingButton(
          loading: _loading,
          onPressed: _otpValue.length == 6 ? _verifyOtp : null,
          child: const Text('Verify Code'),
        ),
        const SizedBox(height: 20),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text(
              "Didn't receive the code? ",
              style: TextStyle(
                color: AppColors.textMuted,
                fontSize: 13,
              ),
            ),
            if (_resendCountdown > 0)
              Text(
                'Resend in ${_resendCountdown}s',
                style: const TextStyle(
                  color: AppColors.gold,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              )
            else
              GestureDetector(
                onTap: _resendOtp,
                child: const Text(
                  'Resend Now',
                  style: TextStyle(
                    color: AppColors.gold,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    decoration: TextDecoration.underline,
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }

  Widget _buildOtpDigitBox(int index) {
    final hasFocus = _otpNodes[index].hasFocus;
    final hasValue = _otpCtls[index].text.isNotEmpty;
    return Container(
      width: 46,
      height: 54,
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: hasFocus
              ? AppColors.gold
              : (hasValue ? AppColors.goldLight : AppColors.inputBorder),
          width: hasFocus ? 2 : 1,
        ),
      ),
      child: Center(
        child: TextField(
          controller: _otpCtls[index],
          focusNode: _otpNodes[index],
          keyboardType: TextInputType.number,
          textAlign: TextAlign.center,
          maxLength: 1,
          style: const TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w900,
            color: AppColors.charcoal,
          ),
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          decoration: const InputDecoration(
            counterText: '',
            border: InputBorder.none,
            contentPadding: EdgeInsets.zero,
          ),
          onChanged: (val) => _onDigitChanged(index, val),
        ),
      ),
    );
  }

  Widget _buildStep3NewPassword() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'Set New Password',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w800,
            color: AppColors.navy,
          ),
        ),
        const SizedBox(height: 24),
        TextField(
          controller: _passwordCtl,
          obscureText: _obscurePassword,
          decoration: InputDecoration(
            labelText: 'New Password',
            errorText: _passwordError,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _confirmPasswordCtl,
          obscureText: _obscureConfirm,
          decoration: InputDecoration(
            labelText: 'Confirm Password',
            errorText: _confirmError,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
        const SizedBox(height: 24),
        LoadingButton(
          loading: _loading,
          onPressed: _submitNewPassword,
          child: const Text('Update Password'),
        ),
      ],
    );
  }

  Widget _buildStep4Success() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 40),
        const Icon(
          Icons.check_circle_rounded,
          color: AppColors.success,
          size: 88,
        ),
        const SizedBox(height: 28),
        Text(
          _isPhoneMode ? 'Phone Login Successful!' : 'Password Reset!',
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w900,
            color: AppColors.navy,
          ),
        ),
        const SizedBox(height: 36),
        FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: AppColors.gold,
            minimumSize: const Size(double.infinity, 50),
          ),
          onPressed: () => Navigator.pop(context),
          child: const Text(
            'Back to App',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildErrorBox(String message) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 14,
        vertical: 10,
      ),
      decoration: BoxDecoration(
        color: AppColors.danger.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.error_outline_rounded,
            color: AppColors.danger,
            size: 18,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                color: AppColors.danger,
                fontSize: 12.5,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
