import 'package:flutter/material.dart';

import '../theme/easy_vorrat_theme.dart';

class EasyVorratPanel extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final Color? borderColor;

  const EasyVorratPanel({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(14),
    this.borderColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: EasyVorratColors.surface,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: borderColor ?? EasyVorratColors.border,
        ),
      ),
      child: child,
    );
  }
}

class EasyVorratSectionHeader extends StatelessWidget {
  final String title;
  final IconData? icon;

  const EasyVorratSectionHeader({
    super.key,
    required this.title,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 12, 4, 8),
      child: Row(
        children: [
          if (icon != null) ...[
            Icon(
              icon,
              size: 20,
              color: EasyVorratColors.green,
            ),
            const SizedBox(width: 8),
          ],
          Text(
            title,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: EasyVorratColors.green,
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(width: 10),
          const Expanded(
            child: Divider(),
          ),
        ],
      ),
    );
  }
}

enum ExpiryStatus {
  ok,
  warning,
  expired,
}

class ExpiryStatusChip extends StatelessWidget {
  final ExpiryStatus status;
  final String text;

  const ExpiryStatusChip({
    super.key,
    required this.status,
    required this.text,
  });

  Color get color {
    switch (status) {
      case ExpiryStatus.ok:
        return EasyVorratColors.green;
      case ExpiryStatus.warning:
        return EasyVorratColors.warning;
      case ExpiryStatus.expired:
        return EasyVorratColors.danger;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 9,
        vertical: 4,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(
          color: color,
        ),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}
