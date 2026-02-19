import 'package:logger/logger.dart';
import 'file_logger.dart';

class AppLogger {
  static final AppLogger _instance = AppLogger._internal();
  late Logger _logger;

  factory AppLogger() {
    return _instance;
  }

  AppLogger._internal() {
    _logger = Logger(
      printer: PrettyPrinter(
        methodCount: 2,
        errorMethodCount: 8,
        lineLength: 120,
        colors: true,
        printEmojis: true,
        dateTimeFormat: DateTimeFormat.onlyTimeAndSinceStart,
      ),
      output: MultiOutput([
        ConsoleOutput(),
        CustomFileOutput(fileName: 'vittara_debug.log'),
      ]),
    );
  }

  String _formatContext(String? context, String message) {
    return context != null ? '[$context] $message' : message;
  }

  void debug(dynamic message,
      {String? context, dynamic error, StackTrace? stackTrace}) {
    _logger.d(_formatContext(context, message.toString()),
        error: error, stackTrace: stackTrace);
  }

  void info(dynamic message,
      {String? context, dynamic error, StackTrace? stackTrace}) {
    _logger.i(_formatContext(context, message.toString()),
        error: error, stackTrace: stackTrace);
  }

  void warning(dynamic message,
      {String? context, dynamic error, StackTrace? stackTrace}) {
    _logger.w(_formatContext(context, message.toString()),
        error: error, stackTrace: stackTrace);
  }

  void error(dynamic message,
      {String? context, dynamic error, StackTrace? stackTrace}) {
    _logger.e(_formatContext(context, message.toString()),
        error: error, stackTrace: stackTrace);
  }

  void verbose(dynamic message,
      {String? context, dynamic error, StackTrace? stackTrace}) {
    _logger.t(_formatContext(context, message.toString()),
        error: error, stackTrace: stackTrace);
  }
}
