/// Ownership-conditional placement of the fork ("Skapa kopia" / Create copy)
/// action on the recipe-detail screen (BUT-972, tested by BUT-1178).
///
/// A shared recipe the user does NOT own promotes "Create copy" to a primary
/// app-bar action; an owned or local (no `createdBy`) recipe keeps it as a
/// secondary overflow item. The two placements MUST stay mutually exclusive and
/// exhaustive — exposed here as pure predicates so `recipe_detail_view.dart` and
/// the test assert the same logic (no duplicated condition that could silently
/// drift from the view).
library;

import 'package:butlery/core/extensions/default_value_extensions.dart';

/// Show the fork action as a primary app-bar button: the recipe is shared
/// (`createdBy` is non-empty) and owned by someone else.
bool showForkInAppBar(String? createdBy, String? currentUserId) =>
    createdBy.orEmpty().isNotEmpty && createdBy != currentUserId;

/// Show the fork action as a secondary overflow item: the recipe is local
/// (empty `createdBy`) or owned by the current user.
///
/// This is the exact logical complement of [showForkInAppBar]; the pair is the
/// mutual-exclusion invariant BUT-1178 pins.
bool showForkInOverflow(String? createdBy, String? currentUserId) =>
    createdBy.orEmpty().isEmpty || createdBy == currentUserId;
