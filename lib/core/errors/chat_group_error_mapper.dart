// lib/core/errors/chat_group_error_mapper.dart

import 'package:cloud_functions/cloud_functions.dart';
import 'package:butlery/core/l10n/app_locale.dart';
import 'package:butlery/core/utils/logger.dart';

/// Maps a `ChatGroupRepository` callable's failure to a Swedish message,
/// shared by every ViewModel that calls one (BUT-1838).
///
/// One place so the callables' error shapes — the minor-membership gate's
/// `blockedUserIds`, the rate limiter's `resource-exhausted`, the member cap's
/// `invalid-argument` — are read identically everywhere they're caught,
/// instead of drifting between the flows that catch them.
class ChatGroupErrorMapper {
  ChatGroupErrorMapper._();

  /// The member-cap value the callables enforce
  /// (`MAX_CHAT_GROUP_MEMBERS` in `functions/src/groups/minor-membership-gate.ts`).
  /// Not read from the error — the callable's message states it in English
  /// prose, not a structured field — so it is pinned here instead of parsed.
  static const int maxMembers = 100;

  /// [genericFallback] is the operation-specific "something else went wrong"
  /// message the caller already shows. Never the reason a member was blocked:
  /// that reason is a minor's age, and the caller's business ends at "who",
  /// never "why".
  static String map(Object error, {required String genericFallback}) {
    if (error is FirebaseFunctionsException) {
      switch (error.code) {
        case 'permission-denied':
          final details = error.details;
          if (details is Map && details['blockedUserIds'] != null) {
            return AppLocale.current.chatGroupAddMembersBlocked;
          }
          break;
        case 'resource-exhausted':
          return AppLocale.current.errorRateLimitExceeded(
            _retryAfterSeconds(error),
          );
        case 'invalid-argument':
          if (error.message?.contains('members') ?? false) {
            return AppLocale.current.chatGroupTooManyMembers(maxMembers);
          }
          break;
        case 'failed-precondition':
          // BUT-1856. Read from a STRUCTURED detail rather than the message,
          // unlike the member cap above: that one has to sniff prose because
          // the callable states the number in English, and repeating the
          // mistake in a new branch is how it becomes the house style.
          final preconditionDetails = error.details;
          if (preconditionDetails is Map &&
              preconditionDetails['reason'] == 'group-too-small') {
            return AppLocale.current.chatGroupNeedsAnotherMember;
          }
          break;
      }
      AppLogger.error('Chat group callable failed: ${error.code}', error);
      return genericFallback;
    }

    AppLogger.error('Chat group operation failed', error);
    return genericFallback;
  }

  static int _retryAfterSeconds(FirebaseFunctionsException error) {
    final details = error.details;
    if (details is Map) {
      final seconds = details['retryAfterSeconds'];
      if (seconds is int) return seconds;
      if (seconds is num) return seconds.round();
    }
    return 60;
  }
}
