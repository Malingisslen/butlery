// The avatar and display-name sections of the profile editor.

import 'package:flutter/material.dart';
import 'package:butlery/widgets/common/avatar_circle.dart';
import 'package:butlery/widgets/common/buttons/butlery_text_button.dart';
import 'package:butlery/viewmodels/user_profile_viewmodel.dart';
import 'package:butlery/widgets/common/press_fill.dart';
import 'package:butlery/widgets/common/section_heading.dart';
import 'package:butlery/widgets/common/indicators/progress_overlay.dart';
import 'package:butlery/widgets/styled/styled_input.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/core/utils/snackbar_utils.dart';
import 'package:butlery/core/validators/form_validators.dart';
import 'package:butlery/core/utils/validation_utils.dart';
import 'package:butlery/core/extensions/localization_extension.dart';

/// The round avatar and the saffron "Ändra bild" under it; "Ta bort" only
/// when there is a picture to remove.
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
    final l10n = context.l10n;
    return Center(
      child: Column(
        children: [
          Stack(
            alignment: Alignment.center,
            children: [
              Semantics(
                label: l10n.a11yChangeProfileImage,
                button: true,
                child: PressFill(
                  surface: PressSurface.base,
                  child: InkWell(
                    customBorder: const CircleBorder(),
                    onTap: viewModel.isUploadingAvatar ? null : onUploadAvatar,
                    child: AvatarCircle(
                      imageUrl: viewModel.avatarUrl,
                      displayName: viewModel.displayName.isNotEmpty
                          ? viewModel.displayName
                          : l10n.profileNewUser,
                      size: AvatarCircleSize.header,
                    ),
                  ),
                ),
              ),
              if (viewModel.isUploadingAvatar)
                ProgressOverlay.avatar(text: l10n.commonUploading),
            ],
          ),
          const SizedBox(height: AppDimensions.space4),
          Wrap(
            alignment: WrapAlignment.center,
            spacing: AppDimensions.space16,
            children: [
              ButleryTextButton(
                onPressed: viewModel.isUploadingAvatar ? null : onUploadAvatar,
                label: l10n.profileChangePhoto,
              ),
              if (viewModel.avatarUrl != null)
                ButleryTextButton(
                  onPressed: viewModel.isUploadingAvatar
                      ? null
                      : () {
                          viewModel.removeAvatar();
                          SnackBarUtils.showSuccess(
                            context,
                            l10n.profileAvatarRemoved,
                          );
                        },
                  label: l10n.commonRemove,
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
        SectionHeading(context.l10n.profileDisplayName),
        const SizedBox(height: AppDimensions.space4),
        StyledInput(
          controller: controller,
          focusNode: focusNode,
          hint: context.l10n.profileDisplayNameHint,
          errorText: viewModel.displayNameError,
          validText:
              viewModel.displayNameError == null && controller.text.isNotEmpty
              ? context.l10n.profileDisplayNameAvailable
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
      ],
    );
  }
}
