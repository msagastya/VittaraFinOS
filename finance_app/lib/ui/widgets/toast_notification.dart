import 'dart:async';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:vittara_fin_os/ui/styles/app_styles.dart';
import 'package:vittara_fin_os/ui/styles/design_tokens.dart';
import 'package:vittara_fin_os/ui/widgets/animations.dart';

// ============================================================
// TOAST NOTIFICATION SYSTEM - VittaraFinOS
// ============================================================
// Modern, non-intrusive toast notifications that slide in
// from the bottom and auto-dismiss.
// ============================================================

/// Toast types for different feedback scenarios
enum ToastType { success, error, warning, info }

/// Toast notification data model
class ToastData {
  final String message;
  final ToastType type;
  final String? actionLabel;
  final VoidCallback? onAction;
  final Duration duration;
  final IconData? icon;

  const ToastData({
    required this.message,
    this.type = ToastType.info,
    this.actionLabel,
    this.onAction,
    this.duration = const Duration(seconds: 3),
    this.icon,
  });
}

/// Global toast controller for showing toasts from anywhere
class ToastController {
  static final ToastController _instance = ToastController._internal();
  factory ToastController() => _instance;
  ToastController._internal();

  final _toastStreamController = StreamController<ToastData?>.broadcast();
  Stream<ToastData?> get toastStream => _toastStreamController.stream;

  void show(ToastData toast) {
    _toastStreamController.add(toast);
  }

  void showSuccess(String message,
      {String? actionLabel, VoidCallback? onAction}) {
    show(ToastData(
      message: message,
      type: ToastType.success,
      actionLabel: actionLabel,
      onAction: onAction,
    ));
  }

  void showError(String message,
      {String? actionLabel, VoidCallback? onAction}) {
    show(ToastData(
      message: message,
      type: ToastType.error,
      actionLabel: actionLabel,
      onAction: onAction,
      duration: const Duration(seconds: 4),
    ));
  }

  void showWarning(String message,
      {String? actionLabel, VoidCallback? onAction}) {
    show(ToastData(
      message: message,
      type: ToastType.warning,
      actionLabel: actionLabel,
      onAction: onAction,
    ));
  }

  void showInfo(String message, {String? actionLabel, VoidCallback? onAction}) {
    show(ToastData(
      message: message,
      type: ToastType.info,
      actionLabel: actionLabel,
      onAction: onAction,
    ));
  }

  void dismiss() {
    _toastStreamController.add(null);
  }

  void dispose() {
    _toastStreamController.close();
  }
}

/// Global toast instance for easy access
final toast = ToastController();

/// Toast overlay widget - wrap your app with this
class ToastOverlay extends StatefulWidget {
  final Widget child;

  const ToastOverlay({super.key, required this.child});

  @override
  State<ToastOverlay> createState() => _ToastOverlayState();
}

class _ToastOverlayState extends State<ToastOverlay> {
  ToastData? _currentToast;
  Timer? _dismissTimer;
  StreamSubscription<ToastData?>? _subscription;

  @override
  void initState() {
    super.initState();
    _subscription = toast.toastStream.listen(_onToastReceived);
  }

  void _onToastReceived(ToastData? toastData) {
    _dismissTimer?.cancel();

    setState(() {
      _currentToast = toastData;
    });

    if (toastData != null) {
      _dismissTimer = Timer(toastData.duration, () {
        if (mounted) {
          setState(() {
            _currentToast = null;
          });
        }
      });
    }
  }

  @override
  void dispose() {
    _dismissTimer?.cancel();
    _subscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        widget.child,
        if (_currentToast != null)
          Positioned(
            left: Spacing.lg,
            right: Spacing.lg,
            bottom: MediaQuery.of(context).padding.bottom + Spacing.xxl,
            child: _ToastWidget(
              data: _currentToast!,
              onDismiss: () {
                _dismissTimer?.cancel();
                setState(() {
                  _currentToast = null;
                });
              },
            ),
          ),
      ],
    );
  }
}

/// Individual toast widget
class _ToastWidget extends StatefulWidget {
  final ToastData data;
  final VoidCallback onDismiss;

  const _ToastWidget({required this.data, required this.onDismiss});

  @override
  State<_ToastWidget> createState() => _ToastWidgetState();
}

class _ToastWidgetState extends State<_ToastWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: AppDurations.toast,
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 1),
      end: Offset.zero,
    ).animate(
        CurvedAnimation(parent: _controller, curve: MotionCurves.standard));

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
        CurvedAnimation(parent: _controller, curve: MotionCurves.standard));

    _controller.forward();

    // Haptic feedback based on type
    switch (widget.data.type) {
      case ToastType.success:
        Haptics.success();
        break;
      case ToastType.error:
        Haptics.error();
        break;
      case ToastType.warning:
        Haptics.warning();
        break;
      case ToastType.info:
        Haptics.light();
        break;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Color _getBackgroundColor(BuildContext context) {
    final isDark = AppStyles.isDarkMode(context);
    switch (widget.data.type) {
      case ToastType.success:
        return isDark
            ? SemanticColors.successDark.withValues(alpha: 0.95)
            : SemanticColors.success;
      case ToastType.error:
        return isDark
            ? SemanticColors.errorDark.withValues(alpha: 0.95)
            : SemanticColors.error;
      case ToastType.warning:
        return isDark
            ? SemanticColors.warningDark.withValues(alpha: 0.95)
            : SemanticColors.warning;
      case ToastType.info:
        return isDark
            ? AppStyles.getCardColor(context)
            : AppStyles.getCardColor(context);
    }
  }

  Color _getTextColor(BuildContext context) {
    switch (widget.data.type) {
      case ToastType.success:
      case ToastType.error:
      case ToastType.warning:
        return Colors.white;
      case ToastType.info:
        return AppStyles.getTextColor(context);
    }
  }

  IconData _getIcon() {
    if (widget.data.icon != null) return widget.data.icon!;
    switch (widget.data.type) {
      case ToastType.success:
        return CupertinoIcons.checkmark_circle_fill;
      case ToastType.error:
        return CupertinoIcons.xmark_circle_fill;
      case ToastType.warning:
        return CupertinoIcons.exclamationmark_triangle_fill;
      case ToastType.info:
        return CupertinoIcons.info_circle_fill;
    }
  }

  @override
  Widget build(BuildContext context) {
    final backgroundColor = _getBackgroundColor(context);
    final textColor = _getTextColor(context);
    final icon = _getIcon();

    return SlideTransition(
      position: _slideAnimation,
      child: FadeTransition(
        opacity: _fadeAnimation,
        child: GestureDetector(
          onTap: widget.onDismiss,
          onHorizontalDragEnd: (details) {
            if (details.primaryVelocity != null &&
                details.primaryVelocity!.abs() > 100) {
              widget.onDismiss();
            }
          },
          child: Container(
            padding: const EdgeInsets.symmetric(
              horizontal: Spacing.lg,
              vertical: Spacing.md,
            ),
            decoration: BoxDecoration(
              color: backgroundColor,
              borderRadius: Radii.buttonRadius,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.2),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              children: [
                Icon(icon, color: textColor, size: IconSizes.md),
                const SizedBox(width: Spacing.md),
                Expanded(
                  child: Text(
                    widget.data.message,
                    style: TextStyle(
                      color: textColor,
                      fontSize: TypeScale.body,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                if (widget.data.actionLabel != null &&
                    widget.data.onAction != null) ...[
                  const SizedBox(width: Spacing.md),
                  GestureDetector(
                    onTap: () {
                      widget.data.onAction!();
                      widget.onDismiss();
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: Spacing.md,
                        vertical: Spacing.xs,
                      ),
                      decoration: BoxDecoration(
                        color: textColor.withValues(alpha: 0.2),
                        borderRadius: Radii.chipRadius,
                      ),
                      child: Text(
                        widget.data.actionLabel!,
                        style: TextStyle(
                          color: textColor,
                          fontSize: TypeScale.footnote,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ============================================================
// CONTEXT EXTENSION FOR EASY TOAST ACCESS
// ============================================================

extension ToastExtension on BuildContext {
  void showSuccessToast(String message,
      {String? actionLabel, VoidCallback? onAction}) {
    toast.showSuccess(message, actionLabel: actionLabel, onAction: onAction);
  }

  void showErrorToast(String message,
      {String? actionLabel, VoidCallback? onAction}) {
    toast.showError(message, actionLabel: actionLabel, onAction: onAction);
  }

  void showWarningToast(String message,
      {String? actionLabel, VoidCallback? onAction}) {
    toast.showWarning(message, actionLabel: actionLabel, onAction: onAction);
  }

  void showInfoToast(String message,
      {String? actionLabel, VoidCallback? onAction}) {
    toast.showInfo(message, actionLabel: actionLabel, onAction: onAction);
  }
}
