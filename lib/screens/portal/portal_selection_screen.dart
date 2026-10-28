import 'package:flutter/material.dart';
import 'package:animated_text_kit/animated_text_kit.dart';
import '../../core/app_theme.dart';

enum PortalType { customer, technician }

class PortalSelectionScreen extends StatefulWidget {
  const PortalSelectionScreen({super.key, required this.onSelect});
  final void Function(PortalType portal) onSelect;
  @override
  State<PortalSelectionScreen> createState() => _PortalSelectionScreenState();
}

class _PortalSelectionScreenState extends State<PortalSelectionScreen>
    with TickerProviderStateMixin {
  late final AnimationController _fadeCtrl;
  late final Animation<double> _fade;

  @override
  void initState() {
    super.initState();
    _fadeCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 700));
    _fade = CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeOut);
    _fadeCtrl.forward();
  }

  @override
  void dispose() {
    _fadeCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.softGray,
      body: SafeArea(
        child: FadeTransition(
          opacity: _fade,
          child: LayoutBuilder(
            builder: (context, constraints) {
              return SingleChildScrollView(
                physics: const ClampingScrollPhysics(),
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                child: ConstrainedBox(
                  constraints: BoxConstraints(minHeight: constraints.maxHeight),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // ── Top: Logo + Brand ─────────────────────────────
                      _TopSection(),
                      const SizedBox(height: 12),

                      // ── Portal Cards ──────────────────────────────────
                      Column(children: [
                        _PortalCard(
                          title: 'Customer',
                          subtitle:
                              'Order sign boards, request service\nand track your jobs',
                          icon: Icons.storefront_rounded,
                          accentColor: AppColors.gold,
                          gradient: const LinearGradient(
                            colors: [AppColors.navy, AppColors.navyDeep],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          features: const [
                            (
                              Icons.shopping_bag_outlined,
                              'New sign board orders'
                            ),
                            (
                              Icons.calculate_outlined,
                              'Instant price calculator'
                            ),
                            (Icons.build_outlined, 'Service requests'),
                            (
                              Icons.location_on_outlined,
                              'GPS location sharing'
                            ),
                            (
                              Icons.receipt_long_outlined,
                              'Order & service tracking'
                            ),
                            (Icons.auto_awesome_outlined, 'AI assistant'),
                          ],
                          onTap: () => widget.onSelect(PortalType.customer),
                        ),
                        const SizedBox(height: 14),
                        _PortalCard(
                          title: 'Technician',
                          subtitle:
                              'Manage assigned jobs, navigate\nto sites and update status',
                          icon: Icons.engineering_rounded,
                          accentColor: AppColors.gold,
                          gradient: const LinearGradient(
                            colors: [AppColors.navyDeep, AppColors.navy],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          features: const [
                            (Icons.work_outline, 'View assigned jobs'),
                            (
                              Icons.navigation_outlined,
                              'GPS navigation to site'
                            ),
                            (
                              Icons.camera_alt_outlined,
                              'Before & after photos'
                            ),
                            (Icons.sync_alt_rounded, 'Job status workflow'),
                            (Icons.notifications_outlined, 'Emergency alerts'),
                            (Icons.verified_outlined, 'OTP job completion'),
                          ],
                          onTap: () => widget.onSelect(PortalType.technician),
                        ),
                      ]),

                      const SizedBox(height: 14),

                      // ── Footer ────────────────────────────────────────
                      _Footer(),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

// ── Top Section ───────────────────────────────────────────────────────────────
class _TopSection extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Column(children: [
        // Logo
        Container(
          width: 90,
          height: 90,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                  color: AppColors.gold.withValues(alpha: .3),
                  blurRadius: 24,
                  spreadRadius: 2),
            ],
          ),
          child: ClipOval(
            child: Image.asset('assets/images/logo.jpeg', fit: BoxFit.cover),
          ),
        ),
        const SizedBox(height: 12),

        // Sign + Fix title
        const Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          Text('Sign',
              style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.w900,
                  color: AppColors.navy,
                  letterSpacing: -0.5)),
          Text('Fix',
              style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.w900,
                  color: AppColors.gold,
                  letterSpacing: -0.5)),
        ]),
        const SizedBox(height: 6),

        // Animated tagline
        SizedBox(
          height: 22,
          child: AnimatedTextKit(
            animatedTexts: [
              ColorizeAnimatedText(
                'ALL SIGNAGE SOLUTIONS',
                textStyle: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 2),
                colors: [
                  AppColors.gold,
                  AppColors.navy,
                  AppColors.goldLight,
                  AppColors.textLight
                ],
              ),
              ColorizeAnimatedText(
                'REPAIR  •  MANUFACTURE  •  INSTALL',
                textStyle: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1),
                colors: [
                  AppColors.goldLight,
                  AppColors.navy,
                  AppColors.gold,
                  AppColors.textLight
                ],
              ),
            ],
            repeatForever: true,
            pause: const Duration(milliseconds: 500),
          ),
        ),
        const SizedBox(height: 8),

        // Gold divider
        Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          Container(width: 36, height: 1.5, color: AppColors.gold),
          const SizedBox(width: 6),
          Container(
              width: 6,
              height: 6,
              decoration: const BoxDecoration(
                  color: AppColors.gold, shape: BoxShape.circle)),
          const SizedBox(width: 6),
          Container(width: 36, height: 1.5, color: AppColors.gold),
        ]),
        const SizedBox(height: 10),

        const Text(
          'Select Your Portal',
          style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: AppColors.charcoal,
              letterSpacing: 0.4),
        ),
      ]);
}

// ── Portal Card ───────────────────────────────────────────────────────────────
class _PortalCard extends StatefulWidget {
  const _PortalCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.accentColor,
    required this.gradient,
    required this.features,
    required this.onTap,
  });
  final String title, subtitle;
  final IconData icon;
  final Color accentColor;
  final Gradient gradient;
  final List<(IconData, String)> features;
  final VoidCallback onTap;
  @override
  State<_PortalCard> createState() => _PortalCardState();
}

class _PortalCardState extends State<_PortalCard> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) {
        if (!mounted) return;
        setState(() => _pressed = false);
        widget.onTap();
      },
      onTapCancel: () {
        if (mounted) setState(() => _pressed = false);
      },
      child: AnimatedScale(
        scale: _pressed ? 0.97 : 1.0,
        duration: const Duration(milliseconds: 100),
        child: Container(
          width: double.infinity,
          decoration: BoxDecoration(
            color: AppColors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
                color: widget.accentColor.withValues(alpha: .4), width: 1.5),
            boxShadow: [
              BoxShadow(
                  color: widget.accentColor.withValues(alpha: .12),
                  blurRadius: 16,
                  offset: const Offset(0, 4)),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Header ──────────────────────────────────────────────
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Icon
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: widget.accentColor.withValues(alpha: .15),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                            color: widget.accentColor.withValues(alpha: .25)),
                      ),
                      child: Icon(widget.icon,
                          color: widget.accentColor, size: 24),
                    ),
                    const SizedBox(width: 12),

                    // Title + subtitle
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(children: [
                            Text(widget.title,
                                style: const TextStyle(
                                    color: AppColors.navy,
                                    fontSize: 18,
                                    fontWeight: FontWeight.w900)),
                            const SizedBox(width: 5),
                            Text('Portal',
                                style: TextStyle(
                                    color: widget.accentColor,
                                    fontSize: 18,
                                    fontWeight: FontWeight.w900)),
                          ]),
                          const SizedBox(height: 4),
                          Text(widget.subtitle,
                              style: const TextStyle(
                                  color: AppColors.textLight,
                                  fontSize: 12,
                                  height: 1.4)),
                        ],
                      ),
                    ),
                    const SizedBox(width: 10),

                    // Enter button
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 10),
                      decoration: BoxDecoration(
                        color: widget.accentColor,
                        borderRadius: BorderRadius.circular(22),
                      ),
                      child: Text(
                        'Enter',
                        style: TextStyle(
                          color: widget.accentColor == AppColors.gold
                              ? AppColors.navyDeep
                              : AppColors.white,
                          fontWeight: FontWeight.w800,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // Divider
              Divider(
                  height: 0, color: widget.accentColor.withValues(alpha: .2)),

              // ── Features 2x3 grid ────────────────────────────────────
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
                child: Column(
                  children: List.generate(3, (row) {
                    final i = row * 2;
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Row(children: [
                        Expanded(
                            child: _FeatureItem(
                                widget.features[i], widget.accentColor)),
                        if (i + 1 < widget.features.length)
                          Expanded(
                              child: _FeatureItem(
                                  widget.features[i + 1], widget.accentColor)),
                      ]),
                    );
                  }),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FeatureItem extends StatelessWidget {
  const _FeatureItem(this.feature, this.color);
  final (IconData, String) feature;
  final Color color;
  @override
  Widget build(BuildContext context) => Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(feature.$1, size: 13, color: color),
          const SizedBox(width: 5),
          Expanded(
            child: Text(
              feature.$2,
              style: const TextStyle(
                  color: AppColors.textLight, fontSize: 11.5, height: 1.3),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      );
}

// ── Footer ─────────────────────────────────────────────────────────────────────
class _Footer extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Column(children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: AppColors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppColors.cardBorder),
          ),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.handyman_outlined, size: 13, color: AppColors.gold),
              SizedBox(width: 5),
              Text('REPAIR',
                  style: TextStyle(
                      fontSize: 11,
                      color: AppColors.textLight,
                      fontWeight: FontWeight.w600)),
              SizedBox(width: 8),
              _Dot(),
              SizedBox(width: 8),
              Icon(Icons.settings_outlined, size: 13, color: AppColors.gold),
              SizedBox(width: 5),
              Text('MANUFACTURE',
                  style: TextStyle(
                      fontSize: 11,
                      color: AppColors.textLight,
                      fontWeight: FontWeight.w600)),
              SizedBox(width: 8),
              _Dot(),
              SizedBox(width: 8),
              Icon(Icons.construction_outlined,
                  size: 13, color: AppColors.gold),
              SizedBox(width: 5),
              Text('INSTALL',
                  style: TextStyle(
                      fontSize: 11,
                      color: AppColors.textLight,
                      fontWeight: FontWeight.w600)),
            ],
          ),
        ),
        const SizedBox(height: 8),
        const Text('DL SSR INFOTECH  •  SignFix v1.0',
            style: TextStyle(fontSize: 11, color: AppColors.textMuted)),
      ]);
}

class _Dot extends StatelessWidget {
  const _Dot();
  @override
  Widget build(BuildContext context) => Container(
      width: 3,
      height: 3,
      decoration:
          const BoxDecoration(color: AppColors.gold, shape: BoxShape.circle));
}
