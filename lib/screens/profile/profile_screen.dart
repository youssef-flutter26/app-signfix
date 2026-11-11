import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../core/app_theme.dart';
import '../../core/app_utils.dart';
import '../../services/api_client.dart';
import '../../widgets/common.dart';
import '../notifications/notifications_screen.dart';
import '../support/help_support_screen.dart';
import 'wallet_screen.dart';
import '../../widgets/address_autocomplete_field.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({
    super.key,
    required this.api,
    required this.onLogout,
    this.onOpenActivity,
  });
  final ApiClient api;
  final VoidCallback onLogout;
  final ValueChanged<int>? onOpenActivity;
  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  late Future<Map<String, dynamic>> _future;
  bool _editing = false;
  final _nameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _addressCtrl = TextEditingController();
  bool _saving = false;

  String _addressLine(Object? address) {
    if (address is String) return address;
    if (address is! Map) return '';

    return (address['addressLine'] ?? address['address_line'])?.toString() ??
        '';
  }

  String _addressText(Object? address) {
    if (address is String) return address;
    if (address is! Map) return '';

    return [
      address['addressLine'] ?? address['address_line'],
      address['city'],
      address['state'],
      address['pincode'],
    ]
        .where((part) => part != null && part.toString().trim().isNotEmpty)
        .map((part) => part.toString().trim())
        .join(', ');
  }

  @override
  void initState() {
    super.initState();
    _future = widget.api.getProfile();
  }

  Future<void> _refreshProfile() async {
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
    _addressCtrl.dispose();
    super.dispose();
  }

  void _startEdit(Map<String, dynamic> p) {
    _nameCtrl.text = p['name']?.toString() ?? '';
    _phoneCtrl.text = (p['phone'] ?? p['mobile'])?.toString() ?? '';
    // Clear "Not provided" placeholder so user sees empty field
    final addr = _addressLine(p['address']);
    _addressCtrl.text =
        (addr == 'Not provided' || addr == 'not provided') ? '' : addr;
    setState(() => _editing = true);
  }

  Future<void> _pickProfilePhoto(Map<String, dynamic> p) async {
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
                    color: AppColors.gold.withValues(alpha: .12),
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
      // Remove photo
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

  void _openSavedAddressesModal(Map<String, dynamic> p) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => _SavedAddressesSheet(
        api: widget.api,
        onChanged: _refreshProfile,
      ),
    );
  }

  Future<void> _saveEdit() async {
    setState(() => _saving = true);
    try {
      await widget.api.updateProfile({
        'name': _nameCtrl.text.trim(),
        'mobile': _phoneCtrl.text.trim(),
        'address': _addressCtrl.text.trim(),
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
            style: TextStyle(color: AppColors.charcoal)),
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
      widget.onLogout(); // main.dart _logout() → popUntil + setState
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: AppColors.softGray,
        appBar: AppBar(
          backgroundColor: AppColors.appBar,
          foregroundColor: AppColors.navy,
          elevation: 0,
          surfaceTintColor: Colors.transparent,
          title: const Text('My Account',
              style: TextStyle(
                  color: AppColors.navy, fontWeight: FontWeight.w800)),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_rounded,
                color: AppColors.goldDark),
            onPressed: () => Navigator.pop(context),
          ),
        ),
        body: FutureBuilder<Map<String, dynamic>>(
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
                          width: 2,
                        ),
                      ),
                      child: Icon(
                        isAuthError
                            ? Icons.lock_outline_rounded
                            : Icons.error_outline_rounded,
                        color:
                            isAuthError ? AppColors.warning : AppColors.danger,
                        size: 40,
                      ),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      isAuthError
                          ? 'Session Expired'
                          : 'Could Not Load Profile',
                      style: const TextStyle(
                        color: AppColors.navy,
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      isAuthError
                          ? 'Your session has expired. Please sign in again to continue.'
                          : 'Unable to load your profile. Please try again.',
                      style: const TextStyle(
                          color: AppColors.midGray, fontSize: 13),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 24),
                    if (isAuthError)
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton.icon(
                          onPressed: () async {
                            await widget.api.logout();
                            widget.onLogout();
                          },
                          icon: const Icon(Icons.login_rounded),
                          label: const Text('Sign In Again'),
                        ),
                      )
                    else
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton(
                          onPressed: () {
                            final future = widget.api.getProfile();
                            setState(() {
                              _future = future;
                            });
                          },
                          child: const Text('Try Again'),
                        ),
                      ),
                  ]),
                ),
              );
            }
            final p = snap.data!;
            return RefreshIndicator(
              color: AppColors.gold,
              backgroundColor: AppColors.white,
              onRefresh: _refreshProfile,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(18),
                children: [
                  // ── Avatar + Name ────────────────────────────────────────────
                  Center(
                      child: Column(children: [
                    GestureDetector(
                      onTap: () => _pickProfilePhoto(p),
                      child: Stack(
                        children: [
                          Container(
                            width: 88,
                            height: 88,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: AppColors.gold.withValues(alpha: .15),
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
                                      fit: BoxFit.cover, width: 88, height: 88)
                                  : Center(
                                      child: Text(
                                      (p['name'] as String? ?? 'C')
                                          .substring(0, 1)
                                          .toUpperCase(),
                                      style: const TextStyle(
                                          fontSize: 36,
                                          fontWeight: FontWeight.w900,
                                          color: AppColors.gold),
                                    )),
                            ),
                          ),
                          // Camera icon overlay
                          Positioned(
                            bottom: 0,
                            right: 0,
                            child: Container(
                              width: 26,
                              height: 26,
                              decoration: const BoxDecoration(
                                color: AppColors.gold,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.camera_alt_rounded,
                                  size: 14, color: AppColors.navy),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(p['name']?.toString() ?? 'Customer',
                        style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                            color: AppColors.navy)),
                    const SizedBox(height: 4),
                    Text(p['email']?.toString() ?? '',
                        style: const TextStyle(
                            color: AppColors.midGray, fontSize: 13)),
                    const SizedBox(height: 4),
                    Text('Member since ${p['memberSince'] ?? ''}',
                        style: const TextStyle(
                            fontSize: 11, color: AppColors.charcoal)),
                  ])),
                  const SizedBox(height: 20),

                  // ── Stats ────────────────────────────────────────────────────
                  Row(children: [
                    _StatCard('${p['totalOrders'] ?? 0}', 'Orders',
                        Icons.shopping_bag_outlined, AppColors.gold,
                        onTap: () => widget.onOpenActivity?.call(0)),
                    const SizedBox(width: 8),
                    _StatCard('${p['totalServices'] ?? 0}', 'Services',
                        Icons.build_outlined, AppColors.info,
                        onTap: () => widget.onOpenActivity?.call(1)),
                    const SizedBox(width: 8),
                    _StatCard(
                      money(p['walletBalance'] ?? 0),
                      'Wallet',
                      Icons.account_balance_wallet_outlined,
                      AppColors.success,
                      onTap: () async {
                        await Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => WalletScreen(api: widget.api),
                          ),
                        );
                        _refreshProfile();
                      },
                    ),
                  ]),
                  const SizedBox(height: 20),

                  // ── Personal Info ─────────────────────────────────────────────
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
                            const Text('Personal Information',
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
                                        color: AppColors.goldDark
                                            .withValues(alpha: .3)),
                                  ),
                                  child: const Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(Icons.edit_outlined,
                                            size: 14,
                                            color: AppColors.goldDark),
                                        SizedBox(width: 4),
                                        Text('Edit',
                                            style: TextStyle(
                                                color: AppColors.goldDark,
                                                fontWeight: FontWeight.w700,
                                                fontSize: 12)),
                                      ]),
                                ),
                              ),
                          ]),
                          const SizedBox(height: 14),
                          if (_editing) ...[
                            TextField(
                              controller: _nameCtrl,
                              style: const TextStyle(color: AppColors.charcoal),
                              decoration: const InputDecoration(
                                labelText: 'Full name',
                                prefixIcon: Icon(Icons.person_outline),
                              ),
                            ),
                            const SizedBox(height: 10),
                            TextField(
                              controller: _phoneCtrl,
                              keyboardType: TextInputType.phone,
                              style: const TextStyle(color: AppColors.charcoal),
                              decoration: const InputDecoration(
                                labelText: 'Phone',
                                prefixIcon: Icon(Icons.phone_outlined),
                              ),
                            ),
                            const SizedBox(height: 10),
                            TextField(
                              controller: _addressCtrl,
                              maxLines: 2,
                              style: const TextStyle(color: AppColors.charcoal),
                              decoration: const InputDecoration(
                                labelText: 'Address',
                                hintText: 'Enter your full address',
                                prefixIcon: Icon(Icons.location_on_outlined),
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
                                      onPressed: _saveEdit,
                                      child: const Text('Save'))),
                            ]),
                          ] else ...[
                            _InfoRow(
                                Icons.phone_outlined,
                                'Phone',
                                (p['phone'] ?? p['mobile'])?.toString() ??
                                    'Not set'),
                            const SizedBox(height: 10),
                            if (p['emergencyContact'] != null &&
                                p['emergencyContact']
                                    .toString()
                                    .isNotEmpty) ...[
                              _InfoRow(
                                  Icons.emergency_outlined,
                                  'Emergency Contact',
                                  p['emergencyContact'].toString()),
                              const SizedBox(height: 10),
                            ],
                            _InfoRow(
                                Icons.location_on_outlined,
                                'Address',
                                _addressText(p['address']).isEmpty ||
                                        _addressText(p['address'])
                                            .toLowerCase()
                                            .contains('not provided')
                                    ? 'Not set — tap Edit to add'
                                    : _addressText(p['address'])),
                          ],
                        ]),
                  ),
                  const SizedBox(height: 14),

                  // ── Menu options ──────────────────────────────────────────────
                  Container(
                    decoration: BoxDecoration(
                      color: AppColors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppColors.cardBorder),
                    ),
                    child: Column(children: [
                      _MenuTile(
                        icon: Icons.account_balance_wallet_outlined,
                        iconColor: AppColors.success,
                        title: 'Wallet & Cashback',
                        subtitle:
                            'Available Balance: ${money(p['walletBalance'] ?? 0)}',
                        trailing: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: AppColors.success.withValues(alpha: .14),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: AppColors.success.withValues(alpha: .4),
                            ),
                          ),
                          child: Text(
                            money(p['walletBalance'] ?? 0),
                            style: const TextStyle(
                              color: AppColors.success,
                              fontWeight: FontWeight.w800,
                              fontSize: 12,
                            ),
                          ),
                        ),
                        onTap: () async {
                          await Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => WalletScreen(api: widget.api),
                            ),
                          );
                          _refreshProfile();
                        },
                      ),
                      const Divider(height: 0, color: AppColors.cardBorder),

                      // Saved Delivery Addresses
                      _MenuTile(
                        icon: Icons.location_on_outlined,
                        iconColor: AppColors.gold,
                        title: 'Saved Delivery Addresses',
                        subtitle: 'Manage home, shop & work locations',
                        onTap: () => _openSavedAddressesModal(p),
                      ),
                      const Divider(height: 0, color: AppColors.cardBorder),

                      // Notifications
                      _MenuTile(
                        icon: Icons.notifications_outlined,
                        iconColor: AppColors.gold,
                        title: 'Notifications',
                        onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) =>
                                  NotificationsScreen(api: widget.api),
                            )),
                      ),
                      const Divider(height: 0, color: AppColors.cardBorder),

                      // Help & Support
                      _MenuTile(
                        icon: Icons.help_outline_rounded,
                        iconColor: AppColors.gold,
                        title: 'Help & Support',
                        onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const HelpSupportScreen(),
                            )),
                      ),
                      const Divider(height: 0, color: AppColors.cardBorder),

                      // About SignFix
                      _MenuTile(
                        icon: Icons.info_outline_rounded,
                        iconColor: AppColors.success,
                        title: 'About SignFix',
                        onTap: () => showDialog(
                          context: context,
                          builder: (_) => AlertDialog(
                            backgroundColor: AppColors.white,
                            title: Row(children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: Image.asset('assets/images/logo.jpeg',
                                    width: 32, height: 32, fit: BoxFit.cover),
                              ),
                              const SizedBox(width: 10),
                              RichText(
                                  text: const TextSpan(children: [
                                TextSpan(
                                    text: 'Sign',
                                    style: TextStyle(
                                        color: AppColors.navy,
                                        fontSize: 18,
                                        fontWeight: FontWeight.w900)),
                                TextSpan(
                                    text: 'Fix',
                                    style: TextStyle(
                                        color: AppColors.gold,
                                        fontSize: 18,
                                        fontWeight: FontWeight.w900)),
                              ])),
                            ]),
                            content: const Text(
                              'Version 1.0.0\n\nSign Board Sales, Service & Maintenance Management Platform.\n\nREPAIR  •  MANUFACTURE  •  INSTALL\n\nDeveloped by DL SSR INFOTECH',
                              style: TextStyle(
                                  color: AppColors.charcoal, height: 1.5),
                            ),
                            actions: [
                              FilledButton(
                                onPressed: () => Navigator.pop(context),
                                child: const Text('Close'),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ]),
                  ),
                  const SizedBox(height: 20),

                  // ── Sign out ──────────────────────────────────────────────────
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
                                  fontSize: 15,
                                )),
                          ]),
                    ),
                  ),
                  const SizedBox(height: 30),
                ],
              ),
            );
          },
        ),
      );
}

// ── Widgets ───────────────────────────────────────────────────────────────────
class _StatCard extends StatelessWidget {
  const _StatCard(this.value, this.label, this.icon, this.color, {this.onTap});
  final String value, label;
  final IconData icon;
  final Color color;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => Expanded(
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(14),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 14),
              decoration: BoxDecoration(
                color: AppColors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: color.withValues(alpha: .3)),
              ),
              child: Row(children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: .12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icon, color: color, size: 18),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          value,
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: color,
                          ),
                        ),
                      ),
                      Text(
                        label,
                        style: const TextStyle(
                          fontSize: 11,
                          color: AppColors.charcoal,
                        ),
                      ),
                    ],
                  ),
                ),
              ]),
            ),
          ),
        ),
      );
}

class _InfoRow extends StatelessWidget {
  const _InfoRow(this.icon, this.label, this.value);
  final IconData icon;
  final String label, value;
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
                        fontSize: 11, color: AppColors.charcoal)),
                const SizedBox(height: 2),
                Text(value,
                    style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppColors.charcoal)),
              ])),
        ],
      );
}

class _MenuTile extends StatelessWidget {
  const _MenuTile({
    required this.icon,
    required this.iconColor,
    required this.title,
    this.subtitle,
    this.trailing,
    required this.onTap,
  });
  final IconData icon;
  final Color iconColor;
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: iconColor.withValues(alpha: .12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: iconColor, size: 18),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: AppColors.navy,
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                  if (subtitle != null && subtitle!.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      subtitle!,
                      style: const TextStyle(
                        color: AppColors.charcoal,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            if (trailing != null) ...[
              trailing!,
              const SizedBox(width: 8),
            ],
            const Icon(Icons.arrow_forward_ios_rounded,
                size: 14, color: AppColors.textMuted),
          ]),
        ),
      );
}

class _SavedAddressesSheet extends StatefulWidget {
  const _SavedAddressesSheet({
    required this.api,
    required this.onChanged,
  });

  final ApiClient api;
  final VoidCallback onChanged;

  @override
  State<_SavedAddressesSheet> createState() => _SavedAddressesSheetState();
}

class _SavedAddressesSheetState extends State<_SavedAddressesSheet> {
  bool _loading = true;
  List<Map<String, dynamic>> _addresses = [];
  bool _addingNew = false;
  bool _saving = false;

  String _label = 'Home';
  bool _isDefault = false;
  StructuredAddress? _newAddress;

  @override
  void initState() {
    super.initState();
    _fetch();
  }

  Future<void> _fetch() async {
    setState(() => _loading = true);
    try {
      final list = await widget.api.getSavedAddresses();
      if (mounted) {
        setState(() {
          _addresses = list;
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _delete(dynamic id) async {
    try {
      await widget.api.deleteCustomerAddress(id);
      await _fetch();
      widget.onChanged();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not delete address: $e'),
            backgroundColor: AppColors.danger,
          ),
        );
      }
    }
  }

  Future<void> _saveNew() async {
    if (_newAddress == null || _newAddress!.fullDisplayAddress.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter an address.'),
          backgroundColor: AppColors.danger,
        ),
      );
      return;
    }

    setState(() => _saving = true);
    try {
      final addr = _newAddress!;
      final line = addr.addressLine.isNotEmpty
          ? addr.addressLine
          : addr.formattedAddress;

      await widget.api.saveCustomerAddress({
        'label': _label,
        'addressLine': line,
        'city': addr.city.isNotEmpty ? addr.city : null,
        'state': addr.state.isNotEmpty ? addr.state : null,
        'pincode': addr.pincode.isNotEmpty ? addr.pincode : null,
        'latitude': addr.latitude,
        'longitude': addr.longitude,
        'isDefault': _isDefault,
      });

      setState(() {
        _addingNew = false;
        _newAddress = null;
        _saving = false;
      });
      await _fetch();
      widget.onChanged();
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to save address: $e'),
            backgroundColor: AppColors.danger,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        top: 20,
        left: 20,
        right: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Row(
                children: [
                  Icon(Icons.location_on_outlined,
                      color: AppColors.gold, size: 22),
                  SizedBox(width: 8),
                  Text(
                    'Saved Delivery Addresses',
                    style: TextStyle(
                        color: AppColors.navy,
                        fontSize: 18,
                        fontWeight: FontWeight.w800),
                  ),
                ],
              ),
              IconButton(
                icon: const Icon(Icons.close, color: AppColors.midGray),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (_loading)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(32),
                child: CircularProgressIndicator(color: AppColors.gold),
              ),
            )
          else ...[
            if (_addresses.isEmpty && !_addingNew)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Center(
                  child: Column(
                    children: [
                      Icon(Icons.location_off_outlined,
                          size: 48, color: AppColors.midGray),
                      SizedBox(height: 12),
                      Text(
                        'No saved addresses yet',
                        style: TextStyle(
                            color: AppColors.textSecondary, fontSize: 14),
                      ),
                    ],
                  ),
                ),
              ),
            if (_addresses.isNotEmpty)
              Flexible(
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: _addresses.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (ctx, i) {
                    final a = _addresses[i];
                    final label = a['label']?.toString() ?? 'Other';
                    final line = a['addressLine']?.toString() ??
                        a['address_line']?.toString() ??
                        '';
                    final city = a['city']?.toString() ?? '';
                    final pincode = a['pincode']?.toString() ?? '';
                    final isDef = a['isDefault'] == true;

                    return Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.navyCard,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                            color:
                                isDef ? AppColors.gold : AppColors.cardBorder),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            label.toLowerCase() == 'home'
                                ? Icons.home_outlined
                                : label.toLowerCase() == 'shop'
                                    ? Icons.storefront_outlined
                                    : Icons.business_outlined,
                            color: isDef ? AppColors.gold : AppColors.navy,
                            size: 22,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Text(
                                      label,
                                      style: const TextStyle(
                                          color: AppColors.textBody,
                                          fontWeight: FontWeight.w700,
                                          fontSize: 14),
                                    ),
                                    if (isDef) ...[
                                      const SizedBox(width: 8),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 6, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: AppColors.gold
                                              .withValues(alpha: .2),
                                          borderRadius:
                                              BorderRadius.circular(6),
                                        ),
                                        child: const Text(
                                          'Default',
                                          style: TextStyle(
                                              color: AppColors.goldDark,
                                              fontSize: 10,
                                              fontWeight: FontWeight.w700),
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  [line, city, pincode]
                                      .where((s) => s.isNotEmpty)
                                      .join(', '),
                                  style: const TextStyle(
                                      color: AppColors.charcoal, fontSize: 12),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete_outline,
                                color: AppColors.danger, size: 20),
                            onPressed: () => _delete(a['id']),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            const SizedBox(height: 12),
            if (!_addingNew)
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.add_location_alt_outlined,
                      color: AppColors.gold),
                  label: const Text('Add New Address',
                      style: TextStyle(
                          color: AppColors.navy, fontWeight: FontWeight.w700)),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: AppColors.gold),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: () => setState(() => _addingNew = true),
                ),
              )
            else ...[
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.navyCard,
                  borderRadius: BorderRadius.circular(12),
                  border:
                      Border.all(color: AppColors.gold.withValues(alpha: .4)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Label:',
                        style: TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 12,
                            fontWeight: FontWeight.w600)),
                    const SizedBox(height: 6),
                    Row(
                      children: ['Home', 'Shop', 'Work', 'Other'].map((lbl) {
                        final sel = _label == lbl;
                        return Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: ChoiceChip(
                            label: Text(lbl),
                            selected: sel,
                            onSelected: (_) => setState(() => _label = lbl),
                            selectedColor: AppColors.gold,
                            backgroundColor: AppColors.cardBg,
                            labelStyle: TextStyle(
                              color: sel ? AppColors.navy : AppColors.textBody,
                              fontSize: 12,
                              fontWeight:
                                  sel ? FontWeight.w700 : FontWeight.w500,
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 12),
                    AddressAutocompleteField(
                      api: widget.api,
                      allowSave: false,
                      onAddressSelected: (addr) => _newAddress = addr,
                    ),
                    const SizedBox(height: 8),
                    CheckboxListTile(
                      value: _isDefault,
                      onChanged: (v) => setState(() => _isDefault = v ?? false),
                      contentPadding: EdgeInsets.zero,
                      activeColor: AppColors.gold,
                      dense: true,
                      title: const Text('Set as default delivery address',
                          style: TextStyle(
                              color: AppColors.textBody, fontSize: 13)),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: TextButton(
                            onPressed: () => setState(() => _addingNew = false),
                            child: const Text('Cancel',
                                style: TextStyle(color: AppColors.navy)),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.gold,
                              foregroundColor: AppColors.navyDeep,
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10)),
                            ),
                            onPressed: _saving ? null : _saveNew,
                            child: _saving
                                ? const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: AppColors.navyDeep),
                                  )
                                : const Text('Save Address',
                                    style:
                                        TextStyle(fontWeight: FontWeight.w700)),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ],
        ],
      ),
    );
  }
}
