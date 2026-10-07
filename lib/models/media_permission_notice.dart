import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart' show ImageSource;

import 'package:butlery/core/utils/os_permission_helper.dart';

/// What a camera or photo-library answer leaves to explain where an image
/// is added (flow 07, flows-roles-budget.md:98-106): which source was asked
/// for and what the OS answered.
@immutable
class MediaPermissionNotice {
  const MediaPermissionNotice({required this.source, required this.outcome});

  /// The notice a pick's permission answer calls for, or null when it calls
  /// for none. Limited access is its own state with a way to choose more
  /// (produktregler.md:684), so it is kept even though the pick went ahead.
  static MediaPermissionNotice? after(
    ImageSource source,
    OsPermissionOutcome outcome,
  ) => outcome == OsPermissionOutcome.granted
      ? null
      : MediaPermissionNotice(source: source, outcome: outcome);

  final ImageSource source;
  final OsPermissionOutcome outcome;

  @override
  bool operator ==(Object other) =>
      other is MediaPermissionNotice &&
      other.source == source &&
      other.outcome == outcome;

  @override
  int get hashCode => Object.hash(source, outcome);
}
