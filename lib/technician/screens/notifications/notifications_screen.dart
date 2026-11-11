import 'package:flutter/material.dart';
import '../../core/app_theme.dart';
import '../../services/api_client.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen(
      {super.key, required this.api, this.onUnreadChanged});
  final TechnicianApi api;
  final void Function(int unread)? onUnreadChanged;
  @override
  State<NotificationsScreen> createState() => NotificationsScreenState();
}

class NotificationsScreenState extends State<NotificationsScreen> {
  late Future<List<dynamic>> _future;

  @override
  void initState() {
    super.initState();
    _future = _fetchAndNotify();
  }

  Future<List<dynamic>> _fetchAndNotify() async {
    final list = await widget.api.notifications();
    final unread = list.where((n) => n['read'] != true).length;
    if (mounted) widget.onUnreadChanged?.call(unread);
    return list;
  }

  void _handleAuthError() async {
    await widget.api.logout();
    if (mounted) {
      Navigator.of(context).pushNamedAndRemoveUntil('/', (_) => false);
    }
  }

  /// Called by shell via GlobalKey when tab is selected
  void refresh() {
    final f = _fetchAndNotify();
    if (mounted) {
      setState(() {
        _future = f;
      });
    }
  }

  Future<void> _pullToRefresh() async {
    final future = _fetchAndNotify();
    if (mounted) {
      setState(() {
        _future = future;
      });
    }
    await future.then<void>((_) {}, onError: (Object _) {});
  }

  void _reload() => refresh();

  Future<void> _markAllRead() async {
    await widget.api.markAllRead();
    _reload();
  }

  Future<void> _markRead(String id) async {
    await widget.api.markNotificationRead(id);
    _reload();
  }

  IconData _icon(String? type) {
    switch (type) {
      case 'emergency':
        return Icons.warning_amber_rounded;
      case 'job':
        return Icons.work_outline;
      case 'completed':
        return Icons.check_circle_outline;
      default:
        return Icons.notifications_outlined;
    }
  }

  Color _color(String? type) {
    switch (type) {
      case 'emergency':
        return AppColors.danger;
      case 'job':
        return AppColors.info;
      case 'completed':
        return AppColors.success;
      default:
        return AppColors.warning;
    }
  }

  @override
  Widget build(BuildContext context) => Container(
        color: AppColors.softGray,
        child: FutureBuilder<List<dynamic>>(
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
              return RefreshIndicator(
                color: AppColors.gold,
                backgroundColor: AppColors.white,
                onRefresh: _pullToRefresh,
                child: ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  children: [
                    SizedBox(
                      height: MediaQuery.sizeOf(context).height * .65,
                      child: Center(
                          child: Padding(
                        padding: const EdgeInsets.all(28),
                        child:
                            Column(mainAxisSize: MainAxisSize.min, children: [
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
                                  : 'Could Not Load Alerts',
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
                                    child: const Text('Try Again'),
                                  ),
                          ),
                        ]),
                      )),
                    ),
                  ],
                ),
              );
            }
            final list = snap.data ?? [];

            if (list.isEmpty) {
              return RefreshIndicator(
                color: AppColors.gold,
                backgroundColor: AppColors.white,
                onRefresh: _pullToRefresh,
                child: ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  children: [
                    SizedBox(
                      height: MediaQuery.sizeOf(context).height * .65,
                      child: Center(
                          child:
                              Column(mainAxisSize: MainAxisSize.min, children: [
                        Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: AppColors.white,
                            shape: BoxShape.circle,
                            border: Border.all(color: AppColors.cardBorder),
                          ),
                          child: const Icon(Icons.notifications_none_rounded,
                              size: 48, color: AppColors.midGray),
                        ),
                        const SizedBox(height: 16),
                        const Text('No alerts yet',
                            style: TextStyle(
                                color: AppColors.navy,
                                fontSize: 15,
                                fontWeight: FontWeight.w600)),
                        const SizedBox(height: 6),
                        const Text(
                            'New job assignments and updates\nwill appear here.',
                            style: TextStyle(
                                color: AppColors.midGray,
                                fontSize: 13,
                                height: 1.5),
                            textAlign: TextAlign.center),
                      ])),
                    ),
                  ],
                ),
              );
            }

            final unread = list.where((n) => n['read'] != true).length;

            return RefreshIndicator(
              color: AppColors.gold,
              backgroundColor: AppColors.white,
              onRefresh: _pullToRefresh,
              child: Column(
                children: [
                  // Header row
                  Container(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                    color: AppColors.softGray,
                    child: Row(children: [
                      if (unread > 0)
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 4),
                          decoration: BoxDecoration(
                            color: AppColors.gold.withValues(alpha: .12),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                                color: AppColors.gold.withValues(alpha: .3)),
                          ),
                          child: Text('$unread unread',
                              style: const TextStyle(
                                  color: AppColors.gold,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 12)),
                        ),
                      const Spacer(),
                      TextButton(
                        onPressed: _markAllRead,
                        child: const Text('Mark all read',
                            style: TextStyle(
                                color: AppColors.gold,
                                fontWeight: FontWeight.w700)),
                      ),
                    ]),
                  ),

                  Expanded(
                    child: ListView.separated(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 4),
                      itemCount: list.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 8),
                      itemBuilder: (_, i) {
                        final n = list[i] as Map<String, dynamic>;
                        final isRead = n['read'] == true;
                        final color = _color(n['type']?.toString());
                        final isEmergency = n['type'] == 'emergency';

                        return GestureDetector(
                          onTap: () {
                            // Mark as read if unread
                            if (!isRead) _markRead(n['id'].toString());
                            // Show notification detail bottom sheet
                            _showDetail(context, n, color);
                          },
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: AppColors.white,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: isEmergency
                                    ? AppColors.danger.withValues(alpha: .6)
                                    : isRead
                                        ? AppColors.cardBorder
                                        : color.withValues(alpha: .4),
                                width: isEmergency ? 1.5 : 1,
                              ),
                              boxShadow: isEmergency
                                  ? [
                                      BoxShadow(
                                          color: AppColors.danger
                                              .withValues(alpha: .12),
                                          blurRadius: 10),
                                    ]
                                  : [],
                            ),
                            child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // Icon
                                  Container(
                                    width: 44,
                                    height: 44,
                                    decoration: BoxDecoration(
                                      color: color.withValues(alpha: .15),
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                          color: color.withValues(alpha: .3)),
                                    ),
                                    child: Icon(_icon(n['type']?.toString()),
                                        color: color, size: 20),
                                  ),
                                  const SizedBox(width: 12),

                                  Expanded(
                                    child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Row(children: [
                                            Expanded(
                                              child: Text(n['title'] ?? '',
                                                  style: TextStyle(
                                                    color: isEmergency
                                                        ? AppColors.danger
                                                        : AppColors.navy,
                                                    fontWeight: isRead
                                                        ? FontWeight.w600
                                                        : FontWeight.w800,
                                                    fontSize: 14,
                                                  )),
                                            ),
                                            if (!isRead)
                                              Container(
                                                width: 8,
                                                height: 8,
                                                margin: const EdgeInsets.only(
                                                    left: 6),
                                                decoration: BoxDecoration(
                                                    color: color,
                                                    shape: BoxShape.circle),
                                              ),
                                          ]),
                                          const SizedBox(height: 5),
                                          Text(n['body'] ?? '',
                                              style: const TextStyle(
                                                  color: AppColors
                                                      .textLight, // ✅ always visible
                                                  fontSize: 13,
                                                  height: 1.4)),
                                          const SizedBox(height: 6),
                                          Row(children: [
                                            const Icon(
                                                Icons.access_time_rounded,
                                                size: 11,
                                                color: AppColors.midGray),
                                            const SizedBox(width: 4),
                                            Text(n['createdAt'] ?? '',
                                                style: const TextStyle(
                                                    fontSize: 11,
                                                    color: AppColors.midGray)),
                                            if (isRead) ...[
                                              const Spacer(),
                                              const Icon(Icons.done_all_rounded,
                                                  size: 13,
                                                  color: AppColors.success),
                                            ],
                                          ]),
                                        ]),
                                  ),
                                ]),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      );

  void _showDetail(BuildContext context, Map<String, dynamic> n, Color color) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          // Handle
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: AppColors.cardBorder,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 16),
          // Icon
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: color.withValues(alpha: .15),
              shape: BoxShape.circle,
              border: Border.all(color: color.withValues(alpha: .3)),
            ),
            child: Icon(_icon(n['type']?.toString()), color: color, size: 24),
          ),
          const SizedBox(height: 14),
          // Title
          Text(
            n['title']?.toString() ?? '',
            style: const TextStyle(
                color: AppColors.navy,
                fontSize: 16,
                fontWeight: FontWeight.w800),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          // Body
          Text(
            n['body']?.toString() ?? '',
            style: const TextStyle(
                color: AppColors.midGray, fontSize: 13, height: 1.5),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          // Time
          if ((n['createdAt']?.toString() ?? '').isNotEmpty)
            Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              const Icon(Icons.access_time_rounded,
                  size: 12, color: AppColors.midGray),
              const SizedBox(width: 4),
              Text(n['createdAt'].toString(),
                  style:
                      const TextStyle(fontSize: 11, color: AppColors.midGray)),
            ]),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Close'),
            ),
          ),
          const SizedBox(height: 8),
        ]),
      ),
    );
  }
}
