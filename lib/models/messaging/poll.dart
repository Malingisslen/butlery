// lib/models/messaging/poll.dart

import 'package:butlery/core/utils/serialization_utils.dart';
import 'package:uuid/uuid.dart';

/// A poll option that users can vote on.
class PollOption {
  final String id;
  final String text;
  final List<String> voterIds;

  const PollOption({
    required this.id,
    required this.text,
    this.voterIds = const [],
  });

  factory PollOption.create({required String text}) {
    return PollOption(id: const Uuid().v4(), text: text);
  }

  factory PollOption.fromMap(Map<String, dynamic> data) {
    return PollOption(
      id: SerializationUtils.safeString(data, 'id'),
      text: SerializationUtils.safeString(data, 'text'),
      voterIds: SerializationUtils.safeStringList(data, 'voterIds'),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'text': text,
      'voterIds': voterIds,
    };
  }

  PollOption copyWith({List<String>? voterIds}) {
    return PollOption(
      id: id,
      text: text,
      voterIds: voterIds ?? this.voterIds,
    );
  }

  int get voteCount => voterIds.length;

  bool hasVoted(String userId) => voterIds.contains(userId);
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
      createdAt: DateTime.now(),
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
      allowMultipleChoices:
          SerializationUtils.safeBool(data, 'allowMultipleChoices'),
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
  bool get isExpired => deadline != null && DateTime.now().isAfter(deadline!);

  /// Whether voting is still allowed.
  bool get isActive => !isClosed && !isExpired;
}
