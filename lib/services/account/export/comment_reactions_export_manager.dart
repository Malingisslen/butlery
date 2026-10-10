// lib/services/account/export/comment_reactions_export_manager.dart

import 'dart:async';

import 'package:cloud_functions/cloud_functions.dart';
import 'package:butlery/core/utils/logger.dart' as app_logger;

/// BUT-2318: the Art. 15 section for the emoji reactions the requester put on
/// comments.
///
/// The comment read rule refuses the client the per-key `array-contains`
/// query, so the `exportCommentReactions` callable (Admin SDK, europe-west1)
/// finds them server-side and returns only comment ids and keys; this manager
/// only calls it and shapes the section.
class CommentReactionsExportManager {
  static const String _logTag = 'CommentReactionsExportManager';
  static const String callableName = 'exportCommentReactions';

  /// The callable's own decline token, passed through so the bundle names it.
  static const String tooLargeErrorCode = 'comment-reactions-too-large';

  static const String note =
      'These are the emoji reactions you have added to comments, by comment id '
      'and reaction. The comment text is not repeated here, because it may be '
      "another person's.";

  final FirebaseFunctions _functions;

  CommentReactionsExportManager({required FirebaseFunctions functions})
    : _functions = functions;

  /// No uid is sent: the callable takes the requester from `request.auth` only.
  Future<Map<String, dynamic>> exportCommentReactions() async {
    try {
      final result = await _functions
          .httpsCallable(
            callableName,
            options: HttpsCallableOptions(timeout: const Duration(seconds: 60)),
          )
          .call<Map<dynamic, dynamic>>();
      // Cast, not `?? []`: a response missing the key must fail the section,
      // not read as "you reacted to nothing".
      final rows = result.data['reactions'] as List;
      final reactions = [
        for (final row in rows.cast<Map<dynamic, dynamic>>())
          {
            'comment_id': row['commentId'] as String,
            'reaction': row['key'] as String,
          },
      ];
      return {'reactions': reactions, 'total': reactions.length, 'note': note};
    } catch (e, st) {
      // A single gap must not cost the requester the whole bundle.
      final code = _errorCode(e);
      app_logger.AppLogger.error(
        '[$_logTag] Failed to export comment reactions (error_code=$code)',
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
      return 'comment-reactions-${known ? e.code : 'unknown'}';
    }
    if (e is TimeoutException) return 'comment-reactions-timeout';
    return 'comment-reactions-export-failed';
  }
}
