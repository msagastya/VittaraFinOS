import 'package:flutter/cupertino.dart';
import 'package:vittara_fin_os/ui/styles/app_styles.dart';

/// A CupertinoButton that shows a spinner while an async action runs
/// and disables itself to prevent double-submit.
///
/// Usage:
///   LoadingButton(
///     label: 'Save',
///     color: AppStyles.aetherTeal,
///     onPressed: () async { await saveData(); },
///   )
class LoadingButton extends StatefulWidget {
  final String label;
  final Future<void> Function() onPressed;
  final Color? color;
  final Color? textColor;
  final double borderRadius;
  final EdgeInsets? padding;

  const LoadingButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.color,
    this.textColor,
    this.borderRadius = 14,
    this.padding,
  });

  @override
  State<LoadingButton> createState() => _LoadingButtonState();
}

class _LoadingButtonState extends State<LoadingButton> {
  bool _loading = false;

  Future<void> _handlePress() async {
    if (_loading) return;
    setState(() => _loading = true);
    try {
      await widget.onPressed();
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bg = widget.color ?? AppStyles.aetherTeal;
    final fg = widget.textColor ?? CupertinoColors.white;

    return CupertinoButton(
      padding: widget.padding ??
          const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
      color: bg,
      borderRadius: BorderRadius.circular(widget.borderRadius),
      onPressed: _loading ? null : _handlePress,
      child: _loading
          ? SizedBox(
              width: 20,
              height: 20,
              child: CupertinoActivityIndicator(color: fg),
            )
          : Text(
              widget.label,
              style: TextStyle(
                color: fg,
                fontWeight: FontWeight.w600,
                fontSize: 15,
              ),
            ),
    );
  }
}
