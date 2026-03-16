import 'dart:convert';
import 'dart:math';
import 'package:crypto/crypto.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Manages offline PIN recovery via a one-time Emergency Recovery Code.
///
/// Flow:
///   1. User sets PIN → call [generateAndStoreRecoveryCode] → show code to user (once).
///   2. User forgets PIN → call [verifyRecoveryCode] → if true, allow PIN reset.
///   3. Rate-limit wrong attempts via [recordFailedAttempt] / [isLockedOut].
class PinRecoveryController {
  PinRecoveryController._();
  static final PinRecoveryController instance = PinRecoveryController._();

  static const _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
    iOptions: IOSOptions(accessibility: KeychainAccessibility.first_unlock),
  );

  static const _keyRecoveryHash = 'vfos_recovery_hash';
  static const _keyFailedAttempts = 'vfos_recovery_failed_attempts';
  static const _keyLockoutUntil = 'vfos_recovery_lockout_until';

  // ── Code generation ─────────────────────────────────────────────────────────

  /// Generates a new recovery code, stores its hash securely, and returns
  /// the human-readable code to be shown ONCE to the user.
  /// Format: VFOS-XXXX-XXXX-XXXX-XXXX  (20 alphanumeric chars + 4 dashes)
  Future<String> generateAndStoreRecoveryCode() async {
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789'; // no O/0/I/1 for clarity
    final rng = Random.secure();
    final raw = List.generate(20, (_) => chars[rng.nextInt(chars.length)]).join();
    final formatted = 'VFOS-${raw.substring(0, 4)}-${raw.substring(4, 8)}-'
        '${raw.substring(8, 12)}-${raw.substring(12, 16)}-${raw.substring(16, 20)}';

    final hash = _hashCode(raw);
    await _storage.write(key: _keyRecoveryHash, value: hash);

    // Reset failed attempts on new code generation
    await _storage.delete(key: _keyFailedAttempts);
    await _storage.delete(key: _keyLockoutUntil);

    return formatted;
  }

  /// Returns true if a recovery code has been stored.
  Future<bool> hasRecoveryCode() async {
    final hash = await _storage.read(key: _keyRecoveryHash);
    return hash != null && hash.isNotEmpty;
  }

  // ── Verification ─────────────────────────────────────────────────────────────

  /// Verifies the user-entered recovery code.
  /// Handles rate limiting. Returns [RecoveryResult].
  Future<RecoveryResult> verifyRecoveryCode(String input) async {
    // Check lockout first
    if (await isLockedOut()) {
      final until = await _lockoutUntil();
      return RecoveryResult.lockedOut(
          until ?? DateTime.now().add(const Duration(minutes: 1)));
    }

    // Normalize input — strip spaces, dashes, uppercase
    final normalized = input.replaceAll(RegExp(r'[\s\-]'), '').toUpperCase();

    final storedHash = await _storage.read(key: _keyRecoveryHash);
    if (storedHash == null) return RecoveryResult.noCodeSet();

    if (_hashCode(normalized) == storedHash) {
      // Success — clear rate limiting, invalidate used code
      await _storage.delete(key: _keyFailedAttempts);
      await _storage.delete(key: _keyLockoutUntil);
      await _storage.delete(key: _keyRecoveryHash); // code is single-use
      return RecoveryResult.success();
    }

    // Wrong code — record failed attempt
    return await _recordFailedAttempt();
  }

  // ── Rate limiting ─────────────────────────────────────────────────────────────

  Future<bool> isLockedOut() async {
    final until = await _lockoutUntil();
    if (until == null) return false;
    return DateTime.now().isBefore(until);
  }

  Future<Duration?> lockoutRemaining() async {
    final until = await _lockoutUntil();
    if (until == null) return null;
    final remaining = until.difference(DateTime.now());
    return remaining.isNegative ? null : remaining;
  }

  Future<int> failedAttempts() async {
    final s = await _storage.read(key: _keyFailedAttempts);
    return int.tryParse(s ?? '0') ?? 0;
  }

  Future<RecoveryResult> _recordFailedAttempt() async {
    final attempts = await failedAttempts() + 1;
    await _storage.write(key: _keyFailedAttempts, value: attempts.toString());

    // Exponential back-off: 1, 2, 5, 15, 60 minutes
    final lockoutMinutes = _lockoutMinutes(attempts);
    if (lockoutMinutes > 0) {
      final until = DateTime.now().add(Duration(minutes: lockoutMinutes));
      await _storage.write(
          key: _keyLockoutUntil, value: until.millisecondsSinceEpoch.toString());
      return RecoveryResult.lockedOut(until);
    }

    return RecoveryResult.wrongCode(attempts: attempts, remainingBeforeLockout: 3 - attempts);
  }

  int _lockoutMinutes(int attempts) {
    if (attempts == 3) return 1;
    if (attempts == 4) return 2;
    if (attempts == 5) return 5;
    if (attempts == 6) return 15;
    if (attempts >= 7) return 60;
    return 0;
  }

  Future<DateTime?> _lockoutUntil() async {
    final s = await _storage.read(key: _keyLockoutUntil);
    if (s == null) return null;
    final ms = int.tryParse(s);
    if (ms == null) return null;
    return DateTime.fromMillisecondsSinceEpoch(ms);
  }

  // ── Helpers ──────────────────────────────────────────────────────────────────

  static String _hashCode(String code) {
    final bytes = utf8.encode('vfos_recovery_salt_v1_$code');
    return sha256.convert(bytes).toString();
  }
}

// ── Result types ──────────────────────────────────────────────────────────────

enum RecoveryResultType { success, wrongCode, lockedOut, noCodeSet }

class RecoveryResult {
  final RecoveryResultType type;
  final int? attempts;
  final int? remainingBeforeLockout;
  final DateTime? lockedUntil;

  const RecoveryResult._({
    required this.type,
    this.attempts,
    this.remainingBeforeLockout,
    this.lockedUntil,
  });

  factory RecoveryResult.success() =>
      const RecoveryResult._(type: RecoveryResultType.success);

  factory RecoveryResult.wrongCode(
          {required int attempts, required int remainingBeforeLockout}) =>
      RecoveryResult._(
        type: RecoveryResultType.wrongCode,
        attempts: attempts,
        remainingBeforeLockout: remainingBeforeLockout,
      );

  factory RecoveryResult.lockedOut(DateTime until) =>
      RecoveryResult._(type: RecoveryResultType.lockedOut, lockedUntil: until);

  factory RecoveryResult.noCodeSet() =>
      const RecoveryResult._(type: RecoveryResultType.noCodeSet);

  bool get isSuccess => type == RecoveryResultType.success;
}
