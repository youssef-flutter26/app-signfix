import 'package:flutter/material.dart';
import '../../core/app_theme.dart';
import '../../core/app_utils.dart';
import '../../services/api_client.dart';

class OrderDetailScreen extends StatefulWidget {
  const OrderDetailScreen(
      {super.key, required this.api, required this.orderId});
  final ApiClient api;
  final String orderId;
  @override
  State<OrderDetailScreen> createState() => _OrderDetailScreenState();
}

class _OrderDetailScreenState extends State<OrderDetailScreen> {
  late Future<Map<String, dynamic>> _future;

  @override
  void initState() {
    super.initState();
    _future = widget.api.orderDetail(widget.orderId);
  }

  void _handleAuthError() async {
    await widget.api.logout();
    if (mounted) {
      Navigator.of(context).pushNamedAndRemoveUntil('/', (_) => false);
    }
  }

  Future<void> _refresh() async {
    final future = widget.api.orderDetail(widget.orderId);
    setState(() {
      _future = future;
    });
    await future.then<void>((_) {}, onError: (Object _) {});
  }

  void _reload() {
    _refresh();
  }

  Color _statusColor(String s) {
    switch (s) {
      case 'completed':
      case 'delivered':
        return AppColors.success;
      case 'in_production':
      case 'ready':
        return AppColors.gold;
      case 'pending':
      case 'reviewed':
        return AppColors.warning;
      case 'cancelled':
        return AppColors.danger;
      default:
        return AppColors.textMuted;
    }
  }

  static const _flow = [
    'pending',
    'reviewed',
    'in_production',
    'ready',
    'installation',
    'delivered',
  ];

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: AppColors.softGray,
        appBar: AppBar(
          backgroundColor: AppColors.navy,
          leading: IconButton(
            icon:
                const Icon(Icons.arrow_back_ios_rounded, color: AppColors.gold),
            onPressed: () => Navigator.pop(context),
          ),
          title: Text(widget.orderId,
              style: const TextStyle(
                  fontWeight: FontWeight.w800, color: AppColors.white)),
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
                            : 'Could Not Load Order',
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
                              child: const Text('Try Again')),
                    ),
                  ]),
                ),
              );
            }
            final o = snap.data!;
            final status = o['status']?.toString() ?? 'pending';
            final currentStep =
                _flow.indexOf(status).clamp(0, _flow.length - 1);
            final statusColor = _statusColor(status);

            return RefreshIndicator(
              color: AppColors.gold,
              backgroundColor: AppColors.white,
              onRefresh: _refresh,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16),
                children: [
                  // ── Header card ──────────────────────────────────────────────
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: AppColors.white,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(
                          color: AppColors.gold.withValues(alpha: .35)),
                      boxShadow: [
                        BoxShadow(
                            color: AppColors.gold.withValues(alpha: .1),
                            blurRadius: 16)
                      ],
                    ),
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(o['product'] ?? 'Sign Board Order',
                              style: const TextStyle(
                                  color: AppColors.navy,
                                  fontSize: 20,
                                  fontWeight: FontWeight.w800)),
                          const SizedBox(height: 6),
                          Text('Placed on ${o['createdAt'] ?? ''}',
                              style: const TextStyle(
                                  color: AppColors.textMuted, fontSize: 12)),
                          const SizedBox(height: 12),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 14, vertical: 6),
                            decoration: BoxDecoration(
                              color: statusColor.withValues(alpha: .15),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                  color: statusColor.withValues(alpha: .4)),
                            ),
                            child: Text(humanize(status),
                                style: TextStyle(
                                    color: statusColor,
                                    fontWeight: FontWeight.w800,
                                    fontSize: 13)),
                          ),
                        ]),
                  ),
                  const SizedBox(height: 16),

                  // ── Progress stepper ─────────────────────────────────────────
                  _Card(
                    title: 'Order Progress',
                    child: Column(children: [
                      ..._flow.asMap().entries.map((entry) {
                        final idx = entry.key;
                        final step = entry.value;
                        final isDone = idx <= currentStep;
                        final isNow = idx == currentStep;
                        return Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Column(children: [
                                Container(
                                  width: 28,
                                  height: 28,
                                  decoration: BoxDecoration(
                                    color: isDone
                                        ? AppColors.success
                                        : AppColors.softGray,
                                    shape: BoxShape.circle,
                                    border: isNow
                                        ? Border.all(
                                            color: AppColors.success, width: 2)
                                        : null,
                                  ),
                                  child: Icon(
                                    isDone
                                        ? Icons.check_rounded
                                        : Icons.radio_button_unchecked,
                                    size: 14,
                                    color: isDone
                                        ? AppColors.white
                                        : AppColors.textMuted,
                                  ),
                                ),
                                if (idx < _flow.length - 1)
                                  Container(
                                    width: 2,
                                    height: 28,
                                    color: idx < currentStep
                                        ? AppColors.success
                                        : AppColors.cardBorder,
                                  ),
                              ]),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Padding(
                                  padding:
                                      const EdgeInsets.only(top: 4, bottom: 28),
                                  child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(humanize(step),
                                            style: TextStyle(
                                              fontWeight: isNow
                                                  ? FontWeight.w800
                                                  : FontWeight.w600,
                                              color: isDone
                                                  ? AppColors.charcoal
                                                  : AppColors.textMuted, // ✅
                                              fontSize: 13,
                                            )),
                                        if (isNow)
                                          const Text('Current status',
                                              style: TextStyle(
                                                  fontSize: 11,
                                                  color: AppColors.success)),
                                      ]),
                                ),
                              ),
                            ]);
                      }),
                    ]),
                  ),
                  const SizedBox(height: 16),

                  // ── Specifications ───────────────────────────────────────────
                  _Card(
                    title: 'Specifications',
                    child: Column(children: [
                      _Row('Product', o['product'] ?? '—'),
                      _Row('Material', o['material'] ?? '—'),
                      _Row('Lighting', o['lighting'] ?? '—'),
                      _Row('Size',
                          '${o['length'] ?? 0} ft × ${o['width'] ?? 0} ft'),
                      _Row('Quantity', '${o['quantity'] ?? 1}'),
                      _Row('Installation',
                          o['installation'] == true ? 'Yes' : 'No'),
                      _Row('Transportation',
                          o['transportation'] == true ? 'Yes' : 'No'),
                      if ((o['address'] ?? '').toString().isNotEmpty)
                        _Row('Address', o['address'].toString()),
                      // ✅ Show text design if present
                      if ((o['signText'] ?? '').toString().isNotEmpty) ...[
                        const Divider(height: 16, color: AppColors.cardBorder),
                        _Row('Sign Text', o['signText'].toString()),
                        if ((o['signFont'] ?? '').toString().isNotEmpty)
                          _Row('Sign Font', o['signFont'].toString()),
                      ],
                    ]),
                  ),
                  const SizedBox(height: 16),

                  // ── Price breakdown ──────────────────────────────────────────
                  _Card(
                    title: 'Price Breakdown',
                    child: Column(children: [
                      _Row('Estimated Price', money(o['estimatedPrice'])),
                      _Row('GST', money(o['gst'])),
                      const Divider(height: 20, color: AppColors.cardBorder),
                      Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('Total',
                                style: TextStyle(
                                    fontWeight: FontWeight.w800,
                                    fontSize: 15,
                                    color: AppColors.navy)),
                            Text(money(o['estimatedPrice']),
                                style: const TextStyle(
                                    fontWeight: FontWeight.w800,
                                    fontSize: 20,
                                    color: AppColors.gold)),
                          ]),
                    ]),
                  ),
                  const SizedBox(height: 16),

                  // ── Status history ───────────────────────────────────────────
                  if ((o['statusHistory'] as List? ?? []).isNotEmpty)
                    _Card(
                      title: 'Status History',
                      child: Column(children: [
                        ...(o['statusHistory'] as List).map((h) {
                          final m = h as Map<String, dynamic>;
                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 6),
                            child: Row(children: [
                              const Icon(Icons.history_rounded,
                                  size: 16, color: AppColors.gold),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(humanize(m['status'] ?? ''),
                                    style: const TextStyle(
                                        fontWeight: FontWeight.w600,
                                        color: AppColors.charcoal)), // ✅
                              ),
                              Text(m['time'] ?? '',
                                  style: const TextStyle(
                                      fontSize: 12,
                                      color: AppColors.textMuted)), // ✅
                            ]),
                          );
                        }),
                      ]),
                    ),
                  const SizedBox(height: 24),
                ],
              ),
            );
          },
        ),
      );
}

// ── Reusable card ─────────────────────────────────────────────────────────────
class _Card extends StatelessWidget {
  const _Card({required this.title, required this.child});
  final String title;
  final Widget child;
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.cardBorder),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title,
              style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: AppColors.navy)),
          const SizedBox(height: 14),
          child,
        ]),
      );
}

// ── Spec row ──────────────────────────────────────────────────────────────────
class _Row extends StatelessWidget {
  const _Row(this.label, this.value);
  final String label, value;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 5),
        child:
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Text(label,
              style: const TextStyle(
                  color: AppColors.textMuted, fontSize: 13)), // ✅
          Flexible(
              child: Text(value,
                  style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                      color: AppColors.charcoal), // ✅
                  textAlign: TextAlign.end)),
        ]),
      );
}
