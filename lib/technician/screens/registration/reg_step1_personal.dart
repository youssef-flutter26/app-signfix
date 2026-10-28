import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../core/app_theme.dart';
import '../../services/api_client.dart';
import 'registration_data.dart';
import 'registration_widgets.dart';
import 'reg_step2_employment.dart';

class RegStep1Personal extends StatefulWidget {
  const RegStep1Personal({super.key, required this.api, required this.data});
  final TechnicianApi api;
  final TechRegistrationData data;
  @override
  State<RegStep1Personal> createState() => _RegStep1PersonalState();
}

class _RegStep1PersonalState extends State<RegStep1Personal> {
  final _name = TextEditingController();
  final _mobile = TextEditingController();
  final _email = TextEditingController();
  final _doj = TextEditingController();
  String? _photoPath;
  String? _error;

  @override
  void initState() {
    super.initState();
    _name.text = widget.data.fullName;
    _email.text = widget.data.email;
    _doj.text = widget.data.dateOfJoining;
    _photoPath = widget.data.profilePhotoPath;

    // +91 prefix for India
    _mobile.addListener(() {
      const prefix = '+91 ';
      if (!_mobile.text.startsWith(prefix)) {
        final digits = _mobile.text.replaceAll(RegExp(r'[^\d]'), '');
        final cleaned = digits.startsWith('91')
            ? digits.substring(2)
            : digits.startsWith('0')
                ? digits.substring(1)
                : digits;
        _mobile.value = TextEditingValue(
          text: prefix + cleaned,
          selection:
              TextSelection.collapsed(offset: prefix.length + cleaned.length),
        );
      }
    });
    // Set prefix or restore saved value
    if (widget.data.mobile.isEmpty) {
      _mobile.text = '+91 ';
      _mobile.selection = TextSelection.collapsed(offset: _mobile.text.length);
    } else {
      _mobile.text = widget.data.mobile;
    }
  }

  @override
  void dispose() {
    _name.dispose();
    _mobile.dispose();
    _email.dispose();
    _doj.dispose();
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
          Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                  color: AppColors.cardBorder,
                  borderRadius: BorderRadius.circular(2))),
          const SizedBox(height: 14),
          const Text('Profile Photo',
              style: TextStyle(
                  color: AppColors.navy,
                  fontWeight: FontWeight.w800,
                  fontSize: 16)),
          const SizedBox(height: 10),
          ListTile(
            leading:
                const Icon(Icons.camera_alt_outlined, color: AppColors.gold),
            title: const Text('Take Photo',
                style: TextStyle(color: AppColors.navy)),
            onTap: () => Navigator.pop(context, ImageSource.camera),
          ),
          ListTile(
            leading:
                const Icon(Icons.photo_library_outlined, color: AppColors.info),
            title: const Text('Choose from Gallery',
                style: TextStyle(color: AppColors.navy)),
            onTap: () => Navigator.pop(context, ImageSource.gallery),
          ),
        ]),
      ),
    );
    if (src == null) return;
    final img = await ImagePicker().pickImage(source: src, imageQuality: 80);
    if (img != null && mounted) setState(() => _photoPath = img.path);
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: const ColorScheme.light(
            primary: AppColors.gold,
            onPrimary: AppColors.navy,
            surface: AppColors.white,
            onSurface: AppColors.charcoal,
          ),
        ),
        child: child!,
      ),
    );
    if (picked != null && mounted) {
      setState(() => _doj.text = picked.toIso8601String().split('T').first);
    }
  }

  bool _validate() {
    if (_photoPath == null || _photoPath!.isEmpty) {
      setState(
          () => _error = 'Profile photo is required. Please add your photo.');
      return false;
    }
    if (_name.text.trim().isEmpty) {
      setState(() => _error = 'Full name is required.');
      return false;
    }
    if (_name.text.trim().length < 2) {
      setState(() => _error = 'Full name must be at least 2 characters.');
      return false;
    }
    final mob = _mobile.text.trim();
    if (mob.isEmpty || mob == '+91' || mob == '+91 ') {
      setState(() => _error = 'Mobile number is required.');
      return false;
    }
    final cleanDigits = mob.replaceAll(RegExp(r'[\s\-\(\)\+]'), '');
    final numberAfter91 =
        cleanDigits.startsWith('91') ? cleanDigits.substring(2) : cleanDigits;
    if (numberAfter91.length != 10 ||
        !RegExp(r'^\d+$').hasMatch(numberAfter91)) {
      setState(() => _error =
          'Enter a valid 10-digit number after +91 (e.g. +91 9876543210).');
      return false;
    }
    if (_email.text.trim().isEmpty) {
      setState(() => _error = 'Work email is required.');
      return false;
    }
    if (!_email.text.contains('@') || !_email.text.contains('.')) {
      setState(() => _error = 'Please enter a valid email address.');
      return false;
    }
    if (_doj.text.isEmpty) {
      setState(() =>
          _error = 'Date of joining is required. Please tap the date field.');
      return false;
    }
    setState(() => _error = null);
    return true;
  }

  void _next() {
    if (!_validate()) return;
    widget.data.fullName = _name.text.trim();
    // Normalize to +91XXXXXXXXXX format
    final cleanDigits = _mobile.text.replaceAll(RegExp(r'[\s\-\(\)\+]'), '');
    final numberAfter91 =
        cleanDigits.startsWith('91') ? cleanDigits.substring(2) : cleanDigits;
    widget.data.mobile = '+91$numberAfter91';
    widget.data.email = _email.text.trim();
    widget.data.dateOfJoining = _doj.text;
    widget.data.profilePhotoPath = _photoPath;
    Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) =>
              RegStep2Employment(api: widget.api, data: widget.data),
        ));
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
          const RegProgressBar(step: 1),
          Expanded(
              child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('Personal Information',
                  style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: AppColors.navy)),
              const SizedBox(height: 4),
              const Text('Step 1 of 3 — Tell us about yourself',
                  style: TextStyle(color: AppColors.midGray, fontSize: 13)),
              const SizedBox(height: 24),

              // Photo
              Center(
                  child: GestureDetector(
                onTap: _pickPhoto,
                child: Stack(children: [
                  Container(
                    width: 90,
                    height: 90,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppColors.white,
                      border: Border.all(
                          color: _photoPath == null
                              ? AppColors.danger.withValues(alpha: .7)
                              : AppColors.gold.withValues(alpha: .4),
                          width: 2),
                    ),
                    child: ClipOval(
                      child: _photoPath != null
                          ? Image.file(File(_photoPath!), fit: BoxFit.cover)
                          : const Icon(Icons.person_outline,
                              size: 40, color: AppColors.midGray),
                    ),
                  ),
                  Positioned(
                    bottom: 0,
                    right: 0,
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: const BoxDecoration(
                          color: AppColors.gold, shape: BoxShape.circle),
                      child: const Icon(Icons.camera_alt_rounded,
                          size: 14, color: AppColors.navy),
                    ),
                  ),
                ]),
              )),
              const SizedBox(height: 6),
              Center(
                  child: Text(
                _photoPath == null
                    ? 'Profile Photo (Required) *'
                    : 'Profile Photo Added ✓',
                style: TextStyle(
                    color: _photoPath == null
                        ? AppColors.danger
                        : AppColors.success,
                    fontSize: 12,
                    fontWeight: FontWeight.w600),
              )),
              const SizedBox(height: 22),

              RegField(
                  ctrl: _name,
                  label: 'Full Name *',
                  icon: Icons.person_outline),
              const SizedBox(height: 12),
              // Mobile with +91 prefix
              TextField(
                controller: _mobile,
                keyboardType: TextInputType.phone,
                textInputAction: TextInputAction.next,
                style: const TextStyle(color: AppColors.charcoal),
                decoration: const InputDecoration(
                  labelText: 'Mobile Number *',
                  hintText: '+91 9876543210',
                  prefixIcon: Icon(Icons.phone_outlined, color: AppColors.gold),
                ),
              ),
              const SizedBox(height: 4),
              const Text('OTP will be sent to this number',
                  style: TextStyle(color: AppColors.midGray, fontSize: 11)),
              const SizedBox(height: 12),
              RegField(
                  ctrl: _email,
                  label: 'Work Email *',
                  icon: Icons.mail_outline,
                  type: TextInputType.emailAddress),
              const SizedBox(height: 12),

              // Date picker
              GestureDetector(
                onTap: _pickDate,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
                  decoration: BoxDecoration(
                    color: AppColors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                        color: _doj.text.isEmpty
                            ? AppColors.inputBorder
                            : AppColors.gold.withValues(alpha: .4)),
                  ),
                  child: Row(children: [
                    const Icon(Icons.calendar_today_outlined,
                        color: AppColors.gold, size: 20),
                    const SizedBox(width: 12),
                    Expanded(
                        child: Text(
                      _doj.text.isEmpty ? 'Date of Joining *' : _doj.text,
                      style: TextStyle(
                          color: _doj.text.isEmpty
                              ? AppColors.midGray
                              : AppColors.midGray,
                          fontSize: 15),
                    )),
                    const Icon(Icons.arrow_drop_down_rounded,
                        color: AppColors.midGray),
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
                child: FilledButton.icon(
                  onPressed: _next,
                  icon: const Icon(Icons.arrow_forward_rounded),
                  label: const Text('Next: Employment Details'),
                ),
              ),
              const SizedBox(height: 20),
            ]),
          )),
        ]),
      );
}
