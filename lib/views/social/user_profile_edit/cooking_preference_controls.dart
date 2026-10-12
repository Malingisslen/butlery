// Cooking-preference controls (skill level + cuisine affinities).
//
// These live on the profile-edit "cooking identity" section as social "about
// me" bio data. They once also tuned the weekly menu (BUT-1320) and were
// mirrored into the Settings screen, but BUT-1594 removed the cuisine/skill
// menu nudges (the menu is drawn from the user's own recipes, so weighting by
// them double-counted taste) — so this is now a single-consumer widget. Kept
// factored out (rather than inlined) so a future "suggest new recipes"
// discovery feature can reuse it. Persistence stays with
// [UserProfileViewModel.saveProfile], never duplicated here.

import 'package:flutter/material.dart';
import 'package:butlery/viewmodels/user_profile_viewmodel.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/theme/app_mode_colors.dart';
import 'package:butlery/core/extensions/localization_extension.dart';
import 'package:butlery/services/tagging/config/cuisine_config.dart';
import 'package:butlery/models/user_profile.dart';
import 'package:butlery/widgets/common/list/butlery_list.dart';
import 'package:butlery/widgets/common/navigation/underline_tabs.dart';
import 'package:butlery/widgets/common/section_heading.dart';
import 'package:butlery/widgets/common/sheets/butlery_sheet.dart';

/// Skill-level tabs and the favourite-cuisines row, bound to [viewModel].
class CookingPreferenceControls extends StatelessWidget {
  final UserProfileViewModel viewModel;

  const CookingPreferenceControls({super.key, required this.viewModel});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final cuisines = viewModel.cuisineAffinities;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionHeading(l10n.profileCookingSkill),
        const SizedBox(height: AppDimensions.space4),
        // Nullable: no level chosen is a valid state, and tapping the chosen
        // one again clears it, as the segmented control it replaces did.
        UnderlineTabs<CookingSkillLevel?>(
          values: CookingSkillLevel.values,
          selected: viewModel.cookingSkillLevel,
          onChanged: (level) => viewModel.updateCookingSkillLevel(
            level == viewModel.cookingSkillLevel ? null : level,
          ),
          labelOf: (level) => switch (level) {
            CookingSkillLevel.beginner => l10n.profileCookingSkillBeginner,
            CookingSkillLevel.intermediate =>
              l10n.profileCookingSkillIntermediate,
            CookingSkillLevel.advanced => l10n.profileCookingSkillAdvanced,
            null => '',
          },
        ),
        const SizedBox(height: AppDimensions.space8),
        ButleryListSection(
          rows: [
            ButleryListRow(
              label: l10n.profileCuisineAffinities,
              subtitle: cuisines.isEmpty
                  ? l10n.profileCuisineAffinitiesHint
                  : cuisines.join(', '),
              onTap: () => _chooseCuisines(context),
            ),
          ],
        ),
      ],
    );
  }

  void _chooseCuisines(BuildContext context) {
    showButlerySheet<void>(
      context: context,
      builder: (_) => _CuisineSheet(viewModel: viewModel),
    );
  }
}

/// Up to five cuisines, each a toggle; the sheet follows the view model so a
/// choice shows at once.
class _CuisineSheet extends StatelessWidget {
  const _CuisineSheet({required this.viewModel});

  final UserProfileViewModel viewModel;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return ListenableBuilder(
      listenable: viewModel,
      builder: (context, _) {
        final atMax =
            viewModel.cuisineAffinities.length >=
            UserProfileViewModel.maxCuisineAffinities;
        return SingleChildScrollView(
          padding: EdgeInsetsDirectional.fromSTEB(
            AppDimensions.layoutMarginOf(context),
            0,
            AppDimensions.layoutMarginOf(context),
            AppDimensions.layoutMargin,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SectionHeading(l10n.profileCuisineAffinities),
              const SizedBox(height: AppDimensions.space4),
              Text(
                atMax
                    ? l10n.profileCuisineAffinitiesMax
                    : l10n.profileCuisineAffinitiesHint,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: atMax
                      ? context.modeColors.warning
                      : Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
              ButleryListSection(
                rows: [
                  for (final cuisine in CuisineConfig.cuisines)
                    ButleryListRow.toggle(
                      label: cuisine.tag,
                      checked: viewModel.cuisineAffinities.contains(
                        cuisine.tag,
                      ),
                      // A sixth cannot be added; a chosen one can always go.
                      enabled:
                          !atMax ||
                          viewModel.cuisineAffinities.contains(cuisine.tag),
                      onChanged: (_) =>
                          viewModel.toggleCuisineAffinity(cuisine.tag),
                    ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}
