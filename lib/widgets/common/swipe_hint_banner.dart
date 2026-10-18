import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:butlery/core/extensions/localization_extension.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/theme/app_mode_colors.dart';
import 'package:butlery/theme/app_text_styles.dart';
import 'package:butlery/widgets/common/icons/butlery_glyph.dart';
import 'package:butlery/widgets/common/icons/butlery_icons.dart';

/// BUT-982 / BUT-1199: first-use, dismissible hint teaching an otherwise-
/// invisible gesture (swipe-to-edit/delete on recipe cards, long-press a
/// cooking step to start a timer, swipe a shopping item to claim it).
///
/// Self-contained: callers drop it in and it owns its own seen-state, so it
/// adds no persistence logic to the host view. It stops for good once the
/// gesture has been used ([markUsed]), once it is dismissed, or after
/// [maxShows] visits (produktregler § 16.5). Renders nothing while the state
/// loads.
///
/// Defaults reproduce the original recipe-swipe hint (BUT-982) so existing
/// `const SwipeHintBanner()` call sites are unchanged; new surfaces pass a
/// distinct [seenKey], [icon], and [message] (BUT-1199).
class SwipeHintBanner extends StatefulWidget {
  const SwipeHintBanner({
    super.key,
    this.seenKey = recipeSwipeSeenKey,
    this.icon = ButleryIcons.hand,
    this.message,
    this.onInk = false,
  });

  /// SharedPreferences key for the once-per-device dismiss flag.
  final String seenKey;

  /// Leading glyph — the gesture cue (swipe, touch_app, …).
  final IconData icon;

  /// Hint copy. When null, falls back to the recipe-swipe string so the
  /// zero-arg constructor keeps its original behaviour.
  final String? message;

  /// Drawn on the ink base (cooking mode): a tonal on-ink surface with paper
  /// text, as Skarmar v12 del 1 #lagastaende draws the tip.
  final bool onInk;

  /// Visits after which the hint stays away on its own.
  static const int maxShows = 3;

  /// Hints already counted as a visit in this app run. A banner that remounts
  /// (selection mode, grid/list switch) is still the same visit.
  static final Set<String> _countedThisRun = {};

  @visibleForTesting
  static void startNewRunForTest() => _countedThisRun.clear();

  static String _shownKey(String seenKey) => '${seenKey}_shown';

  /// The gesture was used, so the hint has nothing left to teach.
  static Future<void> markUsed(String seenKey) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(seenKey, true);
  }

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
    final shownKey = SwipeHintBanner._shownKey(widget.seenKey);
    final shown = prefs.getInt(shownKey) ?? 0;
    final counted = SwipeHintBanner._countedThisRun.contains(widget.seenKey);
    final visible = !seen && (counted || shown < SwipeHintBanner.maxShows);
    if (visible && !counted) {
      SwipeHintBanner._countedThisRun.add(widget.seenKey);
      await prefs.setInt(shownKey, shown + 1);
    }
    if (mounted) setState(() => _visible = visible);
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
    final foreground = widget.onInk ? cs.onPrimary : cs.onSurface;

    return Container(
      margin: const EdgeInsets.symmetric(
        horizontal: AppDimensions.space8,
        vertical: AppDimensions.space4,
      ),
      padding: const EdgeInsetsDirectional.fromSTEB(
        AppDimensions.space8,
        AppDimensions.space4,
        AppDimensions.space4,
        AppDimensions.space4,
      ),
      decoration: BoxDecoration(
        // The information surface, without a border (B83-2b), with the
        // control radius (B83-2c).
        color: widget.onInk
            ? AppModeColors.surfaceRaisedOnInk()
            : context.modeColors.surfaceTintWarning,
        borderRadius: BorderRadius.circular(AppDimensions.radiusControl),
      ),
      child: Row(
        children: [
          ButleryIcon(
            widget.icon,
            size: AppDimensions.iconSizeM,
            color: foreground,
          ),
          const SizedBox(width: AppDimensions.space8),
          Expanded(
            child: Text(
              widget.message ?? context.l10n.recipeSwipeHintText,
              style: AppTextStyles.bodySmall.copyWith(
                color: widget.onInk
                    ? cs.onPrimary
                    : AppModeColors.textBody(cs.brightness),
              ),
            ),
          ),
          IconButton(
            icon: const ButleryIcon(
              ButleryIcons.x,
              size: AppDimensions.iconSizeS,
            ),
            tooltip: context.l10n.commonDismiss,
            color: foreground,
            onPressed: _dismiss,
          ),
        ],
      ),
    );
  }
}
