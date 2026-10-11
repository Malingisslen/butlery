// lib/services/account/export/moderation_appeals_export_manager.dart

import 'dart:async';

import 'package:cloud_functions/cloud_functions.dart';
import 'package:butlery/core/utils/logger.dart' as app_logger;

/// BUT-2353: the Art. 15 section for the appeals the requester wrote about a
/// moderation decision.
///
/// Appeals are server-only records that carry no uid, so the
/// `exportModerationAppeals` callable (Admin SDK, europe-west1) resolves them
/// from the requester's reports; this manager only calls it and shapes the
/// section.
class ModerationAppealsExportManager {
  static const String _logTag = 'ModerationAppealsExportManager';
  static const String callableName = 'exportModerationAppeals';

  /// The callable's own decline token, passed through so the bundle names it.
  static const String tooLargeErrorCode = 'moderation-appeals-too-large';

  static const String note =
      'These are the appeals you have sent about a decision on a report, with '
      'the text you wrote. The content the decision concerned is not repeated '
      "here, because it may be another person's.";

  final FirebaseFunctions _functions;

  ModerationAppealsExportManager({required FirebaseFunctions functions})
    : _functions = functions;

  /// No uid is sent: the callable takes the requester from `request.auth` only.
  Future<Map<String, dynamic>> exportModerationAppeals() async {
    try {
      final result = await _functions
          .httpsCallable(
            callableName,
            options: HttpsCallableOptions(timeout: const Duration(seconds: 60)),
          )
          .call<Map<dynamic, dynamic>>();
      // Cast, not `?? []`: a response missing the key must fail the section,
      // not read as "you appealed nothing".
      final rows = result.data['appeals'] as List;
      final appeals = [
        for (final row in rows.cast<Map<dynamic, dynamic>>())
          {
            'role': row['role'] as String,
            'text': row['text'] as String,
            'created_at': row['createdAt'] as String?,
            'status': row['status'] as String?,
            'answered_at': row['answeredAt'] as String?,
          },
      ];
      return {'appeals': appeals, 'total': appeals.length, 'note': note};
    } catch (e, st) {
      // A single gap must not cost the requester the whole bundle.
      final code = _errorCode(e);
      app_logger.AppLogger.error(
        '[$_logTag] Failed to export moderation appeals (error_code=$code)',
        e,
        _logTag,
        st,
      );
      return {
        'error': 'This section could not be exported.',
        'error_code': code,
      };
    }
  }

  /// A stable token, never the exception text, which the bundle root would
  /// otherwise carry to whoever the requester forwards it to.
  static String _errorCode(Object e) {
    if (e is FirebaseFunctionsException) {
      final details = e.details;
      if (details is Map && details['error_code'] == tooLargeErrorCode) {
        return tooLargeErrorCode;
      }
      final known = RegExp(r'^[a-z-]+$').hasMatch(e.code);
      return 'moderation-appeals-${known ? e.code : 'unknown'}';
    }
    if (e is TimeoutException) return 'moderation-appeals-timeout';
    return 'moderation-appeals-export-failed';
  }
}
