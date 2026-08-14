// lib/services/account/export/chat_group_export.dart

import 'package:butlery/core/utils/logger.dart' as app_logger;
import 'package:butlery/repositories/firebase/firebase_data_export_repository.dart';
import 'package:butlery/services/account/export/export_pagination_helper.dart'
    show sanitizeForJson;

/// BUT-1838: the Article-15 leg for chat groups.
///
/// The conversations section already carries a group's NAME (as the
/// conversation `title`), its membership (`participantIds`) and the requester's
/// own join stamp. This leg exists for the one fact that lives nowhere else and
/// is genuinely about the requester: **who added them to the group**.
///
/// It exports a PROJECTION, never the document. Dumping `chat_groups` would
/// re-export three uid-keyed maps that duplicate what `conversation_info`
/// already holds — and a second copy of a redaction decision is precisely how
/// two sections drift apart (BUT-1772/BUT-1798). Other members'
/// `memberAddedBy` entries stay out: who invited somebody else is third-party
/// behaviour.
///
/// Split out of [SocialExportManager] purely to keep that facade under the
/// 500-line limit, in the same shape as [SharedShoppingListExport].
class ChatGroupExport {
  final FirebaseDataExportRepository _exports;

  static const String _logTag = 'ChatGroupExport';

  const ChatGroupExport(this._exports);

  /// Returns the section payload, or a `{error_code: …}` marker.
  ///
  /// A failure here must never take the messages section with it: the
  /// conversations and their messages are the larger Art. 15 obligation, and
  /// this leg is an addition to them.
  Future<Map<String, dynamic>> export(String userId) async {
    try {
      final groups = await _exports.exportChatGroups(userId);
      return <String, dynamic>{
        // sanitizeForJson is NOT optional, and the failure it prevents is not
        // local: a raw Firestore `Timestamp` reaching the bundle throws out of
        // `jsonEncode` for the ENTIRE export, so a user who belongs to one chat
        // group would get no file at all rather than a degraded section. The
        // encode happens after every section is gathered, so no try/catch in
        // here can save it. Same warning as `shared_shopping_list_export.dart`
        // and `content_export_manager.dart`.
        'chat_groups': groups
            .map((g) => sanitizeForJson(g) as Map<String, dynamic>)
            .toList(),
      };
    } catch (e) {
      app_logger.AppLogger.error('[$_logTag] Failed to export chat groups', e);
      // `error_code` at section level, not a bespoke boolean: that is the key
      // `DataExportService` lifts into the bundle's own completeness summary,
      // so a flag it does not recognise is a failure the bundle claims did not
      // happen.
      return <String, dynamic>{
        'chat_groups': const <Map<String, dynamic>>[],
        'error_code': 'chat-groups-export-failed',
      };
    }
  }
}
