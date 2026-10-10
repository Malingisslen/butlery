// BUT-643: show the kcal / protein / carbs / fat strip under a recipe's title.
//
// Off by default. Persists immediately via UserService; the full table is
// always one tap away on the recipe whatever this is set to.

import 'package:flutter/material.dart';
import 'package:butlery/core/extensions/localization_extension.dart';
import 'package:butlery/core/providers/application_provider.dart';
import 'package:butlery/core/utils/snackbar_utils.dart';
import 'package:butlery/services/user_service.dart';
import 'package:butlery/theme/app_text_styles.dart';
import 'package:butlery/widgets/common/icons/butlery_glyph.dart';
import 'package:butlery/widgets/common/icons/butlery_icons.dart';

/// Settings toggle: the nutrition strip on recipes (default off).
///
/// Public so widget tests can render it without the whole settings hub.
class NutritionStripTile extends StatefulWidget {
  const NutritionStripTile({super.key});

  @override
  State<NutritionStripTile> createState() => _NutritionStripTileState();
}

class _NutritionStripTileState extends State<NutritionStripTile> {
  late final UserService _userService;

  @override
  void initState() {
    super.initState();
    _userService = ServiceLocator.get<UserService>();
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
    try {
      await _userService.setShowNutritionStrip(value);
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
    final cs = Theme.of(context).colorScheme;
    return SwitchListTile(
      secondary: ButleryIcon(
        ButleryIcons.barChart,
        color: cs.onSurfaceVariant,
      ),
      title: Text(
        context.l10n.settingsNutritionStripTitle,
        style: AppTextStyles.bodyMedium,
      ),
      subtitle: Text(
        context.l10n.settingsNutritionStripSubtitle,
        style: AppTextStyles.bodySmall.copyWith(color: cs.onSurfaceVariant),
      ),
      value: _userService.currentUserProfile?.showNutritionStrip ?? false,
      onChanged: _onChanged,
    );
  }
}
