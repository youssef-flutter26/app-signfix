import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../core/app_theme.dart';
import '../../services/api_client.dart';
import '../../widgets/common.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key, required this.api, required this.onLogout});
  final TechnicianApi api;
  final VoidCallback onLogout;
  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  late Future<Map<String, dynamic>> _future;
  bool _editing = false;
  bool _saving = false;
  final _nameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _emergencyCtrl = TextEditingController();
  final _skillsCtrl = TextEditingController();
  bool _locationSharing = true;

  @override
  void initState() {
    super.initState();
    _future = widget.api.getProfile();
  }

  void _handleAuthError() async {
    await widget.api.logout();
    if (mounted) widget.onLogout();
  }

  void _reload() {
    final future = widget.api.getProfile();
    setState(() {
      _future = future;
    });
  }

  Future<void> _pullToRefresh() async {
    final future = widget.api.getProfile();
    setState(() {
      _future = future;
    });
    await future.then<void>((_) {}, onError: (Object _) {});
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    _emergencyCtrl.dispose();
    _skillsCtrl.dispose();
    super.dispose();
  }

  void _startEdit(Map<String, dynamic> p) {
    _nameCtrl.text = p['name'] ?? '';
    _phoneCtrl.text = (p['mobile'] ?? p['phone'])?.toString() ?? '';
    _emergencyCtrl.text = p['emergencyContact']?.toString() ?? '';
    _skillsCtrl.text = (p['skills'] as List? ?? []).join(', ');
    _locationSharing = p['locationSharing'] == true;
    setState(() => _editing = true);
  }

  Future<void> _pickPhoto(Map<String, dynamic> p) async {
    final picker = ImagePicker();
    final source = await showModalBottomSheet<ImageSource>(
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
          const SizedBox(height: 16),
          const Text('Update Profile Photo',
              style: TextStyle(
                  color: AppColors.navy,
                  fontWeight: FontWeight.w800,
                  fontSize: 16)),
          const SizedBox(height: 16),
          ListTile(
            leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                    color: AppColors.gold.withValues(alpha: .12),
                    borderRadius: BorderRadius.circular(10)),
                child: const Icon(Icons.camera_alt_outlined,
                    color: AppColors.gold)),
            title: const Text('Take Photo',
                style: TextStyle(
                    color: AppColors.navy, fontWeight: FontWeight.w600)),
            onTap: () => Navigator.pop(context, ImageSource.camera),
          ),
          ListTile(
            leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                    color: AppColors.navy.withValues(alpha: .08),
                    borderRadius: BorderRadius.circular(10)),
                child: const Icon(Icons.photo_library_outlined,
                    color: AppColors.gold)),
            title: const Text('Choose from Gallery',
                style: TextStyle(
                    color: AppColors.navy, fontWeight: FontWeight.w600)),
            onTap: () => Navigator.pop(context, ImageSource.gallery),
          ),
          if (p['profilePhotoPath'] != null &&
              (p['profilePhotoPath'] as String).isNotEmpty)
            ListTile(
              leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                      color: AppColors.danger.withValues(alpha: .12),
                      borderRadius: BorderRadius.circular(10)),
                  child: const Icon(Icons.delete_outline,
                      color: AppColors.danger)),
              title: const Text('Remove Photo',
                  style: TextStyle(
                      color: AppColors.danger, fontWeight: FontWeight.w600)),
              onTap: () => Navigator.pop(context, null),
            ),
        ]),
      ),
    );
    if (source == null && p['profilePhotoPath'] != null) {
      await widget.api.updateProfile({'profilePhotoPath': null});
      if (mounted) {
        final future = widget.api.getProfile();
        setState(() {
          _future = future;
        });
      }
      return;
    }
    if (source == null) return;
    final img = await picker.pickImage(source: source, imageQuality: 80);
    if (img == null || !mounted) return;
    await widget.api.updateProfile({'profilePhotoPath': img.path});
    if (mounted) {
      final future = widget.api.getProfile();
      setState(() {
        _future = future;
      });
    }
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      final skills = _skillsCtrl.text
          .split(',')
          .map((s) => s.trim())
          .where((s) => s.isNotEmpty)
          .toList();
      await widget.api.updateProfile({
        'name': _nameCtrl.text.trim(),
        'mobile': _phoneCtrl.text.trim(),
        'emergencyContact': _emergencyCtrl.text.trim(),
        'skills': skills,
        'locationSharing': _locationSharing,
      });
      if (mounted) {
        setState(() {
          _editing = false;
          _future = widget.api.getProfile();
        });
      }
    } catch (e) {
      if (mounted) showAppError(context, e);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _confirmLogout() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.white,
        title: const Text('Sign out', style: TextStyle(color: AppColors.navy)),
        content: const Text('Are you sure you want to sign out?',
            style: TextStyle(color: AppColors.midGray)),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel')),
          FilledButton(
              style: FilledButton.styleFrom(backgroundColor: AppColors.danger),
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Sign out')),
        ],
      ),
    );
    if (ok == true) {
      await widget.api.logout();
      widget.onLogout();
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: AppColors.softGray,
        appBar: AppBar(
          backgroundColor: AppColors.appBar,
          foregroundColor: AppColors.navy,
          automaticallyImplyLeading: false,
          title: const Text('My Profile',
              style: TextStyle(
                  color: AppColors.navy, fontWeight: FontWeight.w800)),
        ),
        body: Container(
          color: AppColors.softGray,
          child: FutureBuilder<Map<String, dynamic>>(
            future: _future,
            builder: (context, snap) {
              if (snap.connectionState != ConnectionState.done) {
                return const Center(
                    child: CircularProgressIndicator(color: AppColors.gold));
              }
              if (snap.hasError) {
                final errMsg = snap.error.toString();
                final isAuthError =
                    errMsg.toLowerCase().contains('authentication') ||
                        errMsg.toLowerCase().contains('unauthorized') ||
                        errMsg.toLowerCase().contains('401');
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(28),
                    child: Column(mainAxisSize: MainAxisSize.min, children: [
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: isAuthError
                              ? AppColors.warning.withValues(alpha: .1)
                              : AppColors.danger.withValues(alpha: .1),
                          shape: BoxShape.circle,
                          border: Border.all(
                              color: isAuthError
                                  ? AppColors.warning
                                  : AppColors.danger,
                              width: 2),
                        ),
                        child: Icon(
                            isAuthError
                                ? Icons.lock_outline_rounded
                                : Icons.error_outline_rounded,
                            color: isAuthError
                                ? AppColors.warning
                                : AppColors.danger,
                            size: 40),
                      ),
                      const SizedBox(height: 20),
                      Text(
                          isAuthError
                              ? 'Session Expired'
                              : 'Could Not Load Profile',
                          style: const TextStyle(
                              color: AppColors.navy,
                              fontSize: 18,
                              fontWeight: FontWeight.w800)),
                      const SizedBox(height: 8),
                      Text(
                          isAuthError
                              ? 'Your session has expired. Please sign in again.'
                              : 'Unable to load data. Please try again.',
                          style: const TextStyle(
                              color: AppColors.midGray, fontSize: 13),
                          textAlign: TextAlign.center),
                      const SizedBox(height: 24),
                      SizedBox(
                        width: double.infinity,
                        child: isAuthError
                            ? FilledButton.icon(
                                onPressed: _handleAuthError,
                                icon: const Icon(Icons.login_rounded),
                                label: const Text('Sign In Again'))
                            : OutlinedButton(
                                onPressed: _reload,
                                child: const Text('Try Again')),
                      ),
                    ]),
                  ),
                );
              }
              final p = snap.data!;
              final skills = List<String>.from(p['skills'] as List? ?? []);

              return RefreshIndicator(
                color: AppColors.gold,
                backgroundColor: AppColors.white,
                onRefresh: _pullToRefresh,
                child: ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.all(18),
                  children: [
                    // ── Avatar & Name ──────────────────────────────────────────────
                    Center(
                        child: Column(children: [
                      GestureDetector(
                        onTap: () => _pickPhoto(p),
                        child:
                            Stack(alignment: Alignment.bottomRight, children: [
                          Container(
                            width: 90,
                            height: 90,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: AppColors.gold.withValues(alpha: .12),
                              border: Border.all(
                                  color: AppColors.gold.withValues(alpha: .5),
                                  width: 2),
                              boxShadow: [
                                BoxShadow(
                                    color: AppColors.gold.withValues(alpha: .2),
                                    blurRadius: 16)
                              ],
                            ),
                            child: ClipOval(
                              child: p['profilePhotoPath'] != null &&
                                      (p['profilePhotoPath'] as String)
                                          .isNotEmpty
                                  ? Image.file(File(p['profilePhotoPath']),
                                      fit: BoxFit.cover, width: 90, height: 90)
                                  : Center(
                                      child: Text(
                                      (p['name'] as String? ?? 'T')
                                          .substring(0, 1)
                                          .toUpperCase(),
                                      style: const TextStyle(
                                          fontSize: 36,
                                          fontWeight: FontWeight.w900,
                                          color: AppColors.gold),
                                    )),
                            ),
                          ),
                          // Camera icon
                          Container(
                            padding: const EdgeInsets.all(6),
                            decoration: const BoxDecoration(
                                color: AppColors.gold, shape: BoxShape.circle),
                            child: const Icon(Icons.camera_alt_rounded,
                                size: 14, color: AppColors.navyDeep),
                          ),
                          // Online dot
                          Positioned(
                            top: 0,
                            right: 0,
                            child: Container(
                              padding: const EdgeInsets.all(3),
                              decoration: const BoxDecoration(
                                  color: AppColors.success,
                                  shape: BoxShape.circle),
                              child: const Icon(Icons.check_rounded,
                                  size: 10, color: AppColors.white),
                            ),
                          ),
                        ]),
                      ),
                      const SizedBox(height: 12),
                      Text(
                          p['name']?.toString().isNotEmpty == true
                              ? p['name'].toString()
                              : 'Technician',
                          style: const TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w800,
                              color: AppColors.navy)),
                      const SizedBox(height: 4),
                      Text(p['email'] ?? '',
                          style: const TextStyle(
                              color: AppColors.midGray, fontSize: 13)),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 5),
                        decoration: BoxDecoration(
                          color: AppColors.gold.withValues(alpha: .1),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                              color: AppColors.gold.withValues(alpha: .3)),
                        ),
                        child: Text(
                            p['employeeId']?.toString().isNotEmpty == true
                                ? 'EMP ID: ${p['employeeId']}'
                                : 'ID: ${p['technicianId'] ?? '—'}',
                            style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: AppColors.gold)),
                      ),
                    ])),
                    const SizedBox(height: 20),

                    // ── Performance ────────────────────────────────────────────────
                    Row(children: [
                      _PerfCard('${p['totalJobsCompleted'] ?? 0}', 'Jobs Done',
                          Icons.check_circle_outline, AppColors.success),
                      const SizedBox(width: 12),
                      _PerfCard('${p['rating'] ?? '—'}', 'Rating',
                          Icons.star_rounded, AppColors.warning),
                    ]),
                    const SizedBox(height: 16),

                    // ── Profile Details ────────────────────────────────────────────
                    Container(
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        color: AppColors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: AppColors.cardBorder),
                      ),
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(children: [
                              const Text('Profile Details',
                                  style: TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w800,
                                      color: AppColors.navy)),
                              const Spacer(),
                              if (!_editing)
                                GestureDetector(
                                  onTap: () => _startEdit(p),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 12, vertical: 6),
                                    decoration: BoxDecoration(
                                      color:
                                          AppColors.gold.withValues(alpha: .12),
                                      borderRadius: BorderRadius.circular(20),
                                      border: Border.all(
                                          color: AppColors.gold
                                              .withValues(alpha: .3)),
                                    ),
                                    child: const Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(Icons.edit_outlined,
                                              size: 14, color: AppColors.gold),
                                          SizedBox(width: 4),
                                          Text('Edit',
                                              style: TextStyle(
                                                  color: AppColors.gold,
                                                  fontWeight: FontWeight.w700,
                                                  fontSize: 12)),
                                        ]),
                                  ),
                                ),
                            ]),
                            const SizedBox(height: 14),
                            if (_editing) ...[
                              _Field(
                                  _nameCtrl, 'Full name', Icons.person_outline),
                              const SizedBox(height: 10),
                              _Field(_phoneCtrl, 'Phone', Icons.phone_outlined,
                                  type: TextInputType.phone),
                              const SizedBox(height: 10),
                              _Field(_emergencyCtrl, 'Emergency contact',
                                  Icons.emergency_outlined,
                                  type: TextInputType.phone),
                              const SizedBox(height: 10),
                              _Field(_skillsCtrl, 'Skills (comma separated)',
                                  Icons.build_outlined,
                                  hint: 'e.g. LED Wiring, ACP Fabrication'),
                              const SizedBox(height: 10),
                              Container(
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(12),
                                  border:
                                      Border.all(color: AppColors.cardBorder),
                                ),
                                child: Material(
                                  color: AppColors.white,
                                  borderRadius: BorderRadius.circular(12),
                                  child: SwitchListTile(
                                    contentPadding: const EdgeInsets.symmetric(
                                        horizontal: 14),
                                    value: _locationSharing,
                                    onChanged: (v) =>
                                        setState(() => _locationSharing = v),
                                    title: const Text('Location sharing',
                                        style: TextStyle(
                                            color: AppColors.navy,
                                            fontWeight: FontWeight.w600)),
                                    subtitle: const Text(
                                        'Allow admin to track your location during jobs',
                                        style: TextStyle(
                                            color: AppColors.midGray,
                                            fontSize: 12)),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 14),
                              Row(children: [
                                Expanded(
                                    child: OutlinedButton(
                                        onPressed: () =>
                                            setState(() => _editing = false),
                                        child: const Text('Cancel'))),
                                const SizedBox(width: 10),
                                Expanded(
                                    child: LoadingButton(
                                        loading: _saving,
                                        onPressed: _save,
                                        child: const Text('Save'))),
                              ]),
                            ] else ...[
                              _InfoRow(
                                  Icons.phone_outlined,
                                  'Phone',
                                  (p['mobile'] ?? p['phone'])
                                              ?.toString()
                                              .isNotEmpty ==
                                          true
                                      ? (p['mobile'] ?? p['phone']).toString()
                                      : 'Not set'),
                              const SizedBox(height: 10),
                              _InfoRow(
                                  Icons.emergency_outlined,
                                  'Emergency contact',
                                  p['emergencyContact']
                                              ?.toString()
                                              .isNotEmpty ==
                                          true
                                      ? p['emergencyContact'].toString()
                                      : 'Not set'),
                              const SizedBox(height: 10),
                              if (p['employeeId'] != null &&
                                  p['employeeId'].toString().isNotEmpty) ...[
                                _InfoRow(Icons.badge_outlined, 'Employee ID',
                                    p['employeeId'].toString()),
                                const SizedBox(height: 10),
                              ],
                              if (p['dateOfJoining'] != null &&
                                  p['dateOfJoining'].toString().isNotEmpty) ...[
                                _InfoRow(
                                    Icons.calendar_today_outlined,
                                    'Date of Joining',
                                    p['dateOfJoining'].toString()),
                                const SizedBox(height: 10),
                              ],
                              if ((p['serviceAreas'] as List?)?.isNotEmpty ==
                                  true) ...[
                                _InfoRow(
                                    Icons.location_city_outlined,
                                    'Work Location',
                                    (p['serviceAreas'] as List).join(', ')),
                                const SizedBox(height: 10),
                              ],
                              _InfoRow(
                                p['locationSharing'] == true
                                    ? Icons.location_on_outlined
                                    : Icons.location_off_outlined,
                                'Location sharing',
                                p['locationSharing'] == true
                                    ? 'Enabled'
                                    : 'Disabled',
                                valueColor: p['locationSharing'] == true
                                    ? AppColors.success
                                    : AppColors.midGray,
                              ),
                            ],
                          ]),
                    ),
                    const SizedBox(height: 14),

                    // ── Skills ─────────────────────────────────────────────────────
                    if (skills.isNotEmpty && !_editing)
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: AppColors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: AppColors.cardBorder),
                        ),
                        child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Skills',
                                  style: TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w800,
                                      color: AppColors.navy)),
                              const SizedBox(height: 12),
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: skills
                                    .map((s) => Container(
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 12, vertical: 6),
                                          decoration: BoxDecoration(
                                            color: AppColors.gold
                                                .withValues(alpha: .1),
                                            borderRadius:
                                                BorderRadius.circular(20),
                                            border: Border.all(
                                                color: AppColors.gold
                                                    .withValues(alpha: .3)),
                                          ),
                                          child: Text(s,
                                              style: const TextStyle(
                                                  color: AppColors.gold,
                                                  fontWeight: FontWeight.w600,
                                                  fontSize: 12)),
                                        ))
                                    .toList(),
                              ),
                            ]),
                      ),
                    const SizedBox(height: 20),

                    // ── Sign out ───────────────────────────────────────────────────
                    GestureDetector(
                      onTap: _confirmLogout,
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        decoration: BoxDecoration(
                          color: AppColors.danger.withValues(alpha: .08),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                              color: AppColors.danger.withValues(alpha: .4)),
                        ),
                        child: const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.logout_rounded,
                                  color: AppColors.danger, size: 20),
                              SizedBox(width: 8),
                              Text('Sign Out',
                                  style: TextStyle(
                                      color: AppColors.danger,
                                      fontWeight: FontWeight.w800,
                                      fontSize: 15)),
                            ]),
                      ),
                    ),
                    const SizedBox(height: 30),
                  ],
                ),
              );
            },
          ),
        ),
      );
}

// ── Widgets ────────────────────────────────────────────────────────────────────
class _PerfCard extends StatelessWidget {
  const _PerfCard(this.value, this.label, this.icon, this.color);
  final String value, label;
  final IconData icon;
  final Color color;
  @override
  Widget build(BuildContext context) => Expanded(
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: color.withValues(alpha: .3)),
          ),
          child: Row(children: [
            Container(
              padding: const EdgeInsets.all(9),
              decoration: BoxDecoration(
                  color: color.withValues(alpha: .12),
                  borderRadius: BorderRadius.circular(10)),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(width: 12),
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(value,
                  style: TextStyle(
                      fontSize: 22, fontWeight: FontWeight.w800, color: color)),
              Text(label,
                  style:
                      const TextStyle(fontSize: 12, color: AppColors.midGray)),
            ]),
          ]),
        ),
      );
}

class _Field extends StatelessWidget {
  const _Field(this.ctrl, this.label, this.icon,
      {this.type = TextInputType.text, this.hint});
  final TextEditingController ctrl;
  final String label;
  final IconData icon;
  final TextInputType type;
  final String? hint;
  @override
  Widget build(BuildContext context) => TextField(
        controller: ctrl,
        keyboardType: type,
        style: const TextStyle(color: AppColors.charcoal),
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          prefixIcon: Icon(icon),
        ),
      );
}

class _InfoRow extends StatelessWidget {
  const _InfoRow(this.icon, this.label, this.value, {this.valueColor});
  final IconData icon;
  final String label, value;
  final Color? valueColor;
  @override
  Widget build(BuildContext context) => Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: AppColors.gold),
          const SizedBox(width: 10),
          Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Text(label,
                    style: const TextStyle(
                        fontSize: 11, color: AppColors.midGray)),
                const SizedBox(height: 2),
                Text(value,
                    style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: valueColor ?? AppColors.charcoal)),
              ])),
        ],
      );
}
