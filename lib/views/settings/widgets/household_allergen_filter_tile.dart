// BUT-1465: opt out of household-wide allergen filtering in the weekly menu.
//
// Extracted from settings_hub_view.dart to keep that file under the 500-line
// limit (CLAUDE.md rule #2). Visible only when a household exists; persists
// immediately via UserService (mirrors AutoAddPantryTile). Turning it OFF
// requires confirming an explicit child-safety warning that names the allergens
// which opting out actually stops filtering; turning it back ON is frictionless.

import 'package:flutter/material.dart';
import 'package:butlery/core/extensions/localization_extension.dart';
import 'package:butlery/core/providers/application_provider.dart';
import 'package:butlery/core/utils/snackbar_utils.dart';
import 'package:butlery/models/user_allergen_preferences.dart';
import 'package:butlery/services/household_service.dart';
import 'package:butlery/services/user_service.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/theme/app_text_styles.dart';
import 'package:butlery/theme/butlery_colors_extension.dart';
import 'package:butlery/widgets/common/dialogs/base_dialog.dart';

/// Settings toggle: opt out of household-wide allergen filtering in menus.
///
/// Public (not `_...`) so widget tests can render it in isolation without the
/// full [SettingsHubView] dependency graph.
class HouseholdAllergenFilterTile extends StatefulWidget {
  const HouseholdAllergenFilterTile({super.key});

  @override
  State<HouseholdAllergenFilterTile> createState() =>
      _HouseholdAllergenFilterTileState();
}

class _HouseholdAllergenFilterTileState
    extends State<HouseholdAllergenFilterTile> {
  late final UserService _userService;
  HouseholdService? _householdService;

  @override
  void initState() {
    super.initState();
    _userService = ServiceLocator.get<UserService>();
    _householdService = ServiceLocator.tryGet<HouseholdService>();
    // HouseholdService isn't a Listenable; hasHousehold is read live on each
    // build and rarely changes while this screen is open. UserService drives
    // rebuilds when the toggle persists.
    _userService.addListener(_onExternalChange);
  }

  @override
  void dispose() {
    _userService.removeListener(_onExternalChange);
    super.dispose();
  }

  void _onExternalChange() {
    if (mounted) setState(() {});
  }

  Future<void> _onChanged(bool value) async {
    if (value) {
      // Re-enabling protection is frictionless — no confirmation.
      await _persist(true);
      return;
    }
    // Turning OFF lowers a safety net for household members (incl. a child).
    // Fetch the household's tracked allergens so the warning can name the ones
    // opting out actually exposes, then require an explicit confirm.
    final aggregate = await _householdService?.aggregateAllergenPreferences();
    if (!mounted) return;
    final confirmed = await _confirmTurnOff(aggregate);
    if (confirmed == true) {
      await _persist(false);
    }
    // If not confirmed, nothing persists — the controlled switch never moved
    // (still bound to the unchanged `on` value), so it stays ON.
  }

  /// Persists the flag, surfacing an error if the write fails so the user is
  /// never left believing they changed a safety setting that did not save.
  Future<void> _persist(bool value) async {
    try {
      await _userService.setUseHouseholdAllergens(value);
    } catch (_) {
      if (mounted) {
        SnackBarUtils.showError(context, context.l10n.settingsSaveFailed);
      }
    }
  }

  Future<bool?> _confirmTurnOff(HouseholdAllergenAggregate? aggregate) {
    final l10n = context.l10n;
    // BUT-1663: an incomplete roster produces a widened, safety-floored set
    // that is NOT the household's real allergen list. Naming it here would
    // tell Malin she is unprotecting allergies nobody has while omitting the
    // ones they do — so drop to the generic body and say the list is partial.
    final rosterComplete = aggregate?.isRosterComplete ?? true;
    final names = rosterComplete
        ? _newlyUnprotectedNames(aggregate?.preferences)
        : '';
    final body = names.isEmpty
        ? l10n.householdAllergenOffBodyGeneric
        : l10n.householdAllergenOffBody(names);
    return ConfirmationDialog.show(
      context,
      title: l10n.householdAllergenOffTitle,
      message: rosterComplete
          ? body
          : '$body\n\n${l10n.householdAllergenRosterIncomplete}',
      titleIcon: Icons.warning_amber,
      // Weighted red confirm (isDangerous) — this is the one settings toggle
      // whose wrong tap has a child-safety consequence, so it should carry
      // gravity. But it is NOT a delete, so override the default trash icon
      // with a warning icon (base_dialog defaults primaryActionIcon to
      // Icons.delete when isDangerous).
      isDangerous: true,
      primaryActionIcon: Icons.warning_amber,
      primaryActionText: l10n.commonTurnOff,
      secondaryActionText: l10n.commonCancel,
    );
  }

  /// Natural-language list of the allergens that opting OUT actually stops
  /// filtering — the household union MINUS the owner's OWN tracked allergens,
  /// which single-user (owner-only) filtering still protects after the opt-out.
  /// Naming an owner-own allergen would be a false statement in the safety
  /// dialog (it stays filtered either way). Empty when opting out exposes
  /// nothing new (then the generic body is used).
  String _newlyUnprotectedNames(UserAllergenPreferences? prefs) {
    if (prefs == null) return '';
    final owner = _userService.allergenPreferences;
    final allergens = prefs.trackedAllergens.difference(owner.trackedAllergens);
    final dietary = prefs.trackedDietary.difference(owner.trackedDietary);
    final labels = <String>[
      ...allergens.map(AllergenPreferenceOptions.getAllergenLabel),
      ...dietary.map(AllergenPreferenceOptions.getDietaryLabel),
    ];
    if (labels.isEmpty) return '';
    if (labels.length == 1) return labels.first;
    final and = context.l10n.commonListAnd;
    return '${labels.sublist(0, labels.length - 1).join(', ')} $and ${labels.last}';
  }

  @override
  Widget build(BuildContext context) {
    // Self-gate: only meaningful when the user actually has a household.
    if (!(_householdService?.hasHousehold ?? false)) {
      return const SizedBox.shrink();
    }
    final cs = Theme.of(context).colorScheme;
    final on = _userService.currentUserProfile?.useHouseholdAllergens ?? true;
    final warning = context.butleryColors.warning;

    return SwitchListTile(
      secondary: Icon(
        Icons.groups_outlined,
        color: on ? cs.onSurfaceVariant : warning,
      ),
      title: Text(
        context.l10n.householdAllergenFilterTitle,
        style: AppTextStyles.bodyMedium,
      ),
      subtitle: on
          ? Text(
              context.l10n.householdAllergenFilterSubtitleOn,
              style: AppTextStyles.bodySmall.copyWith(
                color: cs.onSurfaceVariant,
              ),
            )
          : Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.warning_amber,
                  size: AppDimensions.iconSizeS,
                  color: warning,
                ),
                const SizedBox(width: AppDimensions.spacingXxs),
                Expanded(
                  child: Text(
                    context.l10n.householdAllergenFilterSubtitleOff,
                    style: AppTextStyles.bodySmall.copyWith(color: warning),
                  ),
                ),
              ],
            ),
      value: on,
      onChanged: _onChanged,
    );
  }
}
