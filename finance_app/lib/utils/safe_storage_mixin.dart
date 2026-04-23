import 'package:flutter/foundation.dart';
import 'package:vittara_fin_os/ui/widgets/toast_notification.dart';

/// Mixin that wraps any async write operation with error capture and
/// user-visible toast feedback. Applied to all data controllers.
///
/// Usage:
///   class MyController with ChangeNotifier, SafeStorageMixin { ... }
///
///   Future<void> save() => safeWrite('save items', () async {
///     await DatabaseService.instance.upsertDataRow(...);
///   });
mixin SafeStorageMixin on ChangeNotifier {
  String? _lastSaveError;

  /// The most recent save error message, or null if the last save succeeded.
  String? get lastSaveError => _lastSaveError;

  /// Executes [fn] and surfaces any exception as a toast + debug log.
  /// Returns true if the write succeeded, false otherwise.
  Future<bool> safeWrite(
    String operationName,
    Future<void> Function() fn,
  ) async {
    try {
      await fn();
      _lastSaveError = null;
      return true;
    } catch (e, stack) {
      _lastSaveError = e.toString();
      debugPrint('[SafeWrite] $operationName failed: $e\n$stack');
      ToastController().showError('Save failed — please try again');
      return false;
    }
  }
}
