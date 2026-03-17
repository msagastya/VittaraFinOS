import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:vittara_fin_os/ui/styles/app_styles.dart';
import 'package:vittara_fin_os/ui/styles/design_tokens.dart';

// AU9-06 — Unified AppButton component

enum AppButtonVariant { primary, secondary, destructive, ghost }

class AppButton extends StatelessWidget {
  final String label;
  final VoidCallback? onTap;
  final AppButtonVariant variant;
  final bool isLoading;
  final IconData? icon;

  const AppButton({
    super.key,
    required this.label,
    this.onTap,
    this.variant = AppButtonVariant.primary,
    this.isLoading = false,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    Color bg;
    Color fg;
    switch (variant) {
      case AppButtonVariant.primary:
        bg = AppStyles.aetherTeal;
        fg = Colors.black;
      case AppButtonVariant.secondary:
        bg = AppStyles.getCardColor(context);
        fg = AppStyles.getTextColor(context);
      case AppButtonVariant.destructive:
        bg = AppStyles.plasmaRed;
        fg = Colors.white;
      case AppButtonVariant.ghost:
        bg = Colors.transparent;
        fg = AppStyles.aetherTeal;
    }

    return GestureDetector(
      onTap: isLoading ? null : onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: Spacing.xl,
          vertical: Spacing.md,
        ),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(Radii.md),
          border: variant == AppButtonVariant.ghost
              ? Border.all(color: AppStyles.aetherTeal)
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (isLoading)
              const CupertinoActivityIndicator()
            else ...[
              if (icon != null) ...[
                Icon(icon, color: fg, size: 16),
                const SizedBox(width: 6),
              ],
              Text(
                label,
                style: TextStyle(
                  color: fg,
                  fontWeight: FontWeight.w600,
                  fontSize: TypeScale.body,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
