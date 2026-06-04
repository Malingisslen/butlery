import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:butlery/core/extensions/localization_extension.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/theme/app_text_styles.dart';

/// BUT-982 / BUT-1199: first-use, dismissible hint teaching an otherwise-
/// invisible gesture (swipe-to-edit/delete on recipe cards, long-press a
/// cooking step to start a timer, swipe a shopping item to claim it).
///
/// Self-contained: callers drop it in and it owns its own seen-state, so it
/// adds no persistence logic to the host view. Shown once per device — on
/// dismiss it sets a SharedPreferences flag (keyed by [seenKey]) and never
/// renders again. Renders nothing while the flag loads or once it has been seen.
///
/// Defaults reproduce the original recipe-swipe hint (BUT-982) so existing
/// `const SwipeHintBanner()` call sites are unchanged; new surfaces pass a
/// distinct [seenKey], [icon], and [message] (BUT-1199).
class SwipeHintBanner extends StatefulWidget {
  const SwipeHintBanner({
    super.key,
    this.seenKey = recipeSwipeSeenKey,
    this.icon = Icons.swipe,
    this.message,
  });

  /// SharedPreferences key for the once-per-device dismiss flag.
  final String seenKey;

  /// Leading glyph — the gesture cue (swipe, touch_app, …).
  final IconData icon;

  /// Hint copy. When null, falls back to the recipe-swipe string so the
  /// zero-arg constructor keeps its original behaviour.
  final String? message;

  /// Default key for the recipe-list swipe hint (BUT-982).
  static const String recipeSwipeSeenKey = 'butlery_hint_recipe_swipe_seen';

  /// Cooking-mode: long-press a step to start a timer (BUT-1199).
  static const String cookingStepSeenKey = 'butlery_hint_cooking_step_seen';

  /// Collaborative shopping: swipe an item to claim it (BUT-1199).
  static const String shoppingClaimSeenKey = 'butlery_hint_shopping_claim_seen';

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
    final seen = prefs.getBool(widget.seenKey) ?? false;
    if (mounted) setState(() => _visible = !seen);
  }

  Future<void> _dismiss() async {
    setState(() => _visible = false);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(widget.seenKey, true);
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
          Icon(widget.icon, size: AppDimensions.iconSizeM, color: cs.primary),
          const SizedBox(width: AppDimensions.spacingSm),
          Expanded(
            child: Text(
              widget.message ?? context.l10n.recipeSwipeHintText,
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
