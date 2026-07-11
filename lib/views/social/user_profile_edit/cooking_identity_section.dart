// Cooking identity section (skill level, cuisine affinities, bio) extracted
// from user_profile_edit_view.dart to keep the parent under the 634-line
// baseline.
//
// The skill + cuisine controls live in [CookingPreferenceControls]. They are
// profile "about me" bio data; they no longer tune the weekly menu (BUT-1594
// removed the cuisine/skill menu nudges). This section keeps the profile-only
// bits (section header + bio field) around that control.

import 'package:flutter/material.dart';
import 'package:butlery/viewmodels/user_profile_viewmodel.dart';
import 'package:butlery/views/social/user_profile_edit/cooking_preference_controls.dart';
import 'package:butlery/widgets/styled/styled_input.dart';
import 'package:butlery/theme/app_text_styles.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/core/validators/form_validators.dart';
import 'package:butlery/core/extensions/localization_extension.dart';

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

        // Skill level + cuisine affinities (profile bio data; no longer menu-tuning)
        CookingPreferenceControls(viewModel: viewModel),
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
