// lib/services/account/export/shared_residue_export_manager.dart

import 'dart:async';

import 'package:cloud_functions/cloud_functions.dart';
import 'package:butlery/core/utils/logger.dart' as app_logger;
import 'package:butlery/services/account/export/export_pagination_helper.dart'
    show sanitizeForJson;

/// BUT-1747: the Art. 15 section for shared shopping data the client SDK
/// cannot read — shared lists the requester has LEFT, and the
/// `shared_content/{id}/items` rows naming them.
///
/// The read rules refuse both to the requester's own client, so the
/// `exportSharedResidue` callable (Admin SDK, europe-west1) reads and projects
/// them server-side; this manager only calls it and shapes the section.
class SharedResidueExportManager {
  static const String _logTag = 'SharedResidueExportManager';
  static const String callableName = 'exportSharedResidue';

  /// The callable's own decline token, passed through so the bundle names it.
  static const String tooLargeErrorCode = 'shared-residue-too-large';

  /// Byte-invariant (BUT-2056): it states third-party facts, so it is the
  /// same on every export and never varies with what the callable found.
  static const String dataMinimisation =
      'From shared lists you have left, only the items that name you are '
      "included, and the list owner's user ID is kept. On every item in this "
      "section, other people's user IDs and display names are removed.";

  final FirebaseFunctions _functions;

  SharedResidueExportManager({required FirebaseFunctions functions})
    : _functions = functions;

  /// No uid is sent: the callable takes the requester from `request.auth` only.
  Future<Map<String, dynamic>> exportSharedListsLeft() async {
    try {
      final result = await _functions
          .httpsCallable(
            callableName,
            options: HttpsCallableOptions(
              timeout: const Duration(seconds: 120),
            ),
          )
          .call<Map<dynamic, dynamic>>();
      final data = result.data;
      // Cast, not `?? []`: a response missing a key must fail the section, not
      // read as "you left nothing".
      return {
        'shared_lists_left': sanitizeForJson(data['shared_lists_left'] as List),
        'shared_content_items': sanitizeForJson(
          data['shared_content_items'] as List,
        ),
        'known_gaps': sanitizeForJson(data['known_gaps'] as List),
        'data_minimisation': dataMinimisation,
      };
    } catch (e, st) {
      // Unlike `ComplianceExportManager.exportAuditLogs`, no error here aborts
      // the bundle: a single gap must not cost the requester the whole bundle.
      final code = _errorCode(e);
      app_logger.AppLogger.error(
        '[$_logTag] Failed to export shared lists left (error_code=$code)',
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
      return 'shared-lists-left-${known ? e.code : 'unknown'}';
    }
    if (e is TimeoutException) return 'shared-lists-left-timeout';
    return 'shared-lists-left-export-failed';
  }
}
