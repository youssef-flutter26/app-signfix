import 'dart:async';
import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/app_theme.dart';
import '../../services/api_client.dart';
import 'registration_data.dart';
import 'registration_widgets.dart';
import 'pending_approval_screen.dart';

class OtpVerificationScreen extends StatefulWidget {
  const OtpVerificationScreen(
      {super.key, required this.api, required this.data});
  final TechnicianApi api;
  final TechRegistrationData data;
  @override
  State<OtpVerificationScreen> createState() => _OtpVerificationScreenState();
}

class _OtpVerificationScreenState extends State<OtpVerificationScreen> {
  final List<TextEditingController> _ctls =
      List.generate(6, (_) => TextEditingController());
  final List<FocusNode> _nodes = List.generate(6, (_) => FocusNode());

  bool _loading = false;
  bool _resending = false;
  String? _error;
  int _secondsLeft = 120;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _startTimer();
    // Listen to focus changes for border updates
    for (final n in _nodes) {
      n.addListener(() {
        if (mounted) setState(() {});
      });
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    for (final c in _ctls) {
      c.dispose();
    }
    for (final n in _nodes) {
      n.dispose();
    }
    super.dispose();
  }

  void _startTimer() {
    _timer?.cancel();
    setState(() => _secondsLeft = 120);
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() {
        if (_secondsLeft > 0) _secondsLeft--;
      });
    });
  }

  String get _otp => _ctls.map((c) => c.text).join();
  String get _timerText {
    final m = _secondsLeft ~/ 60;
    final s = _secondsLeft % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  void _onDigitChanged(int index, String value) {
    if (value.length == 1 && index < 5) {
      _nodes[index + 1].requestFocus();
    } else if (value.isEmpty && index > 0) {
      _nodes[index - 1].requestFocus();
    }
    setState(() {});
    if (_otp.length == 6) _verify();
  }

  Future<void> _verify() async {
    if (_loading) return;
    if (_otp.length < 6) {
      setState(() => _error = 'Please enter the complete 6-digit OTP.');
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      if (widget.data.registrationVerificationToken.isEmpty) {
        final res = await widget.api.verifyOtp(widget.data.email, _otp);
        widget.data.registrationVerificationToken =
            res['verificationToken']?.toString() ?? '';
        if (widget.data.registrationVerificationToken.isEmpty) {
          throw const ApiException(
              'Email verification token was not returned. Please try again.');
        }
      }
      await widget.api.register(widget.data.toPayload());
      if (!mounted) return;
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const PendingApprovalScreen()),
        (r) => false,
      );
    } on ApiException catch (e) {
      if (mounted) {
        // If the verification token was rejected by the server, clear it so
        // the next attempt will re-verify the OTP instead of reusing a bad token.
        if (e.statusCode == 422 &&
            widget.data.registrationVerificationToken.isNotEmpty) {
          widget.data.registrationVerificationToken = '';
        }
        setState(() => _error = e.toString());
      }
    } catch (e) {
      if (mounted) {
        setState(() => _error = e.toString().replaceFirst('Exception: ', ''));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _resend() async {
    setState(() {
      _resending = true;
      _error = null;
    });
    for (final c in _ctls) {
      c.clear();
    }
    // Clear any previous verification token so the new OTP is verified fresh.
    widget.data.registrationVerificationToken = '';
    _nodes[0].requestFocus();
    try {
      await widget.api.sendOtp(widget.data.email, widget.data.mobile);
      _startTimer();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('New OTP sent to your email address.')));
      }
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _resending = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: AppColors.softGray,
        appBar: AppBar(
          backgroundColor: AppColors.navyDark,
          leading: IconButton(
            icon:
                const Icon(Icons.arrow_back_ios_rounded, color: AppColors.gold),
            onPressed: () => Navigator.pop(context),
          ),
          title: const Text('Verify Email',
              style: TextStyle(
                  color: AppColors.white, fontWeight: FontWeight.w800)),
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(children: [
            const SizedBox(height: 20),

            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: AppColors.info.withValues(alpha: .1),
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.info.withValues(alpha: .3)),
                boxShadow: [
                  BoxShadow(
                      color: AppColors.info.withValues(alpha: .15),
                      blurRadius: 16)
                ],
              ),
              child: const Icon(Icons.email_outlined,
                  color: AppColors.info, size: 36),
            ),
            const SizedBox(height: 20),

            const Text('OTP Verification',
                style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: AppColors.navy)),
            const SizedBox(height: 8),
            Text('Enter the 6-digit OTP sent to\n${widget.data.email}',
                textAlign: TextAlign.center,
                style: const TextStyle(
                    color: AppColors.midGray, fontSize: 14, height: 1.5)),
            const SizedBox(height: 32),

            // 6 OTP boxes
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(
                  6,
                  (i) => Container(
                        width: 46,
                        height: 56,
                        margin: const EdgeInsets.symmetric(horizontal: 4),
                        decoration: BoxDecoration(
                          color: AppColors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: _ctls[i].text.isNotEmpty
                                ? AppColors.gold
                                : _nodes[i].hasFocus
                                    ? AppColors.info
                                    : AppColors.inputBorder,
                            width:
                                _ctls[i].text.isNotEmpty || _nodes[i].hasFocus
                                    ? 2
                                    : 1,
                          ),
                        ),
                        child: TextField(
                          controller: _ctls[i],
                          focusNode: _nodes[i],
                          textAlign: TextAlign.center,
                          keyboardType: TextInputType.number,
                          maxLength: 1,
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly
                          ],
                          style: const TextStyle(
                              color: AppColors.navy,
                              fontSize: 22,
                              fontWeight: FontWeight.w900),
                          decoration: const InputDecoration(
                            counterText: '',
                            border: InputBorder.none,
                            enabledBorder: InputBorder.none,
                            focusedBorder: InputBorder.none,
                          ),
                          onChanged: (v) => _onDigitChanged(i, v),
                        ),
                      )),
            ),
            const SizedBox(height: 16),

            // Demo hint — only visible in debug builds
            if (kDebugMode && widget.api.mockMode)
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: AppColors.warning.withValues(alpha: .08),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                      color: AppColors.warning.withValues(alpha: .3)),
                ),
                child: const Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Icons.info_outline, size: 14, color: AppColors.warning),
                  SizedBox(width: 6),
                  Text('Demo OTP: 123456',
                      style: TextStyle(
                          color: AppColors.warning,
                          fontSize: 12,
                          fontWeight: FontWeight.w600)),
                ]),
              ),
            const SizedBox(height: 20),

            // Timer
            Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              Icon(Icons.timer_outlined,
                  size: 16,
                  color:
                      _secondsLeft > 0 ? AppColors.midGray : AppColors.danger),
              const SizedBox(width: 6),
              Text(
                _secondsLeft > 0
                    ? 'Resend OTP in $_timerText'
                    : 'You can request a new OTP now.',
                style: TextStyle(
                    color:
                        _secondsLeft > 0 ? AppColors.midGray : AppColors.danger,
                    fontSize: 13),
              ),
            ]),
            const SizedBox(height: 10),

            // Resend
            _secondsLeft == 0
                ? TextButton.icon(
                    onPressed: _resending ? null : _resend,
                    icon: _resending
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: AppColors.gold))
                        : const Icon(Icons.sms_outlined),
                    label: const Text('Resend OTP'),
                  )
                : TextButton(
                    onPressed: null,
                    child: Text('Resend OTP in $_timerText',
                        style: const TextStyle(color: AppColors.midGray)),
                  ),

            if (_error != null) ...[
              const SizedBox(height: 14),
              RegErrorBox(_error!)
            ],
            const SizedBox(height: 24),

            SizedBox(
              width: double.infinity,
              child: _loading
                  ? Container(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      decoration: BoxDecoration(
                          color: AppColors.gold.withValues(alpha: .3),
                          borderRadius: BorderRadius.circular(14)),
                      child: const Center(
                          child: Row(mainAxisSize: MainAxisSize.min, children: [
                        SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: AppColors.gold)),
                        SizedBox(width: 10),
                        Text('Verifying & submitting…',
                            style: TextStyle(
                                color: AppColors.gold,
                                fontWeight: FontWeight.w700)),
                      ])),
                    )
                  : FilledButton.icon(
                      onPressed: _otp.length == 6 ? _verify : null,
                      icon: const Icon(Icons.verified_user_outlined),
                      label: const Text('Verify & Create Account'),
                    ),
            ),
            const SizedBox(height: 20),
          ]),
        ),
      );
}
