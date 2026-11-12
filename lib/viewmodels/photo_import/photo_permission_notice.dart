import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';
import 'package:butlery/core/utils/os_permission_helper.dart';

/// Resolves the camera or photo-library permission for a pick (flow 07).
/// The view supplies it, because our explanation before the system prompt
/// needs a BuildContext.
///
/// [askAgain] is true after an explicit "Fråga igen": the user has just asked
/// for the system prompt, so our explanation is not repeated
typedef PhotoPermissionResolver =
    Future<OsPermissionOutcome> Function(ImageSource source, bool askAgain);

/// The permission state the photo-import view explains inline: which source
/// was asked for and what the OS answered.
@immutable
class PhotoPermissionNotice {
  const PhotoPermissionNotice({
    required this.source,
    required this.outcome,
    this.addAsPage = false,
  });

  final ImageSource source;
  final OsPermissionOutcome outcome;

  /// The refused pick was "add a page", so "Fråga igen" adds one too.
  final bool addAsPage;
}
