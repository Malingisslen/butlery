// The save bar and the unsaved-changes notice of the profile editor.

import 'package:flutter/material.dart';
import 'package:butlery/widgets/common/buttons/hero_button.dart';
import 'package:butlery/viewmodels/user_profile_viewmodel.dart';
import 'package:butlery/widgets/common/buttons/action_buttons.dart';
import 'package:butlery/widgets/common/layout/layout_containers.dart';
import 'package:butlery/widgets/common/icons/butlery_glyph.dart';
import 'package:butlery/widgets/common/icons/butlery_icons.dart';
import 'package:butlery/theme/app_text_styles.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/theme/app_mode_colors.dart';
import 'package:butlery/core/extensions/localization_extension.dart';

/// The one saffron action, fixed at the foot of the page. Saving says so and
/// draws the plate line.
class ProfileSaveBar extends StatelessWidget {
  final UserProfileViewModel viewModel;
  final VoidCallback onSave;

  const ProfileSaveBar({
    super.key,
    required this.viewModel,
    required this.onSave,
  });

  @override
  Widget build(BuildContext context) {
    return BottomActionContainer(
      child: HeroButton(
        key: const ValueKey('profileEdit.save'),
        label: context.l10n.profileSaveProfile,
        onPressed: viewModel.isFormValid ? onSave : null,
        busy: viewModel.isLoading,
        busyLabel: context.l10n.statusSaving,
        expand: true,
      ),
    );
  }
}

/// Reset and the unsaved-changes notice; nothing at all while the form is
/// as saved.
class ProfileUnsavedNotice extends StatelessWidget {
  final UserProfileViewModel viewModel;
  final VoidCallback onReset;

  const ProfileUnsavedNotice({
    super.key,
    required this.viewModel,
    required this.onReset,
  });

  @override
  Widget build(BuildContext context) {
    if (!viewModel.hasUnsavedChanges) return const SizedBox.shrink();
    return Column(
      children: [
        ActionButtons.outlinedButton(
          context,
          label: context.l10n.profileResetChanges,
          icon: ButleryIcons.refreshCw,
          onPressed: onReset,
          isExpanded: true,
        ),
        const SizedBox(height: AppDimensions.space12),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(AppDimensions.space16),
          decoration: BoxDecoration(
            color: context.modeColors.surfaceTintWarning,
            borderRadius: BorderRadius.circular(AppDimensions.radiusControl),
          ),
          child: Row(
            children: [
              ButleryIcon(
                ButleryIcons.triangleAlert,
                color: AppModeColors.textWarning(Theme.of(context).brightness),
                size: AppDimensions.iconSizeM,
              ),
              const SizedBox(width: AppDimensions.space4),
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
    );
  }
}
