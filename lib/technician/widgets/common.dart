import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../../core/app_theme.dart';

class BrandLogo extends StatelessWidget {
  const BrandLogo({super.key, this.size = 48});
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

void showAppError(BuildContext c, Object e) =>
    ScaffoldMessenger.of(c).showSnackBar(SnackBar(content: Text(e.toString())));
