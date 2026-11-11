import 'package:flutter/material.dart';
import '../../core/app_theme.dart';
import '../../services/api_client.dart';
import 'registration_data.dart';
import 'registration_widgets.dart';
import 'otp_verification_screen.dart';

class RegStep3Security extends StatefulWidget {
  const RegStep3Security({super.key, required this.api, required this.data});
  final TechnicianApi api;
  final TechRegistrationData data;
  @override
  State<RegStep3Security> createState() => _RegStep3SecurityState();
}

class _RegStep3SecurityState extends State<RegStep3Security> {
  final _pass = TextEditingController();
  final _confirm = TextEditingController();
  bool _obscure = true;
  bool _terms = false;
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _pass.dispose();
    _confirm.dispose();
    super.dispose();
  }

  bool _validate() {
    // Empty checks first
    if (_pass.text.isEmpty) {
      setState(() => _error = 'Password is required.');
      return false;
    }
    if (_pass.text.length < 10) {
      setState(() => _error = 'Password must be at least 10 characters.');
      return false;
    }
    if (!RegExp(r'^(?=.*[a-z])(?=.*[A-Z])(?=.*\d)(?=.*[^A-Za-z0-9]).{10,72}$')
        .hasMatch(_pass.text)) {
      setState(() => _error =
          'Password must include uppercase, lowercase, a number, and a special character.');
      return false;
    }
    if (_confirm.text.isEmpty) {
      setState(() => _error = 'Please confirm your password.');
      return false;
    }
    if (_pass.text != _confirm.text) {
      setState(() => _error = 'Passwords do not match. Please re-enter.');
      return false;
    }
    if (!_terms) {
      setState(
          () => _error = 'You must accept the Terms & Conditions to continue.');
      return false;
    }
    setState(() => _error = null);
    return true;
  }

  Future<void> _sendOtpAndNext() async {
    if (!_validate()) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await widget.api.sendOtp(widget.data.email, widget.data.mobile);
      widget.data.password = _pass.text;
      widget.data.termsAccepted = _terms;
      if (!mounted) return;
      Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) =>
                OtpVerificationScreen(api: widget.api, data: widget.data),
          ));
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
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
          title: const Text('Create Account',
              style: TextStyle(
                  color: AppColors.white, fontWeight: FontWeight.w800)),
        ),
        body: Column(children: [
          const RegProgressBar(step: 3),
          Expanded(
              child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('Security Setup',
                  style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: AppColors.navy)),
              const SizedBox(height: 4),
              const Text('Step 3 of 3 — Set your password',
                  style: TextStyle(color: AppColors.midGray, fontSize: 13)),
              const SizedBox(height: 24),

              // Info box
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.info.withValues(alpha: .08),
                  borderRadius: BorderRadius.circular(12),
                  border:
                      Border.all(color: AppColors.info.withValues(alpha: .3)),
                ),
                child: const Row(children: [
                  Icon(Icons.lock_outline_rounded,
                      color: AppColors.info, size: 18),
                  SizedBox(width: 10),
                  Expanded(
                      child: Text(
                          'Minimum 10 characters with uppercase, lowercase, number, and special character.',
                          style: TextStyle(
                              color: AppColors.midGray, fontSize: 12))),
                ]),
              ),
              const SizedBox(height: 16),

              // Password
              TextField(
                controller: _pass,
                obscureText: _obscure,
                textInputAction: TextInputAction.next,
                style: const TextStyle(color: AppColors.charcoal),
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(
                  labelText: 'Password *',
                  prefixIcon: const Icon(Icons.lock_outline),
                  suffixIcon: IconButton(
                    icon: Icon(
                        _obscure
                            ? Icons.visibility_outlined
                            : Icons.visibility_off_outlined,
                        color: AppColors.gold),
                    onPressed: () => setState(() => _obscure = !_obscure),
                  ),
                ),
              ),
              if (_pass.text.isNotEmpty) ...[
                const SizedBox(height: 8),
                _PasswordStrength(password: _pass.text),
              ],
              const SizedBox(height: 12),

              // Confirm
              TextField(
                controller: _confirm,
                obscureText: _obscure,
                style: const TextStyle(color: AppColors.charcoal),
                decoration: const InputDecoration(
                  labelText: 'Confirm Password *',
                  prefixIcon: Icon(Icons.lock_outline),
                ),
              ),
              const SizedBox(height: 20),

              // Terms
              GestureDetector(
                onTap: () => setState(() => _terms = !_terms),
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.white,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                        color: _terms
                            ? AppColors.gold.withValues(alpha: .4)
                            : AppColors.cardBorder),
                  ),
                  child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 22,
                          height: 22,
                          margin: const EdgeInsets.only(top: 1),
                          decoration: BoxDecoration(
                            color: _terms ? AppColors.gold : Colors.transparent,
                            borderRadius: BorderRadius.circular(5),
                            border: Border.all(
                                color:
                                    _terms ? AppColors.gold : AppColors.midGray,
                                width: 2),
                          ),
                          child: _terms
                              ? const Icon(Icons.check_rounded,
                                  size: 14, color: AppColors.navyDeep)
                              : null,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                            child: RichText(
                          text: const TextSpan(
                            style: TextStyle(
                                color: AppColors.charcoal,
                                fontSize: 13,
                                height: 1.4),
                            children: [
                              TextSpan(text: 'I accept the '),
                              TextSpan(
                                  text: 'Terms & Conditions',
                                  style: TextStyle(
                                      color: AppColors.gold,
                                      fontWeight: FontWeight.w700)),
                              TextSpan(text: ' and '),
                              TextSpan(
                                  text: 'Privacy Policy',
                                  style: TextStyle(
                                      color: AppColors.gold,
                                      fontWeight: FontWeight.w700)),
                              TextSpan(text: ' of SignFix. *'),
                            ],
                          ),
                        )),
                      ]),
                ),
              ),

              if (_error != null) ...[
                const SizedBox(height: 14),
                RegErrorBox(_error!)
              ],
              const SizedBox(height: 28),

              SizedBox(
                width: double.infinity,
                child: _loading
                    ? Container(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        decoration: BoxDecoration(
                            color: AppColors.gold.withValues(alpha: .3),
                            borderRadius: BorderRadius.circular(14)),
                        child: const Center(
                            child:
                                Row(mainAxisSize: MainAxisSize.min, children: [
                          SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: AppColors.gold)),
                          SizedBox(width: 10),
                          Text('Sending OTP…',
                              style: TextStyle(
                                  color: AppColors.gold,
                                  fontWeight: FontWeight.w700)),
                        ])),
                      )
                    : FilledButton.icon(
                        onPressed: _sendOtpAndNext,
                        icon: const Icon(Icons.sms_outlined),
                        label: Text(
                            'Send OTP to ${widget.data.mobile.isNotEmpty ? widget.data.mobile : "Mobile"}'),
                      ),
              ),
              const SizedBox(height: 20),
            ]),
          )),
        ]),
      );
}

class _PasswordStrength extends StatelessWidget {
  const _PasswordStrength({required this.password});
  final String password;
  int get _score {
    int s = 0;
    if (password.length >= 8) s++;
    if (password.length >= 12) s++;
    if (RegExp(r'[A-Z]').hasMatch(password)) s++;
    if (RegExp(r'\d').hasMatch(password)) s++;
    if (RegExp(r'[!@#\$%^&*]').hasMatch(password)) s++;
    return s;
  }

  @override
  Widget build(BuildContext context) {
    final s = _score;
    final color = s <= 1
        ? AppColors.danger
        : s <= 3
            ? AppColors.warning
            : AppColors.success;
    final label = s <= 1
        ? 'Weak'
        : s <= 3
            ? 'Medium'
            : 'Strong';
    return Row(children: [
      Expanded(
          child: LinearProgressIndicator(
        value: s / 5,
        color: color,
        backgroundColor: AppColors.cardBorder,
        borderRadius: BorderRadius.circular(4),
        minHeight: 4,
      )),
      const SizedBox(width: 10),
      Text(label,
          style: TextStyle(
              color: color, fontSize: 11, fontWeight: FontWeight.w700)),
    ]);
  }
}
