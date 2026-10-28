import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../core/app_theme.dart';
import '../../services/api_client.dart';
import '../../widgets/common.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({
    super.key,
    required this.api,
    required this.onAuthenticated,
    required this.onLoginTap,
  });
  final ApiClient api;
  final VoidCallback onAuthenticated;
  final VoidCallback onLoginTap;
  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _phone = TextEditingController();
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  bool _loading = false;
  bool _obscure = true;
  String? _error;
  String? _photoPath;

  @override
  void initState() {
    super.initState();
    // Prevent user from deleting the +91 prefix
    _phone.addListener(() {
      const prefix = '+91 ';
      if (!_phone.text.startsWith(prefix)) {
        final digits = _phone.text.replaceAll(RegExp(r'[^\d]'), '');
        final cleaned = digits.startsWith('91')
            ? digits.substring(2)
            : digits.startsWith('0')
                ? digits.substring(1)
                : digits;
        _phone.value = TextEditingValue(
          text: prefix + cleaned,
          selection:
              TextSelection.collapsed(offset: prefix.length + cleaned.length),
        );
      }
    });
    _phone.text = '+91 ';
    _phone.selection = TextSelection.collapsed(offset: _phone.text.length);
  }

  @override
  void dispose() {
    for (final c in [_name, _email, _phone, _password, _confirm]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _pickPhoto() async {
    final src = await showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: AppColors.white,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(width: 40, height: 4,
              decoration: BoxDecoration(color: AppColors.cardBorder,
                  borderRadius: BorderRadius.circular(2))),
          const SizedBox(height: 14),
          const Text('Profile Photo',
              style: TextStyle(color: AppColors.navy,
                  fontWeight: FontWeight.w800, fontSize: 16)),
          const SizedBox(height: 10),
          ListTile(
            leading: const Icon(Icons.camera_alt_outlined, color: AppColors.gold),
            title: const Text('Take Photo',
                style: TextStyle(color: AppColors.charcoal)),
            onTap: () => Navigator.pop(context, ImageSource.camera),
          ),
          ListTile(
            leading: const Icon(Icons.photo_library_outlined, color: AppColors.info),
            title: const Text('Choose from Gallery',
                style: TextStyle(color: AppColors.charcoal)),
            onTap: () => Navigator.pop(context, ImageSource.gallery),
          ),
        ]),
      ),
    );
    if (src == null) return;
    final img = await ImagePicker().pickImage(source: src, imageQuality: 80);
    if (img != null && mounted) setState(() => _photoPath = img.path);
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    final name = _name.text.trim();
    final email = _email.text.trim();
    final phone = _phone.text.trim();
    final pass = _password.text;
    final confirm = _confirm.text;

    if (_photoPath == null || _photoPath!.isEmpty) {
      setState(() => _error = 'Profile photo is required. Please add your photo.');
      return;
    }
    if (name.isEmpty) {
      setState(() => _error = 'Full name is required.');
      return;
    }
    if (name.length < 2) {
      setState(() => _error = 'Full name must be at least 2 characters.');
      return;
    }
    if (email.isEmpty) {
      setState(() => _error = 'Email address is required.');
      return;
    }
    if (!email.contains('@') || !email.contains('.')) {
      setState(() => _error = 'Please enter a valid email address.');
      return;
    }
    if (phone.isEmpty || phone == '+91 ' || phone == '+91') {
      setState(() => _error = 'Phone number is required.');
      return;
    }
    final cleanDigits = phone.replaceAll(RegExp(r'[\s\-\(\)\+]'), '');
    // +91 XXXXXXXXXX → "91" + 10 digits = 12 total
    final numberAfter91 =
        cleanDigits.startsWith('91') ? cleanDigits.substring(2) : cleanDigits;
    final mobileForBackend = '+91$numberAfter91';
    if (numberAfter91.length != 10 ||
        !RegExp(r'^\d+$').hasMatch(numberAfter91)) {
      setState(() => _error =
          'Enter a valid 10-digit number after +91 (e.g. +91 9876543210).');
      return;
    }
    if (pass.isEmpty) {
      setState(() => _error = 'Password is required.');
      return;
    }
    if (pass.length < 10) {
      setState(() => _error = 'Password must be at least 10 characters.');
      return;
    }
    if (!RegExp(r'^(?=.*[a-z])(?=.*[A-Z])(?=.*\d)(?=.*[^A-Za-z0-9]).{10,72}$')
        .hasMatch(pass)) {
      setState(() => _error =
          'Password must include uppercase, lowercase, a number, and a special character.');
      return;
    }
    if (confirm.isEmpty) {
      setState(() => _error = 'Please confirm your password.');
      return;
    }
    if (pass != confirm) {
      setState(() => _error = 'Passwords do not match.');
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final result =
          await widget.api.register(name, email, mobileForBackend, pass);
      if (mounted) {
        if (result['token'] != null) {
          widget.onAuthenticated();
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                result['message']?.toString() ??
                    'Account created. You can now sign in.',
              ),
              backgroundColor: AppColors.success,
              duration: const Duration(seconds: 5),
            ),
          );
          widget.onLoginTap();
        }
      }
    } catch (e) {
      if (mounted) {
        String msg = e.toString();
        if (msg.startsWith('Exception: ')) msg = msg.substring(11);
        if (msg.startsWith('ApiException: ')) msg = msg.substring(14);
        setState(() => _error = msg);
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: AppColors.softGray,
        body: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 430),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // ── Profile Photo ─────────────────────────────────────
                    Center(
                      child: GestureDetector(
                        onTap: _pickPhoto,
                        child: Stack(children: [
                          Container(
                            width: 90,
                            height: 90,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: AppColors.softGray,
                              border: Border.all(
                                color: _photoPath == null
                                    ? AppColors.danger.withValues(alpha: .7)
                                    : AppColors.gold.withValues(alpha: .6),
                                width: 2,
                              ),
                              boxShadow: [
                                BoxShadow(
                                    color: AppColors.gold.withValues(alpha: .2),
                                    blurRadius: 16)
                              ],
                            ),
                            child: ClipOval(
                              child: _photoPath != null
                                  ? Image.file(File(_photoPath!),
                                      fit: BoxFit.cover)
                                  : const Icon(Icons.person_outline,
                                      size: 40, color: AppColors.textMuted),
                            ),
                          ),
                          Positioned(
                            bottom: 0,
                            right: 0,
                            child: Container(
                              padding: const EdgeInsets.all(6),
                              decoration: const BoxDecoration(
                                  color: AppColors.gold,
                                  shape: BoxShape.circle),
                              child: const Icon(Icons.camera_alt_rounded,
                                  size: 14, color: AppColors.navyDeep),
                            ),
                          ),
                        ]),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Center(
                      child: Text(
                        _photoPath == null
                            ? 'Profile Photo Required *'
                            : 'Photo Added ✓',
                        style: TextStyle(
                          color: _photoPath == null
                              ? AppColors.danger
                              : AppColors.success,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),

                    // ── Title ─────────────────────────────────────────────────
                    const Text('Create Account',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.w900,
                          color: AppColors.navy,
                        )),
                    const SizedBox(height: 6),
                    const Text(
                        'Join SignFix to order sign boards\nand request service.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: AppColors.textLight, // ✅ visible on dark bg
                          height: 1.4,
                          fontSize: 13,
                        )),
                    const SizedBox(height: 28),

                    // ── Fields ───────────────────────────────────────────────
                    _Field(
                      controller: _name,
                      label: 'Full name',
                      icon: Icons.person_outline,
                      action: TextInputAction.next,
                    ),
                    const SizedBox(height: 12),
                    _Field(
                      controller: _email,
                      label: 'Email address',
                      icon: Icons.mail_outline,
                      type: TextInputType.emailAddress,
                      action: TextInputAction.next,
                    ),
                    const SizedBox(height: 12),
                    // ── Phone with +91 prefix ────────────────────────────
                    TextField(
                      controller: _phone,
                      keyboardType: TextInputType.phone,
                      textInputAction: TextInputAction.next,
                      style: const TextStyle(color: AppColors.charcoal),
                      decoration: const InputDecoration(
                        labelText: 'Phone number',
                        hintText: '+91 9876543210',
                        prefixIcon: Icon(Icons.phone_outlined),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _password,
                      obscureText: _obscure,
                      textInputAction: TextInputAction.next,
                      style: const TextStyle(color: AppColors.charcoal),
                      decoration: InputDecoration(
                        labelText: 'Password',
                        prefixIcon: const Icon(Icons.lock_outline),
                        suffixIcon: IconButton(
                          icon: Icon(
                            _obscure
                                ? Icons.visibility_outlined
                                : Icons.visibility_off_outlined,
                            color: AppColors.gold,
                          ),
                          onPressed: () => setState(() => _obscure = !_obscure),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _confirm,
                      obscureText: _obscure,
                      onSubmitted: (_) => _submit(),
                      style: const TextStyle(color: AppColors.charcoal),
                      decoration: const InputDecoration(
                        labelText: 'Confirm password',
                        prefixIcon: Icon(Icons.lock_outline),
                      ),
                    ),

                    // ── Error ─────────────────────────────────────────────────
                    if (_error != null) ...[
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: AppColors.danger.withValues(alpha: .1),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                              color: AppColors.danger.withValues(alpha: .4)),
                        ),
                        child: Text(_error!,
                            style: const TextStyle(
                                color: AppColors.danger, fontSize: 13)),
                      ),
                    ],

                    const SizedBox(height: 20),
                    LoadingButton(
                        loading: _loading,
                        onPressed: _submit,
                        child: const Text('Create Account')),

                    const SizedBox(height: 16),

                    // ── Login link ────────────────────────────────────────────
                    Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                      const Text('Already have an account? ',
                          style: TextStyle(color: AppColors.textMuted)), // ✅
                      GestureDetector(
                        onTap: widget.onLoginTap,
                        child: const Text('Sign in',
                            style: TextStyle(
                              color: AppColors.gold, // ✅ gold not primary
                              fontWeight: FontWeight.w700,
                            )),
                      ),
                    ]),
                    const SizedBox(height: 8),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
}

// ── Reusable text field ───────────────────────────────────────────────────────
class _Field extends StatelessWidget {
  const _Field({
    required this.controller,
    required this.label,
    required this.icon,
    this.type = TextInputType.text,
    this.action = TextInputAction.next,
  });
  final TextEditingController controller;
  final String label;
  final IconData icon;
  final TextInputType type;
  final TextInputAction action;
  @override
  Widget build(BuildContext context) => TextField(
        controller: controller,
        keyboardType: type,
        textInputAction: action,
        style: const TextStyle(color: AppColors.charcoal), // ✅ charcoal input text
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(icon),
        ),
      );
}
