// lib/services/account/export/comment_reactions_export_manager.dart

import 'dart:async';

import 'package:cloud_functions/cloud_functions.dart';
import 'package:butlery/core/utils/logger.dart' as app_logger;

/// BUT-2318: the Art. 15 section for the emoji reactions the requester put on
/// comments, and (BUT-2398) the one for their reactions on chat messages.
///
/// The read rules refuse the client the per-key `array-contains` query, so
/// the `exportCommentReactions` callable (Admin SDK, europe-west1) finds them
/// server-side and returns only comment or message ids and keys; this manager
/// calls it once and shapes both sections.
class CommentReactionsExportManager {
  static const String _logTag = 'CommentReactionsExportManager';
  static const String callableName = 'exportCommentReactions';

  /// The callable's own decline tokens, passed through so the bundle names
  /// them.
  static const String tooLargeErrorCode = 'comment-reactions-too-large';
  static const String messagesTooLargeErrorCode = 'message-reactions-too-large';

  static const String note =
      'These are the emoji reactions you have added to comments, by comment id '
      'and reaction. The comment text is not repeated here, because it may be '
      "another person's.";

  static const String messageNote =
      'These are the emoji reactions you have added to chat messages, by '
      'message id and reaction. The message text is not repeated here, because '
      "it may be another person's.";

  final FirebaseFunctions _functions;

  CommentReactionsExportManager({required FirebaseFunctions functions})
    : _functions = functions;

  /// Both sections from one call, so the callable's rate limit is spent once
  /// per bundle. No uid is sent: the callable takes the requester from
  /// `request.auth` only.
  Future<({Map<String, dynamic> comments, Map<String, dynamic> messages})>
  exportReactions() async {
    final Map<dynamic, dynamic> data;
    try {
      final result = await _functions
          .httpsCallable(
            callableName,
            options: HttpsCallableOptions(timeout: const Duration(seconds: 60)),
          )
          .call<Map<dynamic, dynamic>>();
      data = result.data;
    } catch (e, st) {
      return (
        comments: _failed('comment-reactions', e, st),
        messages: _failed('message-reactions', e, st),
      );
    }
    return (
      comments: _section(
        'comment-reactions',
        data['reactions'],
        'commentId',
        'comment_id',
        note,
      ),
      messages: _section(
        'message-reactions',
        data['messageReactions'],
        'messageId',
        'message_id',
        messageNote,
      ),
    );
  }

  static Map<String, dynamic> _section(
    String prefix,
    Object? raw,
    String idKey,
    String idLabel,
    String sectionNote,
  ) {
    try {
      // Cast, not `?? []`: a response missing the key must fail the section,
      // not read as "you reacted to nothing".
      final reactions = [
        for (final row in (raw as List).cast<Map<dynamic, dynamic>>())
          {idLabel: row[idKey] as String, 'reaction': row['key'] as String},
      ];
      return {
        'reactions': reactions,
        'total': reactions.length,
        'note': sectionNote,
      };
    } catch (e, st) {
      return _failed(prefix, e, st);
    }
  }

  // A single gap must not cost the requester the whole bundle.
  static Map<String, dynamic> _failed(String prefix, Object e, StackTrace st) {
    final code = _errorCode(prefix, e);
    app_logger.AppLogger.error(
      '[$_logTag] Failed to export $prefix (error_code=$code)',
      e,
      _logTag,
      st,
    );
    return {'error': 'This section could not be exported.', 'error_code': code};
  }

  /// A stable token, never the exception text, which the bundle root would
  /// otherwise carry to whoever the requester forwards it to.
  static String _errorCode(String prefix, Object e) {
    if (e is FirebaseFunctionsException) {
      final details = e.details;
      if (details is Map) {
        final declined = details['error_code'];
        if (declined == tooLargeErrorCode ||
            declined == messagesTooLargeErrorCode) {
          return declined as String;
        }
      }
      final known = RegExp(r'^[a-z-]+$').hasMatch(e.code);
      return '$prefix-${known ? e.code : 'unknown'}';
    }
    if (e is TimeoutException) return '$prefix-timeout';
    return '$prefix-export-failed';
  }
}
