// lib/models/messaging/poll.dart

import 'package:clock/clock.dart';
import 'package:butlery/core/utils/serialization_utils.dart';
import 'package:uuid/uuid.dart';

/// A poll option that users can vote on.
/// Optional recipe metadata ([recipeId], [recipeImageUrl], [recipePortions])
/// lets a poll embed "Vad ska vi äta?" choices with thumbnails — backward
/// compatible: plain-text polls deserialize with these three fields as null.
class PollOption {
  final String id;
  final String text;
  final List<String> voterIds;
  final String? recipeId;
  final String? recipeImageUrl;
  final int? recipePortions;

  const PollOption({
    required this.id,
    required this.text,
    this.voterIds = const [],
    this.recipeId,
    this.recipeImageUrl,
    this.recipePortions,
  });

  factory PollOption.create({
    required String text,
    String? recipeId,
    String? recipeImageUrl,
    int? recipePortions,
  }) {
    return PollOption(
      id: const Uuid().v4(),
      text: text,
      recipeId: recipeId,
      recipeImageUrl: recipeImageUrl,
      recipePortions: recipePortions,
    );
  }

  factory PollOption.fromMap(Map<String, dynamic> data) {
    return PollOption(
      id: SerializationUtils.safeString(data, 'id'),
      text: SerializationUtils.safeString(data, 'text'),
      voterIds: SerializationUtils.safeStringList(data, 'voterIds'),
      recipeId: SerializationUtils.safeNullableString(data, 'recipeId'),
      recipeImageUrl: SerializationUtils.safeNullableString(
        data,
        'recipeImageUrl',
      ),
      recipePortions: SerializationUtils.safeNullableInt(
        data,
        'recipePortions',
      ),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'text': text,
      'voterIds': voterIds,
      if (recipeId != null) 'recipeId': recipeId,
      if (recipeImageUrl != null) 'recipeImageUrl': recipeImageUrl,
      if (recipePortions != null) 'recipePortions': recipePortions,
    };
  }

  PollOption copyWith({List<String>? voterIds}) {
    return PollOption(
      id: id,
      text: text,
      voterIds: voterIds ?? this.voterIds,
      recipeId: recipeId,
      recipeImageUrl: recipeImageUrl,
      recipePortions: recipePortions,
    );
  }

  int get voteCount => voterIds.length;

  bool hasVoted(String userId) => voterIds.contains(userId);

  /// Whether this option carries a recipe reference.
  bool get hasRecipe => recipeId != null;
}

/// Whether a poll's votes were actually READ, and if not, why (BUT-1908).
///
/// Before this existed the client could not tell "nobody has voted" from "the
/// votes were never fetched": both arrive as `voterIds == []`, and a poll drawn
/// that way says "0 röster" over real votes. That is not only a display bug —
/// the creator was shown an empty poll, tapped "avsluta", and the close path
/// re-read the message on its own uncapped route, resolved the REAL winner and
/// wrote it into the week's plan. The screen said nothing was there; the app
/// acted on votes the creator never saw.
///
/// A boolean is not enough, and the split is deliberate: [capped] is a client
/// decision that a re-read repairs, while [failed] may be permanent. They say
/// different things to the user. As a SAFETY control they are the same — both
/// must disable the close button identically — so gate on `!= ok`, and use the
/// distinction only for the wording and the log.
///
/// This value is written during hydration and lives in memory only. Nothing
/// round-trips a hydrated `Message` back to Firestore: the repository's
/// `closePoll` re-reads the RAW document before writing, so the map it sends
/// is built from what is stored rather than from the hydrated copy. (It writes
/// the whole `metadata` map, not one field — the raw re-read is what makes
/// that safe, not the size of the write.)
enum PollVoteHydration {
  /// The tally was read. `voterIds` reflects the subcollection.
  ok,

  /// Excluded by `MessageQueryModule.maxHydratedPolls`. Repairable by a re-read.
  capped,

  /// The read was attempted and errored. May be permanent.
  failed
  ;

  /// The key this is stored under, as a sibling of `poll` inside a message's
  /// metadata — NOT inside the poll map, which is the shape Firestore persists.
  static const String metadataKey = 'pollVoteHydration';

  /// Reads the marker off a message's metadata.
  ///
  /// Absent means [ok], and the default has to be that way round: flipping it
  /// would disable the close button on every correctly-read poll, since a poll
  /// with no votes is stamped by the same code path as one with votes.
  ///
  /// It is safe because the paths that RENDER a poll hydrate — the one-shot
  /// read, the live stream and `getMessage`. Two ways to inherit [ok] wrongly,
  /// both named rather than guarded: a future reader that builds a `Message` by
  /// hand and skips hydration, and a stored poll whose `options` is not a List,
  /// which `_merge` returns early on without stamping. Stamp at the new reader
  /// rather than changing this default.
  static PollVoteHydration fromMetadata(Map<String, dynamic>? metadata) {
    final raw = metadata?[metadataKey];
    return switch (raw) {
      'capped' => PollVoteHydration.capped,
      'failed' => PollVoteHydration.failed,
      _ => PollVoteHydration.ok,
    };
  }

  /// True when the votes on screen cannot be trusted to be the real ones.
  bool get isUnread => this != PollVoteHydration.ok;
}

/// A poll embedded in a chat message for group decision-making.
class Poll {
  final String id;
  final String question;
  final List<PollOption> options;
  final bool allowMultipleChoices;
  final DateTime? deadline;
  final String creatorId;
  final DateTime createdAt;
  final bool isClosed;

  const Poll({
    required this.id,
    required this.question,
    required this.options,
    this.allowMultipleChoices = false,
    this.deadline,
    required this.creatorId,
    required this.createdAt,
    this.isClosed = false,
  });

  factory Poll.create({
    required String question,
    required List<String> optionTexts,
    required String creatorId,
    bool allowMultipleChoices = false,
    DateTime? deadline,
  }) {
    return Poll(
      id: const Uuid().v4(),
      question: question,
      options: optionTexts.map((t) => PollOption.create(text: t)).toList(),
      allowMultipleChoices: allowMultipleChoices,
      deadline: deadline,
      creatorId: creatorId,
      createdAt: clock.now(),
    );
  }

  /// Build a poll from pre-constructed options — used when options carry
  /// recipe metadata (A2 "Vad ska vi äta?") and can't be expressed as plain
  /// strings.
  factory Poll.fromOptions({
    required String question,
    required List<PollOption> options,
    required String creatorId,
    bool allowMultipleChoices = false,
    DateTime? deadline,
  }) {
    return Poll(
      id: const Uuid().v4(),
      question: question,
      options: options,
      allowMultipleChoices: allowMultipleChoices,
      deadline: deadline,
      creatorId: creatorId,
      createdAt: clock.now(),
    );
  }

  factory Poll.fromMap(Map<String, dynamic> data) {
    return Poll(
      id: SerializationUtils.safeString(data, 'id'),
      question: SerializationUtils.safeString(data, 'question'),
      options: SerializationUtils.safeObjectList(
        data,
        'options',
        PollOption.fromMap,
      ),
      allowMultipleChoices: SerializationUtils.safeBool(
        data,
        'allowMultipleChoices',
      ),
      deadline: SerializationUtils.safeDateTime(data, 'deadline'),
      creatorId: SerializationUtils.safeString(data, 'creatorId'),
      createdAt: SerializationUtils.safeRequiredDateTime(data, 'createdAt'),
      isClosed: SerializationUtils.safeBool(data, 'isClosed'),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'question': question,
      'options': options.map((o) => o.toMap()).toList(),
      'allowMultipleChoices': allowMultipleChoices,
      'deadline': SerializationUtils.serializeDateTime(deadline),
      'creatorId': creatorId,
      'createdAt': SerializationUtils.serializeDateTime(createdAt),
      'isClosed': isClosed,
    };
  }

  Poll copyWith({
    List<PollOption>? options,
    bool? isClosed,
  }) {
    return Poll(
      id: id,
      question: question,
      options: options ?? this.options,
      allowMultipleChoices: allowMultipleChoices,
      deadline: deadline,
      creatorId: creatorId,
      createdAt: createdAt,
      isClosed: isClosed ?? this.isClosed,
    );
  }

  int get totalVotes {
    final allVoters = <String>{};
    for (final option in options) {
      allVoters.addAll(option.voterIds);
    }
    return allVoters.length;
  }

  /// Whether the poll has expired based on deadline.
  bool get isExpired => deadline != null && clock.now().isAfter(deadline!);

  /// Whether voting is still allowed.
  bool get isActive => !isClosed && !isExpired;
}

/// Why `MessagingService.closePoll` refused to close a poll (BUT-1908/BUT-1909).
///
/// Closing is a ONE-WAY door: `isClosed` has no reset anywhere in the
/// repository, and a creator-triggered close writes the winning recipe into the
/// household's week. So the close path refuses rather than guesses whenever the
/// tally it would resolve on is not the real one. Every refusal leaves the poll
/// OPEN and writes no plan, so a retry is always safe.
enum PollCloseRefusal {
  /// The votes were never read. Acting on that is the exact BUT-1908 harm: the
  /// creator sees "0 röster" and the app resolves the real winner behind the
  /// screen.
  ///
  /// Which STATE the service can see is not the same question as which states
  /// exist. `closePoll` reads through `getMessage`, whose list holds ONE
  /// message, so the cap cannot apply there — a capped poll reaches the service
  /// marked `ok`. That is why the gate lives in the widget and in
  /// `ChatViewModel.closePoll`, both of which hold the copy the user saw.
  votesUnread,

  /// The viewer's block list could not be determined, so blocked ballots cannot
  /// be excluded. Fail-open is right for DISPLAY and wrong here: a blocked
  /// person's vote would decide a recipe that other members then see in their
  /// plan (BUT-1909, Trust & Safety condition).
  blockListUnknown,
}

/// Thrown by `MessagingService.closePoll` instead of closing on a tally it
/// cannot trust. Carries [reason] so the UI can say which of the two happened —
/// they need different Swedish text, because one is repaired by a re-read and
/// the other may not be.
class PollCloseRefusedException implements Exception {
  const PollCloseRefusedException(this.reason);

  final PollCloseRefusal reason;

  @override
  String toString() => 'PollCloseRefusedException(${reason.name})';
}
