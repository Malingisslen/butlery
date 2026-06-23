// Avatar and display-name sections extracted from user_profile_edit_view.dart
// to keep the parent under the 634-line baseline. Pure relocation — no logic
// or wiring changes.

import 'package:flutter/material.dart';
import 'package:butlery/viewmodels/user_profile_viewmodel.dart';
import 'package:butlery/widgets/user/user_display_widgets.dart';
import 'package:butlery/widgets/common/buttons/action_buttons.dart';
import 'package:butlery/widgets/common/indicators/progress_overlay.dart';
import 'package:butlery/widgets/styled/styled_input.dart';
import 'package:butlery/theme/app_text_styles.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/theme/butlery_colors_extension.dart';
import 'package:butlery/core/utils/snackbar_utils.dart';
import 'package:butlery/core/validators/form_validators.dart';
import 'package:butlery/core/utils/validation_utils.dart';
import 'package:butlery/core/extensions/localization_extension.dart';

/// Avatar display with upload/remove buttons.
class ProfileAvatarSection extends StatelessWidget {
  final UserProfileViewModel viewModel;
  final VoidCallback onUploadAvatar;

  const ProfileAvatarSection({
    super.key,
    required this.viewModel,
    required this.onUploadAvatar,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        children: [
          // Avatar with edit overlay
          Stack(
            children: [
              UserDisplayWidgets.editableAvatar(
                imageUrl: viewModel.avatarUrl,
                displayName: viewModel.displayName.isNotEmpty
                    ? viewModel.displayName
                    : context.l10n.profileNewUser,
                onEditTap: onUploadAvatar,
              ),
              // Upload progress overlay
              if (viewModel.isUploadingAvatar)
                ProgressOverlay.avatar(text: context.l10n.commonUploading),
            ],
          ),

          const SizedBox(height: AppDimensions.spacingL),

          // Avatar action buttons
          Wrap(
            alignment: WrapAlignment.center,
            spacing: AppDimensions.spacingL,
            children: [
              ActionButtons.outlinedButton(
                context,
                label: viewModel.avatarUrl != null
                    ? context.l10n.profileChangeAvatar
                    : context.l10n.profileAddAvatar,
                icon: Icons.camera_alt,
                onPressed: viewModel.isUploadingAvatar ? null : onUploadAvatar,
              ),
              if (viewModel.avatarUrl != null)
                ActionButtons.outlinedButton(
                  context,
                  label: context.l10n.commonRemove,
                  icon: Icons.delete_outline,
                  onPressed: viewModel.isUploadingAvatar
                      ? null
                      : () {
                          viewModel.removeAvatar();
                          SnackBarUtils.showSuccess(
                            context,
                            context.l10n.profileAvatarRemoved,
                          );
                        },
                ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Display-name text field with availability indicator and validation.
class ProfileDisplayNameField extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final UserProfileViewModel viewModel;
  final ValueChanged<String> onChanged;

  const ProfileDisplayNameField({
    super.key,
    required this.controller,
    required this.focusNode,
    required this.viewModel,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          context.l10n.profileDisplayName,
          style: AppTextStyles.labelMedium,
        ),
        const SizedBox(height: AppDimensions.spacingXs),
        StyledInput(
          controller: controller,
          focusNode: focusNode,
          hint: context.l10n.profileDisplayNameHint,
          prefixIcon: const Icon(Icons.person),
          suffixIcon: viewModel.displayNameError != null
              ? Icon(Icons.error, color: Theme.of(context).colorScheme.error)
              : controller.text.isNotEmpty && viewModel.displayNameError == null
              ? Icon(Icons.check_circle, color: context.butleryColors.success)
              : null,
          // BUT-517: required + content-filter chain on displayName.
          validator: FormValidators.combine([
            (value) => ValidationUtils.validateRequired(
              value,
              fieldName: context.l10n.profileDisplayName,
            ),
            FormValidators.contentFilter(context.l10n.profileDisplayName),
          ]),
          onChanged: onChanged,
        ),
        if (viewModel.displayNameError != null) ...[
          const SizedBox(height: AppDimensions.spacingXs),
          Text(
            viewModel.displayNameError!,
            style: AppTextStyles.bodySmall.copyWith(
              color: Theme.of(context).colorScheme.error,
            ),
          ),
        ],
      ],
    );
  }
}
