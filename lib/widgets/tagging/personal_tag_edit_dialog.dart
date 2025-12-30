import 'package:flutter/material.dart';

import 'package:butlery/models/tagging/personal_tag.dart';
import 'package:butlery/theme/app_colors.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/theme/app_text_styles.dart';
import 'package:butlery/widgets/tagging/personal_tag_color_picker.dart';

/// Dialog for creating or editing a personal tag.
///
/// Returns the created/updated [PersonalTag] when saved, or null if cancelled.
class PersonalTagEditDialog extends StatefulWidget {
  final PersonalTag? existingTag;
  final Future<bool> Function(String name, {String? excludeId}) checkNameExists;

  const PersonalTagEditDialog({
    super.key,
    this.existingTag,
    required this.checkNameExists,
  });

  /// Shows the dialog and returns the result.
  static Future<PersonalTag?> show(
    BuildContext context, {
    PersonalTag? existingTag,
    required Future<bool> Function(String name, {String? excludeId}) checkNameExists,
  }) {
    return showDialog<PersonalTag>(
      context: context,
      builder: (context) => PersonalTagEditDialog(
        existingTag: existingTag,
        checkNameExists: checkNameExists,
      ),
    );
  }

  @override
  State<PersonalTagEditDialog> createState() => _PersonalTagEditDialogState();
}

class _PersonalTagEditDialogState extends State<PersonalTagEditDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();

  String? _selectedColor;
  String? _selectedIcon;
  bool _isChecking = false;
  bool _isSaving = false;
  String? _nameError;

  bool get _isEditing => widget.existingTag != null;

  // Available icons (emojis for simplicity)
  static const List<String> _availableIcons = [
    '🏷️', '⭐', '❤️', '🔥', '💎', '🎯', '🏠', '👨‍👩‍👧', '👵', '👴',
    '🍽️', '🥗', '🍕', '🍰', '☕', '🌿', '🥩', '🐟', '🥬', '🌶️',
    '⚡', '💪', '🎉', '📌', '✨', '🌟', '💡', '🎨', '📚', '🎵',
  ];

  @override
  void initState() {
    super.initState();
    if (widget.existingTag != null) {
      _nameController.text = widget.existingTag!.name;
      _selectedColor = widget.existingTag!.color;
      _selectedIcon = widget.existingTag!.icon;
    } else {
      // Default color for new tags
      _selectedColor = PersonalTagColors.colors.first;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _validateName(String? value) async {
    if (value == null || value.trim().isEmpty) {
      setState(() => _nameError = 'Ange ett taggnamn');
      return;
    }

    final validation = PersonalTag.validateName(value);
    if (validation != null) {
      setState(() => _nameError = validation);
      return;
    }

    // Check for duplicate name
    setState(() => _isChecking = true);
    final exists = await widget.checkNameExists(
      value.trim(),
      excludeId: widget.existingTag?.id,
    );
    setState(() {
      _isChecking = false;
      _nameError = exists ? 'En tagg med detta namn finns redan' : null;
    });
  }

  Future<void> _save() async {
    // Run validation
    await _validateName(_nameController.text);

    if (_nameError != null) return;
    if (!(_formKey.currentState?.validate() ?? false)) return;

    setState(() => _isSaving = true);

    try {
      final name = _nameController.text.trim();

      PersonalTag result;
      if (_isEditing) {
        result = widget.existingTag!.copyWith(
          name: name,
          color: _selectedColor,
          icon: _selectedIcon,
          updatedAt: DateTime.now(),
        );
      } else {
        result = PersonalTag.create(
          name: name,
          color: _selectedColor,
          icon: _selectedIcon,
        );
      }

      if (mounted) {
        Navigator.of(context).pop(result);
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: AppColors.cardWhite,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppDimensions.borderRadiusL),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 400),
        child: Padding(
          padding: const EdgeInsets.all(AppDimensions.paddingL),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                _buildHeader(),
                const Divider(height: AppDimensions.spacingXl),

                // Name field
                _buildNameField(),
                const SizedBox(height: AppDimensions.spacingL),

                // Color picker
                PersonalTagColorPicker(
                  title: 'Färg',
                  selectedColor: _selectedColor,
                  onColorSelected: (color) {
                    setState(() => _selectedColor = color);
                  },
                ),
                const SizedBox(height: AppDimensions.spacingL),

                // Icon picker
                _buildIconPicker(),
                const SizedBox(height: AppDimensions.spacingL),

                // Preview
                _buildPreview(),

                const Divider(height: AppDimensions.spacingXl),

                // Actions
                _buildActions(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      children: [
        Icon(
          _isEditing ? Icons.edit_outlined : Icons.add_circle_outline,
          color: AppColors.primaryBlue,
          size: AppDimensions.iconSizeAction,
        ),
        const SizedBox(width: AppDimensions.spacingM),
        Expanded(
          child: Text(
            _isEditing ? 'Redigera tagg' : 'Skapa ny tagg',
            style: AppTextStyles.titleLarge,
          ),
        ),
        IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ],
    );
  }

  Widget _buildNameField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Namn', style: AppTextStyles.labelMedium),
        const SizedBox(height: AppDimensions.spacingXs),
        TextFormField(
          controller: _nameController,
          autofocus: !_isEditing,
          textCapitalization: TextCapitalization.sentences,
          decoration: InputDecoration(
            hintText: 'T.ex. "Mammas recept"',
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppDimensions.borderRadiusM),
            ),
            errorText: _nameError,
            suffixIcon: _isChecking
                ? const Padding(
                    padding: EdgeInsets.all(12),
                    child: SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  )
                : null,
          ),
          maxLength: 50,
          onChanged: (value) {
            // Clear error on change, will validate on save
            if (_nameError != null) {
              setState(() => _nameError = null);
            }
          },
        ),
      ],
    );
  }

  Widget _buildIconPicker() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Ikon (valfritt)', style: AppTextStyles.labelMedium),
        const SizedBox(height: AppDimensions.spacingS),
        SizedBox(
          height: 50,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: _availableIcons.length + 1, // +1 for "no icon" option
            separatorBuilder: (_, __) =>
                const SizedBox(width: AppDimensions.spacingXs),
            itemBuilder: (context, index) {
              if (index == 0) {
                // No icon option
                final isSelected = _selectedIcon == null;
                return _buildIconOption(
                  child: const Icon(Icons.do_not_disturb_alt, size: 20),
                  isSelected: isSelected,
                  onTap: () => setState(() => _selectedIcon = null),
                  tooltip: 'Ingen ikon',
                );
              }
              final icon = _availableIcons[index - 1];
              final isSelected = _selectedIcon == icon;
              return _buildIconOption(
                child: Text(icon, style: const TextStyle(fontSize: 24)),
                isSelected: isSelected,
                onTap: () => setState(() => _selectedIcon = icon),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildIconOption({
    required Widget child,
    required bool isSelected,
    required VoidCallback onTap,
    String? tooltip,
  }) {
    final widget = GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.primaryBlue.withValues(alpha: 0.1)
              : AppColors.backgroundBeige,
          borderRadius: BorderRadius.circular(AppDimensions.borderRadiusM),
          border: Border.all(
            color: isSelected ? AppColors.primaryBlue : AppColors.divider,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Center(child: child),
      ),
    );

    if (tooltip != null) {
      return Tooltip(message: tooltip, child: widget);
    }
    return widget;
  }

  Widget _buildPreview() {
    final name = _nameController.text.trim();
    if (name.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Förhandsgranskning', style: AppTextStyles.labelMedium),
        const SizedBox(height: AppDimensions.spacingS),
        Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppDimensions.paddingM,
            vertical: AppDimensions.paddingS,
          ),
          decoration: BoxDecoration(
            color: PersonalTagColors.fromHex(_selectedColor).withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(AppDimensions.borderRadiusM),
            border: Border.all(
              color: PersonalTagColors.fromHex(_selectedColor).withValues(alpha: 0.3),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (_selectedIcon != null) ...[
                Text(_selectedIcon!, style: const TextStyle(fontSize: 16)),
                const SizedBox(width: AppDimensions.spacingXs),
              ],
              PersonalTagColorDot(color: _selectedColor),
              const SizedBox(width: AppDimensions.spacingS),
              Text(
                name,
                style: AppTextStyles.bodyMedium.copyWith(
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildActions() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        TextButton(
          onPressed: _isSaving ? null : () => Navigator.of(context).pop(),
          child: const Text('Avbryt'),
        ),
        const SizedBox(width: AppDimensions.spacingM),
        FilledButton(
          onPressed: _isSaving || _isChecking ? null : _save,
          child: _isSaving
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : Text(_isEditing ? 'Spara' : 'Skapa'),
        ),
      ],
    );
  }
}
