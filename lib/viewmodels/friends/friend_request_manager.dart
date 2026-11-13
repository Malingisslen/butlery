import 'package:collection/collection.dart';
import 'package:butlery/core/utils/log_sanitizer.dart';
import 'package:butlery/core/utils/logger.dart';
import 'package:butlery/models/friend_request.dart';
import 'package:butlery/services/analytics_service.dart';
import 'package:butlery/services/auth/email_verification_refresh.dart';
import 'package:butlery/services/auth_service.dart';
import 'package:butlery/services/unified/unified_friends_service.dart';
import 'package:butlery/services/user_service/user_service_roles.dart';

/// Friend-request operations for the friends screen: send, accept, reject,
/// cancel and their batches, with the in-flight joining and analytics each
/// of them carries.
class FriendRequestManager {
  final UnifiedFriendsService _friendsService;
  final OwnProfileReader _userService;
  final AnalyticsService _analyticsService;
  final AuthService? _authService;
  final bool Function() _isAccountMatured;
  final bool Function() _isDisposed;
  final bool Function() _hasSearchQuery;
  final List<FriendRequest> Function() _incomingRequests;
  final void Function() _onChanged;

  bool _blockedByUnverifiedEmail = false;

  FriendRequestManager({
    required UnifiedFriendsService friendsService,
    required OwnProfileReader userService,
    required AnalyticsService analyticsService,
    required AuthService? authService,
    required bool Function() isAccountMatured,
    required bool Function() isDisposed,
    required bool Function() hasSearchQuery,
    required List<FriendRequest> Function() incomingRequests,
    required void Function() onChanged,
  }) : _friendsService = friendsService,
       _userService = userService,
       _analyticsService = analyticsService,
       _authService = authService,
       _isAccountMatured = isAccountMatured,
       _isDisposed = isDisposed,
       _hasSearchQuery = hasSearchQuery,
       _incomingRequests = incomingRequests,
       _onChanged = onChanged;

  // BUT-2306: a second tap while the first call is still running joins it.
  // Run twice, the send failed on the request its twin had just added and
  // reported "Kunde inte skicka vänförfrågan" for a request that went out.
  final _inFlight = <String, Future<bool>>{};

  // The block body matters: `remove` returns this very future, and a
  // whenComplete callback that returns a future is awaited, so an arrow body
  // would make the call wait on itself forever.
  Future<bool> _joined(String key, Future<bool> Function() run) {
    final running = _inFlight[key];
    if (running != null) return running;
    final started = _inFlight[key] = run().whenComplete(() {
      _inFlight.remove(key);
      _onChanged();
    });
    _onChanged();
    return started;
  }

  /// Whether a friend request to [userId] is on its way, so its button can
  /// show that it is working instead of inviting a second tap.
  bool isSendingTo(String userId) => _inFlight.containsKey('send:$userId');

  /// Whether the request [requestId] is being accepted. Accepting goes
  /// through a Cloud Function and can take seconds.
  bool isAccepting(String requestId) =>
      _inFlight.containsKey('accept:$requestId');

  /// True when the last send stopped at the maturity gate. The caller says so
  /// with a way to resend the mail, instead of a banner with no way forward.
  bool get blockedByUnverifiedEmail => _blockedByUnverifiedEmail;

  /// Sends a new verification mail; false when it could not be sent.
  Future<bool> resendVerificationEmail() async {
    final auth = _authService;
    if (auth == null) return false;
    try {
      await auth.sendEmailVerification();
      return true;
    } catch (e) {
      AppLogger.warning('Could not resend verification email: $e');
      return false;
    }
  }

  /// Send friend request to user
  Future<bool> sendFriendRequest(String userId, {String? message}) => _joined(
    'send:$userId',
    () => _sendFriendRequest(userId, message: message),
  );

  Future<bool> _sendFriendRequest(String userId, {String? message}) async {
    // Client-side mirror of the server isAccountMatured() gate (BUT-659).
    // The server is still the authority; this prevents the opaque
    // permission-denied that new accounts would otherwise see.
    // BUT-2305: the link may have been opened since sign-in.
    if (!_isAccountMatured()) await refreshEmailVerification(_authService);
    if (_isDisposed()) return false;
    _blockedByUnverifiedEmail = !_isAccountMatured();
    if (_blockedByUnverifiedEmail) {
      _onChanged();
      return false;
    }

    AppLogger.info('🔄 Sending friend request to ${userId.maskedUserId}...');

    final success = await _friendsService.management.sendFriendRequest(
      userId,
      message: message,
    );

    if (success) {
      AppLogger.success(
        '✅ Friend request sent successfully to ${userId.maskedUserId}',
      );

      // Track friend request sent
      await _analyticsService.logFriendRequestSent(
        recipientId: userId,
        source: _hasSearchQuery() ? 'search' : 'discovery',
      );

      // BUT-2306: the search stays, so the card can say the request went;
      // clearing it flashed "Inga vänner matchade din sökning".
      _onChanged();
    } else {
      AppLogger.error(
        '❌ Failed to send friend request to ${userId.maskedUserId}',
      );
    }

    return success;
  }

  /// Accept incoming friend request
  Future<bool> acceptFriendRequest(String requestId) =>
      _joined('accept:$requestId', () => _acceptFriendRequest(requestId));

  Future<bool> _acceptFriendRequest(String requestId) async {
    // Find the request to get sender ID for analytics. The request may have
    // already vanished (cancelled on another device / double-tap) — don't
    // throw; the service safely no-ops on a missing request.
    final request = _incomingRequests().firstWhereOrNull(
      (r) => r.id == requestId,
    );

    final success = await _friendsService.management.acceptFriendRequest(
      requestId,
    );

    if (success) {
      // Track friend request accepted (only when we still have the sender id).
      if (request != null) {
        await _analyticsService.logFriendRequestAccepted(
          senderId: request.fromUserId,
        );
      }
      // First-friend milestone fires at most once per user (BUT-593).
      await _analyticsService.social.logFirstFriendIfMilestone(
        userId: _userService.currentUserId,
        joinedAt: _userService.currentUserProfile?.joinedAt,
      );
    }

    return success;
  }

  /// Reject incoming friend request
  Future<bool> rejectFriendRequest(String requestId) async {
    // Look up sender id before mutation removes it from state. The request may
    // have already vanished (cancelled on another device / double-tap) — don't
    // throw; the service safely no-ops on a missing request.
    final request = _incomingRequests().firstWhereOrNull(
      (r) => r.id == requestId,
    );

    final success = await _friendsService.management.rejectFriendRequest(
      requestId,
    );

    if (success && request != null) {
      await _analyticsService.social.logFriendRequestRejected(
        senderId: request.fromUserId,
      );
    }

    return success;
  }

  /// Cancel sent friend request
  Future<bool> cancelSentRequest(String requestId) async {
    return await _friendsService.management.cancelFriendRequest(requestId);
  }

  /// Accept several incoming requests. Loops [acceptFriendRequest] rather than
  /// the service method it wraps, because the analytics for an accept live on
  /// this ViewModel — a batch built on the service layer would write the
  /// friendships and record none of them.
  ///
  /// Returns the ids that landed — a request can legitimately have vanished
  /// from another device, so one failure must not strand the rest, and the
  /// caller needs to know which ones to stop offering.
  Future<List<String>> acceptFriendRequests(List<String> requestIds) =>
      _runBatch(requestIds, acceptFriendRequest);

  /// Reject several incoming requests. See [acceptFriendRequests].
  Future<List<String>> rejectFriendRequests(List<String> requestIds) =>
      _runBatch(requestIds, rejectFriendRequest);

  /// Cancel several sent requests. [cancelSentRequest] adds nothing of its own,
  /// so this exists for one contract towards the view rather than for the
  /// analytics reason the other two have.
  Future<List<String>> cancelSentRequests(List<String> requestIds) =>
      _runBatch(requestIds, cancelSentRequest);

  /// Each id keeps the per-request analytics of the single-request path,
  /// which this adds a catch around: one id that throws must not strand the
  /// ids after it.
  Future<List<String>> _runBatch(
    List<String> requestIds,
    Future<bool> Function(String) operation,
  ) async {
    final succeeded = <String>[];
    for (final requestId in List<String>.of(requestIds)) {
      try {
        if (await operation(requestId)) succeeded.add(requestId);
      } catch (e) {
        AppLogger.error('❌ Batch operation failed for one request: $e');
      }
    }
    if (succeeded.isNotEmpty) _onChanged();
    return succeeded;
  }
}
