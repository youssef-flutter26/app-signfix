import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
  }) : assert(customerApi != null || technicianApi != null,
            'Either customerApi or technicianApi must be provided.');

  final ApiClient? customerApi;
  final tech.TechnicianApi? technicianApi;
  final String? initialEmail;
  final String portalName;

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  int _currentStep = 1; // 1: Email, 2: OTP, 3: New Password, 4: Success

  // Step 1: Email
  final _emailCtl = TextEditingController();
  String? _emailError;

  // Step 2: OTP (6 digits)
  final List<TextEditingController> _otpCtls =
      List.generate(6, (_) => TextEditingController());
  final List<FocusNode> _otpNodes = List.generate(6, (_) => FocusNode());
  int _resendCountdown = 60;
  Timer? _countdownTimer;
  String? _resetToken;

  // Step 3: Password
  final _passwordCtl = TextEditingController();
  final _confirmPasswordCtl = TextEditingController();
  bool _obscurePassword = true;
  bool _obscureConfirm = true;
  String? _passwordError;
  String? _confirmError;

  // General state
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
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (_resendCountdown > 0) {
        setState(() => _resendCountdown--);
      } else {
        timer.cancel();
      }
    });
  }

  String get _otpValue => _otpCtls.map((c) => c.text).join();

  // ── Step 1: Send OTP ──────────────────────────────────────────────────────
  Future<void> _sendOtp() async {
    FocusScope.of(context).unfocus();
    final email = _emailCtl.text.trim();
    setState(() {
      _emailError = null;
      _generalError = null;
    });

    if (email.isEmpty) {
      setState(() => _emailError = 'Please enter your email address.');
      return;
    }
    if (!email.contains('@') || !email.contains('.')) {
      setState(() => _emailError = 'Please enter a valid email address.');
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
          _emailError = e.message;
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

  // ── Step 2: Verify OTP ────────────────────────────────────────────────────
  Future<void> _verifyOtp() async {
    FocusScope.of(context).unfocus();
    final otp = _otpValue;
    final email = _emailCtl.text.trim();

    if (otp.length < 6) {
      setState(() => _generalError = 'Please enter the full 6-digit code.');
      return;
    }

    setState(() {
      _loading = true;
      _generalError = null;
    });

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
            'Password reset verification token missing. Please try again.');
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

  Future<void> _resendOtp() async {
    if (_resendCountdown > 0 || _loading) return;
    setState(() {
      _loading = true;
      _generalError = null;
    });
    try {
      final email = _emailCtl.text.trim();
      if (widget.customerApi != null) {
        await widget.customerApi!.forgotPassword(email);
      } else {
        await widget.technicianApi!.forgotPassword(email);
      }
      if (!mounted) return;
      _startCountdown();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('A new 6-digit code has been sent to your email.'),
          backgroundColor: AppColors.success,
        ),
      );
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

  // ── Step 3: Reset Password ────────────────────────────────────────────────
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
      setState(() => _passwordError = 'Password must be at least 10 characters.');
      return;
    }
    if (!RegExp(r'^(?=.*[a-z])(?=.*[A-Z])(?=.*\d)(?=.*[^A-Za-z0-9]).{10,72}$')
        .hasMatch(pass)) {
      setState(() => _passwordError =
          'Must include uppercase, lowercase, number, and special character.');
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
      setState(() => _generalError = 'Reset session expired. Please start over.');
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
            icon: const Icon(Icons.arrow_back_ios_new_rounded,
                color: AppColors.gold, size: 20),
            onPressed: _handleBack,
          ),
          title: Text(
            _currentStep == 4
                ? 'Success'
                : 'Reset Password',
            style: const TextStyle(
                color: AppColors.navy,
                fontWeight: FontWeight.w700,
                fontSize: 18),
          ),
          centerTitle: true,
        ),
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Step Indicator (for steps 1-3)
                if (_currentStep < 4) ...[
                  _buildStepIndicator(),
                  const SizedBox(height: 28),
                ],

                // Step content
                if (_currentStep == 1) _buildStep1Email(),
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
        _stepCircle(1, 'Email'),
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
                ? const Icon(Icons.check, color: AppColors.navyDeep, size: 18)
                : Text(
                    '$step',
                    style: TextStyle(
                      color: isActive ? AppColors.navyDeep : AppColors.textMuted,
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
        margin: const EdgeInsets.only(bottom: 16, left: 6, right: 6),
        color: isDone ? AppColors.success : AppColors.cardBorder,
      ),
    );
  }

  // ── Step 1 View ────────────────────────────────────────────────────────────
  Widget _buildStep1Email() {
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
          child: const Icon(Icons.lock_reset_rounded,
              color: AppColors.gold, size: 34),
        ),
        const SizedBox(height: 20),
        const Text(
          'Forgot Password?',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w800,
            color: AppColors.navy,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Enter the email address registered with your ${widget.portalName.toLowerCase()} account. We will send you a 6-digit verification code.',
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 13,
            color: AppColors.textLight,
            height: 1.4,
          ),
        ),
        const SizedBox(height: 28),

        // Email TextField
        TextField(
          controller: _emailCtl,
          keyboardType: TextInputType.emailAddress,
          textInputAction: TextInputAction.done,
          onSubmitted: (_) => _sendOtp(),
          style: const TextStyle(color: AppColors.charcoal),
          decoration: InputDecoration(
            labelText: 'Email Address',
            hintText: 'name@example.com',
            prefixIcon: const Icon(Icons.mail_outline_rounded,
                color: AppColors.goldLight),
            errorText: _emailError,
            filled: true,
            fillColor: AppColors.white,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppColors.inputBorder),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppColors.inputBorder),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppColors.gold, width: 1.5),
            ),
          ),
          onChanged: (_) {
            if (_emailError != null || _generalError != null) {
              setState(() {
                _emailError = null;
                _generalError = null;
              });
            }
          },
        ),

        if (_generalError != null) ...[
          const SizedBox(height: 14),
          _buildErrorBox(_generalError!),
        ],

        const SizedBox(height: 24),
        LoadingButton(
          loading: _loading,
          onPressed: _sendOtp,
          child: const Text('Send Verification Code'),
        ),
      ],
    );
  }

  // ── Step 2 View ────────────────────────────────────────────────────────────
  Widget _buildStep2Otp() {
    final email = _emailCtl.text.trim();
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
          child: const Icon(Icons.mark_email_read_outlined,
              color: AppColors.info, size: 34),
        ),
        const SizedBox(height: 20),
        const Text(
          'Check Your Email',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w800,
            color: AppColors.navy,
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          'We have sent a 6-digit recovery code to:',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 13, color: AppColors.textLight),
        ),
        const SizedBox(height: 4),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Flexible(
              child: Text(
                email,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: AppColors.gold,
                ),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.edit_outlined,
                  size: 16, color: AppColors.textMuted),
              tooltip: 'Change Email',
              onPressed: () => setState(() => _currentStep = 1),
            ),
          ],
        ),
        const SizedBox(height: 24),

        // 6 digit boxes
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
              style: TextStyle(color: AppColors.textMuted, fontSize: 13),
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
              : hasValue
                  ? AppColors.goldLight.withValues(alpha: 0.6)
                  : AppColors.inputBorder,
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

  // ── Step 3 View ────────────────────────────────────────────────────────────
  Widget _buildStep3NewPassword() {
    final pass = _passwordCtl.text;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          width: 64,
          height: 64,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: AppColors.success.withValues(alpha: 0.12),
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.shield_outlined,
              color: AppColors.success, size: 34),
        ),
        const SizedBox(height: 20),
        const Text(
          'Set New Password',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w800,
            color: AppColors.navy,
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          'Create a strong password that you do not use for other services.',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 13, color: AppColors.textLight),
        ),
        const SizedBox(height: 24),

        // New Password
        TextField(
          controller: _passwordCtl,
          obscureText: _obscurePassword,
          textInputAction: TextInputAction.next,
          style: const TextStyle(color: AppColors.charcoal),
          onChanged: (_) => setState(() {}),
          decoration: InputDecoration(
            labelText: 'New Password',
            prefixIcon:
                const Icon(Icons.lock_outline, color: AppColors.goldLight),
            errorText: _passwordError,
            filled: true,
            fillColor: AppColors.white,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppColors.inputBorder),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppColors.inputBorder),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppColors.gold, width: 1.5),
            ),
            suffixIcon: IconButton(
              icon: Icon(
                _obscurePassword
                    ? Icons.visibility_outlined
                    : Icons.visibility_off_outlined,
                color: AppColors.gold,
              ),
              onPressed: () =>
                  setState(() => _obscurePassword = !_obscurePassword),
            ),
          ),
        ),

        // Password requirements checklist
        const SizedBox(height: 12),
        _buildPasswordRequirements(pass),

        const SizedBox(height: 16),

        // Confirm Password
        TextField(
          controller: _confirmPasswordCtl,
          obscureText: _obscureConfirm,
          textInputAction: TextInputAction.done,
          onSubmitted: (_) => _submitNewPassword(),
          style: const TextStyle(color: AppColors.charcoal),
          onChanged: (_) => setState(() {}),
          decoration: InputDecoration(
            labelText: 'Confirm New Password',
            prefixIcon:
                const Icon(Icons.lock_reset_outlined, color: AppColors.goldLight),
            errorText: _confirmError,
            filled: true,
            fillColor: AppColors.white,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppColors.inputBorder),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppColors.inputBorder),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppColors.gold, width: 1.5),
            ),
            suffixIcon: IconButton(
              icon: Icon(
                _obscureConfirm
                    ? Icons.visibility_outlined
                    : Icons.visibility_off_outlined,
                color: AppColors.gold,
              ),
              onPressed: () =>
                  setState(() => _obscureConfirm = !_obscureConfirm),
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
          onPressed: _submitNewPassword,
          child: const Text('Update Password'),
        ),
      ],
    );
  }

  Widget _buildPasswordRequirements(String pass) {
    final hasMinLength = pass.length >= 10;
    final hasUpper = RegExp(r'[A-Z]').hasMatch(pass);
    final hasLower = RegExp(r'[a-z]').hasMatch(pass);
    final hasNumber = RegExp(r'\d').hasMatch(pass);
    final hasSpecial = RegExp(r'[^A-Za-z0-9]').hasMatch(pass);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.softGray,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Password requirements:',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: AppColors.textLight,
            ),
          ),
          const SizedBox(height: 8),
          _requirementRow('At least 10 characters', hasMinLength),
          _requirementRow('Uppercase & lowercase letters', hasUpper && hasLower),
          _requirementRow('At least one number (0-9)', hasNumber),
          _requirementRow('At least one special symbol (!@#\$...)', hasSpecial),
        ],
      ),
    );
  }

  Widget _requirementRow(String text, bool met) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Icon(
            met ? Icons.check_circle_rounded : Icons.radio_button_unchecked,
            size: 14,
            color: met ? AppColors.success : AppColors.textMuted,
          ),
          const SizedBox(width: 8),
          Text(
            text,
            style: TextStyle(
              fontSize: 11.5,
              color: met ? AppColors.charcoal : AppColors.textMuted,
              fontWeight: met ? FontWeight.w600 : FontWeight.normal,
            ),
          ),
        ],
      ),
    );
  }

  // ── Step 4 View: Success ───────────────────────────────────────────────────
  Widget _buildStep4Success() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 40),
        Container(
          width: 88,
          height: 88,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: AppColors.success.withValues(alpha: 0.15),
            shape: BoxShape.circle,
            border: Border.all(color: AppColors.success, width: 2),
          ),
          child: const Icon(Icons.check_rounded,
              color: AppColors.success, size: 48),
        ),
        const SizedBox(height: 28),
        const Text(
          'Password Reset!',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w900,
            color: AppColors.navy,
          ),
        ),
        const SizedBox(height: 12),
        Text(
          _successMessage ??
              'Your password has been reset successfully. You can now log in using your new credentials.',
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 14,
            color: AppColors.textLight,
            height: 1.5,
          ),
        ),
        const SizedBox(height: 36),
        FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: AppColors.gold,
            foregroundColor: AppColors.navyDeep,
            minimumSize: const Size(double.infinity, 50),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          onPressed: () => Navigator.pop(context),
          child: const Text(
            'Back to Login',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
          ),
        ),
      ],
    );
  }

  Widget _buildErrorBox(String message) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.danger.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.danger.withValues(alpha: 0.4)),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline_rounded,
              color: AppColors.danger, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                color: AppColors.danger,
                fontSize: 12.5,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
