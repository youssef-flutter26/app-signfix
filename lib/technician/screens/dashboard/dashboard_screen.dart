import 'package:flutter/material.dart';
import '../../core/app_theme.dart';
import '../../services/api_client.dart';
// humanize() imported from app_utils — no local duplicate needed
import '../../../core/app_utils.dart' show humanize;

// ── Workflow steps definition ─────────────────────────────────────────────────
const _workflowSteps = [
  ('assigned', 'New job assigned to you', AppColors.stepAssigned),
  ('accepted', 'Accept the job to begin', AppColors.stepAccepted),
  ('on_the_way', 'Travel to the customer site', AppColors.stepOnTheWay),
  ('reached_location', 'Mark arrival at site', AppColors.stepReachedLocation),
  ('inspection_started', 'Inspect the sign board', AppColors.stepInspection),
  (
    'work_in_progress',
    'Carry out the repair/install',
    AppColors.stepWorkInProgress
  ),
  ('completed', 'Job done — customer OTP required', AppColors.stepCompleted),
];

int _currentStepIndex(String? status) {
  if (status == null) return -1;
  return _workflowSteps.indexWhere((s) => s.$1 == status);
}

class DashboardScreen extends StatefulWidget {
  const DashboardScreen(
      {super.key, required this.api, required this.onGoToJobs});
  final TechnicianApi api;
  final VoidCallback onGoToJobs;
  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  late Future<Map<String, dynamic>> _statsFuture;
  late Future<Map<String, dynamic>> _profileFuture;
  late Future<List<dynamic>> _jobsFuture;

  @override
  void initState() {
    super.initState();
    _statsFuture = widget.api.dashboard();
    _profileFuture = widget.api.getProfile();
    _jobsFuture = widget.api.jobs();
  }

  Future<void> _refresh() async {
    final s = widget.api.dashboard();
    final p = widget.api.getProfile();
    final j = widget.api.jobs();
    setState(() {
      _statsFuture = s;
      _profileFuture = p;
      _jobsFuture = j;
    });
    await Future.wait([
      s.then<void>((_) {}, onError: (Object _) {}),
      p.then<void>((_) {}, onError: (Object _) {}),
      j.then<void>((_) {}, onError: (Object _) {}),
    ]);
  }

  void _handleAuthError() async {
    await widget.api.logout();
    if (mounted) {
      Navigator.of(context).pushNamedAndRemoveUntil('/', (_) => false);
    }
  }

  void _reload() {
    setState(() {
      _statsFuture = widget.api.dashboard();
      _profileFuture = widget.api.getProfile();
      _jobsFuture = widget.api.jobs();
    });
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: AppColors.softGray,
        body: RefreshIndicator(
          color: AppColors.gold,
          backgroundColor: AppColors.white,
          onRefresh: _refresh,
          child: Container(
            color: AppColors.softGray,
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(18),
              children: [
                // ── Greeting ────────────────────────────────────────────────────
                FutureBuilder<Map<String, dynamic>>(
                  future: _profileFuture,
                  builder: (_, snap) {
                    // ✅ Show actual name — strip "Demo Technician" default
                    String rawName = snap.data?['name']?.toString() ?? '';
                    if (rawName.isEmpty || rawName == 'Demo Technician') {
                      rawName = 'Technician';
                    }
                    final firstName = rawName.split(' ').first;
                    final rating = snap.data?['rating']?.toString() ?? '—';
                    final total =
                        snap.data?['totalJobsCompleted']?.toString() ?? '0';
                    return Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppColors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: AppColors.cardBorder),
                        boxShadow: const [
                          BoxShadow(
                            color: AppColors.shadow,
                            blurRadius: 12,
                            offset: Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Row(children: [
                        Expanded(
                            child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                              Text('Hello, $firstName 👷',
                                  style: const TextStyle(
                                      fontSize: 20,
                                      fontWeight: FontWeight.w800,
                                      color: AppColors.navy)),
                              const SizedBox(height: 4),
                              const Text("Here's your field summary for today.",
                                  style: TextStyle(
                                      color: AppColors.midGray, fontSize: 13)),
                            ])),
                        Column(children: [
                          const Icon(Icons.star_rounded,
                              color: AppColors.warning, size: 22),
                          const SizedBox(height: 2),
                          Text(rating,
                              style: const TextStyle(
                                  fontWeight: FontWeight.w800,
                                  fontSize: 14,
                                  color: AppColors.navy)),
                          Text('$total jobs',
                              style: const TextStyle(
                                  fontSize: 11, color: AppColors.midGray)),
                        ]),
                      ]),
                    );
                  },
                ),
                const SizedBox(height: 18),

                // ── Stats Grid ───────────────────────────────────────────────────
                FutureBuilder<Map<String, dynamic>>(
                  future: _statsFuture,
                  builder: (_, snap) {
                    if (snap.connectionState != ConnectionState.done) {
                      return const SizedBox(
                          height: 120,
                          child: Center(
                              child: CircularProgressIndicator(
                                  color: AppColors.info)));
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
                                    : 'Could Not Load Dashboard',
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
                    final d = snap.data ?? {};
                    return Column(children: [
                      Row(children: [
                        _StatCard("${d['today'] ?? 0}", "Today's Jobs",
                            Icons.today_outlined, AppColors.info),
                        const SizedBox(width: 12),
                        _StatCard("${d['emergency'] ?? 0}", 'Emergency',
                            Icons.warning_amber_rounded, AppColors.danger),
                      ]),
                      const SizedBox(height: 12),
                      Row(children: [
                        _StatCard("${d['assigned'] ?? 0}", 'Assigned',
                            Icons.assignment_outlined, AppColors.warning),
                        const SizedBox(width: 12),
                        _StatCard("${d['inProgress'] ?? 0}", 'In Progress',
                            Icons.engineering_outlined, AppColors.accent),
                      ]),
                      const SizedBox(height: 12),
                      Row(children: [
                        _StatCard("${d['pending'] ?? 0}", 'Pending',
                            Icons.schedule_outlined, AppColors.midGray),
                        const SizedBox(width: 12),
                        _StatCard("${d['completed'] ?? 0}", 'Completed',
                            Icons.check_circle_outline, AppColors.success),
                      ]),
                    ]);
                  },
                ),
                const SizedBox(height: 20),

                // ── View All Jobs button ─────────────────────────────────────────
                GestureDetector(
                  onTap: widget.onGoToJobs,
                  child: Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: AppColors.gold,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: AppColors.goldDark),
                      boxShadow: const [
                        BoxShadow(
                            color: AppColors.shadow,
                            blurRadius: 16,
                            offset: Offset(0, 4))
                      ],
                    ),
                    child: Row(children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppColors.navy.withValues(alpha: .08),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: const Icon(Icons.work_outline_rounded,
                            color: AppColors.navy, size: 26),
                      ),
                      const SizedBox(width: 14),
                      const Expanded(
                          child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                            Text('View All Jobs',
                                style: TextStyle(
                                    color: AppColors.navy,
                                    fontSize: 16,
                                    fontWeight: FontWeight.w800)),
                            SizedBox(height: 3),
                            Text('See assigned, pending and completed jobs.',
                                style: TextStyle(
                                    color: AppColors.charcoal, fontSize: 12)),
                          ])),
                      const Icon(Icons.arrow_forward_ios_rounded,
                          color: AppColors.navy, size: 16),
                    ]),
                  ),
                ),
                const SizedBox(height: 24),

                // ── Job Workflow ─────────────────────────────────────────────────
                const Text('Job Workflow',
                    style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                        color: AppColors.navy)),
                const SizedBox(height: 14),
                FutureBuilder<List<dynamic>>(
                  future: _jobsFuture,
                  builder: (_, snap) {
                    // Find most recent active job status
                    String? activeStatus;
                    if (snap.hasData) {
                      final active = snap.data!
                          .where((j) =>
                              j['status'] != null && j['status'] != 'completed')
                          .toList();
                      if (active.isNotEmpty) {
                        activeStatus = active.first['status']?.toString();
                      }
                    }
                    final activeIdx = _currentStepIndex(activeStatus);

                    return Column(
                      children: _workflowSteps.asMap().entries.map((e) {
                        final idx = e.key;
                        final (status, desc, color) = e.value;
                        final isActive = idx == activeIdx;
                        final isCompleted = activeIdx >= 0 && idx < activeIdx;
                        final isPending = activeIdx >= 0 && idx > activeIdx;

                        // Color logic:
                        // completed steps → dimmed (original color with low opacity)
                        // active step     → full bright color + glow
                        // pending steps   → grey/muted
                        // no active job   → all show normal colors
                        final displayColor = activeIdx < 0
                            ? color
                            : isActive
                                ? color
                                : isCompleted
                                    ? color.withValues(alpha: .35)
                                    : AppColors.midGray.withValues(alpha: .4);

                        return Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Column(children: [
                              AnimatedContainer(
                                duration: const Duration(milliseconds: 300),
                                width: isActive ? 34 : 30,
                                height: isActive ? 34 : 30,
                                decoration: BoxDecoration(
                                  color: isCompleted
                                      ? color.withValues(alpha: .08)
                                      : isActive
                                          ? color.withValues(alpha: .25)
                                          : isPending
                                              ? AppColors.cardBorder
                                                  .withValues(alpha: .3)
                                              : color.withValues(alpha: .15),
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: isActive
                                        ? color
                                        : isCompleted
                                            ? color.withValues(alpha: .3)
                                            : AppColors.cardBorder,
                                    width: isActive ? 2 : 1,
                                  ),
                                  boxShadow: isActive
                                      ? [
                                          BoxShadow(
                                              color:
                                                  color.withValues(alpha: .4),
                                              blurRadius: 10,
                                              spreadRadius: 1)
                                        ]
                                      : [],
                                ),
                                child: Center(
                                  child: isCompleted
                                      ? Icon(Icons.check_rounded,
                                          size: 14,
                                          color: color.withValues(alpha: .5))
                                      : Text(
                                          '${idx + 1}',
                                          style: TextStyle(
                                            fontWeight: FontWeight.w800,
                                            color: displayColor,
                                            fontSize: isActive ? 13 : 12,
                                          ),
                                        ),
                                ),
                              ),
                              if (idx < _workflowSteps.length - 1)
                                AnimatedContainer(
                                  duration: const Duration(milliseconds: 300),
                                  width: 2,
                                  height: 26,
                                  color: isCompleted
                                      ? color.withValues(alpha: .3)
                                      : AppColors.cardBorder,
                                ),
                            ]),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Padding(
                                padding:
                                    const EdgeInsets.only(top: 5, bottom: 20),
                                child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Row(children: [
                                        Text(
                                          humanize(status),
                                          style: TextStyle(
                                            fontWeight: isActive
                                                ? FontWeight.w800
                                                : FontWeight.w600,
                                            color: displayColor,
                                            fontSize: isActive ? 14 : 13,
                                          ),
                                        ),
                                        if (isActive) ...[
                                          const SizedBox(width: 8),
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                                horizontal: 8, vertical: 2),
                                            decoration: BoxDecoration(
                                              color:
                                                  color.withValues(alpha: .2),
                                              borderRadius:
                                                  BorderRadius.circular(10),
                                              border: Border.all(
                                                  color: color.withValues(
                                                      alpha: .5)),
                                            ),
                                            child: Text(
                                              'Current',
                                              style: TextStyle(
                                                  fontSize: 9,
                                                  fontWeight: FontWeight.w800,
                                                  color: color),
                                            ),
                                          ),
                                        ],
                                        if (isCompleted) ...[
                                          const SizedBox(width: 8),
                                          Icon(Icons.check_circle_rounded,
                                              size: 14,
                                              color:
                                                  color.withValues(alpha: .4)),
                                        ],
                                      ]),
                                      Text(
                                        desc,
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: isActive
                                              ? AppColors.midGray
                                              : AppColors.midGray.withValues(
                                                  alpha: isPending ? .4 : .7),
                                        ),
                                      ),
                                    ]),
                              ),
                            ),
                          ],
                        );
                      }).toList(),
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      );
}

class _StatCard extends StatelessWidget {
  const _StatCard(this.value, this.label, this.icon, this.color);
  final String value, label;
  final IconData icon;
  final Color color;
  @override
  Widget build(BuildContext context) => Expanded(
        child: Container(
          padding: const EdgeInsets.all(14),
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
            const SizedBox(width: 10),
            Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  Text(value,
                      style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                          color: color)),
                  Text(label,
                      style: const TextStyle(
                          fontSize: 10, color: AppColors.midGray)),
                ])),
          ]),
        ),
      );
}
