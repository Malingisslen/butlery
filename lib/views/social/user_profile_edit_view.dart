// lib/views/social/user_profile_edit_view.dart

// ignore_for_file: deprecated_member_use // RadioListTile groupValue/onChanged → RadioGroup migration pending

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:butlery/viewmodels/user_profile_viewmodel.dart';
import 'package:butlery/widgets/user/user_display_widgets.dart';
import 'package:butlery/widgets/common/layout_components.dart';
import 'package:butlery/widgets/common/scaffolds/base_scaffold.dart';
import 'package:butlery/theme/app_text_styles.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/theme/butlery_colors_extension.dart';
import 'package:butlery/core/providers/application_provider.dart';
import 'package:butlery/core/utils/validation_utils.dart';
import 'package:butlery/core/utils/snackbar_utils.dart';
import 'package:butlery/core/validators/form_validators.dart';
import 'package:butlery/core/utils/logger.dart';
import 'package:butlery/widgets/common/indicators/loading_indicator.dart';
import 'package:butlery/widgets/common/indicators/progress_overlay.dart';
import 'package:butlery/widgets/common/buttons/action_buttons.dart';
import 'package:butlery/widgets/styled/styled_input.dart';
import 'package:butlery/widgets/common/layout/layout_containers.dart';
import 'package:butlery/core/providers/locale_provider.dart';
import 'package:butlery/services/theme_service.dart';
import 'package:butlery/core/extensions/localization_extension.dart';
import 'package:butlery/core/keyboard/keyboard_submittable_form.dart';
import 'package:butlery/services/tagging/config/cuisine_config.dart';
import 'package:butlery/services/tagging/tag_config_service.dart';
import 'package:butlery/services/unified/unified_recipe_service.dart';
import 'package:butlery/models/user_profile.dart';
import 'package:butlery/models/recipe_unified.dart';
import 'package:butlery/widgets/recipe/collection_insights_card.dart';

class UserProfileEditView extends StatefulWidget {
  const UserProfileEditView({super.key});

  @override
  State<UserProfileEditView> createState() => _UserProfileEditViewState();
}

class _UserProfileEditViewState extends State<UserProfileEditView> {
  late final UserProfileViewModel _viewModel;

  @override
  void initState() {
    super.initState();
    _viewModel = ServiceLocator.get<UserProfileViewModel>();
  }

  @override
  void dispose() {
    _viewModel.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider.value(
      value: _viewModel,
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
  final _bioController = TextEditingController();
  late final LocaleProvider _localeProvider;
  late final ThemeService _themeService;

  bool _hasInitialized = false;

  Map<String, String> _cuisineDisplayNames = const {};
  List<Recipe> _recipesSnapshot = const [];

  @override
  void initState() {
    super.initState();
    _localeProvider = ServiceLocator.get<LocaleProvider>();
    _localeProvider.addListener(_onLocaleChanged);
    _themeService = ServiceLocator.get<ThemeService>();
    _themeService.addListener(_onThemeChanged);

    // Listen for focus changes to check display name availability
    _displayNameFocusNode.addListener(_onFocusChanged);

    _loadCollectionData();
  }

  void _loadCollectionData() {
    try {
      final config = ServiceLocator.get<TagConfigService>().configOrNull;
      final recipeService = ServiceLocator.get<UnifiedRecipeService>();
      _recipesSnapshot = recipeService.recipes;
      _cuisineDisplayNames = config == null
          ? const {}
          : {
              for (final e in config.cuisines.enabledEntries)
                e.key: e.getTag('sv'),
            };
    } catch (e) {
      AppLogger.warning('Could not load collection data: $e');
    }
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
    _bioController.dispose();
    super.dispose();
  }

  void _initializeForm(UserProfileViewModel viewModel, {bool force = false}) {
    if (_hasInitialized && !force) return;

    _displayNameController.text = viewModel.displayName;
    _bioController.text = viewModel.bio;
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
      builder: (context) => AlertDialog(
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const LoadingIndicator(),
            const SizedBox(height: AppDimensions.spacingL),
            Text(context.l10n.profileUploadingAvatar),
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
        SnackBarUtils.showSuccess(context, context.l10n.profileAvatarUploaded);
      } else {
        final errorMsg =
            viewModel.error ?? context.l10n.profileCouldNotUploadAvatar;
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

    // Sync form controllers to ViewModel before save
    viewModel.updateDisplayName(displayName);
    viewModel.updateBio(_bioController.text);

    final success = await viewModel.saveProfile();

    if (mounted) {
      if (success) {
        SnackBarUtils.showSuccess(context, context.l10n.profileSaved);

        // Navigate back after successful save
        Navigator.pop(context);
      } else {
        SnackBarUtils.showError(
            context, viewModel.error ?? context.l10n.profileCouldNotSave);
      }
    }
  }

  Future<bool> _handleBackNavigation(UserProfileViewModel viewModel) async {
    if (!viewModel.hasUnsavedChanges) return true;

    final shouldDiscard = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(context.l10n.profileUnsavedChanges),
        content: Text(
          context.l10n.profileUnsavedChangesMessage,
        ),
        actions: [
          ActionButtons.secondaryButton(
            context,
            label: context.l10n.commonDiscard,
            onPressed: () => Navigator.pop(context, true),
          ),
          ActionButtons.secondaryButton(
            context,
            label: context.l10n.commonCancel,
            onPressed: () => Navigator.pop(context, false),
          ),
          ActionButtons.primaryButton(
            context,
            label: context.l10n.commonSave,
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
        // Use LayoutComponents instead of MainLayoutMenu
        currentIndex: null,
        body: SafeArea(
          // Responsive: center and constrain on large screens
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
                title: context.l10n.profileEditProfile,
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
                      tooltip: context.l10n.commonClearError,
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
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const LoadingIndicator(),
            const SizedBox(height: AppDimensions.spacingMd),
            Text(context.l10n.profileLoading),
          ],
        ),
      );
    }

    return KeyboardSubmittableForm(
      formKey: _formKey,
      onSubmit: () {
        if (viewModel.isLoading || !viewModel.isFormValid) return;
        _saveProfile();
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Avatar section
          _buildAvatarSection(viewModel),
          const SizedBox(height: AppDimensions.spacingXl),

          // Display name field
          _buildDisplayNameField(viewModel),
          const SizedBox(height: AppDimensions.spacingXl),

          // Cooking identity (skill, cuisines, bio)
          _buildCookingIdentitySection(viewModel),
          const SizedBox(height: AppDimensions.spacingXl),

          CollectionInsightsCard(
            recipes: _recipesSnapshot,
            cuisineDisplayNames: _cuisineDisplayNames,
          ),
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
                    : context.l10n.profileNewUser,
                onEditTap: _uploadAvatar,
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
                onPressed: viewModel.isUploadingAvatar ? null : _uploadAvatar,
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
                              context, context.l10n.profileAvatarRemoved);
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
          context.l10n.profileDisplayName,
          style: AppTextStyles.labelMedium,
        ),
        const SizedBox(height: AppDimensions.spacingXs),
        StyledInput(
          controller: _displayNameController,
          focusNode: _displayNameFocusNode,
          hint: context.l10n.profileDisplayNameHint,
          prefixIcon: const Icon(Icons.person),
          suffixIcon: viewModel.displayNameError != null
              ? Icon(Icons.error, color: Theme.of(context).colorScheme.error)
              : _displayNameController.text.isNotEmpty &&
                      viewModel.displayNameError == null
                  ? Icon(Icons.check_circle,
                      color: context.butleryColors.success)
                  : null,
          // BUT-517: required + content-filter chain on displayName.
          validator: FormValidators.combine([
            (value) => ValidationUtils.validateRequired(
                  value,
                  fieldName: context.l10n.profileDisplayName,
                ),
            FormValidators.contentFilter(context.l10n.profileDisplayName),
          ]),
          onChanged: (value) {
            viewModel.updateDisplayName(value);
            // Clear previous validation errors when user types
            if (viewModel.displayNameError != null) {
              Future.delayed(AppDimensions.animationDurationLong, () {
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
              color: Theme.of(context).colorScheme.error,
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildCookingIdentitySection(UserProfileViewModel viewModel) {
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
          controller: _bioController,
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

  Widget _buildPrivacySettings(UserProfileViewModel viewModel) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Semantics(
          header: true,
          child: Text(
            context.l10n.profilePrivacySettings,
            style: AppTextStyles.titleMedium,
          ),
        ),
        const SizedBox(height: AppDimensions.spacingL),
        BorderedContainer(
          child: Column(
            children: [
              SwitchListTile(
                title: Text(context.l10n.profileVisibleInSearch),
                subtitle: Text(context.l10n.profileVisibleInSearchDescription),
                value: viewModel.isSearchable,
                onChanged: viewModel.updateIsSearchable,
                secondary: const Icon(Icons.search),
              ),
              const Divider(height: 1),
              SwitchListTile(
                title: Text(context.l10n.profileSearchableByEmail),
                subtitle:
                    Text(context.l10n.profileSearchableByEmailDescription),
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
                      context.l10n.profileLanguageChangedTo(
                          LocaleProvider.getLocaleName(value)),
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

  Widget _buildThemeSettings() {
    final themeModes = [
      (
        ThemeMode.system,
        context.l10n.profileThemeSystem,
        Icons.settings_suggest
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

  Widget _buildActionButtons(UserProfileViewModel viewModel) {
    return Column(
      children: [
        // Save button
        ActionButtons.primaryButton(
          context,
          label: context.l10n.profileSaveProfile,
          icon: Icons.save,
          onPressed: viewModel.isLoading || !viewModel.isFormValid
              ? null
              : _saveProfile,
          isLoading: viewModel.isLoading,
          loadingText: context.l10n.commonSaving,
          isExpanded: true,
        ),

        const SizedBox(height: AppDimensions.spacingL),

        // Reset button
        ActionButtons.outlinedButton(
          context,
          label: context.l10n.profileResetChanges,
          icon: Icons.refresh,
          onPressed: viewModel.hasUnsavedChanges
              ? () {
                  viewModel.resetForm();
                  _initializeForm(viewModel, force: true);
                  SnackBarUtils.showSuccess(
                      context, context.l10n.profileFormReset);
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
              color: context.butleryColors.warning
                  .withValues(alpha: AppDimensions.opacityVeryLight),
              borderRadius: BorderRadius.circular(AppDimensions.borderRadiusM),
              border: Border.all(
                  color: context.butleryColors.warning
                      .withValues(alpha: AppDimensions.opacityMediumLight)),
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
