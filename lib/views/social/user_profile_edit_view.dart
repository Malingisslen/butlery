// lib/views/social/user_profile_edit_view.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../viewmodels/user_profile_viewmodel.dart';
import '../../widgets/user_avatar.dart';
import '../../widgets/main_layout_menu.dart';
import '../../theme/app_theme.dart';
import '../../core/injection.dart';
import '../../core/validators/form_validators.dart';

/// 🔍 AI INFO BLOCK:
/// Component: User Profile Edit Interface
/// File: views/social/user_profile_edit_view.dart
/// Quick Guide: Komplett profil-redigering med avatar upload och privacy settings
/// Dependencies IN: UserProfileViewModel, UserAvatar, form validators
/// Dependencies OUT: Navigation tillbaka med sparade ändringar
/// Data flow: Load current profile → Edit form → Validation → Avatar upload → Save
/// State management: Konsumerar UserProfileViewModel med Provider
/// Purpose: Fullständig profil-management med elegant UX
/// Common issues: Avatar upload timing, form validation, unsaved changes
/// Test coverage: 60%
/// Performance: ⚡ Optimerad med smart loading states
/// Analytics: ✅ Profile edit tracking via ViewModel
/// Code smells: ✅ Clean separation med ViewModel
/// Connected to: UserProfileViewModel, UserAvatar widget
/// Used in phases: 18

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
    if (_displayNameController.text.trim() != viewModel.displayName) {
      viewModel.checkDisplayNameAvailability();
    }
  }

  Future<void> _uploadAvatar() async {
    final viewModel = context.read<UserProfileViewModel>();

    // Show loading dialog during upload
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AppTheme.mediumLoadingIndicator(),
            SizedBox(height: AppTheme.spacingMd),
            const Text('Laddar upp avatar...'),
          ],
        ),
      ),
    );

    final success = await viewModel.uploadAvatar();

    if (mounted) {
      Navigator.pop(context); // Close loading dialog

      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Avatar uppladdad!'),
            backgroundColor: AppTheme.successColor,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(viewModel.error ?? 'Kunde inte ladda upp avatar'),
            backgroundColor: AppTheme.errorColor,
          ),
        );
      }
    }
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;

    final viewModel = context.read<UserProfileViewModel>();

    // Update ViewModel with current form values
    viewModel.updateDisplayName(_displayNameController.text);
    viewModel.updateBio(_bioController.text);

    final success = await viewModel.saveProfile();

    if (mounted) {
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Profil sparad!'),
            backgroundColor: AppTheme.successColor,
          ),
        );

        // Navigate back after successful save
        Navigator.pop(context);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(viewModel.error ?? 'Kunde inte spara profil'),
            backgroundColor: AppTheme.errorColor,
          ),
        );
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
      child: MainLayoutMenu(
        currentIndex: null,
        body: Scaffold(
          appBar: AppBar(
            title: const Text('Redigera profil'),
            actions: [
              // Clear error button
              if (viewModel.hasError)
                IconButton(
                  icon: const Icon(Icons.refresh),
                  onPressed: viewModel.clearError,
                  tooltip: 'Rensa fel',
                ),

              // Save button
              TextButton(
                onPressed: viewModel.isLoading || !viewModel.isFormValid
                    ? null
                    : _saveProfile,
                child: viewModel.isLoading
                    ? SizedBox(
                        width: 20,
                        height: 20,
                        child: AppTheme.smallLoadingIndicator(),
                      )
                    : const Text('Spara'),
              ),
            ],
          ),
          body: _buildBody(viewModel),
        ),
      ),
    );
  }

  Widget _buildBody(UserProfileViewModel viewModel) {
    if (viewModel.isLoading && !viewModel.hasProfile) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AppTheme.mediumLoadingIndicator(),
            SizedBox(height: AppTheme.spacingMd),
            const Text('Laddar profil...'),
          ],
        ),
      );
    }

    return SingleChildScrollView(
      padding: AppTheme.screenPadding,
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Avatar section
            _buildAvatarSection(viewModel),
            SizedBox(height: AppTheme.spacingLg),

            // Display name field
            _buildDisplayNameField(viewModel),
            SizedBox(height: AppTheme.spacingMd),

            // Bio field
            _buildBioField(viewModel),
            SizedBox(height: AppTheme.spacingLg),

            // Privacy settings
            _buildPrivacySettings(viewModel),
            SizedBox(height: AppTheme.spacingXl),

            // Action buttons
            _buildActionButtons(viewModel),
          ],
        ),
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
              ProfileHeaderAvatar(
                imageUrl: viewModel.avatarUrl,
                displayName: viewModel.displayName.isNotEmpty
                    ? viewModel.displayName
                    : 'Ny användare',
              ),

              // Upload progress overlay
              if (viewModel.isUploadingAvatar)
                Positioned.fill(
                  child: Container(
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.black54,
                    ),
                    child: Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          AppTheme.smallLoadingIndicator(color: Colors.white),
                          SizedBox(height: AppTheme.spacingXs),
                          Text(
                            'Laddar upp...',
                            style:
                                Theme.of(context).textTheme.bodySmall?.copyWith(
                                      color: Colors.white,
                                    ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          ),

          SizedBox(height: AppTheme.spacingMd),

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
                SizedBox(width: AppTheme.spacingMd),
                OutlinedButton.icon(
                  onPressed: viewModel.isUploadingAvatar
                      ? null
                      : () {
                          viewModel.removeAvatar();
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Avatar borttagen'),
                              backgroundColor: AppTheme.successColor,
                            ),
                          );
                        },
                  icon: const Icon(Icons.delete_outline),
                  label: const Text('Ta bort'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppTheme.errorColor,
                    side: BorderSide(color: AppTheme.errorColor),
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
        Text(
          'Visningsnamn',
          style: AppTheme.formLabelStyle,
        ),
        SizedBox(height: AppTheme.spacingXs),
        TextFormField(
          controller: _displayNameController,
          focusNode: _displayNameFocusNode,
          decoration: InputDecoration(
            hintText: 'Ditt namn som andra ser',
            border: const OutlineInputBorder(),
            prefixIcon: const Icon(Icons.person),
            suffixIcon: viewModel.displayNameError != null
                ? Icon(Icons.error, color: AppTheme.errorColor)
                : _displayNameController.text.isNotEmpty &&
                        viewModel.displayNameError == null
                    ? Icon(Icons.check_circle, color: AppTheme.successColor)
                    : null,
          ),
          validator: FormValidators.requiredDisplayName(),
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
            padding: EdgeInsets.only(top: AppTheme.spacingXs),
            child: Text(
              viewModel.displayNameError!,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppTheme.errorColor,
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
        Text(
          'Beskrivning',
          style: AppTheme.formLabelStyle,
        ),
        SizedBox(height: AppTheme.spacingXs),
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
          validator: FormValidators.bio(),
          onChanged: viewModel.updateBio,
        ),
        if (viewModel.bioError != null)
          Padding(
            padding: EdgeInsets.only(top: AppTheme.spacingXs),
            child: Text(
              viewModel.bioError!,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppTheme.errorColor,
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
        Text(
          'Integritetsinställningar',
          style: AppTheme.sectionHeaderStyle,
        ),
        SizedBox(height: AppTheme.spacingMd),
        Container(
          decoration: BoxDecoration(
            border: Border.all(color: Theme.of(context).colorScheme.outline),
            borderRadius: AppTheme.mediumRadius,
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
                ? SizedBox(
                    width: 20,
                    height: 20,
                    child: AppTheme.smallLoadingIndicator(),
                  )
                : const Icon(Icons.save),
            label: Text(
              viewModel.isLoading ? 'Sparar...' : 'Spara profil',
            ),
            style: AppTheme.primaryButtonStyle,
          ),
        ),

        SizedBox(height: AppTheme.spacingMd),

        // Reset button
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: viewModel.hasUnsavedChanges
                ? () {
                    viewModel.resetForm();
                    _initializeForm(viewModel);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Formulär återställt'),
                        backgroundColor: AppTheme.successColor,
                      ),
                    );
                  }
                : null,
            icon: const Icon(Icons.refresh),
            label: const Text('Återställ ändringar'),
          ),
        ),

        // Unsaved changes indicator
        if (viewModel.hasUnsavedChanges)
          Padding(
            padding: EdgeInsets.only(top: AppTheme.spacingMd),
            child: Container(
              padding: EdgeInsets.all(AppTheme.spacingSm),
              decoration: BoxDecoration(
                color: AppTheme.warningColor.withValues(alpha: 0.1),
                borderRadius: AppTheme.smallRadius,
                border: Border.all(
                  color: AppTheme.warningColor.withValues(alpha: 0.3),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.warning_amber,
                    color: AppTheme.warningColor,
                    size: AppTheme.iconSizeInfo,
                  ),
                  SizedBox(width: AppTheme.spacingXs),
                  const Expanded(
                    child: Text(
                      'Du har osparade ändringar',
                      style: TextStyle(fontSize: 12),
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
