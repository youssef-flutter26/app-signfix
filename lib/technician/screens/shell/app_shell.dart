import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/app_theme.dart';
import '../../services/api_client.dart';
import '../dashboard/dashboard_screen.dart';
import '../jobs/jobs_screen.dart';
import '../notifications/notifications_screen.dart';
import '../profile/profile_screen.dart';

class AppShell extends StatefulWidget {
  const AppShell({super.key, required this.api, required this.onLogout});
  final TechnicianApi api;
  final VoidCallback onLogout;
  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int _index = 0;
  int _unread = 0;
  late final List<Widget> _pages;
  final _notifKey = GlobalKey<NotificationsScreenState>();

  @override
  void initState() {
    super.initState();
    _pages = [
      DashboardScreen(api: widget.api, onGoToJobs: () => _goTo(1)),
      JobsScreen(api: widget.api, onLogout: widget.onLogout),
      NotificationsScreen(
        key: _notifKey,
        api: widget.api,
        onUnreadChanged: (count) {
          if (mounted) setState(() => _unread = count);
        },
      ),
      ProfileScreen(api: widget.api, onLogout: widget.onLogout),
    ];
    _loadUnread();
  }

  Future<void> _loadUnread() async {
    try {
      final list = await widget.api.notifications();
      if (mounted) {
        setState(() => _unread = list.where((n) => n['read'] != true).length);
      }
    } catch (_) {}
  }

  void _goTo(int i) {
    // Entering notifications tab → refresh the screen
    if (i == 2) {
      _notifKey.currentState?.refresh();
    }
    // Leaving notifications tab → reload badge
    if (_index == 2 && i != 2) {
      _loadUnread();
    }
    setState(() => _index = i);
  }

  @override
  Widget build(BuildContext context) => PopScope(
        // Dashboard tab (0) → allow minimize; any other tab → go back to Dashboard
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
            elevation: 0,
            surfaceTintColor: Colors.transparent,
            systemOverlayStyle: SystemUiOverlayStyle.dark,
            title: Row(children: [
              // Logo
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: Image.asset('assets/images/logo.jpeg',
                    width: 36, height: 36, fit: BoxFit.cover),
              ),
              const SizedBox(width: 10),
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                RichText(
                    text: const TextSpan(children: [
                  TextSpan(
                      text: 'Sign',
                      style: TextStyle(
                          color: AppColors.navy,
                          fontSize: 16,
                          fontWeight: FontWeight.w900)),
                  TextSpan(
                      text: 'Fix',
                      style: TextStyle(
                          color: AppColors.goldDark,
                          fontSize: 16,
                          fontWeight: FontWeight.w900)),
                  TextSpan(
                      text: ' Tech',
                      style: TextStyle(
                          color: AppColors.goldDark,
                          fontSize: 14,
                          fontWeight: FontWeight.w700)),
                ])),
                const Text('Field operations',
                    style: TextStyle(fontSize: 10, color: AppColors.midGray)),
              ]),
            ]),
            actions: [
              // Notification bell with badge
              Stack(alignment: Alignment.center, children: [
                IconButton(
                  icon: const Icon(Icons.notifications_outlined,
                      color: AppColors.goldDark),
                  onPressed: () => _goTo(2),
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
              ]),
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
                        icon: Icons.dashboard_outlined,
                        selectedIcon: Icons.dashboard,
                        label: 'Dashboard',
                        selected: _index == 0,
                        color: AppColors.gold,
                        onTap: () => _goTo(0)),
                    _NavItem(
                        icon: Icons.work_outline,
                        selectedIcon: Icons.work,
                        label: 'Jobs',
                        selected: _index == 1,
                        color: AppColors.gold,
                        onTap: () => _goTo(1)),
                    _NavItemBadge(
                        icon: Icons.notifications_outlined,
                        selectedIcon: Icons.notifications,
                        label: 'Alerts',
                        selected: _index == 2,
                        color: AppColors.gold,
                        badge: _unread,
                        onTap: () => _goTo(2)),
                    _NavItem(
                        icon: Icons.person_outline,
                        selectedIcon: Icons.person,
                        label: 'Profile',
                        selected: _index == 3,
                        color: AppColors.gold,
                        onTap: () => _goTo(3)),
                  ],
                ),
              ),
            ),
          ),
        ), // close Scaffold
      ); // close PopScope
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
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                decoration: BoxDecoration(
                  color: selected
                      ? color.withValues(alpha: .2)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Icon(
                  selected ? selectedIcon : icon,
                  color: selected ? color : AppColors.midGray,
                  size: 22,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w400,
                  color: selected ? color : AppColors.midGray,
                ),
              ),
            ],
          ),
        ),
      );
}

class _NavItemBadge extends StatelessWidget {
  const _NavItemBadge({
    required this.icon,
    required this.selectedIcon,
    required this.label,
    required this.selected,
    required this.color,
    required this.badge,
    required this.onTap,
  });
  final IconData icon, selectedIcon;
  final String label;
  final bool selected;
  final Color color;
  final int badge;
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
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                decoration: BoxDecoration(
                  color: selected
                      ? color.withValues(alpha: .2)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Icon(
                      selected ? selectedIcon : icon,
                      color: selected ? color : AppColors.midGray,
                      size: 22,
                    ),
                    if (badge > 0)
                      Positioned(
                        top: -4,
                        right: -6,
                        child: Container(
                          width: 15,
                          height: 15,
                          decoration: const BoxDecoration(
                            color: AppColors.danger,
                            shape: BoxShape.circle,
                          ),
                          child: Center(
                            child: Text(
                              '$badge',
                              style: const TextStyle(
                                  color: AppColors.white,
                                  fontSize: 9,
                                  fontWeight: FontWeight.w800),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 2),
              Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w400,
                  color: selected ? color : AppColors.midGray,
                ),
              ),
            ],
          ),
        ),
      );
}
