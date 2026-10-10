// lib/services/account/export/isolated_section_reads.dart

import 'package:butlery/core/utils/logger.dart' as app_logger;

/// Collects one export section whose reads are isolated from each other
/// (BUT-2004, BUT-2008).
///
/// Several reads under one `try` means a refusal on the last one throws away
/// the rows the earlier ones already fetched, and the bundle then says the
/// whole section failed. Here each read gets its own `try`, so a refusal costs
/// only its own key.
///
/// A failed read writes `<key>_error` and `<key>_error_code` and NO value for
/// its key: an empty list beside a failure marker reads as "you have none of
/// these", which is a claim a lookup that did not complete cannot make.
class IsolatedSectionReads {
  IsolatedSectionReads({required this.logTag});

  final String logTag;

  /// The keys the reads produced: per-leg error keys, plus whatever the caller
  /// adds for the legs that succeeded.
  final Map<String, dynamic> section = <String, dynamic>{};

  int _attempted = 0;
  int _failed = 0;

  /// Runs [fetch] in its own `try`. Returns its value, or null when it threw.
  Future<T?> read<T>(String key, Future<T> Function() fetch) async {
    _attempted++;
    try {
      return await fetch();
    } catch (e) {
      _failed++;
      app_logger.AppLogger.error('[$logTag] Failed to export $key', e);
      // A stable sentence, never `e.toString()`: the exception text can carry
      // another user's uid, an index URL and internal paths, and this lands in
      // a bundle the data subject may forward. The exception is logged above.
      section['${key}_error'] = 'Could not export $key.';
      section['${key}_error_code'] = '$key-export-failed';
      return null;
    }
  }

  /// True when at least one read ran and every one of them failed.
  bool get allFailed => _attempted > 0 && _failed == _attempted;

  /// The section-level keys `DataExportService` reads.
  ///
  /// `error_code` alone says the section may be incomplete; `error` says it
  /// could not be exported at all. Setting `error` for one failed read would
  /// tell the data subject that the parts they did receive are missing, and a
  /// "partial" token over a section where every read failed contradicts the
  /// sentence rendered beside it — hence two tokens. Counted rather than
  /// compared to a literal, so a read added later keeps the total-failure
  /// branch reachable.
  Map<String, dynamic> outcome({
    required String partialCode,
    required String failedCode,
    required String failedMessage,
  }) => {
    if (_failed > 0 && !allFailed) 'error_code': partialCode,
    if (allFailed) ...{'error': failedMessage, 'error_code': failedCode},
  };
}
