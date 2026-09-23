/// P5-U26b: where a user's overwritten versions are kept for 30 days.
///
/// See `OverwrittenVersion` for the rule and the storage path. Every call acts
/// on the signed-in user's own versions only; there is no way to read or
/// write another user's.
library;

import 'package:butlery/models/realtime/overwritten_version.dart';
import 'package:butlery/models/realtime/realtime_resource.dart';

abstract class OverwrittenVersionRepository {
  /// Keeps [version] for the signed-in user and returns it with its id.
  /// Throws when nobody is signed in or [version] belongs to someone else.
  Future<OverwrittenVersion> keep(OverwrittenVersion version);

  /// The signed-in user's kept versions for [entity], newest first, limited
  /// to [resourceId] when given. Rows that cannot be restored are left out.
  /// Expiry is the caller's filter, so a stream that stays open across the
  /// 30-day line can still drop a row the moment it expires.
  Stream<List<OverwrittenVersion>> watch({
    required ConflictEntity entity,
    String? resourceId,
  });

  /// Removes one of the signed-in user's kept versions.
  Future<void> forget(String versionId);
}
