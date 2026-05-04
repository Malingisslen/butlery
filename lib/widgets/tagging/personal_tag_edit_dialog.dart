import 'package:clock/clock.dart';
import 'package:flutter/material.dart';

import 'package:butlery/core/extensions/localization_extension.dart';
import 'package:butlery/models/tagging/personal_tag.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/theme/app_text_styles.dart';

/// Result from tag edit dialog including wizard flow choice.
class PersonalTagEditResult {
  final PersonalTag tag;
  final bool shouldCreateRule;

  const PersonalTagEditResult({
    required this.tag,
    this.shouldCreateRule = false,
  });
}

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
    required Future<bool> Function(String name, {String? excludeId})
        checkNameExists,
  }) {
    return showDialog<PersonalTag>(
      context: context,
      builder: (context) => PersonalTagEditDialog(
        existingTag: existingTag,
        checkNameExists: checkNameExists,
      ),
    );
  }

  /// Shows the dialog with wizard flow for new tags.
  ///
  /// After creating a new tag, prompts user to add an automation rule.
  /// Returns [PersonalTagEditResult] with tag and wizard choice.
  static Future<PersonalTagEditResult?> showWithWizard(
    BuildContext context, {
    PersonalTag? existingTag,
    required Future<bool> Function(String name, {String? excludeId})
        checkNameExists,
  }) async {
    final tag = await show(
      context,
      existingTag: existingTag,
      checkNameExists: checkNameExists,
    );

    if (tag == null) return null;

    // Only show wizard for NEW tags (not when editing)
    if (existingTag != null) {
      return PersonalTagEditResult(tag: tag, shouldCreateRule: false);
    }

    // Check if context is still valid after first dialog
    if (!context.mounted) {
      return PersonalTagEditResult(tag: tag, shouldCreateRule: false);
    }

    // Show wizard prompt for new tags
    final shouldCreateRule = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(context.l10n.personalTagWizardAddRule),
        content: Text(
          context.l10n.personalTagWizardAddRuleMessage(tag.name),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(context.l10n.personalTagWizardLater),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(context.l10n.personalTagWizardYesCreateRule),
          ),
        ],
      ),
    );

    return PersonalTagEditResult(
      tag: tag,
      shouldCreateRule: shouldCreateRule ?? false,
    );
  }

  @override
  State<PersonalTagEditDialog> createState() => _PersonalTagEditDialogState();
}

class _PersonalTagEditDialogState extends State<PersonalTagEditDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();

  bool _isChecking = false;
  bool _isSaving = false;
  String? _nameError;

  bool get _isEditing => widget.existingTag != null;

  @override
  void initState() {
    super.initState();
    if (widget.existingTag != null) {
      _nameController.text = widget.existingTag!.name;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _validateName(String? value) async {
    if (value == null || value.trim().isEmpty) {
      setState(() => _nameError = context.l10n.tagDetailNameRequired);
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
    if (!mounted) return;
    setState(() {
      _isChecking = false;
      _nameError = exists ? context.l10n.tagAlreadyExists : null;
    });
  }

  Future<void> _save() async {
    // Run validation
    await _validateName(_nameController.text);

    if (_nameError != null || !mounted) return;
    if (!(_formKey.currentState?.validate() ?? false)) return;

    setState(() => _isSaving = true);

    try {
      final name = _nameController.text.trim();

      PersonalTag result;
      if (_isEditing) {
        result = widget.existingTag!.copyWith(
          name: name,
          updatedAt: clock.now(),
        );
      } else {
        result = PersonalTag.create(name: name);
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
    final cs = Theme.of(context).colorScheme;
    return Dialog(
      backgroundColor: cs.surfaceContainerHighest,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppDimensions.borderRadiusL),
      ),
      child: ConstrainedBox(
        constraints:
            const BoxConstraints(maxWidth: AppDimensions.dialogMaxHeightSmall),
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
    final cs = Theme.of(context).colorScheme;
    return Row(
      children: [
        Icon(
          _isEditing ? Icons.edit_outlined : Icons.add_circle_outline,
          color: cs.primary,
          size: AppDimensions.iconSizeAction,
        ),
        const SizedBox(width: AppDimensions.spacingM),
        Expanded(
          child: Semantics(
            header: true,
            child: Text(
              _isEditing
                  ? context.l10n.personalTagEditTag
                  : context.l10n.personalTagCreateTag,
              style: AppTextStyles.titleLarge,
            ),
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
        Text(context.l10n.commonName, style: AppTextStyles.labelMedium),
        const SizedBox(height: AppDimensions.spacingXs),
        TextFormField(
          controller: _nameController,
          autofocus: !_isEditing,
          textCapitalization: TextCapitalization.sentences,
          decoration: InputDecoration(
            labelText: context.l10n.commonName,
            hintText: context.l10n.personalTagNameHint,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppDimensions.borderRadiusM),
            ),
            errorText: _nameError,
            suffixIcon: _isChecking
                ? const Padding(
                    padding: EdgeInsets.all(AppDimensions.paddingM),
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

  Widget _buildPreview() {
    final name = _nameController.text.trim();
    if (name.isEmpty) return const SizedBox.shrink();

    final cs = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(context.l10n.personalTagPreview, style: AppTextStyles.labelMedium),
        const SizedBox(height: AppDimensions.spacingS),
        Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppDimensions.paddingM,
            vertical: AppDimensions.paddingS,
          ),
          decoration: BoxDecoration(
            color:
                cs.primary.withValues(alpha: AppDimensions.opacityLightSubtle),
            borderRadius: BorderRadius.circular(AppDimensions.borderRadiusM),
            border: Border.all(
              color: cs.primary
                  .withValues(alpha: AppDimensions.opacityMediumLight),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.label,
                size: AppDimensions.iconSizeS,
                color: cs.primary,
              ),
              const SizedBox(width: AppDimensions.spacingS),
              Text(
                name,
                style: AppTextStyles.contentLabel,
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
          child: Text(context.l10n.commonCancel),
        ),
        const SizedBox(width: AppDimensions.spacingM),
        FilledButton(
          onPressed: _isSaving || _isChecking ? null : _save,
          child: _isSaving
              ? SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Theme.of(context).colorScheme.onPrimary,
                  ),
                )
              : Text(_isEditing
                  ? context.l10n.commonSave
                  : context.l10n.commonCreate),
        ),
      ],
    );
  }
}
