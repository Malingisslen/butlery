import 'dart:async';

import 'package:flutter/material.dart';
import 'package:butlery/widgets/common/layout/butlery_page.dart';
import 'package:butlery/core/constants/routes.dart';
import 'package:butlery/core/providers/application_provider.dart';
import 'package:butlery/core/utils/snackbar_utils.dart';
import 'package:butlery/models/parsing/parsed_recipe.dart';
import 'package:butlery/models/recipe_unified.dart';
import 'package:butlery/services/import/parsers/unread_line_detector.dart';
import 'package:butlery/models/tagging/tag_result.dart';
import 'package:butlery/services/parsing/cache/parsed_recipe_cache.dart';
import 'package:butlery/services/tagging/tagging_service.dart';
import 'package:butlery/theme/app_mode_colors.dart';
import 'package:butlery/theme/app_text_styles.dart';
import 'package:butlery/utils/recipe_merge.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/core/extensions/localization_extension.dart';
import 'package:butlery/widgets/common/icons/butlery_glyph.dart';
import 'package:butlery/widgets/common/icons/butlery_icons.dart';
import 'package:butlery/widgets/common/badges/unified_badge.dart';
import 'package:butlery/widgets/common/butlery_link.dart';
import 'package:butlery/widgets/common/layout/layout_containers.dart';
import 'package:butlery/widgets/common/layout/tinted_note.dart';
import 'package:butlery/widgets/common/list/status_row.dart';
import 'package:butlery/widgets/common/section_heading.dart';
import 'package:butlery/widgets/common/utility_components.dart';

/// Preview screen for batch file import.
/// Shows parsed recipes as a selectable checklist before saving.
///
/// A recipe with lines the reader could not read is never saved with the
/// batch: it would save guessed text past the review (flows-roles-budget.md,
/// BUT-2158). Its row says how many lines, and a tap opens it in the editor,
/// where the review shows them.
class BatchImportPreview extends StatefulWidget {
  final List<Recipe> recipes;

  const BatchImportPreview({super.key, required this.recipes, this.backTo});

  /// The name of the import view that opened the preview, for the back
  /// arrow's name "Tillbaka till …" (tillganglighetshandoff:132).
  final String? backTo;

  @override
  State<BatchImportPreview> createState() => _BatchImportPreviewState();
}

/// One row of the picker. Rows are tracked by identity, not by index, because
/// a merge removes rows and would shift every index after it.
class _Row {
  Recipe recipe;
  final int unread;

  /// BUT-2317: the editor takes a recipe's import snapshot out of the cache
  /// when it opens, and the snapshot is what shows the review. The row
  /// holds the snapshot of a recipe it sends to the editor and puts it back
  /// before every open, so a second open still shows the review.
  final ParsedRecipe? reviewSnapshot;
  bool opened = false;

  _Row(this.recipe, {this.reviewSnapshot})
    : unread = recipe.ingredients.where(UnreadLineDetector.isUnread).length;
}

class _BatchImportPreviewState extends State<BatchImportPreview> {
  late List<_Row> _rows;
  final Set<_Row> _selected = {};

  Iterable<_Row> get _batchRows => _rows.where((r) => r.unread == 0);

  @override
  void initState() {
    super.initState();
    final cache = ServiceLocator.tryGet<ParsedRecipeCache>();
    _rows = [
      for (final recipe in widget.recipes)
        _Row(
          recipe,
          reviewSnapshot: recipe.ingredients.any(UnreadLineDetector.isUnread)
              ? cache?.retrieve(recipe.id)
              : null,
        ),
    ];
    _selected.addAll(_batchRows);
  }

  bool get _allSelected =>
      _batchRows.isNotEmpty && _selected.length == _batchRows.length;

  void _toggleAll() {
    setState(() {
      if (_allSelected) {
        _selected.clear();
      } else {
        _selected.addAll(_batchRows);
      }
    });
  }

  Future<void> _openForReview(_Row row) async {
    setState(() => row.opened = true);
    final snapshot = row.reviewSnapshot;
    if (snapshot != null) {
      ServiceLocator.tryGet<ParsedRecipeCache>()?.store(
        row.recipe.id,
        snapshot,
      );
    }
    await Navigator.of(context).pushNamed(
      Routes.manualEntry,
      arguments: {'initialRecipe': row.recipe, 'isTemplate': true},
    );
  }

  void _toggle(_Row row) {
    setState(() {
      if (!_selected.remove(row)) _selected.add(row);
    });
  }

  List<_Row> get _selectedInOrder => [
    for (final row in _rows)
      if (_selected.contains(row)) row,
  ];

  /// BUT-1817: a page the splitter wrongly cut in two is put back together
  /// here, before anything is saved. Reversible, so it gets an undo rather
  /// than a confirmation.
  void _mergeSelected() {
    final parts = _selectedInOrder;
    if (parts.length < 2) return;
    final previousRows = List<_Row>.of(_rows);
    final previousSelected = Set<_Row>.of(_selected);
    final merged = _Row(RecipeMerge.merge([for (final r in parts) r.recipe]));
    setState(() {
      final at = _rows.indexOf(parts.first);
      _rows = [
        for (final row in _rows)
          if (!parts.contains(row)) row,
      ]..insert(at, merged);
      _selected
        ..removeAll(parts)
        ..add(merged);
    });
    unawaited(_previewTags(merged));
    SnackBarUtils.showUndo(
      context,
      context.l10n.importMergedMessage(parts.length),
      onUndo: () {
        if (!mounted) return;
        setState(() {
          _rows = previousRows;
          _selected
            ..clear()
            ..addAll(previousSelected);
        });
      },
    );
  }

  /// The merged recipe has no preview tags (RecipeMerge clears the first
  /// part's), and the allergen-setup prompt after saving reads them. Save
  /// re-tags in full either way; a confirm before this returns only misses
  /// the prompt.
  Future<void> _previewTags(_Row row) async {
    final tagging = ServiceLocator.tryGet<TaggingService>();
    if (tagging == null) return;
    final TagResult? tags;
    try {
      tags = await tagging.generatePhase1Preview(row.recipe);
    } catch (_) {
      return;
    }
    if (!mounted || tags == null) return;
    setState(() => row.recipe = row.recipe.copyWith(tagResult: tags));
  }

  void _confirm() {
    Navigator.pop(context, [for (final row in _selectedInOrder) row.recipe]);
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final l10n = context.l10n;
    final unreadRows = _rows.where((r) => r.unread > 0).toList();
    final readyRows = _batchRows.toList();

    return ButleryPage.undersida(
      title: widget.backTo ?? l10n.importPreviewTitle,
      backTo: widget.backTo,
      actions: [
        Center(
          child: UnifiedBadge.status(
            label: l10n.importPreviewProgress(_selected.length, _rows.length),
          ),
        ),
      ],
      body: ListView(
        padding: AppDimensions.responsiveContentPadding(context),
        children: [
          TintedNote(
            child: Row(
              children: [
                ButleryIcon(ButleryIcons.file, color: cs.onSurface),
                const SizedBox(width: AppDimensions.space12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l10n.importPreviewFoundCount(_rows.length),
                        style: AppTextStyles.bodyBold.copyWith(
                          color: cs.onSurface,
                        ),
                      ),
                      Text(
                        l10n.importPreviewParsedCount(readyRows.length),
                        style: AppTextStyles.bodySmall.copyWith(
                          color: cs.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          if (unreadRows.isNotEmpty) ...[
            const SizedBox(height: AppDimensions.space16),
            SectionHeading(l10n.importPreviewUnreadHeading),
            for (final row in unreadRows)
              StatusRow(
                key: ValueKey('batch-import-unread-${_rows.indexOf(row)}'),
                leading: ButleryIcon(
                  ButleryIcons.triangleAlert,
                  size: AppDimensions.iconSizeS,
                  color: cs.error,
                ),
                title: row.recipe.title,
                detail: row.opened
                    ? l10n.importPreviewOpenedForReview
                    : l10n.importPreviewUnreadLines(row.unread),
                detailColor: row.opened ? null : cs.error,
                onTap: () => _openForReview(row),
              ),
          ],
          if (readyRows.isNotEmpty) ...[
            const SizedBox(height: AppDimensions.space16),
            Row(
              children: [
                Expanded(child: SectionHeading(l10n.importPreviewReadyHeading)),
                ButleryLink(
                  onTap: _toggleAll,
                  child: Text(
                    _allSelected
                        ? l10n.importDeselectAll
                        : l10n.importSelectAll,
                    style: AppTextStyles.labelLarge.copyWith(
                      color: context.modeColors.textLink,
                    ),
                  ),
                ),
              ],
            ),
            for (final row in readyRows)
              StatusRow(
                leading: _selected.contains(row)
                    ? ButleryIcon(
                        ButleryIcons.check,
                        size: AppDimensions.iconSizeS,
                        color: context.modeColors.success,
                      )
                    : const SizedBox.shrink(),
                title: row.recipe.title,
                detail: l10n.importPreviewSubtitle(
                  row.recipe.ingredients.length,
                  row.recipe.instructions.length,
                ),
                checked: _selected.contains(row),
                onTap: () => _toggle(row),
              ),
          ],
        ],
      ),
      bottomNavigationBar: BottomActionContainer(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (_selected.length >= 2) ...[
              UtilityComponents.outlinedButton(
                context,
                label: l10n.importMergeSelected(_selected.length),
                onPressed: _mergeSelected,
              ),
              const SizedBox(height: AppDimensions.space8),
            ],
            UtilityComponents.primaryButton(
              context,
              label: l10n.importConfirmButton(_selected.length),
              onPressed: _selected.isEmpty ? null : _confirm,
              isExpanded: true,
            ),
          ],
        ),
      ),
    );
  }
}
