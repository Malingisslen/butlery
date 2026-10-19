// lib/services/account/export/erasure_residue_export_manager.dart

import 'dart:async';

import 'package:cloud_functions/cloud_functions.dart';
import 'package:butlery/core/utils/logger.dart' as app_logger;
import 'package:butlery/services/account/export/export_pagination_helper.dart'
    show sanitizeForJson;

/// BUT-2414: the Art. 15 section for rows account deletion erases —
/// allergen corrections, the user's own shares, messages in chats they left,
/// analytics rows and more.
///
/// The `exportErasureResidue` callable (Admin SDK, europe-west1) reads each one
/// with the predicate its erasure step uses and projects it server-side; this
/// manager only calls it and shapes the section. Each named section inside
/// carries its own `error_code` when it fails, so one gap does not hide the
/// rest.
class ErasureResidueExportManager {
  static const String _logTag = 'ErasureResidueExportManager';
  static const String callableName = 'exportErasureResidue';
  static const String partialErrorCode = 'erasure-residue-partial';

  final FirebaseFunctions _functions;

  ErasureResidueExportManager({required FirebaseFunctions functions})
    : _functions = functions;

  /// No uid is sent: the callable takes the requester from `request.auth` only.
  Future<Map<String, dynamic>> exportErasureResidue() async {
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
      // Cast, not `?? {}`: a response missing a key must fail the section, not
      // read as "nothing was found".
      final sections = data['sections'] as Map;
      // A root `error_code` without `error` is what DataExportService reports
      // as a partial section; a failure inside `sections` alone it cannot see.
      final partial = sections.values.any(
        (s) => s is Map && s['error_code'] != null,
      );
      return {
        'sections': sanitizeForJson(sections),
        'known_gaps': sanitizeForJson(data['known_gaps'] as List),
        if (partial) 'error_code': partialErrorCode,
      };
    } catch (e, st) {
      final code = _errorCode(e);
      app_logger.AppLogger.error(
        '[$_logTag] Failed to export erasure residue (error_code=$code)',
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
      final known = RegExp(r'^[a-z-]+$').hasMatch(e.code);
      return 'erasure-residue-${known ? e.code : 'unknown'}';
    }
    if (e is TimeoutException) return 'erasure-residue-timeout';
    return 'erasure-residue-export-failed';
  }
}
