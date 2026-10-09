// lib/services/attribution_source.dart

import 'package:butlery/core/l10n/app_locale.dart';
import 'package:butlery/core/providers/application_provider.dart';
import 'package:butlery/services/user_service.dart';

/// Who the signed-in user is SHOWN as on a document other people read: a
/// message, a comment, a shared menu or list (BUT-2009).
///
/// Profile only. The Firebase Auth name and photo are the Google/Apple
/// account's, which the user never chose to show, and `on-profile-updated.ts`
/// and account deletion maintain only the profile copies — so an Auth-sourced
/// stamp is both unconsented and outside both of them.
///
/// Read at each call, never cached, so a rename in the same session is what
/// the next write carries. Name and photo travel together so a writer cannot
/// take one from here and the other from Auth.
///
/// The default resolves [UserService] through the service locator at call
/// time; tests pass [userService].
class AttributionSource {
  AttributionSource({UserService? Function()? userService})
    : _userService = userService ?? ServiceLocator.tryGet<UserService>;

  final UserService? Function() _userService;

  String get displayName =>
      _userService()?.attributionDisplayName ??
      AppLocale.current.displayUnknownUser;

  String? get avatarUrl => _userService()?.profileAvatarUrl;
}
