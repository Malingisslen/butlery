// lib/repositories/firebase/modules/message_poll_mutation_module.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:butlery/core/utils/logger.dart';
import 'package:butlery/core/utils/timestamp_provider.dart';
import 'package:butlery/core/constants/firestore_collections.dart';

/// Poll writes, split out of `MessageMutationModule` (BUT-1925) so the
/// transaction below fits without pushing that file past the 500-line limit.
/// It owns casting a ballot and closing.
class MessagePollMutationModule {
  final FirebaseFirestore firestore;
  final CollectionReference<Map<String, dynamic>> messagesRef;
  final TimestampProvider timestampProvider;

  MessagePollMutationModule({
    required this.firestore,
    required this.messagesRef,
    this.timestampProvider = const ServerTimestampProvider(),
  });

  CollectionReference<Map<String, dynamic>> pollVotesRef(String messageId) =>
      messagesRef.doc(messageId).collection(FirestoreCollections.pollVotes);

  /// Vote on (or toggle off) a poll option.
  ///
  /// Writes `messages/{messageId}/poll_votes/{voterId}` — one row per voter,
  /// doc id == voter uid — never the message document (BUT-1832). Casting a
  /// vote used to be an update of `metadata.poll.options[].voterIds` on the
  /// message, and `firestore.rules` lets only a message's SENDER update it, so
  /// every vote by anyone other than the poll's own author was denied. The
  /// permission is not something a wider message rule could grant: a rule
  /// cannot walk a list of maps, so "change only your own entry inside
  /// options[i].voterIds" is not expressible, while any rule loose enough to
  /// permit the write would also let a participant rewrite the question and
  /// everybody else's votes. With the voter in the PATH the rule is exact.
  ///
  /// The transaction is on the voter's own row, so two people voting at once no
  /// longer contend for one document the way the old whole-metadata rewrite did.
  Future<void> votePoll({
    required String messageId,
    required String optionId,
    required String voterId,
    required bool allowMultiple,
  }) async {
    final voteRef = pollVotesRef(messageId).doc(voterId);

    await firestore.runTransaction((transaction) async {
      final doc = await transaction.get(voteRef);
      final existing = doc.exists
          ? List<String>.from(
              (doc.data()?['optionIds'] as List<dynamic>? ?? const [])
                  .whereType<String>(),
            )
          : <String>[];

      // Behaviour preserved from the inline version, both branches:
      //   multi-choice — tapping an option toggles it, leaving the others alone;
      //   single-choice — the pick REPLACES the previous one, and re-tapping
      //   your current choice leaves it selected rather than clearing it. The
      //   old code reached that second one by stripping every option and then
      //   adding back, which nets to "stays voted"; stated directly here so it
      //   reads as the decision it is and not as a missing toggle.
      final List<String> next;
      if (allowMultiple) {
        next = List<String>.from(existing);
        if (next.contains(optionId)) {
          next.remove(optionId);
        } else {
          next.add(optionId);
        }
      } else {
        next = <String>[optionId];
      }

      if (next.isEmpty) {
        // No selection left. Delete rather than keep an empty row: an empty row
        // is still a uid on a document other participants read, and Art. 17
        // should not have to erase what carries no information.
        if (doc.exists) transaction.delete(voteRef);
        return;
      }

      transaction.set(voteRef, {
        // Duplicated from the doc id on purpose — the erasure sweep queries by
        // FIELD (`collectionGroup('poll_votes').where('voterId', ...)`), and a
        // document id is not a field any query or `hasOnly` can see.
        'voterId': voterId,
        'optionIds': next,
        'votedAt': timestampProvider.serverTimestamp(),
      });
    });

    AppLogger.debug('Poll vote recorded for message $messageId');
  }

  /// Close a poll (creator only). Returns true when THIS call is the one that
  /// closed it, false when it changed nothing — the message is gone, the caller
  /// is not the creator, or somebody else closed it first.
  ///
  /// BUT-1925: the read and the write are ONE transaction, and the closed flag
  /// is the idempotency anchor for the whole close. `MessagingService.closePoll`
  /// writes the winning recipe into a weekly plan AFTER this returns true, so a
  /// second caller whose own pre-read still said "open" has to lose here —
  /// otherwise the same recipe lands in a second slot.
  ///
  /// `fake_cloud_firestore.runTransaction` is a passthrough with no isolation,
  /// so a suite built on the fake shows that the already-closed branch exists
  /// and refuses; it cannot show that two concurrent closers serialise.
  Future<bool> closePoll({
    required String messageId,
    required String closerId,
  }) async {
    final messageRef = messagesRef.doc(messageId);

    return firestore.runTransaction<bool>((transaction) async {
      final doc = await transaction.get(messageRef);
      if (!doc.exists) return false;

      final data = doc.data();
      if (data == null) return false;

      final metadata = Map<String, dynamic>.from(data['metadata'] ?? {});
      final pollMap = Map<String, dynamic>.from(metadata['poll'] ?? {});

      if (pollMap['creatorId'] != closerId) {
        AppLogger.warning('Non-creator attempted to close poll $messageId');
        return false;
      }

      if (pollMap['isClosed'] == true) {
        AppLogger.debug('Poll $messageId is already closed — nothing to do');
        return false;
      }

      pollMap['isClosed'] = true;
      metadata['poll'] = pollMap;
      transaction.update(messageRef, {'metadata': metadata});

      AppLogger.debug('Poll closed: $messageId');
      return true;
    });
  }
}
