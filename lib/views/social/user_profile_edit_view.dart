// lib/views/social/user_profile_edit_view.dart

// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:butlery/viewmodels/user_profile_viewmodel.dart';
import 'package:butlery/widgets/user/user_display_widgets.dart';
import 'package:butlery/widgets/common/layout_components.dart'; // ✅ UPPDATERAD IMPORT
import 'package:butlery/widgets/common/scaffolds/base_scaffold.dart';
import 'package:butlery/theme/app_colors.dart';
import 'package:butlery/theme/app_text_styles.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/core/providers/application_provider.dart';
import 'package:butlery/core/utils/validation_utils.dart';
import 'package:butlery/core/utils/snackbar_utils.dart';
import 'package:butlery/core/utils/logger.dart';
import 'package:butlery/widgets/common/indicators/progress_overlay.dart';
import 'package:butlery/widgets/common/buttons/action_buttons.dart';
import 'package:butlery/widgets/styled/styled_input.dart';
import 'package:butlery/widgets/common/layout/layout_containers.dart';
import 'package:butlery/core/providers/locale_provider.dart';
import 'package:butlery/services/theme_service.dart';

class UserProfileEditView extends StatelessWidget {
  const UserProfileEditView({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => ServiceLocator.get<UserProfileViewModel>(),
      child: const _UserProfileEditViewContent(),
    );
  }
}

class _UserProfileEditViewContent extends StatefulWidget {
  const _UserProfileEditViewContent();

  @override
  State<_UserProfileEditViewContent> createState() =>
      _UserProfileEditViewContentState();
}

class _UserProfileEditViewContentState
    extends State<_UserProfileEditViewContent> {
  final _formKey = GlobalKey<FormState>();
  final _displayNameController = TextEditingController();
  final _displayNameFocusNode = FocusNode();
  late final LocaleProvider _localeProvider;
  late final ThemeService _themeService;

  bool _hasInitialized = false;

  @override
  void initState() {
    super.initState();
    _localeProvider = ServiceLocator.get<LocaleProvider>();
    _localeProvider.addListener(_onLocaleChanged);
    _themeService = ServiceLocator.get<ThemeService>();
    _themeService.addListener(_onThemeChanged);

    // Listen for focus changes to check display name availability
    _displayNameFocusNode.addListener(_onFocusChanged);
  }

  void _onLocaleChanged() {
    if (mounted) setState(() {});
  }

  void _onThemeChanged() {
    if (mounted) setState(() {});
  }

  void _onFocusChanged() {
    if (!_displayNameFocusNode.hasFocus) {
      _checkDisplayNameAvailability();
    }
  }

  @override
  void dispose() {
    _localeProvider.removeListener(_onLocaleChanged);
    _themeService.removeListener(_onThemeChanged);
    _displayNameFocusNode.removeListener(_onFocusChanged);
    _displayNameController.dispose();
    _displayNameFocusNode.dispose();
    super.dispose();
  }

  void _initializeForm(UserProfileViewModel viewModel) {
    if (_hasInitialized) return;

    _displayNameController.text = viewModel.displayName;
    _hasInitialized = true;
  }

  void _checkDisplayNameAvailability() {
    final viewModel = context.read<UserProfileViewModel>();
    final displayName = ValidationUtils.safeTrim(_displayNameController.text);
    if (displayName != viewModel.displayName) {
      viewModel.checkDisplayNameAvailability();
    }
  }

  Future<void> _uploadAvatar() async {
    AppLogger.debug('🎨 VIEW: _uploadAvatar called');
    final viewModel = context.read<UserProfileViewModel>();

    // Show loading dialog during upload
    AppLogger.debug('🎨 VIEW: Showing loading dialog');
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const AlertDialog(
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: AppDimensions.spacingL),
            Text('Laddar upp avatar...'),
          ],
        ),
      ),
    );

    AppLogger.debug('🎨 VIEW: Calling viewModel.uploadAvatar()');
    final success = await viewModel.uploadAvatar();
    AppLogger.debug('🎨 VIEW: uploadAvatar returned: $success');

    if (mounted) {
      Navigator.pop(context); // Close loading dialog

      if (success) {
        AppLogger.info('🎨 VIEW: Upload success, showing success message');
        SnackBarUtils.showSuccess(context, 'Avatar uppladdad!');
      } else {
        final errorMsg = viewModel.error ?? 'Kunde inte ladda upp avatar';
        AppLogger.error('🎨 VIEW: Upload failed, showing error: $errorMsg');
        SnackBarUtils.showError(context, errorMsg);
      }
    }
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;

    final viewModel = context.read<UserProfileViewModel>();

    // Use ValidationUtils for safe text processing
    final displayName = ValidationUtils.safeTrim(_displayNameController.text);

    // Update ViewModel with current form values
    viewModel.updateDisplayName(displayName);

    final success = await viewModel.saveProfile();

    if (mounted) {
      if (success) {
        SnackBarUtils.showSuccess(context, 'Profil sparad!');

        // Navigate back after successful save
        Navigator.pop(context);
      } else {
        SnackBarUtils.showError(
            context, viewModel.error ?? 'Kunde inte spara profil');
      }
    }
  }

  Future<bool> _handleBackNavigation(UserProfileViewModel viewModel) async {
    if (!viewModel.hasUnsavedChanges) return true;

    final shouldDiscard = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Osparade ändringar'),
        content: const Text(
          'Du har osparade ändringar. Vill du spara innan du lämnar?',
        ),
        actions: [
          ActionButtons.secondaryButton(
            context,
            label: 'Kasta bort',
            onPressed: () => Navigator.pop(context, true),
          ),
          ActionButtons.secondaryButton(
            context,
            label: 'Avbryt',
            onPressed: () => Navigator.pop(context, false),
          ),
          ActionButtons.primaryButton(
            context,
            label: 'Spara',
            onPressed: () async {
              Navigator.pop(context, false);
              await _saveProfile();
            },
          ),
        ],
      ),
    );

    return shouldDiscard ?? false;
  }

  @override
  Widget build(BuildContext context) {
    final viewModel = context.watch<UserProfileViewModel>();

    // Initialize form when profile is loaded
    if (viewModel.hasProfile && !_hasInitialized) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _initializeForm(viewModel);
      });
    }

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (!didPop) {
          final canPop = await _handleBackNavigation(viewModel);
          if (canPop && context.mounted) {
            Navigator.pop(context);
          }
        }
      },
      child: LayoutComponents.mainMenu(
        // ✅ UPPDATERAD: LayoutComponents istället för MainLayoutMenu
        currentIndex: null,
        body: SafeArea(
          // ✅ RESPONSIVE: Center and constrain content on large screens
          child: Center(
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: LayoutComponents.valueFor(
                  context: context,
                  mobile: double.infinity,
                  tablet: 600,
                  desktop: 700,
                ),
              ),
              child: FormScaffold(
                title: 'Redigera profil',
                form: _buildForm(viewModel),
                onSave: viewModel.isLoading || !viewModel.isFormValid
                    ? null
                    : _saveProfile,
                isLoading: viewModel.isLoading,
                showSaveButton: false,
                showCancelButton: false,
                additionalActions: [
                  // Clear error button
                  if (viewModel.hasError)
                    IconButton(
                      icon: const Icon(Icons.refresh),
                      onPressed: viewModel.clearError,
                      tooltip: 'Rensa fel',
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildForm(UserProfileViewModel viewModel) {
    // Show loading state for initial profile load
    if (viewModel.isLoading && !viewModel.hasProfile) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: AppDimensions.spacingMd),
            Text('Laddar profil...'),
          ],
        ),
      );
    }

    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Avatar section
          _buildAvatarSection(viewModel),
          const SizedBox(height: AppDimensions.spacingXl),

          // Display name field
          _buildDisplayNameField(viewModel),
          const SizedBox(height: AppDimensions.spacingXl),

          // Privacy settings
          _buildPrivacySettings(viewModel),
          const SizedBox(height: AppDimensions.spacingXl),

          // Language settings
          _buildLanguageSettings(),
          const SizedBox(height: AppDimensions.spacingXl),

          // Theme settings
          _buildThemeSettings(),
          const SizedBox(height: AppDimensions.spacingXxl),

          // Action buttons
          _buildActionButtons(viewModel),
        ],
      ),
    );
  }

  Widget _buildAvatarSection(UserProfileViewModel viewModel) {
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
                    : 'Ny användare',
                onEditTap: _uploadAvatar, // Lägg till denna parameter
              ),
              // Upload progress overlay
              if (viewModel.isUploadingAvatar)
                const ProgressOverlay.avatar(text: 'Laddar upp...'),
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
                    ? 'Ändra avatar'
                    : 'Lägg till avatar',
                icon: Icons.camera_alt,
                onPressed: viewModel.isUploadingAvatar ? null : _uploadAvatar,
              ),
              if (viewModel.avatarUrl != null)
                ActionButtons.outlinedButton(
                  context,
                  label: 'Ta bort',
                  icon: Icons.delete_outline,
                  onPressed: viewModel.isUploadingAvatar
                      ? null
                      : () {
                          viewModel.removeAvatar();
                          SnackBarUtils.showSuccess(
                              context, 'Avatar borttagen');
                        },
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDisplayNameField(UserProfileViewModel viewModel) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Visningsnamn',
          style: AppTextStyles.labelMedium,
        ),
        const SizedBox(height: AppDimensions.spacingXs),
        StyledInput(
          controller: _displayNameController,
          focusNode: _displayNameFocusNode,
          hint: 'Ditt namn som andra ser',
          prefixIcon: const Icon(Icons.person),
          suffixIcon: viewModel.displayNameError != null
              ? const Icon(Icons.error, color: AppColors.error)
              : _displayNameController.text.isNotEmpty &&
                      viewModel.displayNameError == null
                  ? const Icon(Icons.check_circle, color: AppColors.success)
                  : null,
          validator: (value) => ValidationUtils.validateRequired(
            value,
            fieldName: 'Visningsnamn',
          ),
          onChanged: (value) {
            viewModel.updateDisplayName(value);
            // Clear previous validation errors when user types
            if (viewModel.displayNameError != null) {
              Future.delayed(const Duration(milliseconds: 500), () {
                if (mounted && _displayNameController.text == value) {
                  _checkDisplayNameAvailability();
                }
              });
            }
          },
        ),
        if (viewModel.displayNameError != null) ...[
          const SizedBox(height: AppDimensions.spacingXs),
          Text(
            viewModel.displayNameError!,
            style: AppTextStyles.bodySmall.copyWith(
              color: AppColors.error,
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildPrivacySettings(UserProfileViewModel viewModel) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Integritetsinställningar',
          style: AppTextStyles.titleMedium,
        ),
        const SizedBox(height: AppDimensions.spacingL),
        BorderedContainer(
          child: Column(
            children: [
              SwitchListTile(
                title: const Text('Synlig i sökningar'),
                subtitle:
                    const Text('Andra användare kan hitta dig när de söker'),
                value: viewModel.isSearchable,
                onChanged: viewModel.updateIsSearchable,
                secondary: const Icon(Icons.search),
              ),
              const Divider(height: 1),
              SwitchListTile(
                title: const Text('Sökbar via e-post'),
                subtitle:
                    const Text('Andra kan hitta dig genom din e-postadress'),
                value: viewModel.allowEmailSearch,
                onChanged: viewModel.updateAllowEmailSearch,
                secondary: const Icon(Icons.email),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildLanguageSettings() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Språk',
          style: AppTextStyles.titleMedium,
        ),
        const SizedBox(height: AppDimensions.spacingL),
        BorderedContainer(
          child: Column(
            children: LocaleProvider.supportedLocales.map((localeCode) {
              final isSelected =
                  _localeProvider.locale.languageCode == localeCode;
              return RadioListTile<String>(
                title: Text(LocaleProvider.getLocaleName(localeCode)),
                value: localeCode,
                groupValue: _localeProvider.locale.languageCode,
                onChanged: (value) {
                  if (value != null) {
                    _localeProvider.setLocale(value);
                    SnackBarUtils.showSuccess(
                      context,
                      'Språk ändrat till ${LocaleProvider.getLocaleName(value)}',
                    );
                  }
                },
                secondary: Icon(
                  isSelected ? Icons.check_circle : Icons.language,
                  color: isSelected ? AppColors.success : null,
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  Widget _buildThemeSettings() {
    final themeModes = [
      (ThemeMode.system, 'Systemets inställning', Icons.settings_suggest),
      (ThemeMode.light, 'Ljust läge', Icons.light_mode),
      (ThemeMode.dark, 'Mörkt läge', Icons.dark_mode),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Tema',
          style: AppTextStyles.titleMedium,
        ),
        const SizedBox(height: AppDimensions.spacingL),
        BorderedContainer(
          child: Column(
            children: themeModes.map((mode) {
              final isSelected = _themeService.themeMode == mode.$1;
              return RadioListTile<ThemeMode>(
                title: Text(mode.$2),
                value: mode.$1,
                groupValue: _themeService.themeMode,
                onChanged: (value) {
                  if (value != null) {
                    _themeService.setThemeMode(value);
                    SnackBarUtils.showSuccess(
                      context,
                      'Tema ändrat till ${mode.$2}',
                    );
                  }
                },
                secondary: Icon(
                  isSelected ? Icons.check_circle : mode.$3,
                  color: isSelected ? AppColors.success : null,
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  Widget _buildActionButtons(UserProfileViewModel viewModel) {
    return Column(
      children: [
        // Save button
        ActionButtons.primaryButton(
          context,
          label: 'Spara profil',
          icon: Icons.save,
          onPressed: viewModel.isLoading || !viewModel.isFormValid
              ? null
              : _saveProfile,
          isLoading: viewModel.isLoading,
          loadingText: 'Sparar...',
          isExpanded: true,
        ),

        const SizedBox(height: AppDimensions.spacingL),

        // Reset button
        ActionButtons.outlinedButton(
          context,
          label: 'Återställ ändringar',
          icon: Icons.refresh,
          onPressed: viewModel.hasUnsavedChanges
              ? () {
                  viewModel.resetForm();
                  _initializeForm(viewModel);
                  SnackBarUtils.showSuccess(context, 'Formulär återställt');
                }
              : null,
          isExpanded: true,
        ),

        // Unsaved changes indicator
        if (viewModel.hasUnsavedChanges) ...[
          const SizedBox(height: AppDimensions.spacingL),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(AppDimensions.paddingL),
            decoration: BoxDecoration(
              color: AppColors.warning.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(AppDimensions.borderRadiusM),
              border:
                  Border.all(color: AppColors.warning.withValues(alpha: 0.3)),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.warning_amber,
                  color: AppColors.warning,
                  size: AppDimensions.iconSizeM,
                ),
                const SizedBox(width: AppDimensions.spacingXs),
                Expanded(
                  child: Text(
                    'Du har osparade ändringar',
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
