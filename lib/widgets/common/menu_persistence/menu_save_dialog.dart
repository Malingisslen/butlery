// lib/widgets/common/menu_persistence/menu_save_dialog.dart

import 'package:flutter/material.dart';
import 'package:butlery/theme/app_colors.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/theme/app_text_styles.dart';
import 'package:butlery/core/validators/form_validators.dart';
import 'package:butlery/viewmodels/menu_viewmodel.dart';

/// Dialog for saving a menu with name, comment and social sharing
///
/// This dialog allows users to save their generated menus with custom names,
/// optional comments, and social sharing options.
class SaveMenuDialog extends StatefulWidget {
  final MenuViewModel viewModel;
  final List<dynamic>? availableFriends;

  const SaveMenuDialog({
    super.key,
    required this.viewModel,
    this.availableFriends,
  });

  @override
  State<SaveMenuDialog> createState() => _SaveMenuDialogState();
}

class _SaveMenuDialogState extends State<SaveMenuDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _commentController = TextEditingController();
  bool _isLoading = false;
  bool _enableSocialSharing = false;
  final List<String> _selectedFriendIds = [];
  final _shareMessageController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _shareMessageController.text = 'Kolla min nya veckomeny!';
  }

  @override
  void dispose() {
    _nameController.dispose();
    _commentController.dispose();
    _shareMessageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Spara meny'),
      content: SizedBox(
        width: double.maxFinite,
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildMenuInfo(),
                const SizedBox(height: AppDimensions.spacingXl),
                _buildNameField(),
                const SizedBox(height: AppDimensions.spacingXl),
                _buildCommentField(),
                const SizedBox(height: AppDimensions.spacingXl),
                _buildSocialSharingToggle(),
                if (_enableSocialSharing) ...[
                  const SizedBox(height: AppDimensions.spacingXl),
                  _buildFriendSelection(),
                  const SizedBox(height: AppDimensions.spacingXl),
                  _buildShareMessage(),
                ],
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isLoading ? null : () => Navigator.pop(context),
          child: const Text('Avbryt'),
        ),
        FilledButton(
          onPressed: _isLoading ? null : _saveMenu,
          child: _isLoading
              ? SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation(
                      Theme.of(context).colorScheme.onPrimary,
                    ),
                  ),
                )
              : const Text('Spara'),
        ),
      ],
    );
  }

  Widget _buildMenuInfo() {
    return Container(
      padding: const EdgeInsets.all(AppDimensions.spacingL),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(AppDimensions.borderRadiusM),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Meny att spara',
            style: AppTextStyles.bodyLarge.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: AppDimensions.spacingXs),
          Text(
            '${widget.viewModel.totalRecipeCount} recept i ${widget.viewModel.menu.length} kategorier',
            style: AppTextStyles.bodySmall,
          ),
        ],
      ),
    );
  }

  Widget _buildNameField() {
    return TextFormField(
      controller: _nameController,
      decoration: const InputDecoration(
        labelText: 'Menynamn',
        hintText: 'T.ex. Vecka 45 eller Helgmeny',
        border: OutlineInputBorder(),
        prefixIcon: Icon(Icons.restaurant_menu),
      ),
      validator: FormValidators.required('Menynamn krävs'),
      maxLength: 50,
      enabled: !_isLoading,
    );
  }

  Widget _buildCommentField() {
    return TextFormField(
      controller: _commentController,
      decoration: const InputDecoration(
        labelText: 'Kommentar (valfritt)',
        hintText: 'Beskrivning eller noteringar om menyn',
        border: OutlineInputBorder(),
        prefixIcon: Icon(Icons.comment),
      ),
      maxLines: 3,
      maxLength: 200,
      enabled: !_isLoading,
    );
  }

  Widget _buildSocialSharingToggle() {
    return SwitchListTile(
      title: const Text('Dela med vänner'),
      subtitle: const Text('Dela denna meny med valda vänner'),
      value: _enableSocialSharing,
      onChanged: _isLoading ? null : (value) {
        if (mounted) setState(() {
          _enableSocialSharing = value;
          if (!value) {
            _selectedFriendIds.clear();
          }
        });
      },
    );
  }

  Widget _buildFriendSelection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Välj vänner att dela med',
          style: AppTextStyles.bodyLarge.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: AppDimensions.spacingXs),
        Container(
          height: 100,
          decoration: BoxDecoration(
            border: Border.all(color: Theme.of(context).colorScheme.outline),
            borderRadius: BorderRadius.circular(AppDimensions.borderRadiusM),
          ),
          child: const Center(
            child: Text(
              'Vänlistor inte tillgängliga',
              style: TextStyle(color: AppColors.textMedium),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildShareMessage() {
    return TextFormField(
      controller: _shareMessageController,
      decoration: const InputDecoration(
        labelText: 'Delningsmeddelande',
        hintText: 'Meddelande som skickas med menyn',
        border: OutlineInputBorder(),
        prefixIcon: Icon(Icons.message),
      ),
      maxLines: 2,
      maxLength: 100,
      enabled: !_isLoading,
    );
  }

  Future<void> _saveMenu() async {
    if (!_formKey.currentState!.validate()) return;

    if (mounted) setState(() {
      _isLoading = true;
    });

    try {
      // FIXED: Use actual ViewModel save logic
      final success = await widget.viewModel.saveMenuWithNameAndComment(
        _nameController.text,
        _commentController.text,
        shareWithFriends: _enableSocialSharing,
        selectedFriendIds: _selectedFriendIds,
        shareMessage: _shareMessageController.text,
      );
      
      if (mounted) {
        Navigator.pop(context);
        if (success) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Meny "${_nameController.text}" sparad!'),
              backgroundColor: AppColors.success,
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(widget.viewModel.error ?? 'Kunde inte spara meny'),
              backgroundColor: AppColors.error,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        if (mounted) setState(() {
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Fel vid sparande: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }
}