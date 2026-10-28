import 'dart:async';
import 'package:flutter/material.dart';
import 'package:animated_text_kit/animated_text_kit.dart';
import '../../core/app_theme.dart';
import '../../core/app_utils.dart';
import '../../services/api_client.dart';
import '../activity/activity_screen.dart';
import '../ai/ai_chat.dart';
import '../notifications/notifications_screen.dart';
import '../orders/order_detail_screen.dart';
import '../orders/order_wizard.dart';
import '../orders/power_supply_screen.dart';
import '../orders/signage_designer_screen.dart';
import '../profile/profile_screen.dart';
import '../service/service_request.dart';

class CustomerHome extends StatefulWidget {
  const CustomerHome({super.key, required this.api, required this.onLogout});
  final ApiClient api;
  final VoidCallback onLogout;
  @override
  State<CustomerHome> createState() => _CustomerHomeState();
}

class _CustomerHomeState extends State<CustomerHome> {
  int _index = 0;
  late final List<Widget> _pages;
  final _promotionBannerNotifier = ValueNotifier<String?>(null);
  // Notifier to switch ActivityScreen tab (0=orders, 1=services)
  final _trackTabNotifier = ValueNotifier<int>(0);
  final _trackRefreshNotifier = ValueNotifier<int>(0);
  void _goTo(int i) => setState(() => _index = i);
  void _goToOrder() {
    _promotionBannerNotifier.value = null;
    _goTo(1);
  }

  @override
  void initState() {
    super.initState();
    // ✅ FIX: pages ek baar banao — har setState pe recreate nahi hongi
    _pages = [
      _Dashboard(
          api: widget.api,
          onOrder: _goToOrder,
          onBannerOrder: (bannerId) {
            // Banner 2 → Signage Design Studio (full custom screen)
            if (bannerId == 'home_banner_2') {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => SignageDesignerScreen(
                    api: widget.api,
                    promotionBannerId: bannerId,
                    onOrderSubmitted: () {
                      _goTo(3);
                      _trackRefreshNotifier.value++;
                    },
                  ),
                ),
              );
              return;
            }
            // Banner 3 → Power Supply & Drivers catalog
            if (bannerId == 'home_banner_3') {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => PowerSupplyScreen(
                    api: widget.api,
                    promotionBannerId: bannerId,
                    onOrderSubmitted: () {
                      _goTo(3);
                      _trackRefreshNotifier.value++;
                    },
                  ),
                ),
              );
              return;
            }
            // Banner 1 (and any other banners) → standard OrderWizard with cashback
            _promotionBannerNotifier.value = bannerId;
            _goTo(1);
          },
          onService: () => _goTo(2),
          onLogout: widget.onLogout,
          onGoToTrack: (tab) {
            _goTo(3); // go to Track tab
            // Pass tab index via a short delay so Track screen builds first
            Future.delayed(const Duration(milliseconds: 100), () {
              _trackTabNotifier.value = tab;
            });
          }),
      OrderWizard(
        api: widget.api,
        promotionBannerNotifier: _promotionBannerNotifier,
        onOrderSubmitted: () {
          _goTo(3);
          _trackRefreshNotifier.value++;
        },
      ),
      ServiceRequest(api: widget.api),
      ActivityScreen(
        api: widget.api,
        tabNotifier: _trackTabNotifier,
        refreshNotifier: _trackRefreshNotifier,
      ),
      AiChat(api: widget.api),
    ];
  }

  @override
  void dispose() {
    _promotionBannerNotifier.dispose();
    _trackTabNotifier.dispose();
    _trackRefreshNotifier.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      // If on home tab (0) → allow app to minimize naturally
      // If on any other tab → go back to home tab
      canPop: _index == 0,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && _index != 0) {
          setState(() => _index = 0);
        }
      },
      child: Scaffold(
        backgroundColor: AppColors.softGray,
        appBar: AppBar(
          backgroundColor: AppColors.appBar,
          foregroundColor: AppColors.navy,
          surfaceTintColor: Colors.transparent,
          elevation: 0,
          title: Row(children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: Image.asset('assets/images/logo.jpeg',
                  width: 36, height: 36, fit: BoxFit.cover),
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
                        color: AppColors.goldDark,
                        fontSize: 18,
                        fontWeight: FontWeight.w900)),
              ]),
            ),
          ]),
          actions: [
            _NotificationBell(api: widget.api),
            IconButton(
              icon: const Icon(Icons.account_circle_outlined,
                  color: AppColors.goldDark),
              onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => ProfileScreen(
                        api: widget.api, onLogout: widget.onLogout),
                  )),
            ),
          ],
        ),
        body: SafeArea(child: IndexedStack(index: _index, children: _pages)),
        bottomNavigationBar: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: Container(
              height: 70,
              decoration: BoxDecoration(
                color: AppColors.white,
                borderRadius: BorderRadius.circular(30),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _NavItem(
                      icon: Icons.home_outlined,
                      selectedIcon: Icons.home,
                      label: 'Home',
                      selected: _index == 0,
                      color: AppColors.gold,
                      onTap: () => setState(() => _index = 0)),
                  _NavItem(
                      icon: Icons.add_box_outlined,
                      selectedIcon: Icons.add_box,
                      label: 'Order',
                      selected: _index == 1,
                      color: AppColors.gold,
                      onTap: _goToOrder),
                  _NavItem(
                      icon: Icons.build_outlined,
                      selectedIcon: Icons.build,
                      label: 'Service',
                      selected: _index == 2,
                      color: AppColors.gold,
                      onTap: () => setState(() => _index = 2)),
                  _NavItem(
                      icon: Icons.receipt_long_outlined,
                      selectedIcon: Icons.receipt_long,
                      label: 'Track',
                      selected: _index == 3,
                      color: AppColors.gold,
                      onTap: () => setState(() => _index = 3)),
                  _NavItem(
                      icon: Icons.auto_awesome_outlined,
                      selectedIcon: Icons.auto_awesome,
                      label: 'AI',
                      selected: _index == 4,
                      color: AppColors.gold,
                      onTap: () => setState(() => _index = 4)),
                ],
              ),
            ),
          ),
        ),
      ), // close Scaffold
    ); // close PopScope
  }
}

// ── Notification Bell ─────────────────────────────────────────────────────────
class _NotificationBell extends StatefulWidget {
  const _NotificationBell({required this.api});
  final ApiClient api;
  @override
  State<_NotificationBell> createState() => _NotificationBellState();
}

class _NotificationBellState extends State<_NotificationBell> {
  int _unread = 0;
  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final list = await widget.api.notifications();
      if (mounted) {
        setState(() => _unread = list.where((n) => n['read'] != true).length);
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) =>
      Stack(alignment: Alignment.center, children: [
        IconButton(
          icon: const Icon(Icons.notifications_outlined,
              color: AppColors.goldDark),
          onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => NotificationsScreen(
                  api: widget.api,
                  onUnreadChanged: (count) {
                    if (mounted) setState(() => _unread = count);
                  },
                ),
              )).then((_) => _load()),
        ),
        if (_unread > 0)
          Positioned(
            right: 8,
            top: 8,
            child: Container(
              width: 16,
              height: 16,
              decoration: const BoxDecoration(
                  color: AppColors.danger, shape: BoxShape.circle),
              child: Center(
                  child: Text('$_unread',
                      style: const TextStyle(
                          color: AppColors.white,
                          fontSize: 9,
                          fontWeight: FontWeight.w800))),
            ),
          ),
      ]);
}

// ── Dashboard ─────────────────────────────────────────────────────────────────
class _Dashboard extends StatefulWidget {
  const _Dashboard(
      {required this.api,
      required this.onOrder,
      required this.onBannerOrder,
      required this.onService,
      required this.onGoToTrack,
      required this.onLogout});
  final ApiClient api;
  final VoidCallback onOrder;
  final ValueChanged<String> onBannerOrder;
  final VoidCallback onService;
  final void Function(int tabIndex) onGoToTrack; // 0=orders, 1=services
  final VoidCallback onLogout;
  @override
  State<_Dashboard> createState() => _DashboardState();
}

class _DashboardState extends State<_Dashboard> {
  late Future<List<dynamic>> _ordersFuture;
  late Future<List<dynamic>> _servicesFuture;
  late Future<Map<String, dynamic>> _profileFuture;

  final PageController _bannerCtrl = PageController();
  int _bannerPage = 0;
  Timer? _bannerTimer;

  static const _banners = [
    _PromoBanner(id: 'home_banner_1', asset: 'assets/images/banner1.jpeg'),
    _PromoBanner(id: 'home_banner_2', asset: 'assets/images/banner2.jpeg'),
    _PromoBanner(id: 'home_banner_3', asset: 'assets/images/banner3.jpeg'),
  ];

  @override
  void initState() {
    super.initState();
    _ordersFuture = widget.api.orders();
    _servicesFuture = widget.api.services();
    _profileFuture = widget.api.getProfile();
    _startBannerTimer();
  }

  void _startBannerTimer() {
    _bannerTimer = Timer.periodic(const Duration(seconds: 4), (_) {
      if (!mounted || !_bannerCtrl.hasClients) return;
      final next = (_bannerPage + 1) % _banners.length;
      _bannerCtrl.animateToPage(next,
          duration: const Duration(milliseconds: 600), curve: Curves.easeInOut);
    });
  }

  @override
  void dispose() {
    _bannerTimer?.cancel();
    _bannerCtrl.dispose();
    super.dispose();
  }

  void _handleAuthError() async {
    await widget.api.logout();
    if (mounted) widget.onLogout();
  }

  void _reload() {
    setState(() {
      _ordersFuture = widget.api.orders();
      _servicesFuture = widget.api.services();
      _profileFuture = widget.api.getProfile();
    });
  }

  Future<void> _refresh() async {
    final orders = widget.api.orders();
    final services = widget.api.services();
    final profile = widget.api.getProfile();
    setState(() {
      _ordersFuture = orders;
      _servicesFuture = services;
      _profileFuture = profile;
    });
    await Future.wait([
      orders.then<void>((_) {}, onError: (Object _) {}),
      services.then<void>((_) {}, onError: (Object _) {}),
      profile.then<void>((_) {}, onError: (Object _) {}),
    ]);
  }

  // ── Auth-aware error widget (embedded in home dashboard) ─────────────────
  Widget _errorWidget(Object error) {
    final errMsg = error.toString();
    final isAuthError = errMsg.toLowerCase().contains('authentication') ||
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
                  color: isAuthError ? AppColors.warning : AppColors.danger,
                  width: 2),
            ),
            child: Icon(
                isAuthError
                    ? Icons.lock_outline_rounded
                    : Icons.error_outline_rounded,
                color: isAuthError ? AppColors.warning : AppColors.danger,
                size: 40),
          ),
          const SizedBox(height: 20),
          Text(isAuthError ? 'Session Expired' : 'Could Not Load',
              style: const TextStyle(
                  color: AppColors.navy,
                  fontSize: 18,
                  fontWeight: FontWeight.w800)),
          const SizedBox(height: 8),
          Text(
            isAuthError
                ? 'Your session has expired. Please sign in again.'
                : 'Unable to load data. Please try again.',
            style: const TextStyle(color: AppColors.textLight, fontSize: 13),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: isAuthError
                ? FilledButton.icon(
                    onPressed: _handleAuthError,
                    icon: const Icon(Icons.login_rounded),
                    label: const Text('Sign In Again'))
                : OutlinedButton(
                    onPressed: _reload, child: const Text('Try Again')),
          ),
        ]),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => RefreshIndicator(
        color: AppColors.gold,
        backgroundColor: AppColors.white,
        onRefresh: _refresh,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: EdgeInsets.zero,
          children: [
            // ── Promo Banner Slider ─────────────────────────────────────────────
            _PromoBannerSlider(
              controller: _bannerCtrl,
              banners: _banners,
              currentPage: _bannerPage,
              onPageChanged: (i) => setState(() => _bannerPage = i),
              onBannerTap: (bannerId) => widget.onBannerOrder(bannerId),
            ),

            Padding(
              padding: const EdgeInsets.fromLTRB(18, 18, 18, 0),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ── Greeting with animated text ──────────────────────────────────
                    FutureBuilder<Map<String, dynamic>>(
                      future: _profileFuture,
                      builder: (_, snap) {
                        if (snap.hasError) return _errorWidget(snap.error!);
                        // Show first name only — strip "Demo" if default
                        String name = snap.data?['name']?.toString() ?? '';
                        if (name.isEmpty || name == 'Demo Customer') {
                          name = 'there';
                        }
                        final firstName = name.split(' ').first;
                        return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(children: [
                                const Text('Hello, ',
                                    style: TextStyle(
                                        fontSize: 22,
                                        fontWeight: FontWeight.w400,
                                        color: AppColors.textLight)),
                                Text('$firstName 👋',
                                    style: const TextStyle(
                                        fontSize: 22,
                                        fontWeight: FontWeight.w800,
                                        color: AppColors.navy)),
                              ]),
                              const SizedBox(height: 6),
                              // Animated rotating sub-text
                              SizedBox(
                                height: 22,
                                child: AnimatedTextKit(
                                  animatedTexts: [
                                    TypewriterAnimatedText(
                                      'What would you like to do today?',
                                      textStyle: const TextStyle(
                                          fontSize: 13,
                                          color: AppColors.textLight),
                                      speed: const Duration(milliseconds: 55),
                                    ),
                                    TypewriterAnimatedText(
                                      'Order a new sign board →',
                                      textStyle: const TextStyle(
                                          fontSize: 13, color: AppColors.gold),
                                      speed: const Duration(milliseconds: 60),
                                    ),
                                    TypewriterAnimatedText(
                                      'Report a sign board issue →',
                                      textStyle: const TextStyle(
                                          fontSize: 13, color: AppColors.info),
                                      speed: const Duration(milliseconds: 60),
                                    ),
                                  ],
                                  repeatForever: true,
                                  pause: const Duration(milliseconds: 1800),
                                ),
                              ),
                            ]);
                      },
                    ),
                    const SizedBox(height: 18),

                    // ── Quick Stats ──────────────────────────────────────────────────
                    FutureBuilder<List<dynamic>>(
                      future: _ordersFuture,
                      builder: (_, oSnap) => FutureBuilder<List<dynamic>>(
                        future: _servicesFuture,
                        builder: (_, sSnap) {
                          if (oSnap.hasError || sSnap.hasError) {
                            return _errorWidget(oSnap.error ?? sSnap.error!);
                          }
                          final orders = oSnap.data ?? [];
                          final services = sSnap.data ?? [];
                          final activeOrders = orders
                              .where((o) => !['delivered', 'cancelled']
                                  .contains(o['status']))
                              .length;
                          final activeServices = services
                              .where((s) => !['completed', 'cancelled']
                                  .contains(s['status']))
                              .length;
                          return Row(children: [
                            _StatTile('$activeOrders', 'Active\nOrders',
                                AppColors.gold, Icons.shopping_bag_outlined,
                                onTap: () => widget.onGoToTrack(0)),
                            const SizedBox(width: 10),
                            _StatTile('$activeServices', 'Active\nServices',
                                AppColors.info, Icons.build_outlined,
                                onTap: () => widget.onGoToTrack(1)),
                            const SizedBox(width: 10),
                            _StatTile('${orders.length}', 'Total\nOrders',
                                AppColors.success, Icons.check_circle_outline,
                                onTap: () => widget.onGoToTrack(0)),
                          ]);
                        },
                      ),
                    ),
                    const SizedBox(height: 22),

                    // ── Action Cards ──────────────────────────────────────────────────
                    _ActionCard(
                      title: 'Order New Sign Board',
                      subtitle:
                          'Configure size, material & lighting\nGet an instant price estimate',
                      icon: Icons.storefront_rounded,
                      accentColor: AppColors.gold,
                      onTap: widget.onOrder,
                    ),
                    const SizedBox(height: 12),
                    _ActionCard(
                      title: 'Request Service / Repair',
                      subtitle:
                          'Upload photo, describe the issue\nShare GPS location & submit',
                      icon: Icons.handyman_rounded,
                      accentColor: AppColors.info,
                      onTap: widget.onService,
                    ),
                    const SizedBox(height: 24),

                    // ── Recent Orders ─────────────────────────────────────────────────
                    const Text('Recent Activity',
                        style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: AppColors.navy)),
                    const SizedBox(height: 12),
                    FutureBuilder<List<dynamic>>(
                      future: _ordersFuture,
                      builder: (_, snap) {
                        if (snap.connectionState != ConnectionState.done) {
                          return const SizedBox();
                        }
                        if (snap.hasError) return _errorWidget(snap.error!);
                        final recent = (snap.data ?? []).take(3).toList();
                        if (recent.isEmpty) {
                          return Container(
                            padding: const EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              color: AppColors.white,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: AppColors.cardBorder),
                            ),
                            child: const Center(
                                child: Text(
                                    'No orders yet — place your first order!',
                                    style:
                                        TextStyle(color: AppColors.textMuted))),
                          );
                        }
                        return Column(
                          children: recent.map((o) {
                            final status = o['status']?.toString() ?? 'pending';
                            final orderId = o['id']?.toString() ?? '';
                            return GestureDetector(
                              onTap: orderId.isEmpty
                                  ? null
                                  : () => Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (_) => OrderDetailScreen(
                                            api: widget.api,
                                            orderId: orderId,
                                          ),
                                        ),
                                      ),
                              child: Container(
                                margin: const EdgeInsets.only(bottom: 8),
                                padding: const EdgeInsets.all(14),
                                decoration: BoxDecoration(
                                  color: AppColors.white,
                                  borderRadius: BorderRadius.circular(14),
                                  border:
                                      Border.all(color: AppColors.cardBorder),
                                ),
                                child: Row(children: [
                                  Container(
                                    padding: const EdgeInsets.all(9),
                                    decoration: BoxDecoration(
                                      color:
                                          AppColors.gold.withValues(alpha: .1),
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: const Icon(Icons.storefront_outlined,
                                        color: AppColors.gold, size: 18),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                      child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                        Text(orderId,
                                            style: const TextStyle(
                                                fontWeight: FontWeight.w800,
                                                color: AppColors.navy,
                                                fontSize: 13)),
                                        Text(o['product']?.toString() ?? '',
                                            style: const TextStyle(
                                                color: AppColors.textLight,
                                                fontSize: 12)),
                                      ])),
                                  _StatusBadge(status),
                                  const SizedBox(width: 6),
                                  const Icon(Icons.arrow_forward_ios_rounded,
                                      size: 12, color: AppColors.textMuted),
                                ]),
                              ),
                            );
                          }).toList(),
                        );
                      },
                    ),

                    // ── How it works ──────────────────────────────────────────────────
                    const SizedBox(height: 24),
                    const Text('How SignFix Works',
                        style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: AppColors.navy)),
                    const SizedBox(height: 12),
                    ...[
                      (
                        Icons.tune_rounded,
                        AppColors.gold,
                        '1. Configure',
                        'Select type, size, material & lighting',
                        widget.onOrder
                      ),
                      (
                        Icons.calculate_outlined,
                        AppColors.goldLight,
                        '2. Get Estimate',
                        'Instant price calculation on the app',
                        widget.onOrder
                      ),
                      (
                        Icons.local_shipping_outlined,
                        AppColors.info,
                        '3. Track Order',
                        'Follow production to delivery in real time',
                        () => widget.onGoToTrack(0)
                      ),
                      (
                        Icons.build_circle_outlined,
                        AppColors.success,
                        '4. Service Anytime',
                        'Report issues — technician dispatched fast',
                        widget.onService
                      ),
                    ].map((e) =>
                        _HowItWorksRow(e.$1, e.$2, e.$3, e.$4, onTap: e.$5)),

                    const SizedBox(height: 30),
                  ]),
            ),
          ],
        ),
      );
}

// ── Promo Banner Slider ───────────────────────────────────────────────────────
class _PromoBannerSlider extends StatelessWidget {
  const _PromoBannerSlider({
    required this.controller,
    required this.banners,
    required this.currentPage,
    required this.onPageChanged,
    required this.onBannerTap,
  });
  final PageController controller;
  final List<_PromoBanner> banners;
  final int currentPage;
  final ValueChanged<int> onPageChanged;
  final ValueChanged<String> onBannerTap;

  // ── Per-banner badge config ─────────────────────────────────────────────────
  static Map<String, ({IconData icon, String label, Color color})> _badgeConfig(
      String id) {
    switch (id) {
      case 'home_banner_2':
        return {
          'top': (
            icon: Icons.palette_outlined,
            label: 'Neon & Signage Design',
            color: AppColors.navy
          ),
          'cta': (
            icon: Icons.auto_awesome_outlined,
            label: 'Design Studio',
            color: AppColors.navy
          ),
        };
      case 'home_banner_3':
        return {
          'top': (
            icon: Icons.bolt_outlined,
            label: 'Power Supply Catalog',
            color: AppColors.navy
          ),
          'cta': (
            icon: Icons.electrical_services_outlined,
            label: 'Browse Drivers',
            color: AppColors.navy
          ),
        };
      default: // home_banner_1
        return {
          'top': (
            icon: Icons.savings_outlined,
            label: '₹200 Cashback Offer',
            color: AppColors.success
          ),
          'cta': (
            icon: Icons.shopping_cart_outlined,
            label: 'Shop Now',
            color: AppColors.gold
          ),
        };
    }
  }

  @override
  Widget build(BuildContext context) => Column(children: [
        SizedBox(
          height: 200,
          child: PageView.builder(
            controller: controller,
            onPageChanged: onPageChanged,
            itemCount: banners.length,
            itemBuilder: (_, i) {
              final cfg = _badgeConfig(banners[i].id);
              final topBadge = cfg['top']!;
              final ctaBadge = cfg['cta']!;
              return GestureDetector(
                onTap: () => onBannerTap(banners[i].id),
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 2),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(0),
                    child: Stack(fit: StackFit.expand, children: [
                      Image.asset(banners[i].asset, fit: BoxFit.cover),
                      // Dark overlay at bottom
                      Positioned(
                        bottom: 0,
                        left: 0,
                        right: 0,
                        child: Container(
                          height: 60,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.bottomCenter,
                              end: Alignment.topCenter,
                              colors: [
                                AppColors.navyDeep.withValues(alpha: .85),
                                Colors.transparent,
                              ],
                            ),
                          ),
                        ),
                      ),
                      // Top-left badge (cashback / category label)
                      Positioned(
                        top: 14,
                        left: 14,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            color: topBadge.color.withValues(alpha: .92),
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [
                              BoxShadow(
                                color: AppColors.navy.withValues(alpha: .3),
                                blurRadius: 8,
                              ),
                            ],
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(topBadge.icon,
                                  size: 14, color: AppColors.white),
                              const SizedBox(width: 5),
                              Text(
                                topBadge.label,
                                style: const TextStyle(
                                  color: AppColors.white,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      // Bottom-right CTA badge
                      Positioned(
                        bottom: 12,
                        right: 16,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 6),
                          decoration: BoxDecoration(
                            color: ctaBadge.color,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(ctaBadge.icon,
                                  size: 14,
                                  color: ctaBadge.color == AppColors.gold
                                      ? AppColors.navyDeep
                                      : AppColors.white),
                              const SizedBox(width: 5),
                              Text(ctaBadge.label,
                                  style: TextStyle(
                                    color: ctaBadge.color == AppColors.gold
                                        ? AppColors.navyDeep
                                        : AppColors.white,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w800,
                                  )),
                            ],
                          ),
                        ),
                      ),
                    ]),
                  ),
                ),
              );
            },
          ),
        ),
        // Dot indicators
        const SizedBox(height: 10),
        Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(
              banners.length,
              (i) => AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                margin: const EdgeInsets.symmetric(horizontal: 3),
                width: i == currentPage ? 20 : 6,
                height: 6,
                decoration: BoxDecoration(
                  color: i == currentPage ? AppColors.gold : AppColors.midGray,
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
            )),
      ]);
}

class _PromoBanner {
  const _PromoBanner({required this.id, required this.asset});

  final String id;
  final String asset;
}

// ── Stat Tile ─────────────────────────────────────────────────────────────────
class _StatTile extends StatelessWidget {
  const _StatTile(this.value, this.label, this.color, this.icon, {this.onTap});
  final String value, label;
  final Color color;
  final IconData icon;
  final VoidCallback? onTap;
  @override
  Widget build(BuildContext context) => Expanded(
        child: GestureDetector(
          onTap: onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: onTap != null
                  ? color.withValues(alpha: .08)
                  : AppColors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: color.withValues(alpha: .35)),
              boxShadow: onTap != null
                  ? [
                      BoxShadow(
                          color: color.withValues(alpha: .1), blurRadius: 8),
                    ]
                  : [],
            ),
            child: Column(children: [
              Icon(icon, color: color, size: 22),
              const SizedBox(height: 6),
              Text(value,
                  style: TextStyle(
                      fontSize: 20, fontWeight: FontWeight.w900, color: color)),
              Text(label,
                  style: const TextStyle(
                      fontSize: 10, color: AppColors.textLight, height: 1.3),
                  textAlign: TextAlign.center),
              if (onTap != null) ...[
                const SizedBox(height: 4),
                Icon(Icons.arrow_forward_ios_rounded,
                    size: 10, color: color.withValues(alpha: .6)),
              ],
            ]),
          ),
        ),
      );
}

// ── Action Card ───────────────────────────────────────────────────────────────
class _ActionCard extends StatelessWidget {
  const _ActionCard(
      {required this.title,
      required this.subtitle,
      required this.icon,
      required this.accentColor,
      required this.onTap});
  final String title, subtitle;
  final IconData icon;
  final Color accentColor;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [accentColor.withValues(alpha: .15), AppColors.white],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: accentColor.withValues(alpha: .35)),
          ),
          child: Row(children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: accentColor.withValues(alpha: .15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: accentColor, size: 26),
            ),
            const SizedBox(width: 14),
            Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  Text(title,
                      style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          color: AppColors.navy)),
                  const SizedBox(height: 4),
                  Text(subtitle,
                      style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.textLight,
                          height: 1.4)),
                ])),
            Icon(Icons.arrow_forward_ios_rounded, size: 16, color: accentColor),
          ]),
        ),
      );
}

// ── Status Badge ──────────────────────────────────────────────────────────────
class _StatusBadge extends StatelessWidget {
  const _StatusBadge(this.status);
  final String status;
  Color get _color {
    switch (status) {
      case 'delivered':
      case 'completed':
        return AppColors.success;
      case 'in_production':
        return AppColors.gold;
      case 'pending':
        return AppColors.warning;
      case 'cancelled':
        return AppColors.danger;
      default:
        return AppColors.info;
    }
  }

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: _color.withValues(alpha: .12),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: _color.withValues(alpha: .3)),
        ),
        child: Text(
          humanize(status),
          style: TextStyle(
              fontSize: 10, fontWeight: FontWeight.w700, color: _color),
        ),
      );
}

// ── How It Works Row ──────────────────────────────────────────────────────────
class _HowItWorksRow extends StatelessWidget {
  const _HowItWorksRow(this.icon, this.color, this.title, this.subtitle,
      {this.onTap});
  final IconData icon;
  final Color color;
  final String title, subtitle;
  final VoidCallback? onTap;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: GestureDetector(
          onTap: onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: onTap != null
                  ? color.withValues(alpha: .06)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: onTap != null
                    ? color.withValues(alpha: .25)
                    : Colors.transparent,
              ),
            ),
            child: Row(children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: .1),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: color.withValues(alpha: .2)),
                ),
                child: Icon(icon, color: color, size: 18),
              ),
              const SizedBox(width: 12),
              Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                    Text(title,
                        style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            color: AppColors.navy,
                            fontSize: 13)),
                    Text(subtitle,
                        style: const TextStyle(
                            fontSize: 12, color: AppColors.textLight)),
                  ])),
              if (onTap != null)
                Icon(Icons.arrow_forward_ios_rounded,
                    size: 13, color: color.withValues(alpha: .7)),
            ]),
          ),
        ),
      );
}

// ── Custom Nav Item ───────────────────────────────────────────────────────────
class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.icon,
    required this.selectedIcon,
    required this.label,
    required this.selected,
    required this.color,
    required this.onTap,
  });
  final IconData icon, selectedIcon;
  final String label;
  final bool selected;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Expanded(
        child: GestureDetector(
          onTap: onTap,
          behavior: HitTestBehavior.opaque,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                decoration: BoxDecoration(
                  color: selected
                      ? color.withValues(alpha: .2)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Icon(
                  selected ? selectedIcon : icon,
                  color: selected ? color : AppColors.textMuted,
                  size: 22,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w400,
                  color: selected ? color : AppColors.textMuted,
                ),
              ),
            ],
          ),
        ),
      );
}
