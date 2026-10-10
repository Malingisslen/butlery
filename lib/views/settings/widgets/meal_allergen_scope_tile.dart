// BUT-2362: let lunch and middag follow only the people marked home.
//
// Sits under HouseholdAllergenFilterTile and is shown only while that filter
// is on and a household exists, since it narrows that filter. Persists
// immediately via UserService. Turning it ON lowers a safety net for anyone
// marked away, so it asks first; turning it OFF is frictionless.

import 'package:flutter/material.dart';
import 'package:butlery/core/extensions/localization_extension.dart';
import 'package:butlery/core/providers/application_provider.dart';
import 'package:butlery/core/utils/snackbar_utils.dart';
import 'package:butlery/services/household_service.dart';
import 'package:butlery/services/user_service.dart';
import 'package:butlery/theme/app_text_styles.dart';
import 'package:butlery/widgets/common/dialogs/base_dialog.dart';
import 'package:butlery/widgets/common/icons/butlery_glyph.dart';
import 'package:butlery/widgets/common/icons/butlery_icons.dart';

/// Settings toggle: the per-meal allergen choice (default off).
///
/// Public so widget tests can render it without the whole settings hub.
class MealAllergenScopeTile extends StatefulWidget {
  const MealAllergenScopeTile({super.key});

  @override
  State<MealAllergenScopeTile> createState() => _MealAllergenScopeTileState();
}

class _MealAllergenScopeTileState extends State<MealAllergenScopeTile> {
  late final UserService _userService;
  HouseholdService? _householdService;

  @override
  void initState() {
    super.initState();
    _userService = ServiceLocator.get<UserService>();
    _householdService = ServiceLocator.tryGet<HouseholdService>();
    // The household filter above this tile writes through the same service,
    // so this listener also shows and hides the tile when that one changes.
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
    if (!value) {
      await _persist(false);
      return;
    }
    final l10n = context.l10n;
    final confirmed = await ConfirmationDialog.show(
      context,
      title: l10n.mealAllergenScopeOnTitle,
      message: l10n.mealAllergenScopeOnBody,
      titleIcon: ButleryIcons.triangleAlert,
      // Not a delete, so the warning icon replaces the default trash icon.
      isDangerous: true,
      primaryActionIcon: ButleryIcons.triangleAlert,
      primaryActionText: l10n.mealAllergenScopeOnAction,
      secondaryActionText: l10n.commonCancel,
    );
    if (confirmed == true) await _persist(true);
  }

  /// Says when the write fails, so nobody believes a safety setting changed
  /// when it did not.
  Future<void> _persist(bool value) async {
    try {
      await _userService.setUseMealAllergenScope(value);
    } catch (_) {
      if (mounted) {
        SnackBarUtils.showFailure(
          context,
          what: context.l10n.settingsSaveFailed,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final profile = _userService.currentUserProfile;
    final householdFilterOn = profile?.useHouseholdAllergens ?? true;
    if (!(_householdService?.hasHousehold ?? false) || !householdFilterOn) {
      return const SizedBox.shrink();
    }
    final cs = Theme.of(context).colorScheme;
    return SwitchListTile(
      secondary: ButleryIcon(
        ButleryIcons.calendar,
        color: cs.onSurfaceVariant,
      ),
      title: Text(
        context.l10n.mealAllergenScopeTitle,
        style: AppTextStyles.bodyMedium,
      ),
      subtitle: Text(
        context.l10n.mealAllergenScopeSubtitle,
        style: AppTextStyles.bodySmall.copyWith(color: cs.onSurfaceVariant),
      ),
      value: profile?.useMealAllergenScope ?? false,
      onChanged: _onChanged,
    );
  }
}
