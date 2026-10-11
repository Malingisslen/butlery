import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:butlery/core/extensions/default_value_extensions.dart';
import 'package:butlery/core/extensions/localization_extension.dart';
import 'package:butlery/core/utils/snackbar_utils.dart';
import 'package:butlery/models/recipe_unified.dart';
import 'package:butlery/models/tagging/cookbook_details.dart';
import 'package:butlery/models/tagging/personal_tag.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/theme/app_text_styles.dart';
import 'package:butlery/viewmodels/cookbook_viewmodel.dart';
import 'package:butlery/widgets/common/buttons/action_buttons.dart';
import 'package:butlery/widgets/styled/styled_input.dart';

/// "Lägg till recept": tick several recipes that are not in the book yet.
Future<void> showAddRecipesSheet(
  BuildContext context, {
  required CookbookViewModel vm,
  required PersonalTag tag,
}) async {
  final added = await showModalBottomSheet<int>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Theme.of(context).colorScheme.surface,
    shape: const RoundedRectangleBorder(),
    builder: (_) => ChangeNotifierProvider<CookbookViewModel>.value(
      value: vm,
      child: CookbookRecipePickerSheet(tag: tag),
    ),
  );
  if (!context.mounted || added == null) return;
  if (added > 0) {
    SnackBarUtils.showSuccess(context, context.l10n.cookbookAdded(added));
  }
  if (vm.error != null) SnackBarUtils.showWarning(context, vm.error!);
}

class CookbookRecipePickerSheet extends StatefulWidget {
  const CookbookRecipePickerSheet({required this.tag, super.key});

  final PersonalTag tag;

  static const confirmKey = ValueKey('cookbook-picker-confirm');

  @override
  State<CookbookRecipePickerSheet> createState() =>
      _CookbookRecipePickerSheetState();
}

class _CookbookRecipePickerSheetState extends State<CookbookRecipePickerSheet> {
  final Set<String> _ticked = {};
  bool _busy = false;

  Future<void> _add(List<Recipe> candidates) async {
    final vm = context.read<CookbookViewModel>();
    setState(() => _busy = true);
    // Ticked order follows the A–Ö list, so they land last in that order.
    final chosen = candidates.where((r) => _ticked.contains(r.id)).toList();
    final added = await vm.addRecipes(widget.tag, chosen);
    if (!mounted) return;
    Navigator.of(context).pop(added ?? 0);
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<CookbookViewModel>();
    final l10n = context.l10n;
    final candidates = vm.recipesNotIn(widget.tag);

    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.85,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.all(AppDimensions.spacingMd),
              child: Text(
                l10n.cookbookAddRecipes,
                style: AppTextStyles.titleLarge,
              ),
            ),
            if (candidates.isEmpty)
              Padding(
                padding: const EdgeInsets.all(AppDimensions.spacingMd),
                child: Text(l10n.cookbookPickerEmpty),
              )
            else
              Flexible(
                child: ListView(
                  shrinkWrap: true,
                  children: [
                    for (final r in candidates)
                      CheckboxListTile(
                        value: _ticked.contains(r.id),
                        title: Text(r.title),
                        onChanged: _busy
                            ? null
                            : (on) => setState(
                                () => on == true
                                    ? _ticked.add(r.id)
                                    : _ticked.remove(r.id),
                              ),
                      ),
                  ],
                ),
              ),
            Padding(
              padding: const EdgeInsets.all(AppDimensions.spacingMd),
              child: KeyedSubtree(
                key: CookbookRecipePickerSheet.confirmKey,
                child: ActionButtons.primaryButton(
                  context,
                  label: l10n.cookbookPickerAdd(_ticked.length),
                  isExpanded: true,
                  isLoading: _busy,
                  onPressed: _ticked.isEmpty || _busy
                      ? null
                      : () => _add(candidates),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The book's own text for one recipe. Saving an empty text removes it.
Future<void> showCookbookNoteDialog(
  BuildContext context, {
  required CookbookViewModel vm,
  required PersonalTag tag,
  required Recipe recipe,
}) async {
  final text = await showDialog<String>(
    context: context,
    builder: (_) => _CookbookNoteDialog(
      title: recipe.title,
      initial: (tag.cookbook?.noteFor(recipe.id)).orEmpty(),
    ),
  );
  if (text == null || !context.mounted) return;
  final ok = await vm.setNote(tag, recipe.id, text);
  if (!ok && context.mounted && vm.error != null) {
    SnackBarUtils.showWarning(context, vm.error!);
  }
}

/// Owns its controller so the field can still unmount during the exit
/// animation after the dialog's future has completed.
class _CookbookNoteDialog extends StatefulWidget {
  const _CookbookNoteDialog({required this.title, required this.initial});

  final String title;
  final String initial;

  @override
  State<_CookbookNoteDialog> createState() => _CookbookNoteDialogState();
}

class _CookbookNoteDialogState extends State<_CookbookNoteDialog> {
  late final TextEditingController _controller = TextEditingController(
    text: widget.initial,
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return AlertDialog(
      title: Text(widget.title),
      content: StyledInput(
        label: l10n.cookbookNoteLabel,
        helperText: l10n.cookbookNoteHelper,
        controller: _controller,
        maxLength: CookbookDetails.maxNoteLength,
        maxLines: 5,
        minLines: 2,
        autofocus: true,
      ),
      actions: [
        ActionButtons.textButton(
          context,
          label: l10n.commonCancel,
          onPressed: () => Navigator.of(context).pop(),
        ),
        ActionButtons.primaryButton(
          context,
          label: l10n.cookbookSave,
          onPressed: () => Navigator.of(context).pop(_controller.text),
        ),
      ],
    );
  }
}
