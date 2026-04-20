// lib/widgets/cooking/cooking_session_card.dart
//
// BUT-408: "Erik lagar just nu" card.
// Appears below MainViewHeader on mina_recept_view and veckomeny_view when
// one or more friends in the user's FriendCategory groups are currently in
// cooking mode. Square dark-green panel with a gold pulse dot.
//
// Empty/idle state: returns SizedBox.shrink() — no skeleton, no empty copy.

import 'package:flutter/material.dart';

import 'package:butlery/core/constants/routes.dart';
import 'package:butlery/core/extensions/localization_extension.dart';
import 'package:butlery/core/providers/application_provider.dart';
import 'package:butlery/l10n/app_localizations.dart';
import 'package:butlery/models/cooking/cooking_session.dart';
import 'package:butlery/services/unified/unified_recipe_service.dart';
import 'package:butlery/theme/app_colors.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/theme/app_text_styles.dart';
import 'package:butlery/widgets/common/indicators/pulse_dot.dart';

/// Compose the primary presence line from one or more [names] cooking a
/// single [recipe].
String _composeCookingLine(
    AppLocalizations l10n, List<String> names, String recipe) {
  if (names.isEmpty) return '';
  if (names.length == 1) {
    return l10n.cookingNowSingle(names.first, recipe);
  }
  final joined = names.length == 2
      ? '${names[0]} & ${names[1]}'
      : '${names.take(names.length - 1).join(', ')} & ${names.last}';
  return l10n.cookingNowMerge(joined, recipe);
}

/// Live cooking presence card. Pass the latest stream value as [sessions].
///
/// Grouping rules:
/// - No sessions → renders nothing (hidden via [SizedBox.shrink]).
/// - One session → "\<name\> lagar \<recipe\>".
/// - Multiple sessions on the SAME recipe → merged ("\<a\> & \<b\> lagar \<recipe\>")
///   keyed on the first session's recipe.
/// - Multiple sessions across DIFFERENT recipes → the earliest-started
///   session wins the card, remaining sessions remain live in the data but
///   aren't stacked in UI (staff-engineer tradeoff: one card stays legible
///   and predictable; stacking can come later if needed).
class CookingSessionCard extends StatelessWidget {
  const CookingSessionCard({
    required this.sessions,
    super.key,
  });

  /// The raw, ordered list of live sessions for the group being displayed.
  /// Pass `const []` when the stream is idle — the widget hides itself.
  final List<CookingSession> sessions;

  @override
  Widget build(BuildContext context) {
    if (sessions.isEmpty) return const SizedBox.shrink();

    final l10n = context.l10n;

    // Primary session anchors the recipe; same-recipe peers merge in.
    final primary = sessions.first;
    final peers = sessions
        .where((s) => s.recipeId == primary.recipeId)
        .toList(growable: false);
    final names = peers.map((s) => s.userName).toList(growable: false);

    final primaryLine = _composeCookingLine(l10n, names, primary.recipeTitle);
    final eyebrow = l10n.cookingNowEyebrow;

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppDimensions.spacingMd,
        AppDimensions.spacingMd,
        AppDimensions.spacingMd,
        0,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _onTap(context, primary),
          child: Semantics(
            button: true,
            label: '$primaryLine. $eyebrow',
            child: Container(
              decoration: const BoxDecoration(
                color: AppColors.forestGreenDark,
                border: Border(
                  left: BorderSide(
                    color: AppColors.starGold,
                    width: 3,
                  ),
                ),
              ),
              padding: const EdgeInsets.symmetric(
                horizontal: AppDimensions.spacingMd,
                vertical: AppDimensions.spacingSm + AppDimensions.spacingXs,
              ),
              child: Row(
                children: [
                  const PulseDot(
                    color: AppColors.starGold,
                    size: 10,
                  ),
                  const SizedBox(width: AppDimensions.spacingMd),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          eyebrow,
                          style: AppTextStyles.labelSmall.copyWith(
                            color: AppColors.starGold,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 1.8,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          primaryLine,
                          style: AppTextStyles.bodyMedium.copyWith(
                            color: AppColors.textOnPrimary,
                            fontWeight: FontWeight.w600,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    Icons.chevron_right,
                    color: AppColors.textOnPrimary.withValues(alpha: 0.6),
                    size: AppDimensions.iconSizeM,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Navigate to recipe detail. The router expects a full [Recipe] argument,
  /// so we resolve it from the user's local [UnifiedRecipeService] cache.
  /// If the recipe isn't available locally (friend is cooking a recipe the
  /// current user doesn't have access to), this is a silent no-op — the
  /// card still shows the presence, there's just nothing to navigate to.
  void _onTap(BuildContext context, CookingSession session) {
    final service = ServiceLocator.tryGet<UnifiedRecipeService>();
    final recipe = service?.getRecipeById(session.recipeId);
    if (recipe == null) return;
    Navigator.pushNamed(context, Routes.receptDetalj, arguments: recipe);
  }
}
