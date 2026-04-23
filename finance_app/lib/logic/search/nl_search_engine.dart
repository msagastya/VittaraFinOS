import 'package:flutter/foundation.dart';
import 'package:google_mlkit_entity_extraction/google_mlkit_entity_extraction.dart';

/// Hints extracted by ML Kit entity extraction.
/// Used to augment the rule-based parser with entities it can't reach:
/// specific dates ("April 5th"), relative days ("next Tuesday"),
/// and spelled-out amounts ("five hundred rupees").
class NlEntityHints {
  final DateTime? fromDate;
  final DateTime? toDate;
  final double? amountMin;

  const NlEntityHints({this.fromDate, this.toDate, this.amountMin});

  bool get hasAnyHint =>
      fromDate != null || toDate != null || amountMin != null;

  /// Merge into an existing rule-based result — ML Kit fills gaps,
  /// rule-based result wins when both detected the same field.
  NlEntityHints mergeOver(NlEntityHints base) {
    return NlEntityHints(
      fromDate: base.fromDate ?? fromDate,
      toDate: base.toDate ?? toDate,
      amountMin: base.amountMin ?? amountMin,
    );
  }
}

/// On-device ML Kit entity extraction service.
///
/// Runs a second pass on the search query after the synchronous rule-based
/// parser, enriching date and amount signals that regexes miss:
///
///   • Specific dates    — "April 5th", "3rd March 2024"
///   • Relative weekdays — "last Tuesday", "next Monday"
///   • Spelled amounts   — "five hundred rupees", "two thousand"
///
/// Usage (fire-and-forget enhancement pattern):
/// ```dart
/// // 1. Show rule-based results immediately (sync)
/// final parsed = _NLQueryParser.parse(query);
/// _applyResults(parsed);
///
/// // 2. Enhance async — update state if ML Kit finds more
/// NLSearchEngine.instance.extractHints(query).then((hints) {
///   if (hints.hasAnyHint) _applyMlkitHints(hints);
/// });
/// ```
class NLSearchEngine {
  NLSearchEngine._();
  static final NLSearchEngine instance = NLSearchEngine._();

  EntityExtractor? _extractor;

  /// Warm up the ML Kit model on first use.
  /// Safe to call repeatedly — no-ops if already initialised.
  Future<void> warmUp() async {
    if (_extractor != null) return;
    try {
      _extractor = EntityExtractor(language: EntityExtractorLanguage.english);
      // Trigger model download / cache warmup with a short test string
      await _extractor!.annotateText('today');
    } catch (e) {
      debugPrint('[NLSearchEngine] warmUp failed: $e');
      _extractor = null;
    }
  }

  /// Extract date and money hints from [query].
  /// Always resolves — returns empty hints on error or if model unavailable.
  Future<NlEntityHints> extractHints(String query) async {
    if (query.trim().isEmpty) return const NlEntityHints();
    final extractor = _extractor;
    if (extractor == null) return const NlEntityHints();

    try {
      final annotations = await extractor.annotateText(
        query,
        preferredLocale: 'en-IN',
      ).timeout(const Duration(milliseconds: 600));

      DateTime? fromDate;
      DateTime? toDate;
      double? amountMin;

      for (final annotation in annotations) {
        for (final entity in annotation.entities) {
          if (entity is DateTimeEntity) {
            final ms = entity.dateTimeGranularity != DateTimeGranularity.unknown
                ? entity.timestamp
                : null;
            if (ms != null) {
              final dt = DateTime.fromMillisecondsSinceEpoch(ms);
              if (fromDate == null) {
                fromDate = DateTime(dt.year, dt.month, dt.day);
                toDate = DateTime(dt.year, dt.month, dt.day, 23, 59, 59);
              }
            }
          } else if (entity is MoneyEntity) {
            final units = entity.integerPart ?? 0;
            final frac = entity.fractionPart ?? 0;
            final v = units.toDouble() + frac / 100.0;
            if (v > 0 && amountMin == null) amountMin = v;
          }
        }
      }

      return NlEntityHints(
        fromDate: fromDate,
        toDate: toDate,
        amountMin: amountMin,
      );
    } catch (e) {
      debugPrint('[NLSearchEngine] extractHints error: $e');
      return const NlEntityHints();
    }
  }

  void dispose() {
    _extractor?.close();
    _extractor = null;
  }
}
