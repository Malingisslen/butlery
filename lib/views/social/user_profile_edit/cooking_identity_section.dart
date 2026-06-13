// Cooking identity section (skill level, cuisine affinities, bio) extracted
// from user_profile_edit_view.dart to keep the parent under the 634-line
// baseline. Pure relocation — no logic or wiring changes.

import 'package:flutter/material.dart';
import 'package:butlery/viewmodels/user_profile_viewmodel.dart';
import 'package:butlery/widgets/styled/styled_input.dart';
import 'package:butlery/theme/app_text_styles.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/theme/butlery_colors_extension.dart';
import 'package:butlery/core/validators/form_validators.dart';
import 'package:butlery/core/extensions/localization_extension.dart';
import 'package:butlery/services/tagging/config/cuisine_config.dart';
import 'package:butlery/models/user_profile.dart';

/// Skill level selector, cuisine affinity chips, and bio text field.
class CookingIdentitySection extends StatelessWidget {
  final TextEditingController bioController;
  final UserProfileViewModel viewModel;

  const CookingIdentitySection({
    super.key,
    required this.bioController,
    required this.viewModel,
  });

  @override
  Widget build(BuildContext context) {
    final atMax = viewModel.cuisineAffinities.length >=
        UserProfileViewModel.maxCuisineAffinities;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Semantics(
          header: true,
          child: Text(
            context.l10n.profileCookingIdentity,
            style: AppTextStyles.titleMedium,
          ),
        ),
        const SizedBox(height: AppDimensions.spacingL),

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
                  borderRadius:
                      BorderRadius.circular(AppDimensions.borderRadius8),
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
                borderRadius:
                    BorderRadius.circular(AppDimensions.borderRadius8),
              ),
            );
          }).toList(),
        ),
        const SizedBox(height: AppDimensions.spacingL),

        // Bio
        Text(
          context.l10n.profileBio,
          style: AppTextStyles.labelMedium,
        ),
        const SizedBox(height: AppDimensions.spacingXs),
        StyledInput(
          controller: bioController,
          hint: context.l10n.profileBioHint,
          maxLines: 3,
          minLines: 2,
          maxLength: UserProfileViewModel.maxBioLength,
          keyboardType: TextInputType.multiline,
          textInputAction: TextInputAction.newline,
          onChanged: viewModel.updateBio,
          // BUT-517: profanity gate on bio (optional field — empty passes).
          validator: FormValidators.contentFilter(context.l10n.profileBio),
        ),
      ],
    );
  }
}
