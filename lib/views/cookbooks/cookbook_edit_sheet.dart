import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:butlery/core/extensions/localization_extension.dart';
import 'package:butlery/core/utils/snackbar_utils.dart';
import 'package:butlery/models/recipe_unified.dart';
import 'package:butlery/models/tagging/cookbook_details.dart';
import 'package:butlery/models/tagging/personal_tag.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/theme/app_text_styles.dart';
import 'package:butlery/viewmodels/cookbook_viewmodel.dart';
import 'package:butlery/widgets/common/buttons/action_buttons.dart';
import 'package:butlery/widgets/common/dialogs/base_dialog.dart';
import 'package:butlery/widgets/common/press_fill.dart';
import 'package:butlery/widgets/cookbooks/cookbook_cover.dart';
import 'package:butlery/widgets/image/simple_image_widget.dart';
import 'package:butlery/widgets/styled/styled_input.dart';

/// Makes [tag] a cookbook, or edits it when it already is one. True when
/// something was saved.
Future<bool> showCookbookEditSheet(
  BuildContext context, {
  required CookbookViewModel vm,
  required PersonalTag tag,
}) async {
  final saved = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Theme.of(context).colorScheme.surface,
    shape: const RoundedRectangleBorder(),
    builder: (_) => ChangeNotifierProvider<CookbookViewModel>.value(
      value: vm,
      child: CookbookEditSheet(tag: tag),
    ),
  );
  return saved ?? false;
}

class CookbookEditSheet extends StatefulWidget {
  const CookbookEditSheet({required this.tag, super.key});

  final PersonalTag tag;

  static const saveKey = ValueKey('cookbook-edit-save');

  @override
  State<CookbookEditSheet> createState() => _CookbookEditSheetState();
}

class _CookbookEditSheetState extends State<CookbookEditSheet> {
  late final TextEditingController _description;
  late CookbookCover _cover;
  bool _busy = false;

  bool get _making => !widget.tag.isCookbook;

  @override
  void initState() {
    super.initState();
    final existing = widget.tag.cookbook ?? const CookbookDetails();
    _description = TextEditingController(text: existing.description);
    _cover = existing.cover;
  }

  @override
  void dispose() {
    _description.dispose();
    super.dispose();
  }

  Future<void> _pickPhoto() async {
    final vm = context.read<CookbookViewModel>();
    setState(() => _busy = true);
    final url = await vm.pickAndUploadCoverPhoto();
    if (!mounted) return;
    setState(() {
      _busy = false;
      if (url != null) {
        _cover = CookbookCover(
          kind: CookbookCoverKind.photo,
          colorKey: _cover.colorKey,
          imageUrl: url,
        );
      }
    });
    if (url == null && vm.error != null) {
      SnackBarUtils.showWarning(context, vm.error!);
    }
  }

  Future<void> _save() async {
    final vm = context.read<CookbookViewModel>();
    // The latest copy, so an order or note changed elsewhere while the sheet
    // was open is not written back.
    final current = vm.tagById(widget.tag.id) ?? widget.tag;
    final base = current.cookbook ?? const CookbookDetails();
    setState(() => _busy = true);
    final ok = await vm.save(
      current,
      base.copyWith(description: _description.text.trim(), cover: _cover),
    );
    if (!mounted) return;
    setState(() => _busy = false);
    if (ok) {
      Navigator.of(context).pop(true);
    } else if (vm.error != null) {
      SnackBarUtils.showWarning(context, vm.error!);
    }
  }

  Future<void> _remove() async {
    final l10n = context.l10n;
    final confirmed = await ConfirmationDialog.show(
      context,
      title: l10n.cookbookRemove,
      message: l10n.cookbookRemoveBody,
      primaryActionText: l10n.cookbookRemove,
      secondaryActionText: l10n.commonCancel,
      isDangerous: true,
    );
    if (confirmed != true || !mounted) return;
    final vm = context.read<CookbookViewModel>();
    final ok = await vm.remove(widget.tag);
    if (!mounted) return;
    if (ok) {
      Navigator.of(context).pop(true);
    } else if (vm.error != null) {
      SnackBarUtils.showWarning(context, vm.error!);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final vm = context.watch<CookbookViewModel>();
    final recipesWithPhotos = vm
        .recipesIn(widget.tag)
        .where((r) => CookbookViewModel.recipePhoto(r) != null)
        .toList();

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppDimensions.spacingMd),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                _making ? l10n.cookbookMakeTitle : l10n.cookbookEditTitle,
                style: AppTextStyles.titleLarge,
              ),
              if (_making) ...[
                const SizedBox(height: AppDimensions.spacingXs),
                Text(
                  l10n.cookbookMakeIntro(widget.tag.name),
                  style: AppTextStyles.bodyMediumMuted,
                ),
              ],
              const SizedBox(height: AppDimensions.spacingMd),
              StyledInput(
                label: l10n.cookbookDescriptionLabel,
                controller: _description,
                maxLength: CookbookDetails.maxDescriptionLength,
                maxLines: 4,
                minLines: 2,
              ),
              const SizedBox(height: AppDimensions.spacingMd),
              Text(
                l10n.cookbookCoverLabel,
                style: AppTextStyles.sectionLabel.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: AppDimensions.spacingSm),
              _CoverKindPicker(
                selected: _cover.kind,
                onSelected: (kind) => setState(
                  () => _cover = CookbookCover(
                    kind: kind,
                    colorKey: _cover.colorKey,
                    imageUrl: kind == CookbookCoverKind.photo
                        ? _cover.imageUrl
                        : null,
                    recipeId: kind == CookbookCoverKind.recipe
                        ? _cover.recipeId
                        : null,
                  ),
                ),
              ),
              const SizedBox(height: AppDimensions.spacingSm),
              if (_cover.kind == CookbookCoverKind.photo)
                ActionButtons.outlinedButton(
                  context,
                  label: l10n.cookbookChoosePhoto,
                  isLoading: _busy,
                  onPressed: _busy ? null : _pickPhoto,
                ),
              if (_cover.kind == CookbookCoverKind.recipe)
                _RecipePhotoPicker(
                  recipes: recipesWithPhotos,
                  selectedId: _cover.recipeId,
                  onSelected: (id) => setState(
                    () => _cover = CookbookCover(
                      kind: CookbookCoverKind.recipe,
                      colorKey: _cover.colorKey,
                      recipeId: id,
                    ),
                  ),
                ),
              const SizedBox(height: AppDimensions.spacingSm),
              _SwatchRow(
                selectedKey: _cover.colorKey,
                onSelected: (key) => setState(
                  () => _cover = CookbookCover(
                    kind: _cover.kind,
                    colorKey: key,
                    imageUrl: _cover.imageUrl,
                    recipeId: _cover.recipeId,
                  ),
                ),
              ),
              const SizedBox(height: AppDimensions.spacingMd),
              SizedBox(
                height: AppDimensions.buttonHeight * 2,
                child: CookbookCoverView(
                  name: widget.tag.name,
                  cover: _cover,
                  imageUrl: _previewUrl(recipesWithPhotos),
                ),
              ),
              const SizedBox(height: AppDimensions.spacingMd),
              KeyedSubtree(
                key: CookbookEditSheet.saveKey,
                child: ActionButtons.primaryButton(
                  context,
                  label: _making ? l10n.cookbookCreate : l10n.cookbookSave,
                  isExpanded: true,
                  isLoading: _busy,
                  onPressed: _busy ? null : _save,
                ),
              ),
              if (!_making)
                ActionButtons.textButton(
                  context,
                  label: l10n.cookbookRemove,
                  onPressed: _busy ? null : _remove,
                ),
            ],
          ),
        ),
      ),
    );
  }

  String? _previewUrl(List<Recipe> withPhotos) {
    switch (_cover.kind) {
      case CookbookCoverKind.color:
        return null;
      case CookbookCoverKind.photo:
        return _cover.imageUrl;
      case CookbookCoverKind.recipe:
        for (final r in withPhotos) {
          if (r.id == _cover.recipeId) return CookbookViewModel.recipePhoto(r);
        }
        return null;
    }
  }
}

class _CoverKindPicker extends StatelessWidget {
  const _CoverKindPicker({required this.selected, required this.onSelected});

  final CookbookCoverKind selected;
  final ValueChanged<CookbookCoverKind> onSelected;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    String label(CookbookCoverKind k) => switch (k) {
      CookbookCoverKind.photo => l10n.cookbookCoverOwnPhoto,
      CookbookCoverKind.recipe => l10n.cookbookCoverRecipePhoto,
      CookbookCoverKind.color => l10n.cookbookCoverColor,
    };
    return Wrap(
      spacing: AppDimensions.spacingSm,
      children: [
        for (final kind in const [
          CookbookCoverKind.photo,
          CookbookCoverKind.recipe,
          CookbookCoverKind.color,
        ])
          PressFill(
            surface: kind == selected ? PressSurface.ink : PressSurface.base,
            child: ChoiceChip(
              label: Text(label(kind)),
              selected: kind == selected,
              onSelected: (_) => onSelected(kind),
            ),
          ),
      ],
    );
  }
}

class _RecipePhotoPicker extends StatelessWidget {
  const _RecipePhotoPicker({
    required this.recipes,
    required this.selectedId,
    required this.onSelected,
  });

  final List<Recipe> recipes;
  final String? selectedId;
  final ValueChanged<String> onSelected;

  static const double thumbSize = 72;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    if (recipes.isEmpty) {
      return Text(
        l10n.cookbookNoRecipePhotos,
        style: AppTextStyles.bodyMediumMuted,
      );
    }
    final cs = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(l10n.cookbookChooseRecipePhoto, style: AppTextStyles.labelLarge),
        const SizedBox(height: AppDimensions.spacingXs),
        SizedBox(
          height: thumbSize + AppDimensions.spacingSm,
          child: ListView(
            scrollDirection: Axis.horizontal,
            children: [
              for (final r in recipes)
                Padding(
                  padding: const EdgeInsetsDirectional.only(
                    end: AppDimensions.spacingSm,
                  ),
                  child: Semantics(
                    button: true,
                    selected: r.id == selectedId,
                    label: r.title,
                    child: PressFill(
                      surface: PressSurface.base,
                      child: InkWell(
                        onTap: () => onSelected(r.id),
                        child: Container(
                          width: thumbSize,
                          height: thumbSize,
                          decoration: BoxDecoration(
                            border: Border.all(
                              color: r.id == selectedId
                                  ? cs.primary
                                  : cs.outlineVariant,
                              width: r.id == selectedId ? 3 : 1,
                            ),
                          ),
                          child: NetworkImageWidget(
                            imageUrl: CookbookViewModel.recipePhoto(r)!,
                            enableHapticFeedback: false,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _SwatchRow extends StatelessWidget {
  const _SwatchRow({required this.selectedKey, required this.onSelected});

  final String selectedKey;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Wrap(
      spacing: AppDimensions.spacingXs,
      children: [
        for (final key in CookbookCoverPalette.keys)
          Semantics(
            button: true,
            selected: key == selectedKey,
            label: CookbookCoverPalette.name(context, key),
            child: PressFill(
              surface: PressSurface.base,
              child: InkWell(
                key: ValueKey('cookbook-swatch-$key'),
                onTap: () => onSelected(key),
                child: SizedBox.square(
                  dimension: AppDimensions.minTouchTarget,
                  child: Center(
                    child: Container(
                      width: AppDimensions.iconSizeXl,
                      height: AppDimensions.iconSizeXl,
                      decoration: BoxDecoration(
                        color: CookbookCoverPalette.color(context, key),
                        shape: BoxShape.circle,
                        border: key == selectedKey
                            ? Border.all(color: cs.onSurface, width: 3)
                            : null,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
