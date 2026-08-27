// lib/repositories/firebase/modules/message_query_module.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:rxdart/rxdart.dart';
import 'package:butlery/repositories/firebase/dtos/message_dto.dart';
import 'package:butlery/models/messaging/message.dart';
import 'package:butlery/models/messaging/poll.dart';
import 'package:butlery/core/constants/firestore_collections.dart';
import 'package:butlery/core/utils/logger.dart';
import 'package:butlery/core/utils/log_sanitizer.dart';

/// Message query module for read-only message operations.
class MessageQueryModule {
  final CollectionReference<Map<String, dynamic>> messagesRef;

  MessageQueryModule({
    required this.messagesRef,
  });

  /// Ceiling on how many poll subcollections one page of messages may subscribe
  /// to at once. A conversation of nothing but polls would otherwise open one
  /// live listener per message; a page holds 50, and a screen showing more than
  /// this many open polls is not a case worth paying for.
  static const int maxHydratedPolls = 20;

  CollectionReference<Map<String, dynamic>> _pollVotesRef(String messageId) =>
      messagesRef.doc(messageId).collection(FirestoreCollections.pollVotes);

  /// Stream conversation messages with real-time updates.
  ///
  /// [historyStart] MUST be passed for a group conversation: it is the caller's
  /// `memberSince` stamp, and `firestore.rules` refuses any message sent before
  /// it (BUT-1838). This is not a display filter — a query that returns even
  /// ONE document the rules refuse fails ENTIRELY, so omitting it turns a group
  /// chat into a permission error rather than a slightly-too-long history.
  Stream<List<Message>> getConversationMessages({
    required String conversationId,
    DateTime? historyStart,
    int limit = 50,
  }) {
    try {
      AppLogger.info(
        '🔍 [MessageQuery] Creating message stream for conversationId: ${conversationId.maskedConversationId}',
      );
      var query = messagesRef.where(
        'conversationId',
        isEqualTo: conversationId,
      );
      if (historyStart != null) {
        query = query.where(
          'sentAt',
          isGreaterThanOrEqualTo: Timestamp.fromDate(historyStart),
        );
      }
      // A range and an orderBy on the SAME field, so the existing
      // `conversationId ASC + sentAt` composite index covers this unchanged.
      return query
          .orderBy('sentAt', descending: true)
          .limit(limit)
          .snapshots()
          .map((snapshot) {
            AppLogger.debug(
              '📬 [MessageQuery] Stream update: ${snapshot.docs.length} messages for conversation ${conversationId.maskedConversationId}',
            );
            final messages = snapshot.docs
                .map((doc) => MessageDto.fromFirestore(doc))
                .toList()
                .reversed // Reverse to show oldest first
                .toList();
            return messages;
          })
          .switchMap(_withLivePollVotes);
    } catch (e) {
      AppLogger.error(
        '❌ [MessageQuery] Failed to get messages for conversation '
        '${conversationId.maskedConversationId}',
        e,
      );
      return const Stream.empty();
    }
  }

  /// Get paginated messages for conversation.
  Future<List<Message>> getConversationMessagesPage({
    required String conversationId,
    DateTime? historyStart,
    int limit = 50,
    DateTime? startAfter,
  }) async {
    try {
      var query = messagesRef.where(
        'conversationId',
        isEqualTo: conversationId,
      );
      // Same rules constraint as the stream above — see its comment.
      if (historyStart != null) {
        query = query.where(
          'sentAt',
          isGreaterThanOrEqualTo: Timestamp.fromDate(historyStart),
        );
      }
      query = query.orderBy('sentAt', descending: true);

      if (startAfter != null) {
        query = query.startAfter([Timestamp.fromDate(startAfter)]);
      }

      final snapshot = await query.limit(limit).get();

      return _hydratePollVotes(
        snapshot.docs
            .map((doc) => MessageDto.fromFirestore(doc))
            .toList()
            .reversed // Reverse to show oldest first
            .toList(),
      );
    } catch (e) {
      AppLogger.error(
        'Failed to get messages page for conversation '
        '${conversationId.maskedConversationId}',
        e,
      );
      return [];
    }
  }

  /// Get a single message by ID.
  Future<Message?> getMessage(String messageId) async {
    try {
      final doc = await messagesRef.doc(messageId).get();
      if (doc.exists) {
        // Hydration matters here beyond display: `MessagingService.closePoll`
        // reads the poll through this method and picks the winner by vote
        // count.
        //
        // Note what this does NOT mean. The cap below cannot reach this path:
        // the list here holds ONE message, so `.take(maxHydratedPolls)` is a
        // no-op, and a poll's close is hydrated however far down the chat it
        // sits. Nor would an unhydrated poll close on the first option —
        // `_resolveWinner` returns null once every option reads zero votes, so
        // it writes no plan at all. Both claims were made in this file and both
        // were false; they cost a ticket that specified a guard against a state
        // the code cannot enter (BUT-1883, measured 2026-08-20).
        return (await _hydratePollVotes([MessageDto.fromFirestore(doc)])).first;
      }
      return null;
    } catch (e) {
      AppLogger.error('Failed to get message: $messageId', e);
      return null;
    }
  }

  // ─── Poll-vote hydration (BUT-1832) ──────────────────────────────────────
  //
  // Votes are stored at `messages/{messageId}/poll_votes/{voterUid}`, not in
  // `metadata.poll.options[].voterIds` on the message, because only a message's
  // SENDER may update the message — which denied the vote to every participant
  // except the poll's own author. Moving the write does not move the READ: the
  // poll widget, `Poll.totalVotes` and `closePoll`'s winner resolution all read
  // `voterIds`, so this module folds the subcollection back into that shape
  // before handing a Message out. Everything above the repository therefore
  // sees exactly what it saw before, which is why the change stops here.
  //
  // Anything that RENDERS a poll message must hydrate. An unhydrated poll is
  // not a rendering nit — it shows "0 röster" over real votes.
  //
  // The harm is a DISPLAY harm, and it is worth stating precisely because the
  // wrong version of this sentence lived here for days: the close button is
  // still drawn on a poll showing "0 röster", the close then re-reads the
  // message on its own uncapped path and resolves the REAL winner, and a recipe
  // lands in the week's plan that the creator was never shown a vote for. The
  // write is correct; the screen that led to it was not.
  //
  // `searchMessages` below is the deliberate exception and stays unhydrated: its
  // only callers are the service passthrough (no view, viewmodel or widget calls
  // it) and "rensa chatt", which deletes rather than draws. If a search UI ever
  // lands, route it through `_hydratePollVotes` — that is the day this carve-out
  // stops being true.

  bool _isPoll(Message message) => message.metadata?['poll'] is Map;

  // Selected from the TAIL, not the head. Both callers hand this list oldest
  // first, so taking the first N kept the OLDEST polls and dropped the newest —
  // i.e. the ones at the bottom of the chat the user is actually looking at.
  // Those rendered "0 röster" over real votes, which is the exact symptom the
  // comment above says must not happen, and the cap's own justification ("a
  // screen showing more than this many open polls") argues for the visible end.
  ({List<String> kept, List<String> capped}) _pollIds(List<Message> messages) {
    final all = messages.reversed
        .where(_isPoll)
        .map((m) => m.id)
        .toList(growable: false);
    if (all.length <= maxHydratedPolls) {
      return (kept: all, capped: const <String>[]);
    }
    final capped = all.sublist(maxHydratedPolls);
    // The cap used to exclude polls in total silence, so "0 röster over real
    // votes" had no signal at all. This is `warning`, which writes to the local
    // log only — the on-screen marker is what a user or a report actually sees.
    // Counts only, no ids: a conversation id would be two raw uids on a DM.
    AppLogger.warning(
      'Poll-vote hydration capped at $maxHydratedPolls; '
      '${capped.length} poll(s) left unread on this page',
    );
    return (kept: all.sublist(0, maxHydratedPolls), capped: capped);
  }

  /// optionId -> voter uids, from one poll's `poll_votes` rows.
  Map<String, List<String>> _tally(QuerySnapshot<Map<String, dynamic>> snap) {
    final byOption = <String, List<String>>{};
    for (final doc in snap.docs) {
      // The doc id is the voter (the rule pins it there); `voterId` is the
      // field copy the erasure sweep queries on. Prefer the id — it is the one
      // the rule guarantees.
      final voterId = doc.id;
      final optionIds = doc.data()['optionIds'];
      if (optionIds is! List) continue;
      for (final optionId in optionIds.whereType<String>()) {
        (byOption[optionId] ??= <String>[]).add(voterId);
      }
    }
    return byOption;
  }

  /// Replace each option's `voterIds` with the tally, leaving every other key
  /// on the message untouched. Fails OPEN toward the stored message: an
  /// unexpected shape returns the message unchanged rather than blanking a
  /// poll nobody could then read.
  Message _merge(Message message, Map<String, List<String>> byOption) {
    final metadata = message.metadata;
    if (metadata == null) return message;
    final poll = metadata['poll'];
    if (poll is! Map) return message;
    final options = poll['options'];
    if (options is! List) return message;
    // The three early returns above are the fail-open shapes, and they leave
    // the marker UNSET, i.e. `ok`. For the first two — no metadata, no poll map
    // — that is right: there is no poll, so no tally to be wrong about.
    //
    // The THIRD is a genuine gap, named rather than papered over: a poll whose
    // `options` is not a List is still a poll to `_isPoll`, so the widget draws
    // it, reads no votes, and offers the creator a close button on a tally that
    // was never read. `_resolveWinner` then writes no plan, so the harm stops
    // at a burnt poll rather than a wrong recipe — which is why this is a note
    // and not a guard. Only a malformed stored document reaches it.

    final rebuiltOptions = options.map((option) {
      if (option is! Map) return option;
      final copy = Map<String, dynamic>.from(option);
      final optionId = copy['id'];
      copy['voterIds'] = optionId is String
          ? (byOption[optionId] ?? const <String>[])
          : const <String>[];
      return copy;
    }).toList();

    final rebuiltPoll = Map<String, dynamic>.from(poll)
      ..['options'] = rebuiltOptions;
    final rebuiltMetadata = Map<String, dynamic>.from(metadata)
      ..['poll'] = rebuiltPoll
      // Sibling of `poll`, never inside it: the poll map is the shape Firestore
      // persists, and this is an in-memory read state.
      ..[PollVoteHydration.metadataKey] = PollVoteHydration.ok.name;

    return message.copyWith(metadata: rebuiltMetadata);
  }

  /// Stamp a poll the tally never reached, so the UI can tell "no votes" from
  /// "no answer". Leaves `voterIds` exactly as stored — blanking them would be
  /// the fail-closed mistake this module already corrected once.
  Message _markUnread(Message message, PollVoteHydration state) {
    final metadata = message.metadata;
    if (metadata == null) return message;
    return message.copyWith(
      metadata: Map<String, dynamic>.from(metadata)
        ..[PollVoteHydration.metadataKey] = state.name,
    );
  }

  /// One-shot hydration for the non-streaming readers.
  Future<List<Message>> _hydratePollVotes(List<Message> messages) async {
    final ids = _pollIds(messages);
    if (ids.kept.isEmpty && ids.capped.isEmpty) return messages;

    final tallies = <String, Map<String, List<String>>>{};
    await Future.wait(
      ids.kept.map((id) async {
        try {
          tallies[id] = _tally(await _pollVotesRef(id).get());
        } catch (e) {
          // A failed tally must not take the whole page down with it: the
          // messages are the payload, the votes are an overlay. It is no longer
          // SILENT, though — the message is stamped `failed` below, so the UI
          // can refuse to act on a tally it never received.
          AppLogger.warning('Could not read poll votes for message $id: $e');
        }
      }),
    );

    final capped = ids.capped.toSet();
    return messages.map((m) {
      if (tallies.containsKey(m.id)) return _merge(m, tallies[m.id]!);
      if (capped.contains(m.id)) {
        return _markUnread(m, PollVoteHydration.capped);
      }
      // A poll that was in `kept` but is absent from `tallies` is one whose
      // read threw. Anything else here is not a poll at all.
      if (_isPoll(m)) return _markUnread(m, PollVoteHydration.failed);
      return m;
    }).toList();
  }

  /// Live hydration: re-emits whenever any visible poll's votes change, so a
  /// tap updates the bars without waiting for the next message.
  Stream<List<Message>> _withLivePollVotes(List<Message> messages) {
    final ids = _pollIds(messages);
    if (ids.kept.isEmpty && ids.capped.isEmpty) return Stream.value(messages);

    // Genuinely the same fail-open contract as the one-shot path — which took
    // saying it in code rather than in a comment. `onErrorReturnWith` used to
    // hand back an EMPTY tally, and an empty tally is not "no answer": it is
    // present in `tallies`, so `_merge` ran and blanked every option's stored
    // `voterIds`. That is fail-CLOSED, the opposite of the sentence that sat
    // here, and the error path is live: a deleted message makes
    // `pollMessage().data` null and the read denies on a CEL error, a removed
    // participant fails the membership test, and `unavailable` is routine on a
    // long-lived stream. (Not a null `metadata` — `allow read` on `poll_votes`
    // never calls `pollIsOpen()`, so metadata SHAPE cannot deny a read. That
    // example was wrong, and `firestore.rules` records the same mistake being
    // corrected in this very commit.) A null entry is filtered out
    // below instead, so the message passes through untouched, exactly as the
    // one-shot `catch` leaves the id out of its map.
    final perPoll = ids.kept.map(
      (id) => _pollVotesRef(id)
          .snapshots()
          .map<MapEntry<String, Map<String, List<String>>>?>(
            (s) => MapEntry(id, _tally(s)),
          )
          .onErrorReturnWith((e, _) {
            // The one-shot path logs; this one used to say nothing at all, so a
            // permanently unreadable tally was invisible until the outer
            // message snapshot happened to re-emit.
            AppLogger.warning('Poll votes stream failed for $id: $e');
            return null;
          }),
    );

    final capped = ids.capped.toSet();
    return CombineLatestStream.list(perPoll).map((entries) {
      final tallies = Map.fromEntries(
        entries.whereType<MapEntry<String, Map<String, List<String>>>>(),
      );
      return messages.map((m) {
        if (tallies.containsKey(m.id)) return _merge(m, tallies[m.id]!);
        if (capped.contains(m.id)) {
          return _markUnread(m, PollVoteHydration.capped);
        }
        // A null entry — the `onErrorReturnWith` above — lands here, which is
        // the whole point of filtering it out rather than merging an empty
        // tally: the stored `voterIds` survive untouched AND the message now
        // says the number beside them was never confirmed.
        if (_isPoll(m)) return _markUnread(m, PollVoteHydration.failed);
        return m;
      }).toList();
    });
  }

  /// Search messages in conversation (simplified implementation).
  /// [historyStart] carries the same obligation as the two readers above: for
  /// a group conversation `firestore.rules` refuses anything sent before the
  /// caller joined, and one refused document fails the WHOLE query. Omitting it
  /// made search look empty and made "rensa chatt" report success having
  /// deleted nothing, for exactly the members who joined late.
  Future<List<Message>> searchMessages({
    required String conversationId,
    required String query,
    DateTime? historyStart,
    int limit = 20,
  }) async {
    try {
      // Firestore doesn't support full-text search natively
      // This is a simplified implementation that searches in content
      // In production, consider using Algolia or similar

      var searchQuery = messagesRef.where(
        'conversationId',
        isEqualTo: conversationId,
      );
      if (historyStart != null) {
        searchQuery = searchQuery.where(
          'sentAt',
          isGreaterThanOrEqualTo: Timestamp.fromDate(historyStart),
        );
      }
      final messages = await searchQuery
          .orderBy('sentAt', descending: true)
          .limit(limit * 3) // Get more to filter
          .get();

      final lowerQuery = query.toLowerCase();
      return messages.docs
          .map((doc) => MessageDto.fromFirestore(doc))
          .where(
            (message) => message.content.toLowerCase().contains(lowerQuery),
          )
          .take(limit)
          .toList();
    } catch (e) {
      AppLogger.error(
        'Failed to search messages in conversation '
        '${conversationId.maskedConversationId}',
        e,
      );
      return [];
    }
  }
}
