import 'package:flutter/foundation.dart';

/// What a bulk tag delete did, per tag id (P5-U33).
///
/// The delete runs in chunks, each one atomic (BUT-994), so a later chunk can
/// fail after an earlier one landed. produktregler.md:905-909 (§ 17.6) makes
/// that a third outcome: the caller names what went and keeps the rest
/// selected, so it needs the ids on both sides, never only a count.
@immutable
class PersonalTagBulkDeleteResult {
  const PersonalTagBulkDeleteResult({
    required this.deletedIds,
    required this.failedIds,
  });

  /// Nothing went, for example when the user is not signed in.
  PersonalTagBulkDeleteResult.noneDeleted(List<String> tagIds)
    : deletedIds = const [],
      failedIds = List.unmodifiable(tagIds);

  /// The tags that are gone.
  final List<String> deletedIds;

  /// The tags that are still there.
  final List<String> failedIds;

  /// Every tag went.
  bool get isComplete => failedIds.isEmpty;

  /// Some went and some did not.
  bool get isPartial => deletedIds.isNotEmpty && failedIds.isNotEmpty;
}
