import 'package:flutter/foundation.dart' show mapEquals;

import 'package:butlery/core/utils/logger.dart';
import 'package:butlery/models/user_profile.dart';
import 'package:butlery/repositories/interfaces/user_repository.dart';

/// A new profile writes every field, unless the private settings already
/// exist (BUT-2515): the public profile can be gone while the settings are
/// kept, and the defaults of a new profile (no allergies) would replace
/// them. When the answer is unknown the settings are left alone, since a
/// missing settings document is created by the first settings change.
Future<({Set<ProfileField> fields, bool settingsExist})> planNewProfileFields(
  UserRepository repository,
  String uid,
) async {
  try {
    final exist = await repository.settingsDocumentExists(uid);
    return (
      fields: exist ? ProfileField.publicOnly : ProfileField.all,
      settingsExist: exist,
    );
  } catch (e) {
    AppLogger.warning('Could not tell if settings exist; keeping them: $e');
    return (fields: ProfileField.publicOnly, settingsExist: false);
  }
}

/// The fields of [base] this save changes. A field passed as the sentinel
/// is left alone. The always-passed ones (the name, the switches) count
/// only when they differ from [base], since the form shows [base]'s value
/// for every field the user did not touch.
Set<ProfileField> changedProfileFields(
  UserProfile base, {
  required Object unset,
  required String displayName,
  required Object? avatarUrl,
  required bool? isSearchable,
  required bool? allowEmailSearch,
  required Object? cookingSkillLevel,
  required Object? cuisineAffinities,
  required Object? bio,
  required bool? showOnlineStatus,
  required bool? shareActivityToFeed,
  required Map<String, bool>? activityFeedEventTypes,
  required Object? householdSize,
}) => {
  if (displayName != base.displayName) ProfileField.displayName,
  if (!identical(avatarUrl, unset)) ProfileField.avatarUrl,
  if (isSearchable != null && isSearchable != base.isSearchable)
    ProfileField.isSearchable,
  if (allowEmailSearch != null && allowEmailSearch != base.allowEmailSearch)
    ProfileField.allowEmailSearch,
  if (!identical(cookingSkillLevel, unset)) ProfileField.cookingSkillLevel,
  if (!identical(cuisineAffinities, unset)) ProfileField.cuisineAffinities,
  if (!identical(bio, unset)) ProfileField.bio,
  if (showOnlineStatus != null && showOnlineStatus != base.showOnlineStatus)
    ProfileField.showOnlineStatus,
  if (shareActivityToFeed != null &&
      shareActivityToFeed != base.shareActivityToFeed)
    ProfileField.shareActivityToFeed,
  if (activityFeedEventTypes != null &&
      !mapEquals(activityFeedEventTypes, base.activityFeedEventTypes))
    ProfileField.activityFeedEventTypes,
  if (!identical(householdSize, unset)) ProfileField.householdSize,
};
