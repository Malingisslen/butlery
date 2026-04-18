// lib/widgets/messaging/poll_creation_dialog.dart

import 'package:flutter/material.dart';
import 'package:butlery/core/extensions/localization_extension.dart';
import 'package:butlery/models/messaging/poll.dart';
import 'package:butlery/models/recipe_unified.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/theme/app_text_styles.dart';

/// Dialog for creating a new poll in a chat conversation.
/// Supports 2-4 options, single/multiple choice toggle, and optional deadline.
///
/// When [recipeOptions] is provided, the dialog switches to recipe-mode:
/// options are locked (read-only list of recipe thumbnails + titles), the
/// question defaults to the localized "Vad ska vi äta?" prompt, and the
/// user only controls the final question wording and the multiple-choice toggle.
class PollCreationDialog extends StatefulWidget {
  final String creatorId;
  final List<Recipe>? recipeOptions;

  const PollCreationDialog({
    super.key,
    required this.creatorId,
    this.recipeOptions,
  });

  @override
  State<PollCreationDialog> createState() => _PollCreationDialogState();
}

class _PollCreationDialogState extends State<PollCreationDialog> {
  final _questionController = TextEditingController();
  final List<TextEditingController> _optionControllers = [
    TextEditingController(),
    TextEditingController(),
  ];
  bool _allowMultiple = false;
  bool _questionInitialized = false;

  bool get _isRecipeMode =>
      widget.recipeOptions != null && widget.recipeOptions!.isNotEmpty;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_questionInitialized && _isRecipeMode) {
      _questionController.text = context.l10n.askWhatToEat;
      _questionInitialized = true;
    }
  }

  @override
  void dispose() {
    _questionController.dispose();
    for (final c in _optionControllers) {
      c.dispose();
    }
    super.dispose();
  }

  bool get _isValid {
    if (_questionController.text.trim().isEmpty) return false;
    if (_isRecipeMode) return true;
    final filledOptions =
        _optionControllers.where((c) => c.text.trim().isNotEmpty).length;
    return filledOptions >= 2;
  }

  void _addOption() {
    if (_optionControllers.length >= 4) return;
    setState(() {
      _optionControllers.add(TextEditingController());
    });
  }

  void _removeOption(int index) {
    if (_optionControllers.length <= 2) return;
    setState(() {
      _optionControllers[index].dispose();
      _optionControllers.removeAt(index);
    });
  }

  void _submit() {
    if (!_isValid) return;

    late final Poll poll;
    if (_isRecipeMode) {
      final options = widget.recipeOptions!
          .map((r) => PollOption.create(
                text: r.title,
                recipeId: r.id,
                recipeImageUrl: r.primaryImageUrl,
                recipePortions: r.portions,
              ))
          .toList();
      poll = Poll.fromOptions(
        question: _questionController.text.trim(),
        options: options,
        creatorId: widget.creatorId,
        allowMultipleChoices: _allowMultiple,
      );
    } else {
      final optionTexts = _optionControllers
          .map((c) => c.text.trim())
          .where((t) => t.isNotEmpty)
          .toList();
      poll = Poll.create(
        question: _questionController.text.trim(),
        optionTexts: optionTexts,
        creatorId: widget.creatorId,
        allowMultipleChoices: _allowMultiple,
      );
    }

    Navigator.of(context).pop(poll);
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Dialog(
      shape: const RoundedRectangleBorder(
        borderRadius:
            BorderRadius.all(Radius.circular(AppDimensions.borderRadiusS)),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 400),
        child: Padding(
          padding: const EdgeInsets.all(AppDimensions.paddingL),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                _isRecipeMode
                    ? context.l10n.pickRecipesToVote
                    : context.l10n.pollCreateTitle,
                style: AppTextStyles.titleMedium,
              ),
              const SizedBox(height: AppDimensions.spacingMd),

              // Question field
              TextField(
                controller: _questionController,
                decoration: InputDecoration(
                  labelText: context.l10n.pollQuestionLabel,
                  hintText: context.l10n.pollQuestionHint,
                  border: const OutlineInputBorder(
                    borderRadius: BorderRadius.all(
                        Radius.circular(AppDimensions.borderRadiusS)),
                  ),
                  labelStyle: AppTextStyles.labelMedium
                      .copyWith(color: cs.onSurfaceVariant),
                ),
                onChanged: (_) => setState(() {}),
                maxLines: 2,
              ),
              const SizedBox(height: AppDimensions.spacingMd),

              if (_isRecipeMode)
                ..._buildRecipeOptionsList(context)
              else ...[
                // Option fields
                ...List.generate(_optionControllers.length, (index) {
                  return Padding(
                    padding:
                        const EdgeInsets.only(bottom: AppDimensions.spacingSm),
                    child: Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _optionControllers[index],
                            decoration: InputDecoration(
                              labelText:
                                  context.l10n.pollOptionLabel(index + 1),
                              border: const OutlineInputBorder(
                                borderRadius: BorderRadius.all(Radius.circular(
                                    AppDimensions.borderRadiusS)),
                              ),
                              labelStyle: AppTextStyles.labelMedium
                                  .copyWith(color: cs.onSurfaceVariant),
                            ),
                            onChanged: (_) => setState(() {}),
                          ),
                        ),
                        if (_optionControllers.length > 2)
                          IconButton(
                            onPressed: () => _removeOption(index),
                            icon: Icon(Icons.close, color: cs.error, size: 20),
                            tooltip: context.l10n.tooltipRemoveOption,
                          ),
                      ],
                    ),
                  );
                }),

                // Add option button
                if (_optionControllers.length < 4)
                  Align(
                    alignment: AlignmentDirectional.centerStart,
                    child: TextButton.icon(
                      onPressed: _addOption,
                      icon: const Icon(Icons.add, size: 18),
                      label: Text(
                        context.l10n.pollAddOption,
                        style: AppTextStyles.labelMedium
                            .copyWith(color: cs.primary),
                      ),
                    ),
                  ),
              ],

              const SizedBox(height: AppDimensions.spacingSm),

              // Multiple choice toggle
              Row(
                children: [
                  Switch(
                    value: _allowMultiple,
                    onChanged: (v) => setState(() => _allowMultiple = v),
                    activeThumbColor: cs.primary,
                  ),
                  const SizedBox(width: AppDimensions.spacingSm),
                  Text(
                    context.l10n.pollAllowMultiple,
                    style: AppTextStyles.bodyMedium,
                  ),
                ],
              ),

              const SizedBox(height: AppDimensions.spacingMd),

              // Action buttons
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: Text(
                      context.l10n.pollCancel,
                      style: AppTextStyles.labelMedium
                          .copyWith(color: cs.onSurfaceVariant),
                    ),
                  ),
                  const SizedBox(width: AppDimensions.spacingSm),
                  ElevatedButton(
                    onPressed: _isValid ? _submit : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: cs.primary,
                      foregroundColor: cs.surfaceContainerHighest,
                      shape: const RoundedRectangleBorder(
                        borderRadius: BorderRadius.all(
                            Radius.circular(AppDimensions.borderRadiusS)),
                      ),
                    ),
                    child: Text(context.l10n.pollCreate),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Read-only list of recipe options (thumbnail + title + portions). Used in
  /// recipe-mode when the VM has pre-picked the suggestions; the user only
  /// edits the question wording and the multi-choice toggle.
  List<Widget> _buildRecipeOptionsList(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final recipes = widget.recipeOptions!;
    return [
      for (final recipe in recipes)
        Padding(
          padding: const EdgeInsets.only(bottom: AppDimensions.spacingSm),
          child: Row(
            children: [
              SizedBox(
                width: 40,
                height: 40,
                child: recipe.primaryImageUrl != null
                    ? Image.network(
                        recipe.primaryImageUrl!,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => _fallbackThumb(cs),
                      )
                    : _fallbackThumb(cs),
              ),
              const SizedBox(width: AppDimensions.spacingSm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      recipe.title,
                      style: AppTextStyles.bodyMedium,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (recipe.portions != null)
                      Text(
                        '${recipe.portions} ${context.l10n.portionsUnit}',
                        style: AppTextStyles.labelSmall
                            .copyWith(color: cs.onSurfaceVariant),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
    ];
  }

  Widget _fallbackThumb(ColorScheme cs) {
    return DecoratedBox(
      decoration: BoxDecoration(color: cs.surfaceContainerHighest),
      child: Icon(
        Icons.restaurant_menu,
        color: cs.onSurfaceVariant,
        size: 20,
      ),
    );
  }
}
