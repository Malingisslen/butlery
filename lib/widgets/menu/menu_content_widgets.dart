// lib/widgets/menu/menu_content_widgets.dart
//
// The generated menu's content area: summary, hints, errors and the list.

import 'package:flutter/material.dart';
import 'package:butlery/models/recipe_unified.dart';
import 'package:butlery/core/constants/routes.dart';
import 'package:butlery/viewmodels/menu_viewmodel.dart';
import 'package:butlery/viewmodels/menu/menu_generator.dart'
    show MenuPrefSource;
import 'package:butlery/widgets/common/icons/butlery_glyph.dart';
import 'package:butlery/widgets/common/icons/butlery_icons.dart';
import 'package:butlery/widgets/common/state_widget.dart';
import 'package:butlery/widgets/common/buttons/action_buttons.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/theme/app_opacity.dart';
import 'package:butlery/theme/app_mode_colors.dart';
import 'package:butlery/theme/app_text_styles.dart';
import 'package:butlery/widgets/menu/menu_list_rows.dart';
import 'package:butlery/widgets/menu/menu_view_helpers.dart';
import 'package:butlery/core/extensions/localization_extension.dart';
import 'package:butlery/viewmodels/menu_voting_viewmodel.dart';

/// Widget builders for the Veckomeny (weekly menu) view content.
class MenuContentWidgets {
  /// Builds the menu content area (empty state, error state, or menu list).
  /// UI Redesign: Inline error handling with retry button.
  static Widget buildMenuContent(
    BuildContext context, {
    required MenuViewModel viewModel,
    MenuVotingViewModel? votingViewModel,
    VoidCallback? onRetry,
  }) {
    // UI Redesign: Show inline error if there's an error
    if (viewModel.hasError) {
      return _buildInlineError(
        context,
        viewModel: viewModel,
        onRetry: onRetry,
      );
    }

    if (!viewModel.hasMenu) {
      // UI Redesign: Use noMenu state with pea pod illustration and two buttons
      return StateWidget(
        type: StateType.empty,
        emptyVariant: EmptyStateVariant.noMenu,
        // Custom action with two buttons per plan
        customAction: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ActionButtons.primaryButton(
              context,
              label: context.l10n.menuGenerate,
              icon: ButleryIcons.utensils,
              onPressed: onRetry,
            ),
            const SizedBox(height: AppDimensions.space16),
            ActionButtons.outlinedButton(
              context,
              label: context.l10n.menuChooseManually,
              icon: ButleryIcons.list,
              onPressed: () => Navigator.pushNamed(context, Routes.home),
            ),
          ],
        ),
      );
    }

    return ListView(
      children: [
        MenuListTitle(viewModel: viewModel),
        // BUT-1685: a run built on a household roster we could not fully read
        // was filtered by a widened safety floor, not by the family's real
        // allergies — saying "hushållets allergier" would claim a precision
        // this menu does not have. The warning is keyed to the ROSTER, not to
        // the hidden count: the uncertainty exists even when nothing was
        // hidden.
        if (viewModel.hiddenPrefSource.isRosterIncomplete)
          _buildRosterIncompleteHint(context)
        // BUT-1464 (PM condition 1): explain the pool shrink — a menu made
        // smaller by allergen filtering must never look like a bug.
        else if (viewModel.hiddenByFamilyCount > 0)
          _buildHiddenByFamilyHint(
            context,
            viewModel.hiddenByFamilyCount,
            viewModel.hiddenPrefSource,
          ),
        // BUT-2362: dishes kept for a meal when someone is away are on this
        // list too; say so while the choice is on.
        if (viewModel.mealAllergenScopeOn) _buildMealScopeHint(context),
        for (final entry in MenuViewHelpers.getSortedMenuEntries(
          viewModel.menu,
        )) ...[
          buildMenuSection(
            context,
            viewModel: viewModel,
            category: entry.key,
            recipes: entry.value,
            votingViewModel: votingViewModel,
          ),
        ],
        const SizedBox(
          height: AppDimensions.space24 + AppDimensions.space12,
        ),
      ],
    );
  }

  /// Small muted hint row explaining hidden recipes. Attribution follows
  /// [source]: "hushållets allergier" only when a household/present union
  /// actually filtered; a solo user's own filter gets neutral wording
  /// (review M2 — no over-attribution). Butler voice (states the action,
  /// no exclamation).
  static Widget _buildHiddenByFamilyHint(
    BuildContext context,
    int count,
    MenuPrefSource source,
  ) {
    final cs = Theme.of(context).colorScheme;
    final isFamilyScope = source != MenuPrefSource.singleUser;

    return Padding(
      padding: const EdgeInsets.only(bottom: AppDimensions.space8),
      child: Row(
        children: [
          ButleryIcon(
            isFamilyScope ? ButleryIcons.users : ButleryIcons.user,
            size: AppDimensions.iconSizeS,
            color: cs.onSurfaceVariant,
          ),
          const SizedBox(width: AppDimensions.space4),
          Expanded(
            child: Text(
              isFamilyScope
                  ? context.l10n.menuHiddenByFamilyAllergies(count)
                  : context.l10n.menuHiddenByOwnAllergies(count),
              style: AppTextStyles.bodySmall.copyWith(
                color: cs.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
    );
  }

  static Widget _buildMealScopeHint(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: AppDimensions.space8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ButleryIcon(
            ButleryIcons.calendar,
            size: AppDimensions.iconSizeS,
            color: cs.onSurfaceVariant,
          ),
          const SizedBox(width: AppDimensions.space4),
          Expanded(
            child: Text(
              context.l10n.menuMealAllergenScopeHint,
              style: AppTextStyles.bodySmall.copyWith(
                color: cs.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Warning row for a menu generated from an incomplete roster
  /// (BUT-1663 → BUT-1685). Replaces the hidden-count
  /// hint rather than joining it: attributing the shrink to the family's
  /// allergies would over-claim, since the floor did part of the filtering.
  static Widget _buildRosterIncompleteHint(BuildContext context) {
    // Same icon, size and gold as the settings tile's allergen-warning row
    // (household_allergen_filter_tile) — one caution, two surfaces. NOT
    // cs.secondary: `_buildInlineError` below paints hard failures in that
    // rust, which app_colors.dart says is an accent and never an error colour,
    // so don't copy it here — and a caution must not read as a failure anyway.
    // The gold is icons-and-containers only (app_colors.dart), so the text
    // takes onWarningContainer, which clears WCAG AA on cream.
    final colors = context.modeColors;

    return Padding(
      padding: const EdgeInsets.only(bottom: AppDimensions.space8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ButleryIcon(
            ButleryIcons.triangleAlert,
            size: AppDimensions.iconSizeS,
            color: colors.warning,
          ),
          const SizedBox(width: AppDimensions.space4),
          Expanded(
            child: Text(
              context.l10n.householdAllergenRosterIncomplete,
              style: AppTextStyles.bodySmall.copyWith(
                color: colors.onWarningContainer,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// One meal of the generated list.
  static Widget buildMenuSection(
    BuildContext context, {
    required MenuViewModel viewModel,
    required String category,
    required List<Recipe> recipes,
    MenuVotingViewModel? votingViewModel,
  }) {
    return MenuListSection(
      viewModel: viewModel,
      category: category,
      recipes: recipes,
      votingViewModel: votingViewModel,
    );
  }
}

/// UI Redesign: Inline error widget with retry button.
/// Shows error message where menu would appear, with option to retry.
Widget _buildInlineError(
  BuildContext context, {
  required MenuViewModel viewModel,
  VoidCallback? onRetry,
}) {
  final cs = Theme.of(context).colorScheme;

  return Center(
    child: Padding(
      padding: const EdgeInsets.all(AppDimensions.space32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Error icon with rust color
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: cs.secondary.withValues(alpha: AppOpacity.onPaper10),
              borderRadius: BorderRadius.zero,
            ),
            child: ButleryIcon(
              ButleryIcons.triangleAlert,
              size: AppDimensions.iconSizeXl,
              color: cs.secondary,
            ),
          ),
          const SizedBox(height: AppDimensions.space12),

          // Error title
          Text(
            context.l10n.menuGenerateError,
            style: AppTextStyles.titleMedium.copyWith(
              color: context.modeColors.textAccent,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppDimensions.space8),

          // Error message
          // BUT-1820: an unreadable household member widens the safety floor
          // and hides unknown recipes, which can empty the pool. "Lägg till
          // recept först" alone would then send the user to import recipes.
          Text(
            viewModel.hiddenPrefSource.isRosterIncomplete
                ? '${viewModel.error ?? context.l10n.errorUnexpected}\n\n'
                      '${context.l10n.householdAllergenRosterIncomplete}'
                : viewModel.error ?? context.l10n.errorUnexpected,
            style: AppTextStyles.bodyMedium.copyWith(
              color: cs.onSurfaceVariant,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppDimensions.space32),

          // Retry button
          if (onRetry != null)
            ActionButtons.primaryButton(
              context,
              label: context.l10n.commonRetry,
              icon: ButleryIcons.refreshCw,
              onPressed: () {
                viewModel.clearError();
                onRetry();
              },
            ),

          // Dismiss error button
          const SizedBox(height: AppDimensions.space8),
          TextButton(
            onPressed: () => viewModel.clearError(),
            child: Text(
              context.l10n.commonDismiss,
              style: AppTextStyles.bodyMedium.copyWith(
                color: cs.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
    ),
  );
}
