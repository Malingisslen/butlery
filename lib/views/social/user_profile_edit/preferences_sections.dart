// Language, theme, and action-button sections extracted from
// user_profile_edit_view.dart to keep the parent under the 634-line baseline.
// Pure relocation — no logic or wiring changes.

// ignore_for_file: deprecated_member_use // RadioListTile groupValue/onChanged → RadioGroup migration pending

import 'package:flutter/material.dart';
import 'package:butlery/viewmodels/user_profile_viewmodel.dart';
import 'package:butlery/widgets/common/buttons/action_buttons.dart';
import 'package:butlery/widgets/common/layout/layout_containers.dart';
import 'package:butlery/theme/app_text_styles.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/theme/butlery_colors_extension.dart';
import 'package:butlery/core/utils/snackbar_utils.dart';
import 'package:butlery/core/extensions/localization_extension.dart';
import 'package:butlery/core/providers/locale_provider.dart';
import 'package:butlery/services/theme_service.dart';

/// Language picker (radio list).
class LanguageSettingsSection extends StatelessWidget {
  final LocaleProvider localeProvider;

  const LanguageSettingsSection({
    super.key,
    required this.localeProvider,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Semantics(
          header: true,
          child: Text(
            context.l10n.profileLanguage,
            style: AppTextStyles.titleMedium,
          ),
        ),
        const SizedBox(height: AppDimensions.spacingL),
        BorderedContainer(
          child: Column(
            children: LocaleProvider.supportedLocales.map((localeCode) {
              final isSelected =
                  localeProvider.locale.languageCode == localeCode;
              return RadioListTile<String>(
                title: Text(LocaleProvider.getLocaleName(localeCode)),
                value: localeCode,
                groupValue: localeProvider.locale.languageCode,
                onChanged: (value) {
                  if (value != null) {
                    localeProvider.setLocale(value);
                    SnackBarUtils.showSuccess(
                      context,
                      context.l10n.profileLanguageChangedTo(
                        LocaleProvider.getLocaleName(value),
                      ),
                    );
                  }
                },
                secondary: Icon(
                  isSelected ? Icons.check_circle : Icons.language,
                  color: isSelected ? context.butleryColors.success : null,
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }
}

/// Theme picker (system / light / dark radio list).
class ThemeSettingsSection extends StatelessWidget {
  final ThemeService themeService;

  const ThemeSettingsSection({
    super.key,
    required this.themeService,
  });

  @override
  Widget build(BuildContext context) {
    final themeModes = [
      (
        ThemeMode.system,
        context.l10n.profileThemeSystem,
        Icons.settings_suggest,
      ),
      (ThemeMode.light, context.l10n.profileThemeLight, Icons.light_mode),
      (ThemeMode.dark, context.l10n.profileThemeDark, Icons.dark_mode),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Semantics(
          header: true,
          child: Text(
            context.l10n.profileTheme,
            style: AppTextStyles.titleMedium,
          ),
        ),
        const SizedBox(height: AppDimensions.spacingL),
        BorderedContainer(
          child: Column(
            children: themeModes.map((mode) {
              final isSelected = themeService.themeMode == mode.$1;
              return RadioListTile<ThemeMode>(
                title: Text(mode.$2),
                value: mode.$1,
                groupValue: themeService.themeMode,
                onChanged: (value) {
                  if (value != null) {
                    themeService.setThemeMode(value);
                    SnackBarUtils.showSuccess(
                      context,
                      context.l10n.profileThemeChangedTo(mode.$2),
                    );
                  }
                },
                secondary: Icon(
                  isSelected ? Icons.check_circle : mode.$3,
                  color: isSelected ? context.butleryColors.success : null,
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }
}

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
        ActionButtons.primaryButton(
          context,
          label: context.l10n.profileSaveProfile,
          icon: Icons.save,
          onPressed: viewModel.isLoading || !viewModel.isFormValid
              ? null
              : onSave,
          isLoading: viewModel.isLoading,
          loadingText: context.l10n.commonSaving,
          isExpanded: true,
        ),

        const SizedBox(height: AppDimensions.spacingL),

        ActionButtons.outlinedButton(
          context,
          label: context.l10n.profileResetChanges,
          icon: Icons.refresh,
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
              color: context.butleryColors.warning.withValues(
                alpha: AppDimensions.opacityVeryLight,
              ),
              borderRadius: BorderRadius.circular(AppDimensions.borderRadiusM),
              border: Border.all(
                color: context.butleryColors.warning.withValues(
                  alpha: AppDimensions.opacityMediumLight,
                ),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.warning_amber,
                  color: context.butleryColors.warning,
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
