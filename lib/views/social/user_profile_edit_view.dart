// lib/views/social/user_profile_edit_view.dart
//
// Orchestrates the profile editing screen. Build sections are extracted into
// lib/views/social/user_profile_edit/ to keep this file under the 634-line
// baseline.

// ignore_for_file: deprecated_member_use // RadioListTile groupValue/onChanged → RadioGroup migration pending

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:butlery/viewmodels/user_profile_viewmodel.dart';
import 'package:butlery/widgets/common/layout_components.dart';
import 'package:butlery/widgets/common/scaffolds/base_scaffold.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/core/providers/application_provider.dart';
import 'package:butlery/core/utils/validation_utils.dart';
import 'package:butlery/core/utils/snackbar_utils.dart';
import 'package:butlery/core/utils/logger.dart';
import 'package:butlery/widgets/common/indicators/loading_indicator.dart';
import 'package:butlery/widgets/common/buttons/action_buttons.dart';
import 'package:butlery/core/providers/locale_provider.dart';
import 'package:butlery/services/theme_service.dart';
import 'package:butlery/core/extensions/localization_extension.dart';
import 'package:butlery/core/keyboard/keyboard_submittable_form.dart';
import 'package:butlery/services/tagging/tag_config_service.dart';
import 'package:butlery/services/unified/unified_recipe_service.dart';
import 'package:butlery/models/recipe_unified.dart';
import 'package:butlery/widgets/recipe/collection_insights_card.dart';
import 'package:butlery/views/social/user_profile_edit/identity_sections.dart';
import 'package:butlery/views/social/user_profile_edit/cooking_identity_section.dart';
import 'package:butlery/views/social/user_profile_edit/privacy_section.dart';
import 'package:butlery/views/social/user_profile_edit/preferences_sections.dart';

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

    final displayName = ValidationUtils.safeTrim(_displayNameController.text);

    // Sync form controllers to ViewModel before save
    viewModel.updateDisplayName(displayName);
    viewModel.updateBio(_bioController.text);

    final success = await viewModel.saveProfile();

    if (mounted) {
      if (success) {
        SnackBarUtils.showSuccess(context, context.l10n.profileSaved);
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
        content: Text(context.l10n.profileUnsavedChangesMessage),
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
          ProfileAvatarSection(
            viewModel: viewModel,
            onUploadAvatar: _uploadAvatar,
          ),
          const SizedBox(height: AppDimensions.spacingXl),
          ProfileDisplayNameField(
            controller: _displayNameController,
            focusNode: _displayNameFocusNode,
            viewModel: viewModel,
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
          const SizedBox(height: AppDimensions.spacingXl),
          CookingIdentitySection(
            bioController: _bioController,
            viewModel: viewModel,
          ),
          const SizedBox(height: AppDimensions.spacingXl),
          CollectionInsightsCard(
            recipes: _recipesSnapshot,
            cuisineDisplayNames: _cuisineDisplayNames,
          ),
          const SizedBox(height: AppDimensions.spacingXl),
          PrivacySettingsSection(viewModel: viewModel),
          const SizedBox(height: AppDimensions.spacingXl),
          LanguageSettingsSection(localeProvider: _localeProvider),
          const SizedBox(height: AppDimensions.spacingXl),
          ThemeSettingsSection(themeService: _themeService),
          const SizedBox(height: AppDimensions.spacingXxl),
          ProfileActionButtons(
            viewModel: viewModel,
            onSave: _saveProfile,
            onReset: () {
              viewModel.resetForm();
              _initializeForm(viewModel, force: true);
              SnackBarUtils.showSuccess(context, context.l10n.profileFormReset);
            },
          ),
        ],
      ),
    );
  }
}
