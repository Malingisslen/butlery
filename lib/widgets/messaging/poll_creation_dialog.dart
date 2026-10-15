// lib/widgets/messaging/poll_creation_dialog.dart

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:butlery/widgets/common/dialogs/butlery_dialog_frame.dart';
import 'package:butlery/core/extensions/localization_extension.dart';
import 'package:butlery/core/utils/firebase_url_utils.dart';
import 'package:butlery/models/messaging/poll.dart';
import 'package:butlery/models/recipe_unified.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/theme/app_text_styles.dart';
import 'package:butlery/widgets/common/buttons/action_buttons.dart';
import 'package:butlery/widgets/common/buttons/butlery_text_button.dart';
import 'package:butlery/widgets/common/icons/butlery_glyph.dart';
import 'package:butlery/widgets/styled/labeled_field.dart';
import 'package:butlery/widgets/styled/styled_input.dart';
import 'package:butlery/widgets/common/icons/butlery_icons.dart';
import 'package:butlery/widgets/common/input/butlery_switch.dart';

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
    final filledOptions = _optionControllers
        .where((c) => c.text.trim().isNotEmpty)
        .length;
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
          .map(
            (r) => PollOption.create(
              text: r.title,
              recipeId: r.id,
              recipeImageUrl: r.primaryImageUrl,
              recipePortions: r.portions,
            ),
          )
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
    return ButleryDialogFrame(
      // Scrolls when the fields are taller than the space the dialog gets,
      // such as with the keyboard up.
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(AppDimensions.space16),
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
            const SizedBox(height: AppDimensions.space16),

            StyledInput(
              label: context.l10n.pollQuestionLabel,
              hint: context.l10n.pollQuestionHint,
              controller: _questionController,
              onChanged: (_) => setState(() {}),
              maxLines: 2,
            ),
            const SizedBox(height: AppDimensions.space16),

            if (_isRecipeMode)
              ..._buildRecipeOptionsList(context)
            else ...[
              ...List.generate(_optionControllers.length, (index) {
                return Padding(
                  padding: const EdgeInsets.only(
                    bottom: AppDimensions.space8,
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Expanded(
                        child: LabeledField(
                          label: context.l10n.pollOptionLabel(
                            index + 1,
                          ),
                          child: TextField(
                            controller: _optionControllers[index],
                            onChanged: (_) => setState(() {}),
                          ),
                        ),
                      ),
                      if (_optionControllers.length > 2)
                        AppIconButton(
                          icon: ButleryIcons.x,
                          color: cs.error,
                          iconSize: AppDimensions.iconSizeM,
                          semanticLabel: context.l10n.tooltipRemoveOption,
                          onPressed: () => _removeOption(index),
                        ),
                    ],
                  ),
                );
              }),

              if (_optionControllers.length < 4)
                Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: ButleryTextButton(
                    label: context.l10n.pollAddOption,
                    icon: ButleryIcons.plus,
                    onPressed: _addOption,
                  ),
                ),
            ],

            const SizedBox(height: AppDimensions.space8),

            Row(
              children: [
                // The theme's switch: ink track, paper knob when on
                // (feedback_themes.dart switchTheme). An ink knob on the
                // ink track vanished in both modes.
                ButlerySwitch(
                  value: _allowMultiple,
                  onChanged: (v) => setState(() => _allowMultiple = v),
                ),
                const SizedBox(width: AppDimensions.space8),
                Text(
                  context.l10n.pollAllowMultiple,
                  style: AppTextStyles.bodyMedium,
                ),
              ],
            ),

            const SizedBox(height: AppDimensions.space16),

            // An OverflowBar stacks the buttons when a narrow phone cannot
            // fit both on one line.
            OverflowBar(
              alignment: MainAxisAlignment.end,
              overflowAlignment: OverflowBarAlignment.end,
              spacing: AppDimensions.space8,
              overflowSpacing: AppDimensions.space8,
              children: [
                ButleryTextButton(
                  label: context.l10n.pollCancel,
                  onPressed: () => Navigator.of(context).pop(),
                ),
                ActionButtons.primaryButton(
                  context,
                  label: context.l10n.pollCreate,
                  onPressed: _isValid ? _submit : null,
                ),
              ],
            ),
          ],
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
          padding: const EdgeInsets.only(bottom: AppDimensions.space8),
          // One screen-reader stop per recipe, read as title and portions,
          // instead of folding every row into the dialog's own label.
          child: MergeSemantics(
            child: Row(
              children: [
                SizedBox(
                  width: 40,
                  height: 40,
                  child: recipe.primaryImageUrl != null
                      ? CachedNetworkImage(
                          imageUrl: recipe.primaryImageUrl!,
                          cacheKey: FirebaseUrlUtils.stableCacheKey(
                            recipe.primaryImageUrl!,
                          ),
                          fit: BoxFit.cover,
                          placeholder: (_, __) => _fallbackThumb(cs),
                          errorWidget: (_, __, ___) => _fallbackThumb(cs),
                        )
                      : _fallbackThumb(cs),
                ),
                const SizedBox(width: AppDimensions.space8),
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
                          style: AppTextStyles.labelSmall.copyWith(
                            color: cs.onSurfaceVariant,
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
    ];
  }

  Widget _fallbackThumb(ColorScheme cs) {
    return DecoratedBox(
      decoration: BoxDecoration(color: cs.surfaceContainerHighest),
      child: ButleryIcon(
        ButleryIcons.utensils,
        color: cs.onSurfaceVariant,
        size: AppDimensions.iconSizeM,
      ),
    );
  }
}
