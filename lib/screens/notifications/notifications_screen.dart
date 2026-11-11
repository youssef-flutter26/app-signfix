import 'dart:convert';

import 'package:flutter/material.dart';
import '../../core/app_theme.dart';
import '../../services/api_client.dart';
import '../activity/quotation_detail_screen.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen(
      {super.key, required this.api, this.onUnreadChanged});
  final ApiClient api;
  final void Function(int unread)? onUnreadChanged;
  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  late Future<List<dynamic>> _future;

  @override
  void initState() {
    super.initState();
    _future = _fetchAndNotify();
  }

  Future<List<dynamic>> _fetchAndNotify() async {
    final list = await widget.api.notifications();
    final unread = list.where((n) => !_isRead(n)).length;
    if (mounted) widget.onUnreadChanged?.call(unread);
    return list;
  }

  bool _isRead(Map<String, dynamic> notification) =>
      notification['read'] == true || notification['readAt'] != null;

  void _handleAuthError() async {
    await widget.api.logout();
    if (mounted) {
      Navigator.of(context).pushNamedAndRemoveUntil('/', (_) => false);
    }
  }

  void _reload() {
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

  void _showDetail(BuildContext context, Map<String, dynamic> n, Color color,
      IconData icon) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: AppColors.cardBorder,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: color.withValues(alpha: .15),
              shape: BoxShape.circle,
              border: Border.all(color: color.withValues(alpha: .3)),
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(height: 14),
          Text(
            n['title']?.toString() ?? '',
            style: const TextStyle(
                color: AppColors.navy,
                fontSize: 16,
                fontWeight: FontWeight.w800),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            n['body']?.toString() ?? '',
            style: const TextStyle(
                color: AppColors.textLight, fontSize: 13, height: 1.5),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          if ((n['createdAt']?.toString() ?? '').isNotEmpty)
            Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              const Icon(Icons.access_time_rounded,
                  size: 12, color: AppColors.textMuted),
              const SizedBox(width: 4),
              Text(n['createdAt'].toString(),
                  style: const TextStyle(
                      fontSize: 11, color: AppColors.textMuted)),
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

  Map<String, dynamic> _notificationData(Object? value) {
    if (value is Map) return Map<String, dynamic>.from(value);
    if (value is String) {
      try {
        final decoded = jsonDecode(value);
        if (decoded is Map) return Map<String, dynamic>.from(decoded);
      } catch (_) {}
    }
    return const {};
  }

  Future<void> _openNotification(
      Map<String, dynamic> notification, Color color, IconData icon) async {
    if (!_isRead(notification)) {
      await _markRead(notification['id'].toString());
    }
    final eventKey = notification['eventKey']?.toString();
    final data = _notificationData(notification['data']);
    final quotationNo = data['quotationNo']?.toString();
    if ((eventKey == 'quotation.sent' || eventKey == 'quotation.expiring') &&
        quotationNo != null &&
        quotationNo.isNotEmpty &&
        mounted) {
      await Navigator.push<void>(
        context,
        MaterialPageRoute(
          builder: (_) => QuotationDetailScreen(
            api: widget.api,
            quotationNo: quotationNo,
          ),
        ),
      );
      return;
    }
    if (mounted) _showDetail(context, notification, color, icon);
  }

  Future<void> _markAllRead() async {
    await widget.api.markAllNotificationsRead();
    _reload();
  }

  Future<void> _markRead(String id) async {
    await widget.api.markNotificationRead(id);
    _reload();
  }

  IconData _icon(String? type) {
    switch (type) {
      case 'order':
        return Icons.shopping_bag_outlined;
      case 'service':
        return Icons.build_outlined;
      default:
        return Icons.notifications_outlined;
    }
  }

  Color _color(String? type) {
    switch (type) {
      case 'order':
        return AppColors.gold;
      case 'service':
        return AppColors.accent;
      default:
        return AppColors.info;
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: AppColors.softGray,
        appBar: AppBar(
          backgroundColor: AppColors.appBar,
          foregroundColor: AppColors.navy,
          surfaceTintColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_rounded,
                color: AppColors.goldDark),
            onPressed: () => Navigator.pop(context),
          ),
          title: const Text('Notifications',
              style: TextStyle(
                  color: AppColors.navy, fontWeight: FontWeight.w800)),
          actions: [
            TextButton(
              onPressed: _markAllRead,
              child: const Text('Mark all read',
                  style: TextStyle(
                      color: AppColors.goldDark, fontWeight: FontWeight.w700)),
            ),
          ],
        ),
        body: FutureBuilder<List<dynamic>>(
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
                                  : 'Could Not Load Notifications',
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
                                  color: AppColors.textLight, fontSize: 13),
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
                            color: AppColors.softGray,
                            shape: BoxShape.circle,
                            border: Border.all(color: AppColors.cardBorder),
                          ),
                          child: const Icon(Icons.notifications_none_rounded,
                              size: 48, color: AppColors.textMuted),
                        ),
                        const SizedBox(height: 16),
                        const Text('No notifications yet',
                            style: TextStyle(
                                color: AppColors.navy,
                                fontSize: 15,
                                fontWeight: FontWeight.w600)),
                        const SizedBox(height: 6),
                        const Text(
                            'We\'ll notify you about your orders\nand service requests here.',
                            style: TextStyle(
                                color: AppColors.textMuted,
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
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Unread count badge
                  if (unread > 0)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(18, 12, 18, 4),
                      child: Row(children: [
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
                        Text('${list.length} total',
                            style: const TextStyle(
                                color: AppColors.textMuted, fontSize: 12)),
                      ]),
                    ),

                  Expanded(
                    child: ListView.separated(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 10),
                      itemCount: list.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 8),
                      itemBuilder: (_, i) {
                        final n = list[i] as Map<String, dynamic>;
                        final isRead = _isRead(n);
                        final color = _color(n['type']?.toString());
                        final icon = _icon(n['type']?.toString());

                        return GestureDetector(
                          onTap: () => _openNotification(n, color, icon),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              // ✅ FIX: read=white card, unread=softGray
                              color:
                                  isRead ? AppColors.white : AppColors.softGray,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: isRead
                                    ? AppColors.cardBorder
                                    : color.withValues(alpha: .4),
                                width: isRead ? 1 : 1.5,
                              ),
                              boxShadow: isRead
                                  ? []
                                  : [
                                      BoxShadow(
                                        color: color.withValues(alpha: .1),
                                        blurRadius: 8,
                                        offset: const Offset(0, 2),
                                      ),
                                    ],
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
                                    child: Icon(icon, color: color, size: 20),
                                  ),
                                  const SizedBox(width: 12),

                                  // Content
                                  Expanded(
                                    child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Row(children: [
                                            Expanded(
                                              child: Text(n['title'] ?? '',
                                                  style: TextStyle(
                                                    color: AppColors.navy,
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
                                                  shape: BoxShape.circle,
                                                ),
                                              ),
                                          ]),
                                          const SizedBox(height: 5),
                                          Text(n['body'] ?? '',
                                              style: const TextStyle(
                                                color: AppColors
                                                    .textLight, // ✅ always textLight
                                                fontSize: 13,
                                                height: 1.4,
                                              )),
                                          const SizedBox(height: 6),
                                          Row(children: [
                                            const Icon(
                                                Icons.access_time_rounded,
                                                size: 11,
                                                color: AppColors.textMuted),
                                            const SizedBox(width: 4),
                                            Text(n['createdAt'] ?? '',
                                                style: const TextStyle(
                                                  fontSize: 11,
                                                  color: AppColors
                                                      .textMuted, // ✅ always textMuted
                                                )),
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
}
