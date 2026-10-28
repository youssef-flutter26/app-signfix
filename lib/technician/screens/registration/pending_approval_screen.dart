import 'package:flutter/material.dart';
import '../../core/app_theme.dart';

class PendingApprovalScreen extends StatelessWidget {
  const PendingApprovalScreen({super.key, this.rejectionReason});
  final String? rejectionReason;

  @override
  Widget build(BuildContext context) {
    final isRejected = rejectionReason != null;

    return Scaffold(
      backgroundColor: AppColors.softGray,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Status icon
              Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: (isRejected ? AppColors.danger : AppColors.warning)
                      .withValues(alpha: .12),
                  border: Border.all(
                    color: isRejected ? AppColors.danger : AppColors.warning,
                    width: 2,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: (isRejected ? AppColors.danger : AppColors.warning)
                          .withValues(alpha: .2),
                      blurRadius: 20,
                    ),
                  ],
                ),
                child: Icon(
                  isRejected
                      ? Icons.cancel_outlined
                      : Icons.hourglass_top_rounded,
                  size: 48,
                  color: isRejected ? AppColors.danger : AppColors.warning,
                ),
              ),
              const SizedBox(height: 28),

              Text(
                isRejected
                    ? 'Registration Not Approved'
                    : 'Registration Submitted!',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                  color: isRejected ? AppColors.danger : AppColors.navy,
                ),
              ),
              const SizedBox(height: 12),

              Text(
                isRejected
                    ? 'Your SignFix technician registration was not approved.'
                    : 'Your registration has been received and is pending admin approval.',
                textAlign: TextAlign.center,
                style: const TextStyle(
                    color: AppColors.midGray, fontSize: 14, height: 1.5),
              ),

              if (isRejected && rejectionReason!.isNotEmpty) ...[
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.danger.withValues(alpha: .08),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                        color: AppColors.danger.withValues(alpha: .4)),
                  ),
                  child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.info_outline,
                            color: AppColors.danger, size: 18),
                        const SizedBox(width: 10),
                        Expanded(
                            child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                              const Text('Reason:',
                                  style: TextStyle(
                                      color: AppColors.danger,
                                      fontWeight: FontWeight.w700)),
                              const SizedBox(height: 4),
                              Text(rejectionReason!,
                                  style: const TextStyle(
                                      color: AppColors.charcoal, height: 1.4)),
                            ])),
                      ]),
                ),
              ],

              const SizedBox(height: 24),

              // Status steps (only for pending)
              if (!isRejected) ...[
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: AppColors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.cardBorder),
                  ),
                  child: const Column(children: [
                    _StatusStep(
                      icon: Icons.check_circle_rounded,
                      color: AppColors.success,
                      title: 'Registration Submitted',
                      subtitle: 'Your details have been received',
                      done: true,
                    ),
                    _StatusStep(
                      icon: Icons.pending_outlined,
                      color: AppColors.warning,
                      title: 'Admin Review',
                      subtitle: 'SignFix admin will review your application',
                      done: false,
                      isActive: true,
                    ),
                    _StatusStep(
                      icon: Icons.work_outline_rounded,
                      color: AppColors.midGray,
                      title: 'Account Activated',
                      subtitle: 'You will receive a notification when approved',
                      done: false,
                      isLast: true,
                    ),
                  ]),
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppColors.warning.withValues(alpha: .08),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                        color: AppColors.warning.withValues(alpha: .3)),
                  ),
                  child: const Row(children: [
                    Icon(Icons.notifications_outlined,
                        color: AppColors.warning, size: 18),
                    SizedBox(width: 10),
                    Expanded(
                        child: Text(
                      'You will receive a notification once your account is approved.',
                      style: TextStyle(
                          color: AppColors.midGray, fontSize: 12, height: 1.4),
                    )),
                  ]),
                ),
              ],

              const SizedBox(height: 28),

              // Back to login
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: () {
                    // Pop all registration screens back to login
                    Navigator.of(context).popUntil((route) => route.isFirst);
                  },
                  icon: const Icon(Icons.login_rounded),
                  label: Text(isRejected ? 'Back to Login' : 'Back to Login'),
                  style: FilledButton.styleFrom(
                    backgroundColor:
                        isRejected ? AppColors.navyMid : AppColors.gold,
                    foregroundColor:
                        isRejected ? AppColors.white : AppColors.navy,
                  ),
                ),
              ),

              if (isRejected) ...[
                const SizedBox(height: 12),
                const Text(
                  'Contact admin@signfix.in for more information.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppColors.midGray, fontSize: 12),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _StatusStep extends StatelessWidget {
  const _StatusStep({
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
    required this.done,
    this.isActive = false,
    this.isLast = false,
  });
  final IconData icon;
  final Color color;
  final String title, subtitle;
  final bool done, isActive, isLast;

  @override
  Widget build(BuildContext context) => Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Column(children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: color.withValues(alpha: .15),
                border: Border.all(color: color.withValues(alpha: .5)),
              ),
              child: Icon(icon, color: color, size: 16),
            ),
            if (!isLast)
              Container(width: 2, height: 28, color: AppColors.cardBorder),
          ]),
          const SizedBox(width: 14),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(top: 4, bottom: 20),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        style: TextStyle(
                          color: isActive
                              ? AppColors.navy
                              : done
                                  ? AppColors.success
                                  : AppColors.midGray,
                          fontWeight:
                              isActive ? FontWeight.w800 : FontWeight.w600,
                          fontSize: 13,
                        )),
                    const SizedBox(height: 2),
                    Text(subtitle,
                        style: const TextStyle(
                            color: AppColors.midGray, fontSize: 11)),
                  ]),
            ),
          ),
        ],
      );
}
