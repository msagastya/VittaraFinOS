import 'dart:async';

/// A simple async mutual-exclusion lock for Dart.
///
/// Dart is single-threaded, so "concurrency" here means interleaved
/// microtask/event execution around `await` points. This mutex ensures
/// that only one caller executes within [protect] at a time.
class AsyncMutex {
  Completer<void>? _completer;

  Future<void> acquire() async {
    while (_completer != null) {
      await _completer!.future;
    }
    _completer = Completer<void>();
  }

  void release() {
    _completer?.complete();
    _completer = null;
  }

  Future<T> protect<T>(Future<T> Function() fn) async {
    await acquire();
    try {
      return await fn();
    } finally {
      release();
    }
  }
}
