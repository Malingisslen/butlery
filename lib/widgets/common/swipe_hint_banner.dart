import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:butlery/core/extensions/localization_extension.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/theme/app_text_styles.dart';

/// BUT-982: first-use, dismissible hint teaching the otherwise-invisible
/// swipe-to-edit / swipe-to-delete gesture on recipe cards.
///
/// Self-contained: callers just drop in `const SwipeHintBanner()` and it owns
/// its own seen-state, so it adds no persistence logic to the (already large)
/// host view. Shown once per device — on dismiss it sets a SharedPreferences
/// flag and never renders again. Renders nothing while the flag loads or once
/// it has been seen.
class SwipeHintBanner extends StatefulWidget {
  const SwipeHintBanner({super.key});

  /// SharedPreferences key for the once-per-device dismiss flag.
  static const String seenKey = 'butlery_hint_recipe_swipe_seen';

  @override
  State<SwipeHintBanner> createState() => _SwipeHintBannerState();
}

class _SwipeHintBannerState extends State<SwipeHintBanner> {
  /// null while the flag is loading (render nothing), true = show the hint,
  /// false = already seen / just dismissed.
  bool? _visible;

  @override
  void initState() {
    super.initState();
    _loadSeen();
  }

  Future<void> _loadSeen() async {
    final prefs = await SharedPreferences.getInstance();
    final seen = prefs.getBool(SwipeHintBanner.seenKey) ?? false;
    if (mounted) setState(() => _visible = !seen);
  }

  Future<void> _dismiss() async {
    setState(() => _visible = false);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(SwipeHintBanner.seenKey, true);
  }

  @override
  Widget build(BuildContext context) {
    if (_visible != true) return const SizedBox.shrink();
    final cs = Theme.of(context).colorScheme;

    return Container(
      margin: const EdgeInsets.symmetric(
        horizontal: AppDimensions.spacingM,
        vertical: AppDimensions.spacingSm,
      ),
      padding: const EdgeInsetsDirectional.fromSTEB(
        AppDimensions.spacingM,
        AppDimensions.spacingSm,
        AppDimensions.spacingXs,
        AppDimensions.spacingSm,
      ),
      decoration: BoxDecoration(
        color: cs.primaryContainer,
        border: Border.all(color: cs.primary.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Icon(Icons.swipe, size: AppDimensions.iconSizeM, color: cs.primary),
          const SizedBox(width: AppDimensions.spacingSm),
          Expanded(
            child: Text(
              context.l10n.recipeSwipeHintText,
              style: AppTextStyles.bodySmall.copyWith(
                color: cs.onPrimaryContainer,
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close, size: AppDimensions.iconSizeS),
            tooltip: context.l10n.commonDismiss,
            color: cs.onPrimaryContainer,
            visualDensity: VisualDensity.compact,
            onPressed: _dismiss,
          ),
        ],
      ),
    );
  }
}
