/// Maps low-level exceptions to user-friendly, actionable messages.
///
/// Use this class in catch blocks before showing error toasts or dialogs
/// so that users never see raw stack traces or technical error strings.
class UserErrorMapper {
  UserErrorMapper._();

  /// Returns a user-friendly string for [error].
  static String map(Object error) {
    final message = error.toString();

    if (error is FormatException) {
      return 'Invalid data format. Please check your input.';
    }

    if (message.contains('UNIQUE constraint')) {
      return 'This entry already exists.';
    }

    if (message.contains('no such table')) {
      return 'Data not found. Try restarting the app.';
    }

    if (message.contains('SocketException') ||
        message.contains('NetworkException') ||
        message.contains('Connection refused')) {
      return 'No internet connection.';
    }

    if (message.contains('TimeoutException') ||
        message.contains('timed out')) {
      return 'Request timed out. Please try again.';
    }

    if (message.contains('permission') || message.contains('Permission')) {
      return 'Permission denied. Please check app permissions in Settings.';
    }

    if (message.contains('disk') ||
        message.contains('storage') ||
        message.contains('SQLITE_FULL')) {
      return 'Not enough storage space. Free up space and try again.';
    }

    return 'Something went wrong. Please try again.';
  }
}
