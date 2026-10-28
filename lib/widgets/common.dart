import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../core/app_theme.dart';

class BrandLogo extends StatelessWidget {
  const BrandLogo({super.key, this.size = 64});
  final double size;
  @override
  Widget build(BuildContext c) => ClipRRect(
      borderRadius: BorderRadius.circular(size * .22),
      child: SvgPicture.asset('assets/branding/signfix-logo.svg',
          width: size, height: size));
}

class LoadingButton extends StatelessWidget {
  const LoadingButton(
      {super.key,
      required this.loading,
      required this.onPressed,
      required this.child});
  final bool loading;
  final VoidCallback? onPressed;
  final Widget child;
  @override
  Widget build(BuildContext c) => FilledButton(
      style: FilledButton.styleFrom(
        // Override theme's Size.fromHeight — allow natural width in Row
        minimumSize: const Size(64, 48),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
      onPressed: loading ? null : onPressed,
      child: loading
          ? const SizedBox.square(
              dimension: 21,
              child: CircularProgressIndicator(
                  strokeWidth: 2, color: AppColors.navy))
          : child);
}

class ActionCard extends StatelessWidget {
  const ActionCard(
      {super.key,
      required this.title,
      required this.subtitle,
      required this.icon,
      required this.color,
      required this.label,
      required this.onTap});
  final String title, subtitle, label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext c) => Material(
      color: color,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: onTap,
          child: Padding(
              padding: const EdgeInsets.all(20),
              child: Row(children: [
                CircleAvatar(
                    radius: 28,
                    backgroundColor: AppColors.white.withValues(alpha: .24),
                    child: Icon(icon, color: AppColors.white, size: 28)),
                const SizedBox(width: 16),
                Expanded(
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                      Text(title,
                          style: const TextStyle(
                              color: AppColors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.bold)),
                      const SizedBox(height: 5),
                      Text(subtitle,
                          style: const TextStyle(color: AppColors.white70)),
                      const SizedBox(height: 10),
                      Text(label,
                          style: const TextStyle(
                              color: AppColors.white,
                              fontWeight: FontWeight.w700))
                    ]))
              ]))));
}

class StatusTile extends StatelessWidget {
  const StatusTile(
      {super.key,
      required this.icon,
      required this.title,
      required this.subtitle,
      this.color = AppColors.gold}); // ✅ gold default (visible on dark bg)
  final IconData icon;
  final String title, subtitle;
  final Color color;
  @override
  Widget build(BuildContext c) => Card(
      child: ListTile(
          leading: CircleAvatar(
              backgroundColor: color.withValues(alpha: .1),
              child: Icon(icon, color: color)),
          title:
              Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
          subtitle: Text(subtitle)));
}

void showAppError(BuildContext c, Object e) =>
    ScaffoldMessenger.of(c).showSnackBar(SnackBar(content: Text(e.toString())));
