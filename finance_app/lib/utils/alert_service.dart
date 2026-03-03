import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:vittara_fin_os/ui/styles/design_tokens.dart';

/// Alert types
enum AlertType {
  success,
  error,
  warning,
  info,
}

/// Alert service for showing notifications and dialogs
class AlertService {
  AlertService._();

  /// Show a toast-style notification
  static void showToast(
    BuildContext context, {
    required String message,
    required AlertType type,
    Duration duration = const Duration(seconds: 3),
    String? actionLabel,
    VoidCallback? onAction,
  }) {
    final overlay = Overlay.of(context);
    late OverlayEntry overlayEntry;

    overlayEntry = OverlayEntry(
      builder: (context) => _ToastNotification(
        message: message,
        type: type,
        duration: duration,
        actionLabel: actionLabel,
        onAction: onAction,
        onDismiss: () => overlayEntry.remove(),
      ),
    );

    overlay.insert(overlayEntry);

    // Auto-dismiss after duration
    Future.delayed(duration, () {
      if (overlayEntry.mounted) {
        overlayEntry.remove();
      }
    });
  }

  /// Show success toast
  static void showSuccess(
    BuildContext context,
    String message, {
    Duration duration = const Duration(seconds: 3),
  }) {
    showToast(
      context,
      message: message,
      type: AlertType.success,
      duration: duration,
    );
  }

  /// Show error toast
  static void showError(
    BuildContext context,
    String message, {
    Duration duration = const Duration(seconds: 4),
    String? actionLabel,
    VoidCallback? onAction,
  }) {
    showToast(
      context,
      message: message,
      type: AlertType.error,
      duration: duration,
      actionLabel: actionLabel,
      onAction: onAction,
    );
  }

  /// Show warning toast
  static void showWarning(
    BuildContext context,
    String message, {
    Duration duration = const Duration(seconds: 3),
  }) {
    showToast(
      context,
      message: message,
      type: AlertType.warning,
      duration: duration,
    );
  }

  /// Show info toast
  static void showInfo(
    BuildContext context,
    String message, {
    Duration duration = const Duration(seconds: 3),
  }) {
    showToast(
      context,
      message: message,
      type: AlertType.info,
      duration: duration,
    );
  }

  /// Show confirmation dialog
  static Future<bool> showConfirmDialog(
    BuildContext context, {
    required String title,
    required String message,
    String confirmText = 'Confirm',
    String cancelText = 'Cancel',
    bool isDestructive = false,
  }) async {
    final result = await showCupertinoDialog<bool>(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(cancelText),
          ),
          CupertinoDialogAction(
            isDestructiveAction: isDestructive,
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(confirmText),
          ),
        ],
      ),
    );

    return result ?? false;
  }

  /// Show error dialog for critical failures
  static Future<void> showErrorDialog(
    BuildContext context, {
    required String title,
    required String message,
    String? details,
    String buttonText = 'OK',
  }) async {
    await showCupertinoDialog(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: Text(title),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(message),
            if (details != null) ...[
              const SizedBox(height: 12),
              Text(
                details,
                style: const TextStyle(
                  fontSize: TypeScale.footnote,
                  color: CupertinoColors.systemGrey,
                ),
              ),
            ],
          ],
        ),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(buttonText),
          ),
        ],
      ),
    );
  }

  /// Show loading overlay
  static void showLoading(
    BuildContext context, {
    String message = 'Loading...',
  }) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => PopScope(
        canPop: false,
        child: Center(
          child: Container(
            padding: EdgeInsets.all(Spacing.xxl),
            decoration: BoxDecoration(
              color: Theme.of(context).brightness == Brightness.dark
                  ? const Color(0xFF2C2C2E)
                  : Colors.white,
              borderRadius: BorderRadius.circular(Radii.lg),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const CupertinoActivityIndicator(radius: 20),
                SizedBox(height: Spacing.lg),
                Text(
                  message,
                  style: const TextStyle(fontSize: TypeScale.headline),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Hide loading overlay
  static void hideLoading(BuildContext context) {
    Navigator.of(context, rootNavigator: true).pop();
  }

  /// Show bottom sheet alert
  static Future<T?> showBottomSheetAlert<T>({
    required BuildContext context,
    required String title,
    required String message,
    List<AlertAction<T>>? actions,
  }) async {
    return await showCupertinoModalPopup<T>(
      context: context,
      builder: (context) => CupertinoActionSheet(
        title: Text(title),
        message: Text(message),
        actions: actions?.map((action) {
          return CupertinoActionSheetAction(
            onPressed: () => Navigator.of(context).pop(action.value),
            isDestructiveAction: action.isDestructive,
            child: Text(action.label),
          );
        }).toList(),
        cancelButton: CupertinoActionSheetAction(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
      ),
    );
  }

  /// Log error for debugging (can be extended to crash reporting)
  static void logError(
    String error, {
    String? context,
    StackTrace? stackTrace,
    Map<String, dynamic>? metadata,
  }) {
    debugPrint('🔴 ERROR${context != null ? " [$context]" : ""}: $error');
    if (stackTrace != null) {
      debugPrint('Stack trace: $stackTrace');
    }
    if (metadata != null) {
      debugPrint('Metadata: $metadata');
    }

    // TODO: Send to crash reporting service (Firebase Crashlytics, Sentry, etc.)
  }

  /// Log warning
  static void logWarning(String warning, {String? context}) {
    debugPrint('⚠️ WARNING${context != null ? " [$context]" : ""}: $warning');
  }

  /// Log info
  static void logInfo(String info, {String? context}) {
    debugPrint('ℹ️ INFO${context != null ? " [$context]" : ""}: $info');
  }

  /// Handle API error and show user-friendly message
  static void handleApiError(
    BuildContext context,
    dynamic error, {
    String? customMessage,
  }) {
    String message = customMessage ?? 'An error occurred. Please try again.';

    // Parse common error types
    if (error is String) {
      message = error;
    } else if (error.toString().contains('SocketException')) {
      message = 'No internet connection. Please check your network.';
    } else if (error.toString().contains('TimeoutException')) {
      message = 'Request timed out. Please try again.';
    } else if (error.toString().contains('FormatException')) {
      message = 'Invalid data received. Please try again.';
    }

    showError(context, message);
    logError(error.toString(), context: 'API Error');
  }

  /// Handle database error
  static void handleDatabaseError(
    BuildContext context,
    dynamic error, {
    String? operation,
  }) {
    final message =
        'Failed to ${operation ?? "perform operation"}. Please try again.';
    showError(context, message);
    logError(error.toString(),
        context: 'Database Error', metadata: {'operation': operation});
  }

  /// Show retry dialog
  static Future<bool> showRetryDialog(
    BuildContext context, {
    required String title,
    required String message,
  }) async {
    return await showConfirmDialog(
      context,
      title: title,
      message: message,
      confirmText: 'Retry',
      cancelText: 'Cancel',
    );
  }
}

/// Alert action for bottom sheets
class AlertAction<T> {
  final String label;
  final T value;
  final bool isDestructive;

  AlertAction({
    required this.label,
    required this.value,
    this.isDestructive = false,
  });
}

/// Toast notification widget
class _ToastNotification extends StatefulWidget {
  final String message;
  final AlertType type;
  final Duration duration;
  final String? actionLabel;
  final VoidCallback? onAction;
  final VoidCallback onDismiss;

  const _ToastNotification({
    required this.message,
    required this.type,
    required this.duration,
    this.actionLabel,
    this.onAction,
    required this.onDismiss,
  });

  @override
  State<_ToastNotification> createState() => _ToastNotificationState();
}

class _ToastNotificationState extends State<_ToastNotification>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: AppDurations.normal,
      vsync: this,
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, -1),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutCubic,
    ));

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOut,
    ));

    _controller.forward();

    // Schedule dismiss animation
    Future.delayed(
      widget.duration - AppDurations.normal,
      () {
        if (mounted) {
          _controller.reverse().then((_) => widget.onDismiss());
        }
      },
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Color _getBackgroundColor(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    switch (widget.type) {
      case AlertType.success:
        return SemanticColors.success;
      case AlertType.error:
        return SemanticColors.error;
      case AlertType.warning:
        return SemanticColors.warning;
      case AlertType.info:
        return SemanticColors.info;
    }
  }

  IconData _getIcon() {
    switch (widget.type) {
      case AlertType.success:
        return CupertinoIcons.checkmark_circle_fill;
      case AlertType.error:
        return CupertinoIcons.xmark_circle_fill;
      case AlertType.warning:
        return CupertinoIcons.exclamationmark_triangle_fill;
      case AlertType.info:
        return CupertinoIcons.info_circle_fill;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: MediaQuery.of(context).padding.top + 16,
      left: 16,
      right: 16,
      child: SlideTransition(
        position: _slideAnimation,
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: Material(
            color: Colors.transparent,
            child: Container(
              padding: EdgeInsets.all(Spacing.lg),
              decoration: BoxDecoration(
                color: _getBackgroundColor(context),
                borderRadius: BorderRadius.circular(Radii.lg),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.2),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Icon(
                    _getIcon(),
                    color: Colors.white,
                    size: IconSizes.lg,
                  ),
                  SizedBox(width: Spacing.md),
                  Expanded(
                    child: Text(
                      widget.message,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: TypeScale.callout,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  if (widget.actionLabel != null) ...[
                    SizedBox(width: Spacing.md),
                    GestureDetector(
                      onTap: () {
                        widget.onAction?.call();
                        _controller.reverse().then((_) => widget.onDismiss());
                      },
                      child: Text(
                        widget.actionLabel!,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: TypeScale.callout,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                  SizedBox(width: Spacing.sm),
                  GestureDetector(
                    onTap: () {
                      _controller.reverse().then((_) => widget.onDismiss());
                    },
                    child: const Icon(
                      CupertinoIcons.xmark,
                      color: Colors.white,
                      size: 18,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Extension on BuildContext for easy alert access
extension AlertServiceExtension on BuildContext {
  /// Show success message
  void showSuccess(String message) {
    AlertService.showSuccess(this, message);
  }

  /// Show error message
  void showError(String message,
      {String? actionLabel, VoidCallback? onAction}) {
    AlertService.showError(
      this,
      message,
      actionLabel: actionLabel,
      onAction: onAction,
    );
  }

  /// Show warning message
  void showWarning(String message) {
    AlertService.showWarning(this, message);
  }

  /// Show info message
  void showInfo(String message) {
    AlertService.showInfo(this, message);
  }

  /// Show confirmation dialog
  Future<bool> confirm({
    required String title,
    required String message,
    String confirmText = 'Confirm',
    String cancelText = 'Cancel',
    bool isDestructive = false,
  }) {
    return AlertService.showConfirmDialog(
      this,
      title: title,
      message: message,
      confirmText: confirmText,
      cancelText: cancelText,
      isDestructive: isDestructive,
    );
  }

  /// Show loading
  void showLoading({String message = 'Loading...'}) {
    AlertService.showLoading(this, message: message);
  }

  /// Hide loading
  void hideLoading() {
    AlertService.hideLoading(this);
  }
}
