import 'package:flutter/material.dart';
import '../../core/app_theme.dart';

/// Step progress bar (1/3, 2/3, 3/3)
class RegProgressBar extends StatelessWidget {
  const RegProgressBar({super.key, required this.step});
  final int step;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
        color: AppColors.navy,
        child: Row(children: [
          for (int i = 1; i <= 3; i++) ...[
            Expanded(
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                height: 4,
                decoration: BoxDecoration(
                  color: i <= step ? AppColors.gold : AppColors.midGray,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            if (i < 3) const SizedBox(width: 6),
          ],
          const SizedBox(width: 12),
          Text('$step/3',
              style: const TextStyle(
                  color: AppColors.gold,
                  fontWeight: FontWeight.w700,
                  fontSize: 12)),
        ]),
      );
}

/// Standard technician registration text field
class RegField extends StatelessWidget {
  const RegField({
    super.key,
    required this.ctrl,
    required this.label,
    required this.icon,
    this.type = TextInputType.text,
    this.action = TextInputAction.next,
    this.hint,
    this.maxLines = 1,
  });
  final TextEditingController ctrl;
  final String label;
  final IconData icon;
  final TextInputType type;
  final TextInputAction action;
  final String? hint;
  final int maxLines;

  @override
  Widget build(BuildContext context) => TextField(
        controller: ctrl,
        keyboardType: type,
        textInputAction: action,
        maxLines: maxLines,
        style: const TextStyle(color: AppColors.charcoal),
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          prefixIcon: Icon(icon),
        ),
      );
}

/// Error display box
class RegErrorBox extends StatelessWidget {
  const RegErrorBox(this.message, {super.key});
  final String message;
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.danger.withValues(alpha: .1),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppColors.danger.withValues(alpha: .4)),
        ),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Icon(Icons.error_outline, color: AppColors.danger, size: 16),
          const SizedBox(width: 8),
          Expanded(
              child: Text(message,
                  style:
                      const TextStyle(color: AppColors.danger, fontSize: 13))),
        ]),
      );
}
