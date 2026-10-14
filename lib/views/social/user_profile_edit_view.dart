// lib/views/social/user_profile_edit_view.dart
//
// Orchestrates the profile editing screen. Build sections are extracted into
// lib/views/social/user_profile_edit/.

import 'package:flutter/material.dart';
import 'package:butlery/core/utils/common_dialog_actions.dart';
import 'package:butlery/widgets/common/buttons/action_buttons.dart';
import 'package:butlery/widgets/common/dialogs/butlery_dialog.dart';
import 'package:butlery/widgets/common/icons/butlery_icons.dart';
import 'package:butlery/widgets/common/state_widget.dart';
import 'package:provider/provider.dart';
import 'package:butlery/viewmodels/user_profile_viewmodel.dart';
import 'package:butlery/widgets/common/layout/butlery_page.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/core/providers/application_provider.dart';
import 'package:butlery/core/utils/validation_utils.dart';
import 'package:butlery/core/utils/snackbar_utils.dart';
import 'package:butlery/core/utils/logger.dart';
import 'package:butlery/widgets/common/indicators/plate_line.dart';
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

/// A wait, not motion (produktbeslut R8-9 = A).
const Duration _errorClearWait = Duration(milliseconds: 500);

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

  bool _hasInitialized = false;

  Map<String, String> _cuisineDisplayNames = const {};
  List<Recipe> _recipesSnapshot = const [];

  @override
  void initState() {
    super.initState();

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

  void _onFocusChanged() {
    if (!_displayNameFocusNode.hasFocus) {
      _checkDisplayNameAvailability();
    }
  }

  @override
  void dispose() {
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
    showButleryDialog<void>(
      context: context,
      barrierDismissible: false,
      // The plate line with what is happening, never a spinner
      // (produktregler.md:163, B-18).
      builder: (context) => AlertDialog(
        content: PlateLineMessage(
          message: context.l10n.profileUploadingAvatar,
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
        SnackBarUtils.showFailure(context, what: errorMsg);
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
        SnackBarUtils.showFailure(
          context,
          what: viewModel.error ?? context.l10n.profileCouldNotSave,
        );
      }
    }
  }

  Future<bool> _handleBackNavigation(UserProfileViewModel viewModel) async {
    if (!viewModel.hasUnsavedChanges) return true;

    final shouldDiscard =
        await CommonDialogActions.showUnsavedChangesConfirmation(
          context: context,
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
      child: ButleryPage.undersida(
        title: context.l10n.profileEditProfile,
        backTo: context.l10n.moreTitle,
        // A form: the save bar takes the tab bar's place (B-54).
        showTabBar: false,
        actions: [
          if (viewModel.hasError)
            AppIconButton(
              icon: ButleryIcons.refreshCw,
              onPressed: viewModel.clearError,
              semanticLabel: context.l10n.commonClearError,
            ),
        ],
        bottomNavigationBar: ProfileSaveBar(
          viewModel: viewModel,
          onSave: _saveProfile,
        ),
        body: _buildForm(viewModel),
      ),
    );
  }

  Widget _buildForm(UserProfileViewModel viewModel) {
    // Show loading state for initial profile load
    if (viewModel.isLoading && !viewModel.hasProfile) {
      return StateWidget.loading(message: context.l10n.profileLoading);
    }

    return KeyboardSubmittableForm(
      formKey: _formKey,
      onSubmit: () {
        if (viewModel.isLoading || !viewModel.isFormValid) return;
        _saveProfile();
      },
      child: SingleChildScrollView(
        padding: ButleryPageBody.margin(
          context,
          top: AppDimensions.space16,
          bottom: AppDimensions.space32,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ProfileAvatarSection(
              viewModel: viewModel,
              onUploadAvatar: _uploadAvatar,
            ),
            const SizedBox(height: AppDimensions.space24),
            ProfileDisplayNameField(
              controller: _displayNameController,
              focusNode: _displayNameFocusNode,
              viewModel: viewModel,
              onChanged: (value) {
                viewModel.updateDisplayName(value);
                // Clear previous validation errors when user types
                if (viewModel.displayNameError != null) {
                  Future.delayed(_errorClearWait, () {
                    if (mounted && _displayNameController.text == value) {
                      _checkDisplayNameAvailability();
                    }
                  });
                }
              },
            ),
            const SizedBox(height: AppDimensions.space24),
            CookingIdentitySection(
              bioController: _bioController,
              viewModel: viewModel,
            ),
            const SizedBox(height: AppDimensions.space24),
            PrivacySettingsSection(viewModel: viewModel),
            const SizedBox(height: AppDimensions.space24),
            CollectionInsightsCard(
              recipes: _recipesSnapshot,
              cuisineDisplayNames: _cuisineDisplayNames,
            ),
            const SizedBox(height: AppDimensions.space24),
            ProfileUnsavedNotice(
              viewModel: viewModel,
              onReset: () {
                viewModel.resetForm();
                _initializeForm(viewModel, force: true);
                SnackBarUtils.showSuccess(
                  context,
                  context.l10n.profileFormReset,
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
