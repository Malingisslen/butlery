import 'dart:async';

import 'package:flutter/material.dart';
import 'package:butlery/core/constants/routes.dart';
import 'package:butlery/core/providers/application_provider.dart';
import 'package:butlery/core/utils/snackbar_utils.dart';
import 'package:butlery/models/parsing/parsed_recipe.dart';
import 'package:butlery/models/recipe_unified.dart';
import 'package:butlery/services/import/parsers/unread_line_detector.dart';
import 'package:butlery/models/tagging/tag_result.dart';
import 'package:butlery/services/parsing/cache/parsed_recipe_cache.dart';
import 'package:butlery/services/tagging/tagging_service.dart';
import 'package:butlery/theme/app_text_styles.dart';
import 'package:butlery/utils/recipe_merge.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/core/extensions/localization_extension.dart';
import 'package:butlery/widgets/common/butlery_top_bar.dart';
import 'package:butlery/widgets/common/icons/butlery_glyph.dart';
import 'package:butlery/widgets/common/icons/butlery_icons.dart';

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

    return Scaffold(
      // A subpage (Komponentark v1:71-78; B-45): the back arrow and the title
      // on the canonical top bar, left-aligned as drawn (v1:73).
      appBar: ButleryTopBar.undersida(
        title: context.l10n.importPreviewTitle,
        backTo: widget.backTo,
        actions: [
          TextButton.icon(
            onPressed: _toggleAll,
            icon: ButleryIcon(
              _allSelected ? ButleryIcons.square : ButleryIcons.checkSquare,
              size: AppDimensions.iconSizeS,
            ),
            label: Text(
              _allSelected
                  ? context.l10n.importDeselectAll
                  : context.l10n.importSelectAll,
            ),
          ),
        ],
      ),
      body: ListView.builder(
        padding: AppDimensions.responsiveContentPadding(context),
        itemCount: _rows.length,
        itemBuilder: (context, index) {
          final row = _rows[index];
          final recipe = row.recipe;
          final unread = row.unread;

          if (unread > 0) {
            return ListTile(
              key: ValueKey('batch-import-unread-$index'),
              onTap: () => _openForReview(row),
              title: Text(
                recipe.title,
                style: AppTextStyles.titleSmall,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              subtitle: Text(
                row.opened
                    ? context.l10n.importPreviewOpenedForReview
                    : context.l10n.importPreviewUnreadLines(unread),
                style: AppTextStyles.bodySmall.copyWith(
                  color: cs.onSurfaceVariant,
                ),
              ),
              trailing: const ButleryIcon(ButleryIcons.chevronRight),
            );
          }

          return CheckboxListTile(
            value: _selected.contains(row),
            onChanged: (_) => _toggle(row),
            activeColor: cs.primary,
            title: Text(
              recipe.title,
              style: AppTextStyles.titleSmall,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            subtitle: Text(
              context.l10n.importPreviewSubtitle(
                recipe.ingredients.length,
                recipe.instructions.length,
              ),
              style: AppTextStyles.bodySmall.copyWith(
                color: cs.onSurfaceVariant,
              ),
            ),
          );
        },
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppDimensions.spacingMd),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (_selected.length >= 2) ...[
                OutlinedButton(
                  onPressed: _mergeSelected,
                  child: Text(
                    context.l10n.importMergeSelected(_selected.length),
                  ),
                ),
                const SizedBox(height: AppDimensions.spacingSm),
              ],
              FilledButton.icon(
                onPressed: _selected.isEmpty ? null : _confirm,
                icon: const ButleryIcon(ButleryIcons.download),
                label: Text(context.l10n.importConfirmButton(_selected.length)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
