// The action-button section, extracted from user_profile_edit_view.dart to
// keep the parent under the 634-line baseline.

import 'package:flutter/material.dart';
import 'package:butlery/widgets/common/buttons/hero_button.dart';
import 'package:butlery/viewmodels/user_profile_viewmodel.dart';
import 'package:butlery/widgets/common/buttons/action_buttons.dart';
import 'package:butlery/widgets/common/icons/butlery_glyph.dart';
import 'package:butlery/widgets/common/icons/butlery_icons.dart';
import 'package:butlery/theme/app_text_styles.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/theme/app_mode_colors.dart';
import 'package:butlery/core/extensions/localization_extension.dart';

/// Save / reset buttons and unsaved-changes warning banner.
class ProfileActionButtons extends StatelessWidget {
  final UserProfileViewModel viewModel;
  final VoidCallback onSave;
  final VoidCallback onReset;

  const ProfileActionButtons({
    super.key,
    required this.viewModel,
    required this.onSave,
    required this.onReset,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // The view's one saffron action (Skarmar v12 del 3 'Redigera
        // profil'; Grafisk manual v6:219). Saving says so and draws the
        // plate line (Komponentark v1:372; content-style-guide.md:63).
        HeroButton(
          key: const ValueKey('profileEdit.save'),
          label: context.l10n.profileSaveProfile,
          icon: ButleryIcons.save,
          onPressed: viewModel.isFormValid ? onSave : null,
          busy: viewModel.isLoading,
          busyLabel: context.l10n.statusSaving,
          expand: true,
        ),

        const SizedBox(height: AppDimensions.spacingL),

        ActionButtons.outlinedButton(
          context,
          label: context.l10n.profileResetChanges,
          icon: ButleryIcons.refreshCw,
          onPressed: viewModel.hasUnsavedChanges ? onReset : null,
          isExpanded: true,
        ),

        // Unsaved changes indicator
        if (viewModel.hasUnsavedChanges) ...[
          const SizedBox(height: AppDimensions.spacingL),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(AppDimensions.paddingL),
            decoration: BoxDecoration(
              color: context.modeColors.surfaceTintWarning,
              borderRadius: BorderRadius.circular(AppDimensions.radiusControl),
            ),
            child: Row(
              children: [
                ButleryIcon(
                  ButleryIcons.triangleAlert,
                  color: AppModeColors.textWarning(
                    Theme.of(context).brightness,
                  ),
                  size: AppDimensions.iconSizeM,
                ),
                const SizedBox(width: AppDimensions.spacingXs),
                Expanded(
                  child: Text(
                    context.l10n.profileYouHaveUnsavedChanges,
                    style: AppTextStyles.bodySmall,
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}
