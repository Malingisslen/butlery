// lib/views/social/user_profile_edit_view.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:butlery/viewmodels/user_profile_viewmodel.dart';
import 'package:butlery/widgets/user/user_display_widgets.dart';
import 'package:butlery/widgets/common/layout_components.dart'; // ✅ UPPDATERAD IMPORT
import 'package:butlery/widgets/common/scaffolds/base_scaffold.dart';
import 'package:butlery/theme/app_colors.dart';
import 'package:butlery/theme/app_text_styles.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/core/injection.dart';
import 'package:butlery/core/utils/validation_utils.dart';
import 'package:butlery/core/utils/snackbar_utils.dart';


class UserProfileEditView extends StatelessWidget {
  const UserProfileEditView({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => sl<UserProfileViewModel>(),
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
  final _bioController = TextEditingController();
  final _displayNameFocusNode = FocusNode();
  final _bioFocusNode = FocusNode();

  bool _hasInitialized = false;

  @override
  void initState() {
    super.initState();

    // Listen for focus changes to check display name availability
    _displayNameFocusNode.addListener(() {
      if (!_displayNameFocusNode.hasFocus) {
        _checkDisplayNameAvailability();
      }
    });
  }

  @override
  void dispose() {
    _displayNameController.dispose();
    _bioController.dispose();
    _displayNameFocusNode.dispose();
    _bioFocusNode.dispose();
    super.dispose();
  }

  void _initializeForm(UserProfileViewModel viewModel) {
    if (_hasInitialized) return;

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
    final viewModel = context.read<UserProfileViewModel>();

    // Show loading dialog during upload
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

    final success = await viewModel.uploadAvatar();

    if (mounted) {
      Navigator.pop(context); // Close loading dialog

      if (success) {
        SnackBarUtils.showSuccess(context, 'Avatar uppladdad!');
      } else {
        SnackBarUtils.showError(context, viewModel.error ?? 'Kunde inte ladda upp avatar');
      }
    }
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;

    final viewModel = context.read<UserProfileViewModel>();

    // Use ValidationUtils for safe text processing
    final displayName = ValidationUtils.safeTrim(_displayNameController.text);
    final bio = ValidationUtils.safeTrim(_bioController.text);

    // Update ViewModel with current form values
    viewModel.updateDisplayName(displayName);
    viewModel.updateBio(bio);

    final success = await viewModel.saveProfile();

    if (mounted) {
      if (success) {
        SnackBarUtils.showSuccess(context, 'Profil sparad!');

        // Navigate back after successful save
        Navigator.pop(context);
      } else {
        SnackBarUtils.showError(context, viewModel.error ?? 'Kunde inte spara profil');
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
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Kasta bort'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Avbryt'),
          ),
          FilledButton(
            onPressed: () async {
              Navigator.pop(context, false);
              await _saveProfile();
            },
            child: const Text('Spara'),
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
        body: FormScaffold(
          title: 'Redigera profil',
          form: _buildForm(viewModel),
          onSave: viewModel.isLoading || !viewModel.isFormValid ? null : _saveProfile,
          isLoading: viewModel.isLoading,
          showSaveButton: true,
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
            SizedBox(height: 16),
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
          const SizedBox(height: AppDimensions.spacingL),

          // Bio field
          _buildBioField(viewModel),
          const SizedBox(height: AppDimensions.spacingXl),

          // Privacy settings
          _buildPrivacySettings(viewModel),
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
                Positioned.fill(
                  child: Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppColors.neutralDark.withValues(alpha: 0.7),
                    ),
                    child: Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const CircularProgressIndicator(strokeWidth: 2, color: AppColors.neutralLight),
                          const SizedBox(height: AppDimensions.spacingXs),
                          Text(
                            'Laddar upp...',
                            style:
                                Theme.of(context).textTheme.bodySmall?.copyWith(
                                      color: AppColors.neutralLight,
                                    ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          ),

          const SizedBox(height: AppDimensions.spacingL),

          // Avatar action buttons
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              OutlinedButton.icon(
                onPressed: viewModel.isUploadingAvatar ? null : _uploadAvatar,
                icon: const Icon(Icons.camera_alt),
                label: Text(viewModel.avatarUrl != null
                    ? 'Ändra avatar'
                    : 'Lägg till avatar'),
              ),
              if (viewModel.avatarUrl != null) ...[
                const SizedBox(width: AppDimensions.spacingL),
                OutlinedButton.icon(
                  onPressed: viewModel.isUploadingAvatar
                      ? null
                      : () {
                          viewModel.removeAvatar();
                          SnackBarUtils.showSuccess(context, 'Avatar borttagen');
                        },
                  icon: const Icon(Icons.delete_outline),
                  label: const Text('Ta bort'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.error,
                    side: const BorderSide(color: AppColors.error),
                  ),
                ),
              ],
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
        const Text(
          'Visningsnamn',
          style: AppTextStyles.labelMedium,
        ),
        const SizedBox(height: AppDimensions.spacingXs),
        TextFormField(
          controller: _displayNameController,
          focusNode: _displayNameFocusNode,
          decoration: InputDecoration(
            hintText: 'Ditt namn som andra ser',
            border: const OutlineInputBorder(),
            prefixIcon: const Icon(Icons.person),
            suffixIcon: viewModel.displayNameError != null
                ? const Icon(Icons.error, color: AppColors.error)
                : _displayNameController.text.isNotEmpty &&
                        viewModel.displayNameError == null
                    ? const Icon(Icons.check_circle, color: AppColors.success)
                    : null,
          ),
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
        if (viewModel.displayNameError != null)
          Padding(
            padding: const EdgeInsets.only(top: AppDimensions.spacingXs),
            child: Text(
              viewModel.displayNameError!,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppColors.error,
                  ),
            ),
          ),
      ],
    );
  }

  Widget _buildBioField(UserProfileViewModel viewModel) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Beskrivning',
          style: AppTextStyles.labelMedium,
        ),
        const SizedBox(height: AppDimensions.spacingXs),
        TextFormField(
          controller: _bioController,
          focusNode: _bioFocusNode,
          maxLines: 3,
          maxLength: 150,
          decoration: const InputDecoration(
            hintText: 'Berätta lite om dig själv (valfritt)',
            border: OutlineInputBorder(),
            prefixIcon: Icon(Icons.info_outline),
          ),
          validator: (value) => ValidationUtils.validateLength(
            value,
            maxLength: 150,
            fieldName: 'Beskrivning',
          ),
          onChanged: viewModel.updateBio,
        ),
        if (viewModel.bioError != null)
          Padding(
            padding: const EdgeInsets.only(top: AppDimensions.spacingXs),
            child: Text(
              viewModel.bioError!,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppColors.error,
                  ),
            ),
          ),
      ],
    );
  }

  Widget _buildPrivacySettings(UserProfileViewModel viewModel) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Integritetsinställningar',
          style: AppTextStyles.titleMedium,
        ),
        const SizedBox(height: AppDimensions.spacingL),
        Container(
          decoration: BoxDecoration(
            border: Border.all(color: Theme.of(context).colorScheme.outline),
            borderRadius: BorderRadius.circular(AppDimensions.borderRadiusM),
          ),
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

  Widget _buildActionButtons(UserProfileViewModel viewModel) {
    return Column(
      children: [
        // Save button
        SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            onPressed: viewModel.isLoading || !viewModel.isFormValid
                ? null
                : _saveProfile,
            icon: viewModel.isLoading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.save),
            label: Text(
              viewModel.isLoading ? 'Sparar...' : 'Spara profil',
            ),
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.primaryBlue,
              foregroundColor: AppColors.cardWhite,
              minimumSize: const Size(double.infinity, AppDimensions.buttonHeight),
              padding: const EdgeInsets.symmetric(horizontal: AppDimensions.paddingL, vertical: AppDimensions.paddingM),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppDimensions.borderRadiusM),
              ),
            ),
          ),
        ),

        const SizedBox(height: AppDimensions.spacingL),

        // Reset button
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: viewModel.hasUnsavedChanges
                ? () {
                    viewModel.resetForm();
                    _initializeForm(viewModel);
                    SnackBarUtils.showSuccess(context, 'Formulär återställt');
                  }
                : null,
            icon: const Icon(Icons.refresh),
            label: const Text('Återställ ändringar'),
          ),
        ),

        // Unsaved changes indicator
        if (viewModel.hasUnsavedChanges)
          Padding(
            padding: const EdgeInsets.only(top: AppDimensions.spacingL),
            child: Container(
              padding: const EdgeInsets.all(AppDimensions.spacingS),
              decoration: BoxDecoration(
                color: AppColors.warning.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(AppDimensions.borderRadiusS),
                border: Border.all(
                  color: AppColors.warning.withValues(alpha: 0.3),
                ),
              ),
              child: const Row(
                children: [
                  Icon(
                    Icons.warning_amber,
                    color: AppColors.warning,
                    size: AppDimensions.iconSizeM,
                  ),
                  SizedBox(width: AppDimensions.spacingXs),
                  Expanded(
                    child: Text(
                      'Du har osparade ändringar',
                      style: AppTextStyles.bodySmall,
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}
