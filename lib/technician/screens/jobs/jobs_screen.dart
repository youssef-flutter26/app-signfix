import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/app_theme.dart';
import '../../services/api_client.dart';
import '../../widgets/common.dart';
import '../../../core/app_utils.dart' show humanize;

// ── Workflow step color helper ────────────────────────────────────────────────
Color _stepColor(String status) {
  switch (status) {
    case 'assigned':
      return AppColors.stepAssigned;
    case 'accepted':
      return AppColors.stepAccepted;
    case 'on_the_way':
      return AppColors.stepOnTheWay;
    case 'reached_location':
      return AppColors.stepReachedLocation;
    case 'inspection_started':
      return AppColors.stepInspection;
    case 'work_in_progress':
      return AppColors.stepWorkInProgress;
    case 'completed':
      return AppColors.stepCompleted;
    default:
      return AppColors.info;
  }
}

String _stepLabel(String status) {
  switch (status) {
    case 'assigned':
      return 'Assigned';
    case 'accepted':
      return 'Accepted';
    case 'on_the_way':
      return 'On Way';
    case 'reached_location':
      return 'Reached';
    case 'inspection_started':
      return 'Inspect';
    case 'work_in_progress':
      return 'Working';
    case 'completed':
      return 'Done';
    default:
      return status;
  }
}

// ── Jobs List Screen ──────────────────────────────────────────────────────────
class JobsScreen extends StatefulWidget {
  const JobsScreen({super.key, required this.api, required this.onLogout});
  final TechnicianApi api;
  final VoidCallback onLogout;
  @override
  State<JobsScreen> createState() => _JobsScreenState();
}

class _JobsScreenState extends State<JobsScreen> {
  String _filter = 'Today';
  late Future<List<dynamic>> _future;

  @override
  void initState() {
    super.initState();
    _future = widget.api.jobs();
  }

  void _refresh() {
    final future = widget.api.jobs();
    setState(() {
      _future = future;
    });
  }

  void _handleAuthError() async {
    await widget.api.logout();
    if (mounted) widget.onLogout();
  }

  void _reload() {
    final f = widget.api.jobs();
    setState(() {
      _future = f;
    });
  }

  Future<void> _doRefresh() async {
    final f = widget.api.jobs();
    if (mounted) {
      setState(() {
        _future = f;
      });
    }
    await f;
  }

  List<dynamic> _filtered(List<dynamic> jobs) {
    switch (_filter) {
      case 'Today':
        return jobs;
      case 'Priority':
        return jobs
            .where((j) => ['high', 'emergency'].contains(j['priority']))
            .toList();
      case 'Upcoming':
        return jobs.where((j) => j['status'] == 'assigned').toList();
      default:
        return jobs
            .where((j) => j['status']?.toString() == _filter.toLowerCase())
            .toList();
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: AppColors.softGray,
        body: RefreshIndicator(
          color: AppColors.gold,
          backgroundColor: AppColors.white,
          onRefresh: _doRefresh,
          child: FutureBuilder<List<dynamic>>(
            future: _future,
            builder: (context, snapshot) {
              if (snapshot.connectionState != ConnectionState.done) {
                return const Center(
                    child: CircularProgressIndicator(color: AppColors.gold));
              }
              if (snapshot.hasError) {
                final errMsg = snapshot.error.toString();
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
                              : 'Could Not Load Jobs',
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
              final allJobs = snapshot.data ?? [];
              final jobs = _filtered(allJobs);
              final emergencyJobs = allJobs
                  .where((j) =>
                      j['priority'] == 'emergency' &&
                      j['status'] != 'completed')
                  .toList();

              return ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16),
                children: [
                  // Emergency alert
                  if (emergencyJobs.isNotEmpty)
                    Container(
                      margin: const EdgeInsets.only(bottom: 14),
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: AppColors.danger.withValues(alpha: .08),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                            color: AppColors.danger.withValues(alpha: .3)),
                      ),
                      child: Row(children: [
                        const Icon(Icons.warning_amber_rounded,
                            color: AppColors.danger, size: 22),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            '${emergencyJobs.length} emergency job${emergencyJobs.length > 1 ? 's' : ''} require immediate attention.',
                            style: const TextStyle(
                                color: AppColors.danger,
                                fontWeight: FontWeight.w700,
                                fontSize: 13),
                          ),
                        ),
                      ]),
                    ),

                  // Stats
                  _StatsRow(jobs: allJobs),
                  const SizedBox(height: 18),

                  // Filter chips
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        'Today',
                        'Upcoming',
                        'Pending',
                        'Completed',
                        'Priority'
                      ]
                          .map((v) => Padding(
                                padding: const EdgeInsets.only(right: 7),
                                child: ChoiceChip(
                                  label: Text(v),
                                  selected: _filter == v,
                                  onSelected: (_) =>
                                      setState(() => _filter = v),
                                ),
                              ))
                          .toList(),
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Job list
                  if (jobs.isEmpty)
                    const Padding(
                      padding: EdgeInsets.all(50),
                      child: Center(
                          child: Text('No jobs match this filter.',
                              style: TextStyle(color: AppColors.midGray))),
                    )
                  else
                    ...jobs.map((job) => Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: JobCard(
                            job: Map<String, dynamic>.from(job),
                            onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => JobDetailScreen(
                                  api: widget.api,
                                  job: Map<String, dynamic>.from(job),
                                ),
                              ),
                            ).then((_) {
                              if (mounted) _refresh();
                            }),
                          ),
                        )),
                ],
              );
            },
          ),
        ), // close RefreshIndicator
      ); // close Scaffold
}

// ── Stats Row ─────────────────────────────────────────────────────────────────
class _StatsRow extends StatelessWidget {
  const _StatsRow({required this.jobs});
  final List<dynamic> jobs;

  @override
  Widget build(BuildContext context) {
    final assigned = jobs.where((j) => j['status'] == 'assigned').length;
    final inProgress =
        jobs.where((j) => j['status'] == 'work_in_progress').length;
    final completed = jobs.where((j) => j['status'] == 'completed').length;
    return Row(children: [
      _Stat('Assigned', '$assigned', AppColors.info),
      const SizedBox(width: 8),
      _Stat('In Progress', '$inProgress', AppColors.warning),
      const SizedBox(width: 8),
      _Stat('Completed', '$completed', AppColors.success),
    ]);
  }
}

class _Stat extends StatelessWidget {
  const _Stat(this.label, this.value, this.color);
  final String label, value;
  final Color color;

  @override
  Widget build(BuildContext context) => Expanded(
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
          decoration: BoxDecoration(
            color: AppColors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: color.withValues(alpha: .35)),
          ),
          child: Column(children: [
            Text(value,
                style: TextStyle(
                    fontSize: 24, fontWeight: FontWeight.w900, color: color)),
            const SizedBox(height: 3),
            Text(label,
                style: const TextStyle(fontSize: 11, color: AppColors.midGray),
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis),
          ]),
        ),
      );
}

// ── Job Card ──────────────────────────────────────────────────────────────────
class JobCard extends StatelessWidget {
  const JobCard({super.key, required this.job, required this.onTap});
  final Map<String, dynamic> job;
  final VoidCallback onTap;

  Color _priorityColor(String? p) {
    switch (p) {
      case 'emergency':
        return AppColors.danger;
      case 'high':
        return AppColors.warning;
      default:
        return AppColors.midGray;
    }
  }

  @override
  Widget build(BuildContext context) {
    final priority = job['priority']?.toString() ?? 'normal';
    final isEmergency = priority == 'emergency';
    return Container(
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isEmergency
              ? AppColors.danger.withValues(alpha: .6)
              : AppColors.cardBorder,
          width: isEmergency ? 1.5 : 1,
        ),
        boxShadow: isEmergency
            ? [
                BoxShadow(
                    color: AppColors.danger.withValues(alpha: .1),
                    blurRadius: 10),
              ]
            : [],
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Text(job['id']?.toString() ?? 'JOB',
                  style: const TextStyle(
                      color: AppColors.info,
                      fontSize: 11,
                      fontWeight: FontWeight.w800)),
              const Spacer(),
              if (isEmergency)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.danger.withValues(alpha: .1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Row(mainAxisSize: MainAxisSize.min, children: [
                    Icon(Icons.warning_amber_rounded,
                        size: 12, color: AppColors.danger),
                    SizedBox(width: 4),
                    Text('EMERGENCY',
                        style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            color: AppColors.danger)),
                  ]),
                )
              else
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: _priorityColor(priority).withValues(alpha: .1),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                        color: _priorityColor(priority).withValues(alpha: .3)),
                  ),
                  child: Text(humanize(priority),
                      style: TextStyle(
                          color: _priorityColor(priority),
                          fontSize: 10,
                          fontWeight: FontWeight.w700)),
                ),
            ]),
            const SizedBox(height: 6),
            Text(job['customer']?.toString() ?? 'Customer',
                style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    color: AppColors.navy)),
            Text(job['category']?.toString() ?? 'Service job',
                style: const TextStyle(color: AppColors.midGray)),
            const Divider(height: 20, color: AppColors.cardBorder),
            Row(children: [
              const Icon(Icons.location_on_outlined,
                  size: 16, color: AppColors.info),
              const SizedBox(width: 5),
              Expanded(
                child: Text(job['address']?.toString() ?? 'Location pending',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontSize: 13, color: AppColors.midGray)),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: _stepColor(job['status']?.toString() ?? 'assigned')
                      .withValues(alpha: .15),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                      color: _stepColor(job['status']?.toString() ?? 'assigned')
                          .withValues(alpha: .4)),
                ),
                child: Text(humanize(job['status']?.toString() ?? 'assigned'),
                    style: TextStyle(
                        fontSize: 11,
                        color:
                            _stepColor(job['status']?.toString() ?? 'assigned'),
                        fontWeight: FontWeight.w700)),
              ),
            ]),
          ]),
        ),
      ),
    );
  }
}

// ── Job Detail Screen ─────────────────────────────────────────────────────────
class JobDetailScreen extends StatefulWidget {
  const JobDetailScreen({super.key, required this.api, required this.job});
  final TechnicianApi api;
  final Map<String, dynamic> job;
  @override
  State<JobDetailScreen> createState() => _JobDetailState();
}

class _JobDetailState extends State<JobDetailScreen> {
  late String status;
  final notes = TextEditingController();
  final parts = TextEditingController();
  final otp = TextEditingController();
  final evidence = <String, List<File>>{'before': [], 'work': [], 'after': []};
  bool loading = false;

  static const _flow = [
    'assigned',
    'accepted',
    'on_the_way',
    'reached_location',
    'inspection_started',
    'work_in_progress',
    'completed'
  ];

  @override
  void initState() {
    super.initState();
    status = widget.job['status']?.toString() ?? 'assigned';
  }

  @override
  void dispose() {
    notes.dispose();
    parts.dispose();
    otp.dispose();
    super.dispose();
  }

  Future<void> _pick(String kind) async {
    final image = await ImagePicker()
        .pickImage(source: ImageSource.camera, imageQuality: 78);
    if (image != null && mounted) {
      setState(() => evidence[kind]!.add(File(image.path)));
    }
  }

  Future<void> _advance() async {
    final idx = _flow.indexOf(status);
    final next =
        idx < 0 ? _flow.first : _flow[(idx + 1).clamp(0, _flow.length - 1)];
    if (next == 'completed' && evidence['after']!.isEmpty) {
      showAppError(
          context, 'Add at least one after photo before completing the job.');
      return;
    }
    if (next == 'completed' && otp.text.trim().length < 4) {
      showAppError(context, 'Customer OTP is required (minimum 4 digits).');
      return;
    }
    setState(() => loading = true);
    try {
      for (final entry in evidence.entries) {
        for (final file in entry.value) {
          await widget.api.upload(file, entry.key, widget.job['id'].toString());
        }
      }
      final result = await widget.api.updateJob(
        widget.job['id'].toString(),
        next,
        extra: {
          'notes': notes.text.trim(),
          'parts': parts.text.trim(),
          'customerOtp': otp.text.trim(),
        },
      );
      if (mounted) {
        setState(() => status = result['status']?.toString() ?? next);
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('✓ Updated: ${humanize(status)}')));
      }
    } catch (e) {
      if (mounted) showAppError(context, e);
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> _openMaps() async {
    final lat = widget.job['latitude'];
    final lon = widget.job['longitude'];
    final uri = (lat != null && lon != null)
        ? Uri.parse('https://maps.google.com/?q=$lat,$lon')
        : Uri.parse(
            'https://maps.google.com/?q=${Uri.encodeComponent(widget.job['address']?.toString() ?? '')}');
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  Future<void> _callCustomer() async {
    final phone = widget.job['phone']?.toString();
    if (phone == null || phone.isEmpty) {
      showAppError(context, 'Customer phone number is unavailable.');
      return;
    }
    await launchUrl(Uri.parse('tel:$phone'));
  }

  @override
  Widget build(BuildContext context) {
    final idx = _flow.indexOf(status);
    final next =
        idx >= 0 ? _flow[(idx + 1).clamp(0, _flow.length - 1)] : 'accepted';
    final isDone = status == 'completed';
    final priority = widget.job['priority']?.toString() ?? 'normal';

    return Scaffold(
      backgroundColor: AppColors.softGray,
      appBar: AppBar(
        backgroundColor: AppColors.navyDark,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_rounded, color: AppColors.info),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(widget.job['id']?.toString() ?? 'Job details',
            style: const TextStyle(
                fontWeight: FontWeight.w800, color: AppColors.white)),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Header card
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: priority == 'emergency'
                    ? [AppColors.danger, AppColors.navy]
                    : [AppColors.navyDeep, AppColors.navy],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                  color: (priority == 'emergency'
                          ? AppColors.danger
                          : AppColors.info)
                      .withValues(alpha: .5)),
            ),
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(widget.job['customer']?.toString() ?? 'Customer',
                  style: const TextStyle(
                      color: AppColors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.w800)),
              Text(widget.job['category']?.toString() ?? 'Service job',
                  style: const TextStyle(color: AppColors.darkSecondary)),
              const SizedBox(height: 10),
              if ((widget.job['description'] ?? '').toString().isNotEmpty)
                Text(widget.job['description'].toString(),
                    style: const TextStyle(
                        color: AppColors.darkSecondary,
                        fontSize: 13,
                        height: 1.4)),
              const SizedBox(height: 12),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                decoration: BoxDecoration(
                  color: AppColors.white.withValues(alpha: .12),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(humanize(status),
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      color: priority == 'emergency'
                          ? AppColors.danger
                          : _stepColor(status),
                    )),
              ),
            ]),
          ),
          const SizedBox(height: 12),

          // Contact & location
          Container(
            decoration: BoxDecoration(
              color: AppColors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.cardBorder),
            ),
            child: Column(children: [
              ListTile(
                leading: const Icon(Icons.location_on_outlined,
                    color: AppColors.info),
                title: Text(
                    widget.job['address']?.toString() ?? 'Location pending',
                    style: const TextStyle(color: AppColors.charcoal)),
                subtitle: const Text('Navigate to site',
                    style: TextStyle(color: AppColors.midGray)),
                trailing: IconButton(
                  onPressed: _openMaps,
                  icon: const Icon(Icons.navigation_outlined,
                      color: AppColors.info),
                  tooltip: 'Open in Maps',
                ),
              ),
              const Divider(height: 0, color: AppColors.cardBorder, indent: 56),
              ListTile(
                leading:
                    const Icon(Icons.phone_outlined, color: AppColors.success),
                title: Text(
                    widget.job['phone']?.toString() ?? 'Contact unavailable',
                    style: const TextStyle(color: AppColors.charcoal)),
                subtitle: const Text('Call customer',
                    style: TextStyle(color: AppColors.midGray)),
                trailing: IconButton(
                  onPressed: _callCustomer,
                  icon:
                      const Icon(Icons.call_outlined, color: AppColors.success),
                  tooltip: 'Call',
                ),
              ),
            ]),
          ),
          const SizedBox(height: 16),

          // Workflow progress
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.cardBorder),
            ),
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('Job Progress',
                  style: TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 15,
                      color: AppColors.navy)),
              const SizedBox(height: 12),
              LinearProgressIndicator(
                value: (idx + 1) / _flow.length,
                borderRadius: BorderRadius.circular(8),
                minHeight: 6,
                color: _stepColor(status),
                backgroundColor: AppColors.cardBorder,
              ),
              const SizedBox(height: 8),
              Text(
                isDone
                    ? 'All steps completed ✓'
                    : 'Step ${idx + 1} of ${_flow.length}',
                style: TextStyle(
                  fontSize: 12,
                  color: _stepColor(status),
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 14),
              // Step dots row
              Row(
                children: _flow.map((step) {
                  final stepIdx = _flow.indexOf(step);
                  final isDoneStep = stepIdx <= idx;
                  final isCurrent = stepIdx == idx;
                  final color = _stepColor(step);
                  return Expanded(
                    child: Column(children: [
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        width: isCurrent ? 12 : 8,
                        height: isCurrent ? 12 : 8,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: isDoneStep ? color : AppColors.cardBorder,
                          boxShadow: isCurrent
                              ? [
                                  BoxShadow(
                                      color: color.withValues(alpha: .5),
                                      blurRadius: 6)
                                ]
                              : [],
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _stepLabel(step),
                        style: TextStyle(
                          fontSize: 8,
                          color: isDoneStep ? color : AppColors.midGray,
                          fontWeight:
                              isCurrent ? FontWeight.w800 : FontWeight.w400,
                        ),
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ]),
                  );
                }).toList(),
              ),
            ]),
          ),
          const SizedBox(height: 16),

          // Evidence photos
          const Text('Service Evidence',
              style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                  color: AppColors.navy)),
          const SizedBox(height: 8),
          ...evidence.keys.map((kind) => Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: AppColors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppColors.cardBorder),
                ),
                child: Row(children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.info.withValues(alpha: .1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.camera_alt_outlined,
                        color: AppColors.info, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                        Text('${humanize(kind)} photos',
                            style: const TextStyle(
                                color: AppColors.charcoal,
                                fontWeight: FontWeight.w600,
                                fontSize: 14)),
                        Text(
                            evidence[kind]!.isEmpty
                                ? 'No photos yet'
                                : '${evidence[kind]!.length} photo(s) captured',
                            style: const TextStyle(
                                color: AppColors.midGray, fontSize: 12)),
                      ])),
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: () => _pick(kind),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: AppColors.info.withValues(alpha: .15),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                            color: AppColors.info.withValues(alpha: .3)),
                      ),
                      child:
                          const Row(mainAxisSize: MainAxisSize.min, children: [
                        Icon(Icons.add_a_photo_outlined,
                            size: 14, color: AppColors.info),
                        SizedBox(width: 4),
                        Text('Add',
                            style: TextStyle(
                                color: AppColors.info,
                                fontWeight: FontWeight.w700,
                                fontSize: 12)),
                      ]),
                    ),
                  ),
                ]),
              )),
          const SizedBox(height: 16),

          // Notes & parts
          const Text('Work Details',
              style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                  color: AppColors.navy)),
          const SizedBox(height: 8),
          TextField(
            controller: notes,
            maxLines: 3,
            style: const TextStyle(color: AppColors.charcoal),
            decoration: const InputDecoration(
              labelText: 'Work notes',
              alignLabelWithHint: true,
              prefixIcon: Icon(Icons.notes_outlined),
            ),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: parts,
            style: const TextStyle(color: AppColors.charcoal),
            decoration: const InputDecoration(
              labelText: 'Parts / materials used',
              prefixIcon: Icon(Icons.inventory_2_outlined),
            ),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: otp,
            keyboardType: TextInputType.number,
            maxLength: 6,
            style: const TextStyle(color: AppColors.charcoal),
            decoration: const InputDecoration(
              labelText: 'Customer completion OTP',
              hintText: 'Enter OTP given by customer',
              prefixIcon: Icon(Icons.pin_outlined),
            ),
          ),
          const SizedBox(height: 18),

          // Status history
          if ((widget.job['statusHistory'] as List? ?? []).isNotEmpty)
            Container(
              decoration: BoxDecoration(
                color: AppColors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.cardBorder),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Status History',
                          style: TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 15,
                              color: AppColors.navy)),
                      const SizedBox(height: 10),
                      ...(widget.job['statusHistory'] as List).map((h) {
                        final m = h as Map<String, dynamic>;
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 5),
                          child: Row(children: [
                            const Icon(Icons.history,
                                size: 14, color: AppColors.info),
                            const SizedBox(width: 8),
                            Expanded(
                                child: Text(humanize(m['status'] ?? ''),
                                    style: const TextStyle(
                                        fontWeight: FontWeight.w600,
                                        fontSize: 13,
                                        color: AppColors.charcoal))),
                            Text(m['time'] ?? '',
                                style: const TextStyle(
                                    fontSize: 11, color: AppColors.midGray)),
                          ]),
                        );
                      }),
                    ]),
              ),
            ),
          const SizedBox(height: 18),

          // Advance button
          LoadingButton(
            loading: loading,
            onPressed: isDone ? null : _advance,
            child:
                Text(isDone ? '✓ Job Completed' : 'Mark as ${humanize(next)}'),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}
