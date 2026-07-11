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
import 'package:butlery/theme/app_text_styles.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/theme/butlery_colors_extension.dart';
import 'package:butlery/core/extensions/localization_extension.dart';
import 'package:butlery/services/tagging/config/cuisine_config.dart';
import 'package:butlery/models/user_profile.dart';

/// Skill-level selector + cuisine affinity chips, bound to [viewModel].
class CookingPreferenceControls extends StatelessWidget {
  final UserProfileViewModel viewModel;

  const CookingPreferenceControls({super.key, required this.viewModel});

  @override
  Widget build(BuildContext context) {
    final atMax =
        viewModel.cuisineAffinities.length >=
        UserProfileViewModel.maxCuisineAffinities;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Skill level
        Text(
          context.l10n.profileCookingSkill,
          style: AppTextStyles.labelMedium,
        ),
        const SizedBox(height: AppDimensions.spacingXs),
        SizedBox(
          width: double.infinity,
          child: SegmentedButton<CookingSkillLevel>(
            segments: [
              ButtonSegment(
                value: CookingSkillLevel.beginner,
                label: Text(context.l10n.profileCookingSkillBeginner),
              ),
              ButtonSegment(
                value: CookingSkillLevel.intermediate,
                label: Text(context.l10n.profileCookingSkillIntermediate),
              ),
              ButtonSegment(
                value: CookingSkillLevel.advanced,
                label: Text(context.l10n.profileCookingSkillAdvanced),
              ),
            ],
            selected: viewModel.cookingSkillLevel != null
                ? {viewModel.cookingSkillLevel!}
                : {},
            emptySelectionAllowed: true,
            onSelectionChanged: (selection) {
              viewModel.updateCookingSkillLevel(
                selection.isEmpty ? null : selection.first,
              );
            },
            style: ButtonStyle(
              shape: WidgetStatePropertyAll(
                RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(
                    AppDimensions.borderRadius8,
                  ),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: AppDimensions.spacingL),

        // Cuisine affinities
        Text(
          context.l10n.profileCuisineAffinities,
          style: AppTextStyles.labelMedium,
        ),
        const SizedBox(height: AppDimensions.spacingXxs),
        Text(
          atMax
              ? context.l10n.profileCuisineAffinitiesMax
              : context.l10n.profileCuisineAffinitiesHint,
          style: AppTextStyles.bodySmall.copyWith(
            color: atMax
                ? context.butleryColors.warning
                : Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: AppDimensions.spacingXs),
        Wrap(
          spacing: AppDimensions.spacingXs,
          runSpacing: AppDimensions.spacingXs,
          children: CuisineConfig.cuisines.map((cuisine) {
            final selected = viewModel.cuisineAffinities.contains(cuisine.tag);
            return FilterChip(
              label: Text(cuisine.tag),
              selected: selected,
              onSelected: (value) {
                if (!value || !atMax) {
                  viewModel.toggleCuisineAffinity(cuisine.tag);
                }
              },
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(
                  AppDimensions.borderRadius8,
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }
}
