// BUT-1693: share your OWN allergen list with your household, so the weekly
// menu stops substituting a guessed four-allergen floor for you.
//
// Direction A of the design preview, chosen whole by Malin 2026-08-12: a second
// switch row directly under the household-allergen filter, padlock icon, the
// TITLE saying what you can do and the SUBTITLE saying what the household sees
// right now. Turning it ON opens the Art. 9(2)(a) consent copy as a dialog;
// turning it OFF has no dialog at all, because withdrawing a consent must never
// be harder than giving it (Art. 7(3)). The row is hidden entirely when there is
// no household to share with — not shown disabled with an explanation.

import 'package:clock/clock.dart';
import 'package:flutter/material.dart';
import 'package:butlery/core/exceptions/permission_exceptions.dart';
import 'package:butlery/core/extensions/localization_extension.dart';
import 'package:butlery/core/providers/application_provider.dart';
import 'package:butlery/core/utils/logger.dart';
import 'package:butlery/core/utils/snackbar_utils.dart';
import 'package:butlery/models/household_allergen_share.dart';
import 'package:butlery/models/profile_lookup.dart';
import 'package:butlery/models/user_allergen_preferences.dart';
import 'package:butlery/repositories/interfaces/household_allergen_share_repository.dart';
import 'package:butlery/repositories/interfaces/household_repository.dart';
import 'package:butlery/services/feature_flags/feature_flag_service.dart';
import 'package:butlery/services/permission_service.dart';
import 'package:butlery/services/user_service.dart';
import 'package:butlery/theme/app_text_styles.dart';
import 'package:butlery/theme/butlery_colors_extension.dart';
import 'package:butlery/widgets/common/dialogs/base_dialog.dart';

/// Settings toggle: share your own allergen list with your household.
///
/// Public (not `_...`) so widget tests can render it without the full
/// [SettingsHubView] dependency graph, mirroring [HouseholdAllergenFilterTile].
class HouseholdAllergenSharingTile extends StatefulWidget {
  const HouseholdAllergenSharingTile({super.key});

  @override
  State<HouseholdAllergenSharingTile> createState() =>
      _HouseholdAllergenSharingTileState();
}

class _HouseholdAllergenSharingTileState
    extends State<HouseholdAllergenSharingTile> {
  /// The household this member would share into, resolved once. Null means
  /// there is nothing to share with — the row stays hidden rather than
  /// offering a switch whose result nobody could read.
  String? _householdId;

  /// Whether a share document already exists for this member. Null while the
  /// first read is in flight; the row stays hidden until it answers, because a
  /// switch that flips under the user's eyes is worse than a beat of nothing.
  bool? _isSharing;

  bool _busy = false;

  /// Read once in [initState] — the widgets layer resolves services there, not
  /// in `build`.
  late final bool _featureEnabled;

  @override
  void initState() {
    super.initState();
    _featureEnabled =
        ServiceLocator.tryGet<FeatureFlagService>()?.isEnabled(
          FeatureFlags.enableHouseholdAllergenSharing,
        ) ??
        false;
    _resolve();
  }

  /// Resolved once per mount. A failed read leaves the row hidden until the
  /// member returns to Settings — there is deliberately no in-place retry: the
  /// hidden branch of [build] returns before touching any inherited widget, so
  /// this element registers no dependency and nothing could wake it. Recovery
  /// is a remount, which leaving and re-entering the screen performs.
  Future<void> _resolve() async {
    if (!_featureEnabled) return;
    try {
      final households = ServiceLocator.tryGet<HouseholdRepository>();
      final shares = ServiceLocator.tryGet<HouseholdAllergenShareRepository>();
      // The PERMISSION handle: `getForUser` refuses a caller that is not the
      // named user, so this is an auth question, not a profile one.
      final userId = ServiceLocator.tryGet<PermissionService>()?.currentUserId;
      if (households == null || shares == null || userId == null) return;

      final mine = await households.getForUser(userId);
      if (mine.isEmpty) return; // no household → the row stays hidden
      final householdId = mine.first.id;
      final own = await shares.getOwn(householdId);
      if (!mounted) return;
      setState(() {
        _householdId = householdId;
        _isSharing = own != null;
      });
    } catch (e) {
      // Leaving the row hidden is the honest outcome: we cannot say whether
      // this member is sharing, and a switch drawn in the wrong position would
      // tell them something false about their own health data.
      AppLogger.warning('Could not resolve the allergen-sharing state: $e');
    }
  }

  Future<void> _onChanged(bool value) async {
    if (_busy) return;
    if (value) {
      final consented = await _confirmShare();
      if (consented != true) return; // the switch never moved
      if (!mounted) return; // the screen left while the dialog was up
      await _grant();
      return;
    }
    // Withdrawal is one tap, by design (Art. 7(3)).
    await _revoke();
  }

  Future<bool?> _confirmShare() {
    final l10n = context.l10n;
    return ConfirmationDialog.show(
      context,
      title: l10n.householdAllergenShareConfirmTitle,
      message: l10n.householdAllergenShareConfirmBody,
      titleIcon: Icons.lock_outline,
      primaryActionIcon: Icons.lock_outline,
      primaryActionText: l10n.householdAllergenShareConfirmAction,
      secondaryActionText: l10n.commonCancel,
    );
  }

  Future<void> _grant() async {
    final householdId = _householdId;
    final shares = ServiceLocator.tryGet<HouseholdAllergenShareRepository>();
    final userId = ServiceLocator.tryGet<PermissionService>()?.currentUserId;
    // The PROFILE, never `UserService.allergenPreferences`: that getter falls
    // back to `UserAllergenPreferences.defaults` — four allergens AND two
    // diets — for anyone who has never opened the allergen screen. Sharing
    // that would store a declaration the member never made, and because a
    // tracked diet is a HARD menu requirement it would plan the whole
    // household's menu vegan. The read side refuses exactly this substitution
    // (HouseholdAllergenShare.fromMap); the write side must too.
    final userService = ServiceLocator.tryGet<UserService>();
    if (householdId == null || shares == null || userId == null) return;

    // Latched BEFORE the first await, not just before the write: the profile
    // re-read below is an await too, and leaving the switch live across it lets
    // a second tap re-open the consent dialog and race a second create — whose
    // `ValidationException` would then route into the replace branch and revoke
    // a live allergen share for a moment. Every exit below is inside the try,
    // so the latch always clears.
    setState(() => _busy = true);
    try {
      var profile = userService?.currentUserProfile;
      if (profile != null && !profile.settingsMerged) {
        // `currentUserProfile` is a snapshot from sign-in, and `settingsMerged`
        // is written by `fetchProfile` alone — no settings screen re-runs it.
        // So a member whose settings sub-doc blipped once at login would be
        // refused for the whole session, and no instruction we could print
        // would clear it. `lookupUserProfile` re-reads for self whenever the
        // flag is false (it deliberately never caches an unmerged self
        // profile), which is what makes "try again" a real remedy.
        final lookup = await userService!.lookupUserProfile(userId);
        if (!mounted) return;
        // `found` means the READ succeeded, not that the settings came with
        // it — for anyone but the signed-in user it carries an unmerged
        // profile by design. For THIS call site the status check is dead
        // (`userId` is always self, so an unmerged read arrives as
        // `foundSettingsUnavailable`); it is kept as defence in depth for a
        // future non-self caller, and the `settingsMerged` re-check below is
        // what actually decides.
        profile = lookup.status == ProfileLookupStatus.found
            ? lookup.profile
            : null;
      }
      // `profile.uid != userId` is the account-switch window, and NOTHING
      // downstream can close it: the id is `PermissionService.currentUserId`
      // and the repository compares the share against `requireCurrentUserId()`
      // — both read live auth, so they agree with each other while the
      // ALLERGENS still come from a `UserService` profile left behind by the
      // previous account. Rules see the same two live values. This line is the
      // only thing standing between one person's Art. 9 list and another
      // person's declaration, so do not delete it as redundant.
      if (profile == null || !profile.settingsMerged || profile.uid != userId) {
        // We cannot read this member's own settings, so there is nothing
        // truthful to share. Refuse rather than invent — an empty share would
        // read downstream as "I have no allergies" and take away the floor they
        // have today.
        SnackBarUtils.showError(
          context,
          context.l10n.householdAllergenShareSettingsUnread,
        );
        return;
      }
      // Legitimately null: settings were read and the member entered nothing.
      // That IS a declaration of "no allergies", and it is theirs to make.
      final prefs = profile.allergenPreferences;

      // One construction site: two copies drifted once already, and two
      // separate `clock.now()` calls can straddle a tick, leaving the consent
      // timestamp and the mirror timestamp disagreeing about the same act.
      HouseholdAllergenShare buildShare() {
        final now = clock.now();
        return HouseholdAllergenShare(
          householdId: householdId,
          userId: userId,
          trackedAllergens: prefs?.trackedAllergens ?? const {},
          trackedDietary: prefs?.trackedDietary ?? const {},
          // NOT `?? false`: a member who entered nothing runs on the class
          // default, which is TRUE. Sharing false would impose a caution they
          // never chose — and because the household AND-folds this field, one
          // such share strips every unverified recipe from everyone's menu.
          includeUnknownInMenu:
              prefs?.includeUnknownInMenu ??
              UserAllergenPreferences.defaults.includeUnknownInMenu,
          consentGranted: true,
          consentVersion: HouseholdAllergenShare.currentConsentVersion,
          consentGrantedAt: now,
          updatedAt: now,
        );
      }

      // The nested try keeps the replace branch inside the scope that owns
      // `buildShare`; the outer one owns the busy latch.
      try {
        // The consent record is written HERE, in the same act as the list —
        // the timestamp is the moment the member said yes, and the version is
        // the wording they were shown.
        await shares.create(buildShare());
        if (mounted) setState(() => _isSharing = true);
      } on ValidationException {
        // M4: a document already sits there that `getOwn` refused to hand back
        // (its consent record is unreadable), so the switch showed OFF while
        // the member's allergens were in a household-readable collection — and
        // granting could never succeed. The member is consenting right now, so
        // replace it: revoke, then write a fresh record.
        await shares.revoke(householdId);
        await shares.create(buildShare());
        if (mounted) setState(() => _isSharing = true);
      }
    } catch (e) {
      AppLogger.warning('Could not share the allergen list: $e');
      if (mounted) {
        SnackBarUtils.showError(
          context,
          context.l10n.householdAllergenShareFailed,
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _revoke() async {
    final householdId = _householdId;
    final shares = ServiceLocator.tryGet<HouseholdAllergenShareRepository>();
    if (householdId == null || shares == null) return;

    setState(() => _busy = true);
    try {
      await shares.revoke(householdId);
      if (!mounted) return;
      setState(() => _isSharing = false);
      SnackBarUtils.showSuccess(
        context,
        context.l10n.householdAllergenShareStopped,
      );
    } catch (e) {
      AppLogger.warning('Could not stop sharing the allergen list: $e');
      if (mounted) {
        SnackBarUtils.showError(
          context,
          context.l10n.householdAllergenShareFailed,
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final sharing = _isSharing;
    // Hidden until we know all three: the feature is on, there is a household
    // to share with, and whether this member already shares. Malin's call —
    // no disabled row with an explanation.
    if (!_featureEnabled || _householdId == null || sharing == null) {
      return const SizedBox.shrink();
    }

    final cs = Theme.of(context).colorScheme;
    final l10n = context.l10n;

    return SwitchListTile(
      secondary: Icon(
        Icons.lock_outline,
        color: sharing ? cs.onSurfaceVariant : context.butleryColors.warning,
      ),
      title: Text(
        l10n.householdAllergenShareTitle,
        style: AppTextStyles.bodyMedium,
      ),
      subtitle: Text(
        sharing
            ? l10n.householdAllergenShareSubtitleOn
            : l10n.householdAllergenShareSubtitleOff,
        style: AppTextStyles.bodySmall.copyWith(color: cs.onSurfaceVariant),
      ),
      value: sharing,
      onChanged: _busy ? null : _onChanged,
    );
  }
}
