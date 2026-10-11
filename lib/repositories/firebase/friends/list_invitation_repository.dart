import 'package:butlery/core/extensions/default_value_extensions.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:butlery/core/constants/firestore_collections.dart';
import 'package:butlery/core/exceptions/permission_exceptions.dart';
import 'package:butlery/core/utils/timestamp_provider.dart';
import 'package:butlery/models/social_request.dart';
import 'package:butlery/repositories/firebase/firebase_social_request_repository.dart';

enum ListInviteSkipReason {
  self,
  alreadyMember,
  alreadyInvited,
  notFriends,
  unavailable,
}

class ListInviteSkip {
  const ListInviteSkip(this.userId, this.reason);

  final String userId;
  final ListInviteSkipReason reason;
}

/// What `sendListInvitations` answered: invitee id to invitation id for the
/// ones that went out, and why each of the others did not.
class SendListInvitationsResult {
  const SendListInvitationsResult({
    this.sent = const {},
    this.skipped = const [],
  });

  final Map<String, String> sent;
  final List<ListInviteSkip> skipped;
}

class AcceptListInvitationResult {
  const AcceptListInvitationResult({
    required this.alreadyMember,
    required this.listId,
  });

  final bool alreadyMember;
  final String listId;
}

/// Shared shopping list invitations (BUT-2089): the two callables, the
/// recipient's stream, and the recipient's decline and sender's revoke on the
/// `social_requests` row. Seats are only ever written by the server; the
/// permission checks for decline and revoke live in the wrapped
/// [FirebaseSocialRequestRepository].
class ListInvitationRepository {
  ListInvitationRepository({
    required FirebaseFirestore firestore,
    required FirebaseSocialRequestRepository socialRequests,
    TimestampProvider? timestampProvider,
    FirebaseFunctions? functions,
  }) : _firestore = firestore,
       _timestamps = timestampProvider ?? const ServerTimestampProvider(),
       _socialRequests = socialRequests,
       _injectedFunctions = functions;

  final FirebaseFirestore _firestore;
  final TimestampProvider _timestamps;
  final FirebaseSocialRequestRepository _socialRequests;
  final FirebaseFunctions? _injectedFunctions;
  FirebaseFunctions? _functionsCache;

  // Resolved lazily so constructing the repository never needs a Firebase app.
  FirebaseFunctions get _functions => _functionsCache ??=
      (_injectedFunctions ??
      FirebaseFunctions.instanceFor(region: 'europe-west1'));

  CollectionReference<Map<String, dynamic>> get _requestsRef =>
      _firestore.collection(FirestoreCollections.socialRequests);

  Future<SendListInvitationsResult> sendListInvitationsViaFunction({
    required String listId,
    required List<String> userIds,
    String permission = 'edit',
  }) async {
    final callable = _functions.httpsCallable('sendListInvitations');
    final result = await callable.call<Map<String, dynamic>>(<String, dynamic>{
      'listId': listId,
      'userIds': userIds,
      'permission': permission,
    });
    final sent = (result.data['sent'] as List?) ?? const [];
    final skipped = (result.data['skipped'] as List?) ?? const [];
    return SendListInvitationsResult(
      sent: {
        for (final entry in sent.cast<Map>())
          entry['userId'] as String: entry['invitationId'] as String,
      },
      skipped: [
        for (final entry in skipped.cast<Map>())
          ListInviteSkip(
            entry['userId'] as String,
            _skipReasonOf(entry['reason']),
          ),
      ],
    );
  }

  // A reason this build does not know is reported as `unavailable`, the
  // server's own catch-all word, so the inviter never learns more than that.
  static ListInviteSkipReason _skipReasonOf(Object? raw) => switch (raw) {
    'self' => ListInviteSkipReason.self,
    'already_member' => ListInviteSkipReason.alreadyMember,
    'already_invited' => ListInviteSkipReason.alreadyInvited,
    'not_friends' => ListInviteSkipReason.notFriends,
    _ => ListInviteSkipReason.unavailable,
  };

  Future<AcceptListInvitationResult> acceptListInvitationViaFunction(
    String invitationId,
  ) async {
    final callable = _functions.httpsCallable('acceptListInvitation');
    final result = await callable.call<Map<String, dynamic>>(<String, dynamic>{
      'invitationId': invitationId,
    });
    return AcceptListInvitationResult(
      alreadyMember: result.data['alreadyMember'] == true,
      listId: (result.data['listId'] as String?).orEmpty(),
    );
  }

  /// Pending, unexpired list invitations addressed to [userId], newest first.
  /// Equality filters only, so the automatic single-field indexes serve it and
  /// no composite index is needed; the order is applied here.
  Stream<List<SocialRequest>> receivedListInvitationsStream(String userId) {
    return _requestsRef
        .where('toUserId', isEqualTo: userId)
        .where('type', isEqualTo: SocialRequestType.listInvitation.name)
        .where('status', isEqualTo: SocialRequestStatus.pending.name)
        .limit(50)
        .snapshots()
        .map(
          (snapshot) =>
              snapshot.docs
                  .map((doc) => SocialRequest.fromMap(doc.id, doc.data()))
                  .where((r) => r.isListInvitation && !r.isExpired)
                  .toList()
                ..sort((a, b) => b.sentAt.compareTo(a.sentAt)),
        );
  }

  /// Pending, unexpired invitations to [listId] that [userId] sent, oldest
  /// first. `fromUserId` stays in the query because the `social_requests`
  /// read rule admits only the sender and the recipient: a query that did not
  /// pin it would be refused, not merely filtered.
  Stream<List<SocialRequest>> sentListInvitationsStream(
    String userId,
    String listId,
  ) {
    return _requestsRef
        .where('fromUserId', isEqualTo: userId)
        .where('type', isEqualTo: SocialRequestType.listInvitation.name)
        .where('listId', isEqualTo: listId)
        .where('status', isEqualTo: SocialRequestStatus.pending.name)
        .limit(50)
        .snapshots()
        .map(
          (snapshot) =>
              snapshot.docs
                  .map((doc) => SocialRequest.fromMap(doc.id, doc.data()))
                  .where((r) => r.isListInvitation && !r.isExpired)
                  .toList()
                ..sort((a, b) => a.sentAt.compareTo(b.sentAt)),
        );
  }

  /// Declines as the recipient. Throws a [FirebaseException] with code
  /// `unavailable` when offline, and a [ResourceNotFoundException] when the
  /// row is gone or no longer this caller's to answer.
  Future<void> declineListInvitation(String invitationId) => _onServerRow(
    invitationId,
    () => _socialRequests.updateRequestStatus(invitationId, {
      'status': SocialRequestStatus.rejected.name,
      'respondedAt': _timestamps.serverTimestamp(),
    }),
  );

  /// The sender takes back a pending invitation by deleting its row. Throws
  /// like [declineListInvitation].
  Future<void> revokeListInvitation(String invitationId) => _onServerRow(
    invitationId,
    () => _socialRequests.deleteRequest(invitationId),
  );

  /// Reads the row from the server before [action]: offline, the write would
  /// queue and report success for a change nobody has seen.
  ///
  /// The `social_requests` read rule reads the stored row, so a get of a row
  /// that was deleted is refused rather than answered as missing, and so is a
  /// delete of a row that is no longer pending. Either way the invitation is
  /// spent, which the caller shows as such.
  Future<void> _onServerRow(
    String invitationId,
    Future<void> Function() action,
  ) async {
    try {
      await _requestsRef
          .doc(invitationId)
          .get(const GetOptions(source: Source.server));
      await action();
    } on FirebaseException catch (e) {
      if (e.code != 'permission-denied') rethrow;
      throw ResourceNotFoundException(
        'List invitation is not available',
        resourceType: 'social_request',
        resourceId: invitationId,
      );
    }
  }
}
